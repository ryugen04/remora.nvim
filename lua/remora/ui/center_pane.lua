-- Center pane management for remora.nvim

local M = {}

local buffer_utils = require("remora.utils.buffer")
local window_utils = require("remora.utils.window")
local pr_home = require("remora.ui.components.pr_home")
local state = require("remora.state")
local git = require("remora.core.git")

-- 現在のdiff状態
M.current_diff = {
	file_path = nil,
	base_bufnr = nil,
	head_bufnr = nil,
	base_win = nil,
	head_win = nil,
	change_lines = {},
}

-- Show PR detail in center pane
function M.show_pr_detail()
	local layout = require("remora.ui.layout")

	-- diffがあればクリーンアップ
	M.cleanup_diff()

	if not window_utils.is_valid(layout.windows.center) then
		return
	end

	-- Create or reuse PR detail buffer
	local bufnr = buffer_utils.create_scratch({
		filetype = "remora-pr-detail",
		listed = false,
	})

	buffer_utils.set_name(bufnr, "PR Detail")

	-- Render PR detail
	local lines = pr_home.render_detail()
	buffer_utils.set_lines(bufnr, lines, { modifiable = false })

	-- Set buffer in center window
	window_utils.set_buffer(layout.windows.center, bufnr)

	-- Set up keymaps
	buffer_utils.set_keymap(bufnr, "n", "q", function()
		vim.cmd("bdelete")
	end, { desc = "Close PR detail" })
end

-- ファイルをdiff表示で開く
---@param file_path string
function M.open_file_diff(file_path)
	local layout = require("remora.ui.layout")

	if not state.current_pr then
		vim.notify("No PR loaded", vim.log.levels.WARN)
		return
	end

	if not window_utils.is_valid(layout.windows.center) then
		vim.notify("Center pane not available", vim.log.levels.WARN)
		return
	end

	local base_sha = state.current_pr.base_sha
	local head_sha = state.current_pr.head_sha

	if not base_sha or not head_sha then
		vim.notify("PR base/head SHA not available", vim.log.levels.WARN)
		return
	end

	-- 既存diffのクリーンアップ
	M.cleanup_diff()

	vim.notify(
		string.format("Fetching diff: %s (base: %s, head: %s)", file_path, base_sha:sub(1, 7), head_sha:sub(1, 7)),
		vim.log.levels.DEBUG
	)

	-- ファイル内容取得（非同期）
	M._fetch_and_display(file_path, base_sha, head_sha)
end

-- ファイル内容を取得してdiff表示
function M._fetch_and_display(file_path, base_sha, head_sha)
	local base_content_result = nil
	local head_content_result = nil
	local base_fetched = false
	local head_fetched = false
	local ref_not_found = false

	local function try_display()
		if not base_fetched or not head_fetched then
			return
		end

		-- refが見つからない場合はgit fetchを促す
		if ref_not_found then
			vim.notify(
				string.format(
					'Commit not found locally. Run "git fetch origin" first.\nbase: %s\nhead: %s',
					base_sha:sub(1, 7),
					head_sha:sub(1, 7)
				),
				vim.log.levels.WARN
			)
			return
		end

		-- diffを表示
		M._display_diff(file_path, base_content_result or "", head_content_result or "")
	end

	-- base内容取得
	git.show_file_at_ref(base_sha, file_path, function(base_content, base_err, err_type)
		base_fetched = true
		if base_err then
			if err_type == "ref_not_found" then
				ref_not_found = true
			end
			-- ファイルが存在しない場合（新規追加ファイル）は空文字列
			base_content_result = ""
		else
			base_content_result = base_content
		end
		try_display()
	end)

	-- head内容取得
	git.show_file_at_ref(head_sha, file_path, function(head_content, head_err, err_type)
		head_fetched = true
		if head_err then
			if err_type == "ref_not_found" then
				ref_not_found = true
			end
			-- ファイルが削除された場合は空文字列
			head_content_result = ""
		else
			head_content_result = head_content
		end
		try_display()
	end)
end

-- diffを表示 (モダンなside-by-side)
function M._display_diff(file_path, base_content, head_content)
	local layout = require("remora.ui.layout")
	local diff_utils = require("remora.utils.diff")
	local center_win = layout.windows.center

	if not window_utils.is_valid(center_win) then
		return
	end

	-- 中央ウィンドウをフォーカス
	vim.api.nvim_set_current_win(center_win)

	-- diff計算とアライメント
	local base_lines = vim.split(base_content, "\n", { plain = true })
	local head_lines = vim.split(head_content, "\n", { plain = true })
	local aligned = diff_utils.create_aligned_diff(base_lines, head_lines)

	-- filetypeを推測
	local filetype = vim.filetype.match({ filename = file_path }) or ""

	-- base用バッファ作成
	local base_bufnr =
		M._create_aligned_buffer(aligned.left_lines, aligned.left_hl, aligned.left_lnum, file_path, "base", filetype)
	vim.api.nvim_win_set_buf(center_win, base_bufnr)

	-- ウィンドウオプション設定
	M._setup_diff_window(center_win, "base")

	-- 垂直分割してhead用ウィンドウ作成
	vim.cmd("vsplit")
	local head_win = vim.api.nvim_get_current_win()

	-- head用バッファ作成
	local head_bufnr =
		M._create_aligned_buffer(aligned.right_lines, aligned.right_hl, aligned.right_lnum, file_path, "head", filetype)
	vim.api.nvim_win_set_buf(head_win, head_bufnr)

	-- ウィンドウオプション設定
	M._setup_diff_window(head_win, "head")

	-- スクロール同期
	vim.wo[center_win].scrollbind = true
	vim.wo[head_win].scrollbind = true
	vim.wo[center_win].cursorbind = true
	vim.wo[head_win].cursorbind = true

	-- 同期位置をリセット
	vim.cmd("syncbind")

	-- 変更行を収集
	local change_lines = {}
	for i, hl_type in ipairs(aligned.right_hl) do
		if hl_type ~= "normal" then
			table.insert(change_lines, i)
		end
	end

	-- 状態保存
	M.current_diff = {
		file_path = file_path,
		base_bufnr = base_bufnr,
		head_bufnr = head_bufnr,
		base_win = center_win,
		head_win = head_win,
		change_lines = change_lines,
	}

	layout.windows.center_diff = {
		base_win = center_win,
		head_win = head_win,
	}

	-- キーマップ設定
	M._setup_diff_keymaps(base_bufnr)
	M._setup_diff_keymaps(head_bufnr)

	-- フォーカスをhead側に
	vim.api.nvim_set_current_win(head_win)
end

-- カスタム行番号を取得
---@return string
function M.get_lnum()
	local bufnr = vim.api.nvim_get_current_buf()
	local lnum = vim.v.lnum
	local lnums = vim.b[bufnr].remora_lnums

	-- lnums[lnum]がfalse、nil、または0の場合はパディング行
	local line_num = lnums and lnums[lnum]
	if line_num and line_num ~= false and line_num > 0 then
		return string.format("%3d", line_num)
	else
		return "   "
	end
end

-- diffウィンドウのオプション設定
---@param win number
---@param side string|nil 'base' or 'head'
function M._setup_diff_window(win, side)
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "yes:1"
	vim.wo[win].foldmethod = "manual"
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].wrap = false
	vim.wo[win].cursorline = true

	-- statuscolumnでカスタム行番号とサインを表示
	vim.wo[win].statuscolumn = '%#RemoraDiffLineNr#%{v:lua.require("remora.ui.center_pane").get_lnum()}%* %s'

	-- winbarで側を表示
	if side then
		local label = side == "base" and " BASE (old)" or " HEAD (new)"
		vim.wo[win].winbar = "%#" .. (side == "base" and "RemoraDiffDelete" or "RemoraDiffAdd") .. "#" .. label .. "%*"
	end
end

-- アライメント済みバッファ作成
---@param lines table 表示行
---@param highlights table ハイライトタイプ
---@param lnums table オリジナル行番号 (falseはパディング)
---@param file_path string ファイルパス
---@param side string 'base' or 'head'
---@param filetype string ファイルタイプ
function M._create_aligned_buffer(lines, highlights, lnums, file_path, side, filetype)
	local bufnr = buffer_utils.create_scratch({
		filetype = filetype,
		listed = false,
	})

	buffer_utils.set_lines(bufnr, lines, { modifiable = false })
	buffer_utils.set_name(bufnr, string.format("remora://%s/%s", side, file_path))

	vim.bo[bufnr].bufhidden = "wipe"

	-- 行全体ハイライトマッピング
	local line_hl_map = {
		add = "RemoraDiffAdd",
		delete = "RemoraDiffDelete",
		change = side == "base" and "RemoraDiffDelete" or "RemoraDiffAdd",
		padding = "RemoraDiffPadding",
	}

	-- サインマッピング
	local sign_map = {
		add = "RemoraDiffAdd",
		delete = "RemoraDiffDelete",
		change = "RemoraDiffChange",
	}

	-- 行ハイライトとサイン適用
	local ns = vim.api.nvim_create_namespace("remora-diff-" .. side)
	local sign_group = "remora-diff-sign-" .. side

	-- 既存サインをクリア
	vim.fn.sign_unplace(sign_group, { buffer = bufnr })
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	for i, hl_type in ipairs(highlights) do
		-- 行全体ハイライト (extmark with line_hl_group)
		local line_hl = line_hl_map[hl_type]
		if line_hl then
			vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
				line_hl_group = line_hl,
				priority = 10,
			})
		end

		-- サイン配置
		local sign_name = sign_map[hl_type]
		if sign_name then
			vim.fn.sign_place(0, sign_group, sign_name, bufnr, { lnum = i, priority = 10 })
		end
	end

	-- 行番号とハイライトタイプをバッファ変数に保存（statuscolumn用）
	vim.b[bufnr].remora_lnums = lnums
	vim.b[bufnr].remora_hl_types = highlights

	return bufnr
end

-- diffバッファのキーマップ
function M._setup_diff_keymaps(bufnr)
	local opts = { buffer = bufnr, silent = true }

	-- 次の変更へ
	vim.keymap.set("n", "]c", function()
		M._jump_to_next_change(1)
	end, opts)

	-- 前の変更へ
	vim.keymap.set("n", "[c", function()
		M._jump_to_next_change(-1)
	end, opts)

	-- 閉じる
	vim.keymap.set("n", "q", function()
		M.cleanup_diff()
		local layout = require("remora.ui.layout")
		if layout.windows.center and vim.api.nvim_win_is_valid(layout.windows.center) then
			vim.api.nvim_set_current_win(layout.windows.left)
		end
	end, opts)
end

-- 次/前の変更へジャンプ
function M._jump_to_next_change(direction)
	local change_lines = M.current_diff.change_lines or {}
	if #change_lines == 0 then
		return
	end

	local row = vim.api.nvim_win_get_cursor(0)[1]

	if direction > 0 then
		-- 次の変更を探す
		for _, line in ipairs(change_lines) do
			if line > row then
				vim.api.nvim_win_set_cursor(0, { line, 0 })
				return
			end
		end
		-- 見つからなければ最初の変更へ（ラップ）
		vim.api.nvim_win_set_cursor(0, { change_lines[1], 0 })
	else
		-- 前の変更を探す
		for i = #change_lines, 1, -1 do
			if change_lines[i] < row then
				vim.api.nvim_win_set_cursor(0, { change_lines[i], 0 })
				return
			end
		end
		-- 見つからなければ最後の変更へ（ラップ）
		vim.api.nvim_win_set_cursor(0, { change_lines[#change_lines], 0 })
	end
end

-- 旧: diffバッファ作成（互換性のため残す）
function M._create_diff_buffer(content, file_path, side)
	local filetype = vim.filetype.match({ filename = file_path }) or ""

	local bufnr = buffer_utils.create_scratch({
		filetype = filetype,
		listed = false,
	})

	local lines = vim.split(content, "\n", { plain = true })
	buffer_utils.set_lines(bufnr, lines, { modifiable = false })
	buffer_utils.set_name(bufnr, string.format("remora://%s/%s", side, file_path))

	vim.bo[bufnr].bufhidden = "wipe"

	return bufnr
end

-- diffのクリーンアップ
function M.cleanup_diff()
	if M.current_diff.base_bufnr then
		-- diffモード解除
		if M.current_diff.base_win and vim.api.nvim_win_is_valid(M.current_diff.base_win) then
			vim.api.nvim_set_current_win(M.current_diff.base_win)
			pcall(vim.cmd, "diffoff")
		end
		if M.current_diff.head_win and vim.api.nvim_win_is_valid(M.current_diff.head_win) then
			vim.api.nvim_set_current_win(M.current_diff.head_win)
			pcall(vim.cmd, "diffoff")
			-- head側のウィンドウを閉じる
			pcall(vim.api.nvim_win_close, M.current_diff.head_win, true)
		end

		-- バッファ削除
		if M.current_diff.base_bufnr and vim.api.nvim_buf_is_valid(M.current_diff.base_bufnr) then
			buffer_utils.delete(M.current_diff.base_bufnr)
		end
		if M.current_diff.head_bufnr and vim.api.nvim_buf_is_valid(M.current_diff.head_bufnr) then
			buffer_utils.delete(M.current_diff.head_bufnr)
		end

		M.current_diff = {
			file_path = nil,
			base_bufnr = nil,
			head_bufnr = nil,
			base_win = nil,
			head_win = nil,
			change_lines = {},
		}
	end
end

return M

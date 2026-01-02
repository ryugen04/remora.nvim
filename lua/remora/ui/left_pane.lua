-- Left pane management for remora.nvim

local M = {}

local state = require("remora.state")
local events = require("remora.events")
local buffer_utils = require("remora.utils.buffer")
local tree = require("remora.ui.components.tree")
local pr_home = require("remora.ui.components.pr_home")
local memos = require("remora.ui.components.memos")
local local_changes = require("remora.ui.components.local_changes")

-- Pane state
M.bufnr = nil
M.ns = nil
M.line_metadata = {}

-- Initialize left pane
---@param bufnr number
function M.init(bufnr)
	M.bufnr = bufnr
	M.ns = buffer_utils.create_namespace("remora-left-pane")

	-- Set up keymaps
	M._setup_keymaps()

	-- Set up autocmds
	M._setup_autocmds()

	-- Initial render
	M.render()

	-- Listen to events
	events.on(events.PR_LOADED, function()
		M.render()
	end)

	events.on(events.PR_REFRESHED, function()
		M.render()
	end)

	events.on(events.FILE_VIEWED, function()
		M.render()
	end)

	events.on(events.FILE_REVIEWED, function()
		M.render()
	end)

	events.on(events.NOTE_ADDED, function()
		M.render()
	end)

	events.on(events.LOCAL_CHANGES_UPDATED, function()
		M.render()
	end)
end

-- Render left pane
function M.render()
	if not buffer_utils.is_valid(M.bufnr) then
		return
	end

	local lines = {}
	M.line_metadata = {}

	-- PR Home section
	table.insert(lines, "═══════════════════════════════════════")
	table.insert(M.line_metadata, { type = "separator" })

	table.insert(lines, "  PR Home")
	table.insert(M.line_metadata, { type = "section_header", section = "pr_home" })

	table.insert(lines, "═══════════════════════════════════════")
	table.insert(M.line_metadata, { type = "separator" })

	local pr_lines = pr_home.render_summary()
	for _, line in ipairs(pr_lines) do
		table.insert(lines, line)
		table.insert(M.line_metadata, { type = "pr_home" })
	end

	table.insert(lines, "")
	table.insert(M.line_metadata, { type = "blank" })

	-- Files section
	table.insert(lines, "═══════════════════════════════════════")
	table.insert(M.line_metadata, { type = "separator" })

	local view_mode = state.ui.view_mode
	table.insert(lines, string.format("  Files (%s)", view_mode))
	table.insert(M.line_metadata, { type = "section_header", section = "files" })

	table.insert(lines, "═══════════════════════════════════════")
	table.insert(M.line_metadata, { type = "separator" })

	local tree_lines, tree_metadata = tree.render(view_mode)
	for i, line in ipairs(tree_lines) do
		table.insert(lines, line)
		table.insert(M.line_metadata, tree_metadata[i])
	end

	table.insert(lines, "")
	table.insert(M.line_metadata, { type = "blank" })

	-- Local Changes section
	table.insert(lines, "═══════════════════════════════════════")
	table.insert(M.line_metadata, { type = "separator" })

	table.insert(lines, "  Local Changes")
	table.insert(M.line_metadata, { type = "section_header", section = "local_changes" })

	table.insert(lines, "═══════════════════════════════════════")
	table.insert(M.line_metadata, { type = "separator" })

	local local_lines, local_metadata = local_changes.render()
	for i, line in ipairs(local_lines) do
		table.insert(lines, line)
		table.insert(M.line_metadata, local_metadata[i])
	end

	table.insert(lines, "")
	table.insert(M.line_metadata, { type = "blank" })

	-- Memos section
	table.insert(lines, "═══════════════════════════════════════")
	table.insert(M.line_metadata, { type = "separator" })

	table.insert(lines, "  Memos")
	table.insert(M.line_metadata, { type = "section_header", section = "memos" })

	table.insert(lines, "═══════════════════════════════════════")
	table.insert(M.line_metadata, { type = "separator" })

	local memo_lines = memos.render()
	for _, line in ipairs(memo_lines) do
		table.insert(lines, line)
		table.insert(M.line_metadata, { type = "memos" })
	end

	-- Update buffer
	buffer_utils.set_lines(M.bufnr, lines, { modifiable = false })

	-- Apply highlights
	M._apply_highlights()
end

-- Apply syntax highlights
function M._apply_highlights()
	if not buffer_utils.is_valid(M.bufnr) then
		return
	end

	buffer_utils.clear_namespace(M.bufnr, M.ns)

	for line_nr, metadata in ipairs(M.line_metadata) do
		local line_idx = line_nr - 1 -- 0-indexed

		if metadata.type == "separator" then
			buffer_utils.add_highlight(M.bufnr, M.ns, "RemoraSectionSeparator", line_idx, 0, -1)
		elseif metadata.type == "section_header" then
			buffer_utils.add_highlight(M.bufnr, M.ns, "RemoraSectionTitle", line_idx, 0, -1)
		elseif metadata.type == "file" and metadata.hl_group then
			buffer_utils.add_highlight(M.bufnr, M.ns, metadata.hl_group, line_idx, 0, -1)
		elseif metadata.type == "local_file" and metadata.hl_group then
			buffer_utils.add_highlight(M.bufnr, M.ns, metadata.hl_group, line_idx, 0, -1)
		elseif metadata.type == "commit" then
			buffer_utils.add_highlight(M.bufnr, M.ns, "RemoraLocalCommit", line_idx, 0, -1)
		elseif metadata.type == "local_changes_header" then
			buffer_utils.add_highlight(M.bufnr, M.ns, "RemoraLocalHeader", line_idx, 0, -1)
		end
	end
end

-- Set up keymaps
function M._setup_keymaps()
	-- Enter: Select file/item
	buffer_utils.set_keymap(M.bufnr, "n", "<CR>", function()
		M._handle_select()
	end, { desc = "Select item" })

	-- r: Mark file as reviewed
	buffer_utils.set_keymap(M.bufnr, "n", "r", function()
		M._handle_toggle_reviewed()
	end, { desc = "Toggle file reviewed" })

	-- v: Toggle view mode
	buffer_utils.set_keymap(M.bufnr, "n", "v", function()
		M._toggle_view_mode()
	end, { desc = "Toggle view mode" })

	-- R: Refresh PR
	buffer_utils.set_keymap(M.bufnr, "n", "R", function()
		require("remora").refresh()
	end, { desc = "Refresh PR" })

	-- q: Close remora
	buffer_utils.set_keymap(M.bufnr, "n", "q", function()
		require("remora").close()
	end, { desc = "Close Remora" })
end

-- Set up autocmds
function M._setup_autocmds()
	-- Auto-save on buffer leave
	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = M.bufnr,
		callback = function()
			state.save()
		end,
	})
end

-- Handle item selection
function M._handle_select()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line_nr = cursor[1]
	local metadata = M.line_metadata[line_nr]

	if not metadata then
		return
	end

	if metadata.type == "file" then
		-- Open PR file diff
		M._open_file(metadata.path)
	elseif metadata.type == "local_file" then
		-- Open local file diff
		M._open_local_file(metadata.path, metadata.is_staged)
	elseif metadata.type == "section_header" and metadata.section == "pr_home" then
		-- Show PR details in center pane
		M._show_pr_detail()
	end
end

-- Open local file (show in editor for now)
---@param file_path string
---@param is_staged boolean
function M._open_local_file(file_path, is_staged)
	-- TODO: ローカルファイルのdiff表示（将来実装）
	-- 今は単にファイルを開く
	local full_path = vim.fn.getcwd() .. "/" .. file_path
	if vim.fn.filereadable(full_path) == 1 then
		local layout = require("remora.ui.layout")
		if layout.windows.center and vim.api.nvim_win_is_valid(layout.windows.center) then
			vim.api.nvim_set_current_win(layout.windows.center)
			vim.cmd("edit " .. vim.fn.fnameescape(full_path))
		end
	else
		vim.notify("File not found: " .. file_path, vim.log.levels.WARN)
	end
end

-- Open file in center pane with diff
---@param file_path string
function M._open_file(file_path)
	if not state.current_pr then
		return
	end

	-- Mark file as viewed
	state.mark_file_viewed(file_path)
	events.emit(events.FILE_VIEWED, file_path)

	-- Open diff in center pane
	local center_pane = require("remora.ui.center_pane")
	center_pane.open_file_diff(file_path)
end

-- Show PR detail in center pane
function M._show_pr_detail()
	local center_pane = require("remora.ui.center_pane")
	center_pane.show_pr_detail()
end

-- Toggle file reviewed status
function M._handle_toggle_reviewed()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line_nr = cursor[1]
	local metadata = M.line_metadata[line_nr]

	if not metadata or metadata.type ~= "file" then
		vim.notify("No file selected", vim.log.levels.WARN)
		return
	end

	state.toggle_file_reviewed(metadata.path)
	events.emit(events.FILE_REVIEWED, metadata.path)
	M.render()
end

-- Toggle view mode
function M._toggle_view_mode()
	local modes = { "tree", "flat", "status" }
	local current = state.ui.view_mode
	local current_idx = vim.tbl_contains(modes, current) and (vim.fn.index(modes, current) + 1) or 1

	local next_idx = (current_idx % #modes) + 1
	state.ui.view_mode = modes[next_idx]

	M.render()
	vim.notify("View mode: " .. state.ui.view_mode, vim.log.levels.INFO)
end

return M

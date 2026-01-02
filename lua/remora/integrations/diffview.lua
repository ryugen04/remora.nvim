-- diffview.nvim integration for remora.nvim

local M = {}

local state = require("remora.state")
local events = require("remora.events")

-- Check if diffview is available
---@return boolean
function M.is_available()
	local ok, _ = pcall(require, "diffview")
	return ok
end

-- Open file in diffview
---@param file_path string File path to open
---@param opts table|nil Options {on_close}
function M.open_file(file_path, opts)
	opts = opts or {}

	if not M.is_available() then
		vim.notify("diffview.nvim is not installed", vim.log.levels.ERROR)
		return
	end

	if not state.current_pr then
		vim.notify("No PR loaded", vim.log.levels.WARN)
		return
	end

	local pr = state.current_pr
	local base_sha = pr.base_sha
	local head_sha = pr.head_sha

	-- Build diffview command
	-- Format: :DiffviewOpen base_sha...head_sha -- file_path
	local cmd = string.format("DiffviewOpen %s...%s -- %s", base_sha, head_sha, file_path)

	-- Execute diffview command
	vim.cmd(cmd)

	-- Mark file as viewed
	state.mark_file_viewed(file_path)
	events.emit(events.FILE_VIEWED, file_path)

	-- Set up autocmd to handle diffview close
	if opts.on_close then
		vim.api.nvim_create_autocmd("User", {
			pattern = "DiffviewViewClosed",
			once = true,
			callback = opts.on_close,
		})
	end

	-- Set up comment display in diffview
	M._setup_comment_display(file_path)
end

-- Open PR-wide diffview (all files)
function M.open_pr_diff()
	if not M.is_available() then
		vim.notify("diffview.nvim is not installed", vim.log.levels.ERROR)
		return
	end

	if not state.current_pr then
		vim.notify("No PR loaded", vim.log.levels.WARN)
		return
	end

	local pr = state.current_pr
	local cmd = string.format("DiffviewOpen %s...%s", pr.base_sha, pr.head_sha)

	vim.cmd(cmd)

	-- Set up comment display for all files
	M._setup_comment_display()
end

-- Close diffview
function M.close()
	if not M.is_available() then
		return
	end

	vim.cmd("DiffviewClose")
end

-- Setup comment display in diffview buffers
---@param file_path string|nil Specific file path or nil for all
function M._setup_comment_display(file_path)
	-- Wait for diffview to open
	vim.defer_fn(function()
		-- Get current buffer (diffview buffer)
		local bufnr = vim.api.nvim_get_current_buf()
		local bufname = vim.api.nvim_buf_get_name(bufnr)

		-- Check if this is a diffview buffer
		if not bufname:match("diffview://") then
			return
		end

		-- Set up hover for comments
		M._setup_hover_comments(bufnr, file_path)

		-- Set up inline comments
		M._setup_inline_comments(bufnr, file_path)

		-- Set up keymaps for adding comments
		M._setup_comment_keymaps(bufnr, file_path)
	end, 100)
end

-- Setup hover popup for comments
---@param bufnr number
---@param file_path string|nil
function M._setup_hover_comments(bufnr, file_path)
	-- Create autocmd for CursorHold to show comment popup
	vim.api.nvim_create_autocmd("CursorHold", {
		buffer = bufnr,
		callback = function()
			M._show_comment_popup(bufnr, file_path)
		end,
	})
end

-- Show comment popup at cursor position
---@param bufnr number
---@param file_path string|nil
function M._show_comment_popup(bufnr, file_path)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1]

	-- Get comments for this line
	local comments = M._get_comments_for_line(file_path, line)

	if #comments == 0 then
		return
	end

	-- Build popup content
	local lines = {}
	for i, comment in ipairs(comments) do
		if i > 1 then
			table.insert(lines, "---")
		end

		table.insert(lines, string.format("💬 %s", comment.author or "Unknown"))
		table.insert(lines, "")

		-- Split comment body into lines
		for _, body_line in ipairs(vim.split(comment.body, "\n")) do
			table.insert(lines, body_line)
		end
	end

	-- Show popup
	local popup_bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(popup_bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(popup_bufnr, "filetype", "markdown")

	local width = 60
	local height = math.min(#lines, 20)

	local win_opts = {
		relative = "cursor",
		width = width,
		height = height,
		row = 1,
		col = 0,
		style = "minimal",
		border = "rounded",
	}

	local win_id = vim.api.nvim_open_win(popup_bufnr, false, win_opts)

	-- Auto-close on cursor move
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		buffer = bufnr,
		once = true,
		callback = function()
			if vim.api.nvim_win_is_valid(win_id) then
				vim.api.nvim_win_close(win_id, true)
			end
		end,
	})
end

-- Setup inline comment display with virtual text
---@param bufnr number
---@param file_path string|nil
function M._setup_inline_comments(bufnr, file_path)
	local ns = vim.api.nvim_create_namespace("remora-inline-comments")

	-- Get all comments for this file
	local comments_by_line = {}

	if file_path and state.files[file_path] then
		-- Get PR comments from GitHub
		-- TODO: Load from state or GitHub API

		-- Get draft comments
		for _, comment in ipairs(state.draft_comments) do
			if comment.path == file_path then
				local line = comment.line or 1
				comments_by_line[line] = comments_by_line[line] or {}
				table.insert(comments_by_line[line], comment)
			end
		end
	end

	-- Display inline comments as virtual text
	for line, comments in pairs(comments_by_line) do
		local virt_text = string.format("💬 %d comment%s", #comments, #comments > 1 and "s" or "")

		vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
			virt_text = { { virt_text, "Comment" } },
			virt_text_pos = "eol",
		})
	end
end

-- Get comments for a specific line
---@param file_path string|nil
---@param line number
---@return table comments
function M._get_comments_for_line(file_path, line)
	local comments = {}

	if not file_path then
		return comments
	end

	-- Get draft comments
	for _, comment in ipairs(state.draft_comments) do
		if comment.path == file_path and comment.line == line then
			table.insert(comments, comment)
		end
	end

	-- TODO: Get PR comments from GitHub data

	return comments
end

-- Setup keymaps for adding comments in diffview
---@param bufnr number
---@param file_path string|nil
function M._setup_comment_keymaps(bufnr, file_path)
	if not file_path then
		return
	end

	-- <leader>rc - Add review comment
	vim.keymap.set("n", "<leader>rc", function()
		M._add_comment_at_cursor(bufnr, file_path)
	end, { buffer = bufnr, desc = "Add review comment" })

	-- <leader>rs - Add suggestion
	vim.keymap.set("v", "<leader>rs", function()
		M._add_suggestion(bufnr, file_path)
	end, { buffer = bufnr, desc = "Add suggestion" })
end

-- Add comment at cursor position
---@param bufnr number
---@param file_path string
function M._add_comment_at_cursor(bufnr, file_path)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1]

	-- Prompt for comment body
	vim.ui.input({ prompt = "Comment: " }, function(body)
		if not body or body == "" then
			return
		end

		-- Add draft comment
		state.add_draft_comment({
			path = file_path,
			line = line,
			position = nil, -- TODO: Calculate diff position
			body = body,
			is_suggestion = false,
		})

		vim.notify("Draft comment added", vim.log.levels.INFO)

		-- Refresh inline comments
		M._setup_inline_comments(bufnr, file_path)

		-- Emit event
		events.emit(events.COMMENT_ADDED, { path = file_path, line = line })
	end)
end

-- Add suggestion from visual selection
---@param bufnr number
---@param file_path string
function M._add_suggestion(bufnr, file_path)
	-- Get visual selection
	local start_line = vim.fn.line("v")
	local end_line = vim.fn.line(".")

	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	-- Get selected text
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
	local current_code = table.concat(lines, "\n")

	-- Prompt for suggestion
	vim.ui.input({ prompt = "Suggested code: ", default = current_code }, function(suggestion_code)
		if not suggestion_code or suggestion_code == "" then
			return
		end

		-- Prompt for comment
		vim.ui.input({ prompt = "Comment: " }, function(body)
			if not body or body == "" then
				body = "Suggestion:"
			end

			-- Add draft comment with suggestion
			state.add_draft_comment({
				path = file_path,
				line = start_line,
				position = nil, -- TODO: Calculate diff position
				body = body,
				is_suggestion = true,
				suggestion_code = suggestion_code,
			})

			vim.notify("Draft suggestion added", vim.log.levels.INFO)

			-- Emit event
			events.emit(events.COMMENT_ADDED, { path = file_path, line = start_line })
		end)
	end)
end

return M

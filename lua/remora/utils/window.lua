-- Window utilities for remora.nvim

local M = {}

-- Create a split window
---@param opts table {position, size, bufnr}
---@return number winnr
function M.create_split(opts)
	opts = opts or {}

	local position = opts.position or "right" -- left, right, above, below
	local size = opts.size or 40

	-- Save current window
	local current_win = vim.api.nvim_get_current_win()

	-- Create split
	local cmd
	if position == "left" then
		cmd = "topleft vertical " .. size .. "split"
	elseif position == "right" then
		cmd = "botright vertical " .. size .. "split"
	elseif position == "above" then
		cmd = "topleft " .. size .. "split"
	elseif position == "below" then
		cmd = "botright " .. size .. "split"
	end

	vim.cmd(cmd)

	local winnr = vim.api.nvim_get_current_win()

	-- Set buffer if provided
	if opts.bufnr then
		vim.api.nvim_win_set_buf(winnr, opts.bufnr)
	end

	-- Return to original window if requested
	if opts.return_to_current then
		vim.api.nvim_set_current_win(current_win)
	end

	return winnr
end

-- Close window safely
---@param winnr number
function M.close(winnr)
	if winnr and vim.api.nvim_win_is_valid(winnr) then
		vim.api.nvim_win_close(winnr, true)
	end
end

-- Check if window is valid
---@param winnr number
---@return boolean
function M.is_valid(winnr)
	return winnr and vim.api.nvim_win_is_valid(winnr)
end

-- Set window option
---@param winnr number
---@param option string
---@param value any
function M.set_option(winnr, option, value)
	if M.is_valid(winnr) then
		vim.api.nvim_win_set_option(winnr, option, value)
	end
end

-- Get window buffer
---@param winnr number
---@return number bufnr
function M.get_buffer(winnr)
	return vim.api.nvim_win_get_buf(winnr)
end

-- Set window buffer
---@param winnr number
---@param bufnr number
function M.set_buffer(winnr, bufnr)
	vim.api.nvim_win_set_buf(winnr, bufnr)
end

-- Focus window
---@param winnr number
function M.focus(winnr)
	if M.is_valid(winnr) then
		vim.api.nvim_set_current_win(winnr)
	end
end

-- Get cursor position in window
---@param winnr number
---@return table {row, col} 1-indexed
function M.get_cursor(winnr)
	return vim.api.nvim_win_get_cursor(winnr)
end

-- Set cursor position in window
---@param winnr number
---@param row number 1-indexed
---@param col number 0-indexed
function M.set_cursor(winnr, row, col)
	vim.api.nvim_win_set_cursor(winnr, { row, col })
end

-- Set window height
---@param winnr number
---@param height number
function M.set_height(winnr, height)
	M.set_option(winnr, "height", height)
end

-- Set window width
---@param winnr number
---@param width number
function M.set_width(winnr, width)
	M.set_option(winnr, "width", width)
end

return M

-- Buffer utilities for remora.nvim

local M = {}

-- Create a scratch buffer
---@param opts table|nil Options {listed, filetype, buftype}
---@return number bufnr
function M.create_scratch(opts)
	opts = opts or {}

	local bufnr = vim.api.nvim_create_buf(opts.listed or false, true)

	if opts.filetype then
		vim.api.nvim_buf_set_option(bufnr, "filetype", opts.filetype)
	end

	vim.api.nvim_buf_set_option(bufnr, "buftype", opts.buftype or "nofile")
	vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
	vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

	return bufnr
end

-- Set buffer lines
---@param bufnr number
---@param lines table
---@param opts table|nil {modifiable}
function M.set_lines(bufnr, lines, opts)
	opts = opts or {}

	local was_modifiable = vim.api.nvim_buf_get_option(bufnr, "modifiable")

	if opts.modifiable ~= nil then
		vim.api.nvim_buf_set_option(bufnr, "modifiable", opts.modifiable)
	else
		vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	if opts.modifiable == nil then
		vim.api.nvim_buf_set_option(bufnr, "modifiable", was_modifiable)
	end
end

-- Append lines to buffer
---@param bufnr number
---@param lines table
function M.append_lines(bufnr, lines)
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, lines)
end

-- Clear buffer
---@param bufnr number
function M.clear(bufnr)
	M.set_lines(bufnr, {})
end

-- Set buffer keymap
---@param bufnr number
---@param mode string
---@param lhs string
---@param rhs string|function
---@param opts table|nil
function M.set_keymap(bufnr, mode, lhs, rhs, opts)
	opts = opts or {}
	opts.buffer = bufnr
	vim.keymap.set(mode, lhs, rhs, opts)
end

-- Set buffer name
---@param bufnr number
---@param name string
function M.set_name(bufnr, name)
	vim.api.nvim_buf_set_name(bufnr, name)
end

-- Check if buffer is valid
---@param bufnr number
---@return boolean
function M.is_valid(bufnr)
	return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

-- Delete buffer safely
---@param bufnr number
function M.delete(bufnr)
	if M.is_valid(bufnr) then
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end
end

-- Set buffer option
---@param bufnr number
---@param option string
---@param value any
function M.set_option(bufnr, option, value)
	vim.api.nvim_buf_set_option(bufnr, option, value)
end

-- Add highlight to buffer
---@param bufnr number
---@param ns_id number Namespace ID
---@param hl_group string Highlight group
---@param line number 0-indexed line number
---@param col_start number 0-indexed column start
---@param col_end number 0-indexed column end
function M.add_highlight(bufnr, ns_id, hl_group, line, col_start, col_end)
	vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl_group, line, col_start, col_end)
end

-- Create namespace
---@param name string
---@return number ns_id
function M.create_namespace(name)
	return vim.api.nvim_create_namespace(name)
end

-- Clear namespace highlights
---@param bufnr number
---@param ns_id number
function M.clear_namespace(bufnr, ns_id)
	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

return M

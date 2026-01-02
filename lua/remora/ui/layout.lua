-- Main layout management for remora.nvim

local M = {}

local config = require("remora.config")
local buffer_utils = require("remora.utils.buffer")
local window_utils = require("remora.utils.window")
local highlight = require("remora.utils.highlight")

-- Layout state
M.windows = {
	left = nil,
	center = nil,
	right = nil,
}

M.buffers = {
	left = nil,
	right = nil,
}

M.is_open = false

-- Initialize highlights
highlight.setup()

-- Open the three-pane layout
function M.open()
	if M.is_open then
		return
	end

	-- Clear the workspace (optional)
	-- vim.cmd('tabnew')

	-- Create left pane buffer
	M.buffers.left = buffer_utils.create_scratch({
		filetype = "remora-left",
		listed = false,
	})
	buffer_utils.set_name(M.buffers.left, "Remora: PR Browser")

	-- Create right pane buffer
	M.buffers.right = buffer_utils.create_scratch({
		filetype = "remora-right",
		listed = false,
	})
	buffer_utils.set_name(M.buffers.right, "Remora: Review")

	-- Create window layout
	-- Start with center pane (use current window)
	M.windows.center = vim.api.nvim_get_current_win()

	-- Create left pane
	M.windows.left = window_utils.create_split({
		position = "left",
		size = config.get("layout.left_width"),
		bufnr = M.buffers.left,
		return_to_current = true,
	})

	-- Create right pane
	M.windows.right = window_utils.create_split({
		position = "right",
		size = config.get("layout.right_width"),
		bufnr = M.buffers.right,
		return_to_current = true,
	})

	-- Configure windows
	M._configure_windows()

	-- Initialize panes
	local left_pane = require("remora.ui.left_pane")
	local right_pane = require("remora.ui.right_pane")

	left_pane.init(M.buffers.left)
	right_pane.init(M.buffers.right)

	M.is_open = true

	-- Focus left pane by default
	window_utils.focus(M.windows.left)
end

-- Close the layout
function M.close()
	if not M.is_open then
		return
	end

	-- Close windows
	window_utils.close(M.windows.left)
	window_utils.close(M.windows.right)

	-- Delete buffers
	buffer_utils.delete(M.buffers.left)
	buffer_utils.delete(M.buffers.right)

	-- Reset state
	M.windows = { left = nil, center = nil, right = nil }
	M.buffers = { left = nil, right = nil }
	M.is_open = false
end

-- Configure window options
function M._configure_windows()
	-- Left pane
	if window_utils.is_valid(M.windows.left) then
		window_utils.set_option(M.windows.left, "number", false)
		window_utils.set_option(M.windows.left, "relativenumber", false)
		window_utils.set_option(M.windows.left, "signcolumn", "no")
		window_utils.set_option(M.windows.left, "wrap", false)
		window_utils.set_option(M.windows.left, "cursorline", true)
	end

	-- Right pane
	if window_utils.is_valid(M.windows.right) then
		window_utils.set_option(M.windows.right, "number", false)
		window_utils.set_option(M.windows.right, "relativenumber", false)
		window_utils.set_option(M.windows.right, "signcolumn", "no")
		window_utils.set_option(M.windows.right, "wrap", true)
	end
end

-- Refresh layout
function M.refresh()
	if not M.is_open then
		return
	end

	local left_pane = require("remora.ui.left_pane")
	local right_pane = require("remora.ui.right_pane")

	left_pane.render()
	right_pane.render()
end

-- Get current focused pane
---@return string|nil pane "left" | "center" | "right"
function M.get_focused_pane()
	local current_win = vim.api.nvim_get_current_win()

	if current_win == M.windows.left then
		return "left"
	elseif current_win == M.windows.center then
		return "center"
	elseif current_win == M.windows.right then
		return "right"
	end

	return nil
end

-- Focus a specific pane
---@param pane string "left" | "center" | "right"
function M.focus_pane(pane)
	if pane == "left" and M.windows.left then
		window_utils.focus(M.windows.left)
	elseif pane == "center" and M.windows.center then
		window_utils.focus(M.windows.center)
	elseif pane == "right" and M.windows.right then
		window_utils.focus(M.windows.right)
	end
end

return M

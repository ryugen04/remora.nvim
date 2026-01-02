-- Center pane management for remora.nvim

local M = {}

local buffer_utils = require("remora.utils.buffer")
local window_utils = require("remora.utils.window")
local pr_home = require("remora.ui.components.pr_home")

-- Show PR detail in center pane
function M.show_pr_detail()
	local layout = require("remora.ui.layout")

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

-- Open file in diffview (center pane)
---@param file_path string
function M.open_file_in_diffview(file_path)
	-- TODO: Integrate with diffview.nvim
	-- This will be implemented in Phase 3
	vim.notify("Opening " .. file_path .. " in diffview (Phase 3)", vim.log.levels.INFO)
end

return M

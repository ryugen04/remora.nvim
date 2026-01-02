-- Right pane management for remora.nvim

local M = {}

local state = require("remora.state")
local events = require("remora.events")
local buffer_utils = require("remora.utils.buffer")

-- Pane state
M.bufnr = nil
M.ns = nil

-- Available modes
M.modes = {
	{ id = "ai_review", label = "Review" },
	{ id = "ai_ask", label = "Ask" },
	{ id = "pr_comments", label = "PR" },
	{ id = "local_memo", label = "Memo" },
}

-- Initialize right pane
---@param bufnr number
function M.init(bufnr)
	M.bufnr = bufnr
	M.ns = buffer_utils.create_namespace("remora-right-pane")

	-- Set up keymaps
	M._setup_keymaps()

	-- Initial render
	M.render()

	-- Listen to events
	events.on(events.MODE_CHANGED, function()
		M.render()
	end)
end

-- Render right pane
function M.render()
	if not buffer_utils.is_valid(M.bufnr) then
		return
	end

	-- Clear buffer first
	buffer_utils.set_lines(M.bufnr, {}, { modifiable = true })

	local lines = {}

	-- Mode tabs
	local tabs = {}
	for _, mode in ipairs(M.modes) do
		local is_active = state.ui.right_pane_mode == mode.id
		local bracket_left = is_active and "[" or " "
		local bracket_right = is_active and "]" or " "
		table.insert(tabs, string.format("%s%s%s", bracket_left, mode.label, bracket_right))
	end

	table.insert(lines, table.concat(tabs, " "))
	table.insert(lines, string.rep("─", 50))
	table.insert(lines, "")

	-- Set tabs first
	buffer_utils.set_lines(M.bufnr, lines, { modifiable = true })

	-- Then delegate to mode-specific renderer to append content
	M._render_mode_content()
end

-- Render content for current mode
function M._render_mode_content()
	local mode = state.ui.right_pane_mode

	-- Delegate to mode-specific renderers
	if mode == "ai_review" then
		local ai_review = require("remora.ui.modes.ai_review")
		ai_review.render(M.bufnr)
	elseif mode == "ai_ask" then
		local ai_ask = require("remora.ui.modes.ai_ask")
		ai_ask.render(M.bufnr)
	elseif mode == "pr_comments" then
		local pr_comments = require("remora.ui.modes.pr_comments")
		pr_comments.render(M.bufnr)
	elseif mode == "local_memo" then
		local local_memo = require("remora.ui.modes.local_memo")
		local_memo.render(M.bufnr)
	end
end

-- Set up keymaps
function M._setup_keymaps()
	-- Tab navigation: 1, 2, 3, 4
	for i, mode in ipairs(M.modes) do
		buffer_utils.set_keymap(M.bufnr, "n", tostring(i), function()
			M._switch_mode(mode.id)
		end, { desc = "Switch to " .. mode.label })
	end

	-- Tab/Shift-Tab to cycle modes
	buffer_utils.set_keymap(M.bufnr, "n", "<Tab>", function()
		M._next_mode()
	end, { desc = "Next mode" })

	buffer_utils.set_keymap(M.bufnr, "n", "<S-Tab>", function()
		M._prev_mode()
	end, { desc = "Previous mode" })
end

-- Switch to a specific mode
---@param mode_id string
function M._switch_mode(mode_id)
	state.ui.right_pane_mode = mode_id
	events.emit(events.MODE_CHANGED, mode_id)
	M.render()
end

-- Switch to next mode
function M._next_mode()
	local current_idx = 1
	for i, mode in ipairs(M.modes) do
		if mode.id == state.ui.right_pane_mode then
			current_idx = i
			break
		end
	end

	local next_idx = (current_idx % #M.modes) + 1
	M._switch_mode(M.modes[next_idx].id)
end

-- Switch to previous mode
function M._prev_mode()
	local current_idx = 1
	for i, mode in ipairs(M.modes) do
		if mode.id == state.ui.right_pane_mode then
			current_idx = i
			break
		end
	end

	local prev_idx = current_idx == 1 and #M.modes or (current_idx - 1)
	M._switch_mode(M.modes[prev_idx].id)
end

return M

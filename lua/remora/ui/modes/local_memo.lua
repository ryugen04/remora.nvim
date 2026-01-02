-- Local Memo mode for remora.nvim right pane

local M = {}

local state = require("remora.state")
local events = require("remora.events")
local buffer_utils = require("remora.utils.buffer")
local memos_component = require("remora.ui.components.memos")

-- Render Local Memo mode
---@param bufnr number
function M.render(bufnr)
	local lines = memos_component.render_detail()

	buffer_utils.set_lines(bufnr, lines, { modifiable = false })

	-- Set up keymaps
	M._setup_keymaps(bufnr)
end

-- Set up keymaps
---@param bufnr number
function M._setup_keymaps(bufnr)
	-- a: Add TODO
	buffer_utils.set_keymap(bufnr, "n", "a", function()
		M.add_todo()
	end, { desc = "Add TODO" })

	-- n: Add note
	buffer_utils.set_keymap(bufnr, "n", "n", function()
		M.add_note()
	end, { desc = "Add note" })

	-- d: Delete note/todo
	buffer_utils.set_keymap(bufnr, "n", "d", function()
		M.delete_note()
	end, { desc = "Delete note" })

	-- t: Toggle TODO completion
	buffer_utils.set_keymap(bufnr, "n", "t", function()
		M.toggle_todo()
	end, { desc = "Toggle TODO" })
end

-- Add TODO
function M.add_todo()
	vim.ui.input({ prompt = "TODO: " }, function(content)
		if not content or content == "" then
			return
		end

		state.add_note({
			type = "TODO",
			content = content,
		})

		vim.notify("TODO added", vim.log.levels.INFO)

		events.emit(events.NOTE_ADDED, { type = "TODO" })

		-- Refresh right pane
		local right_pane = require("remora.ui.right_pane")
		right_pane.render()
	end)
end

-- Add note
function M.add_note()
	vim.ui.input({ prompt = "Note: " }, function(content)
		if not content or content == "" then
			return
		end

		state.add_note({
			type = "NOTE",
			content = content,
		})

		vim.notify("Note added", vim.log.levels.INFO)

		events.emit(events.NOTE_ADDED, { type = "NOTE" })

		-- Refresh right pane
		local right_pane = require("remora.ui.right_pane")
		right_pane.render()
	end)
end

-- Delete note or TODO
function M.delete_note()
	local global_notes = state.notes.global or {}

	if #global_notes == 0 then
		vim.notify("No notes to delete", vim.log.levels.WARN)
		return
	end

	-- Build selection list
	local choices = {}
	for i, note in ipairs(global_notes) do
		local icon = note.type == "TODO" and "☐" or "📝"
		table.insert(choices, string.format("%d. %s %s", i, icon, note.content))
	end

	vim.ui.select(choices, {
		prompt = "Select note to delete:",
	}, function(choice, idx)
		if not idx then
			return
		end

		-- Remove note
		table.remove(state.notes.global, idx)
		state.save()

		vim.notify("Note deleted", vim.log.levels.INFO)

		-- Refresh right pane
		local right_pane = require("remora.ui.right_pane")
		right_pane.render()
	end)
end

-- Toggle TODO completion status
function M.toggle_todo()
	local global_notes = state.notes.global or {}
	local todos = {}
	local todo_indices = {}

	for i, note in ipairs(global_notes) do
		if note.type == "TODO" then
			table.insert(todos, note)
			table.insert(todo_indices, i)
		end
	end

	if #todos == 0 then
		vim.notify("No TODOs", vim.log.levels.WARN)
		return
	end

	-- Build selection list
	local choices = {}
	for i, todo in ipairs(todos) do
		local status = todo.completed and "☑" or "☐"
		table.insert(choices, string.format("%d. %s %s", i, status, todo.content))
	end

	vim.ui.select(choices, {
		prompt = "Select TODO to toggle:",
	}, function(choice, idx)
		if not idx then
			return
		end

		local global_idx = todo_indices[idx]
		local todo = state.notes.global[global_idx]

		todo.completed = not todo.completed
		todo.completed_at = todo.completed and os.date("%Y-%m-%dT%H:%M:%S") or nil

		state.save()

		local status = todo.completed and "completed" or "uncompleted"
		vim.notify("TODO marked as " .. status, vim.log.levels.INFO)

		-- Refresh right pane
		local right_pane = require("remora.ui.right_pane")
		right_pane.render()
	end)
end

return M

-- Keymap utilities for remora.nvim

local M = {}

-- Global keymaps registry
M.keymaps = {}

-- Register a keymap
---@param mode string
---@param lhs string
---@param rhs function|string
---@param opts table|nil
function M.register(mode, lhs, rhs, opts)
	opts = opts or {}

	local keymap_id = mode .. ":" .. lhs

	-- Store original keymap if it exists
	if not M.keymaps[keymap_id] then
		local existing = vim.fn.maparg(lhs, mode, false, true)
		if existing and existing.lhs then
			M.keymaps[keymap_id] = {
				mode = mode,
				lhs = lhs,
				rhs = existing.rhs or existing.callback,
				opts = existing,
			}
		end
	end

	-- Set new keymap
	vim.keymap.set(mode, lhs, rhs, opts)
end

-- Unregister and restore original keymap
---@param mode string
---@param lhs string
function M.unregister(mode, lhs)
	local keymap_id = mode .. ":" .. lhs

	-- Delete current keymap
	vim.keymap.del(mode, lhs)

	-- Restore original if it existed
	if M.keymaps[keymap_id] then
		local original = M.keymaps[keymap_id]
		vim.keymap.set(original.mode, original.lhs, original.rhs, original.opts)
		M.keymaps[keymap_id] = nil
	end
end

-- Clear all registered keymaps
function M.clear_all()
	for keymap_id, keymap in pairs(M.keymaps) do
		local mode, lhs = keymap_id:match("([^:]+):(.*)")
		if mode and lhs then
			pcall(vim.keymap.del, mode, lhs)
			vim.keymap.set(keymap.mode, keymap.lhs, keymap.rhs, keymap.opts)
		end
	end

	M.keymaps = {}
end

return M

-- Highlight utilities and definitions for remora.nvim

local M = {}

-- Define highlight groups
function M.setup()
	-- PR Status highlights
	vim.api.nvim_set_hl(0, "RemoraTitle", { link = "Title", default = true })
	vim.api.nvim_set_hl(0, "RemoraComment", { link = "Comment", default = true })
	vim.api.nvim_set_hl(0, "RemoraString", { link = "String", default = true })
	vim.api.nvim_set_hl(0, "RemoraNumber", { link = "Number", default = true })

	-- File status highlights
	vim.api.nvim_set_hl(0, "RemoraFileAdded", { link = "DiffAdd", default = true })
	vim.api.nvim_set_hl(0, "RemoraFileModified", { link = "DiffChange", default = true })
	vim.api.nvim_set_hl(0, "RemoraFileDeleted", { link = "DiffDelete", default = true })
	vim.api.nvim_set_hl(0, "RemoraFileRenamed", { link = "DiffText", default = true })

	-- Badge highlights
	vim.api.nvim_set_hl(0, "RemoraBadgeViewed", { fg = "#88c0d0", default = true })
	vim.api.nvim_set_hl(0, "RemoraBadgeReviewed", { fg = "#a3be8c", default = true })
	vim.api.nvim_set_hl(0, "RemoraBadgeCommented", { fg = "#ebcb8b", default = true })
	vim.api.nvim_set_hl(0, "RemoraBadgeNoted", { fg = "#d08770", default = true })
	vim.api.nvim_set_hl(0, "RemoraBadgePinned", { fg = "#bf616a", default = true })
	vim.api.nvim_set_hl(0, "RemoraBadgeAI", { fg = "#b48ead", default = true })

	-- Tree highlights
	vim.api.nvim_set_hl(0, "RemoraTreeFolder", { link = "Directory", default = true })
	vim.api.nvim_set_hl(0, "RemoraTreeFile", { link = "Normal", default = true })
	vim.api.nvim_set_hl(0, "RemoraTreeSelected", { link = "Visual", default = true })

	-- Section highlights
	vim.api.nvim_set_hl(0, "RemoraSectionTitle", { link = "Function", default = true })
	vim.api.nvim_set_hl(0, "RemoraSectionSeparator", { link = "Comment", default = true })

	-- Mode highlights
	vim.api.nvim_set_hl(0, "RemoraModeActive", { link = "TabLineSel", default = true })
	vim.api.nvim_set_hl(0, "RemoraModeInactive", { link = "TabLine", default = true })

	-- Diff highlights
	vim.api.nvim_set_hl(0, "RemoraDiffAdd", { link = "DiffAdd", default = true })
	vim.api.nvim_set_hl(0, "RemoraDiffDelete", { link = "DiffDelete", default = true })
	vim.api.nvim_set_hl(0, "RemoraDiffChange", { link = "DiffChange", default = true })
end

-- Get status highlight group
---@param status string File status (added, modified, deleted, renamed)
---@return string hl_group
function M.get_status_highlight(status)
	if status == "added" then
		return "RemoraFileAdded"
	elseif status == "modified" then
		return "RemoraFileModified"
	elseif status == "deleted" then
		return "RemoraFileDeleted"
	elseif status == "renamed" then
		return "RemoraFileRenamed"
	end
	return "Normal"
end

-- Get badge highlight group
---@param badge_type string Badge type (viewed, reviewed, etc.)
---@return string hl_group
function M.get_badge_highlight(badge_type)
	if badge_type == "viewed" then
		return "RemoraBadgeViewed"
	elseif badge_type == "reviewed" then
		return "RemoraBadgeReviewed"
	elseif badge_type == "commented" then
		return "RemoraBadgeCommented"
	elseif badge_type == "noted" then
		return "RemoraBadgeNoted"
	elseif badge_type == "pinned" then
		return "RemoraBadgePinned"
	elseif badge_type == "ai_reviewed" then
		return "RemoraBadgeAI"
	end
	return "Normal"
end

return M

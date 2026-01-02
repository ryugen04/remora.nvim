-- remora.nvim - Local PR Review Tool
-- Main entry point

local M = {}

local config = require("remora.config")
local state = require("remora.state")
local events = require("remora.events")
local layout = require("remora.ui.layout")

-- Plugin version
M.version = "0.1.0"

-- Setup function
---@param opts table|nil User configuration
function M.setup(opts)
	config.setup(opts)
	state.init()
	events.init()

	-- Create user commands
	vim.api.nvim_create_user_command("RemoraOpen", function(cmd_opts)
		M.open(cmd_opts.args)
	end, {
		nargs = "?",
		desc = "Open remora PR review",
		complete = function()
			return { "owner/repo#123" }
		end,
	})

	vim.api.nvim_create_user_command("RemoraClose", function()
		M.close()
	end, {
		desc = "Close remora PR review",
	})

	vim.api.nvim_create_user_command("RemoraToggle", function()
		M.toggle()
	end, {
		desc = "Toggle remora PR review",
	})

	vim.api.nvim_create_user_command("RemoraRefresh", function()
		M.refresh()
	end, {
		desc = "Refresh PR data from GitHub",
	})

	vim.api.nvim_create_user_command("RemoraSubmitReview", function()
		M.submit_review()
	end, {
		desc = "Submit PR review to GitHub",
	})

	-- Set up keymaps if configured
	if config.options.keymaps.toggle then
		vim.keymap.set("n", config.options.keymaps.toggle, M.toggle, { desc = "Toggle Remora" })
	end
	if config.options.keymaps.refresh then
		vim.keymap.set("n", config.options.keymaps.refresh, M.refresh, { desc = "Refresh Remora PR" })
	end
	if config.options.keymaps.submit_review then
		vim.keymap.set("n", config.options.keymaps.submit_review, M.submit_review, { desc = "Submit Remora Review" })
	end
end

-- Open remora with PR identifier
---@param pr_identifier string|nil Format: "owner/repo#number" or nil to use git context
function M.open(pr_identifier)
	if state.is_open then
		vim.notify("Remora is already open", vim.log.levels.WARN)
		return
	end

	-- Parse PR identifier or detect from git
	local pr_info
	if pr_identifier then
		pr_info = M._parse_pr_identifier(pr_identifier)
	else
		pr_info = M._detect_pr_from_git()
	end

	if not pr_info then
		vim.notify("Failed to detect PR. Use :RemoraOpen owner/repo#number", vim.log.levels.ERROR)
		return
	end

	-- Load PR data
	local github = require("remora.core.github")
	github.fetch_pr(pr_info.owner, pr_info.repo, pr_info.number, function(pr_data, err)
		if err then
			vim.notify("Failed to fetch PR: " .. err, vim.log.levels.ERROR)
			return
		end

		-- Initialize state with PR data
		state.load_pr(pr_data)

		-- Open layout
		layout.open()

		-- Trigger event
		events.emit(events.PR_LOADED, pr_data)

		vim.notify(string.format("Loaded PR #%d: %s", pr_info.number, pr_data.title), vim.log.levels.INFO)
	end)
end

-- Close remora
function M.close()
	if not state.is_open then
		return
	end

	layout.close()
	state.save()
	state.is_open = false
end

-- Toggle remora
function M.toggle()
	if state.is_open then
		M.close()
	else
		M.open()
	end
end

-- Refresh PR data from GitHub
function M.refresh()
	if not state.is_open or not state.current_pr then
		vim.notify("No PR loaded", vim.log.levels.WARN)
		return
	end

	local pr = state.current_pr
	local github = require("remora.core.github")

	vim.notify("Refreshing PR data...", vim.log.levels.INFO)
	github.fetch_pr(pr.owner, pr.repo, pr.number, function(pr_data, err)
		if err then
			vim.notify("Failed to refresh PR: " .. err, vim.log.levels.ERROR)
			return
		end

		state.load_pr(pr_data)
		events.emit(events.PR_REFRESHED, pr_data)
		vim.notify("PR refreshed", vim.log.levels.INFO)
	end)
end

-- Submit review to GitHub
function M.submit_review()
	if not state.is_open or not state.current_pr then
		vim.notify("No PR loaded", vim.log.levels.WARN)
		return
	end

	-- Open review submission UI
	local review_mode = require("remora.ui.modes.pr_comments")
	review_mode.submit_review()
end

-- Parse PR identifier string
---@param identifier string Format: "owner/repo#number"
---@return table|nil pr_info {owner, repo, number}
function M._parse_pr_identifier(identifier)
	local owner, repo, number = identifier:match("([^/]+)/([^#]+)#(%d+)")
	if owner and repo and number then
		return {
			owner = owner,
			repo = repo,
			number = tonumber(number),
		}
	end
	return nil
end

-- Detect PR from current git context
---@return table|nil pr_info {owner, repo, number}
function M._detect_pr_from_git()
	-- TODO: Implement git branch -> PR detection
	-- 1. Get current branch
	-- 2. Get remote URL
	-- 3. Query GitHub API for PR with this branch
	return nil
end

return M

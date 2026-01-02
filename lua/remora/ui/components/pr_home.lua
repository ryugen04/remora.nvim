-- PR Home component for remora.nvim

local M = {}

local state = require("remora.state")

-- Render PR summary (for left pane)
---@return table lines
function M.render_summary()
	local lines = {}

	if not state.current_pr then
		table.insert(lines, "No PR loaded")
		return lines
	end

	local pr = state.current_pr

	-- PR title and number
	table.insert(lines, string.format("PR #%d", pr.number))
	table.insert(lines, pr.title or "Untitled")
	table.insert(lines, "")

	-- Author and state
	table.insert(lines, string.format("👤 %s", pr.author))
	table.insert(lines, string.format("📊 %s", pr.state))
	table.insert(lines, "")

	-- Branches
	table.insert(lines, string.format("🌿 %s ← %s", pr.base_branch, pr.head_branch))

	return lines
end

-- Render PR detail (for center pane)
---@return table lines
function M.render_detail()
	local lines = {}

	if not state.current_pr then
		table.insert(lines, "No PR loaded")
		return lines
	end

	local pr = state.current_pr

	-- Header
	table.insert(
		lines,
		"═══════════════════════════════════════════════════════════"
	)
	table.insert(lines, string.format(" PR #%d: %s", pr.number, pr.title))
	table.insert(
		lines,
		"═══════════════════════════════════════════════════════════"
	)
	table.insert(lines, "")

	-- Metadata
	table.insert(lines, "📋 Details")
	table.insert(
		lines,
		"─────────────────────────────────────────────────────────"
	)
	table.insert(lines, string.format("  Author:        %s", pr.author))
	table.insert(lines, string.format("  State:         %s", pr.state))
	table.insert(lines, string.format("  Base Branch:   %s", pr.base_branch))
	table.insert(lines, string.format("  Head Branch:   %s", pr.head_branch))
	table.insert(lines, string.format("  Created:       %s", M._format_date(pr.created_at)))
	table.insert(lines, string.format("  Updated:       %s", M._format_date(pr.updated_at)))
	table.insert(lines, "")

	-- Statistics
	local file_count = vim.tbl_count(state.files)
	local viewed_count = 0
	local reviewed_count = 0

	for _, file_state in pairs(state.files) do
		if file_state.viewed then
			viewed_count = viewed_count + 1
		end
		if file_state.reviewed then
			reviewed_count = reviewed_count + 1
		end
	end

	table.insert(lines, "📊 Statistics")
	table.insert(
		lines,
		"─────────────────────────────────────────────────────────"
	)
	table.insert(lines, string.format("  Files:         %d", file_count))
	table.insert(lines, string.format("  Viewed:        %d / %d", viewed_count, file_count))
	table.insert(lines, string.format("  Reviewed:      %d / %d", reviewed_count, file_count))
	table.insert(lines, string.format("  Draft Comments: %d", #state.draft_comments))
	table.insert(lines, "")

	-- Description
	if pr.body and pr.body ~= "" then
		table.insert(lines, "📝 Description")
		table.insert(
			lines,
			"─────────────────────────────────────────────────────────"
		)

		-- Split description into lines
		for _, line in ipairs(vim.split(pr.body, "\n")) do
			table.insert(lines, "  " .. line)
		end

		table.insert(lines, "")
	end

	-- Instructions
	table.insert(lines, "⌨️  Quick Actions")
	table.insert(
		lines,
		"─────────────────────────────────────────────────────────"
	)
	table.insert(lines, "  <Enter>  View selected file in diffview")
	table.insert(lines, "  r        Mark file as reviewed")
	table.insert(lines, "  R        Refresh PR data")
	table.insert(lines, "  s        Submit review")
	table.insert(lines, "  q        Close Remora")

	return lines
end

-- Format ISO date to readable format
---@param iso_date string
---@return string
function M._format_date(iso_date)
	if not iso_date then
		return "N/A"
	end

	-- Simple format: just return the date part
	local date_part = iso_date:match("^(%d%d%d%d%-%d%d%-%d%d)")
	return date_part or iso_date
end

return M

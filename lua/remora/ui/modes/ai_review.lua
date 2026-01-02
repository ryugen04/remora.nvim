-- AI Review mode for remora.nvim right pane

local M = {}

local state = require("remora.state")
local buffer_utils = require("remora.utils.buffer")

-- Current review state
M.is_reviewing = false
M.review_output = {}

-- Render AI Review mode
---@param bufnr number
function M.render(bufnr)
	local lines = {}

	table.insert(
		lines,
		"═══════════════════════════════════════════════════════════"
	)
	table.insert(lines, " 🤖 AI Review Mode")
	table.insert(
		lines,
		"═══════════════════════════════════════════════════════════"
	)
	table.insert(lines, "")

	if not state.current_pr then
		table.insert(lines, "⚠️  No PR loaded")
		table.insert(lines, "")
		table.insert(lines, "Load a PR first with :RemoraOpen owner/repo#number")
		buffer_utils.set_lines(bufnr, lines, { modifiable = false })
		return
	end

	local pr = state.current_pr

	table.insert(lines, "📋 PR Information")
	table.insert(
		lines,
		"─────────────────────────────────────────────────────────"
	)
	table.insert(lines, string.format("  PR #%d: %s", pr.number, pr.title))
	table.insert(lines, string.format("  Author: %s", pr.author))
	table.insert(lines, string.format("  Files: %d", vim.tbl_count(state.files)))
	table.insert(lines, "")

	if M.is_reviewing then
		table.insert(lines, "⏳ AI Review in Progress...")
		table.insert(lines, "")
		table.insert(lines, "Output:")
		table.insert(
			lines,
			"─────────────────────────────────────────────────────────"
		)

		for _, line in ipairs(M.review_output) do
			table.insert(lines, line)
		end
	elseif #(state.ai_reviews or {}) > 0 then
		table.insert(lines, "✅ AI Review Complete")
		table.insert(lines, "")
		table.insert(lines, "Review Summary:")
		table.insert(
			lines,
			"─────────────────────────────────────────────────────────"
		)

		-- Show latest AI review
		local latest_review = state.ai_reviews[#state.ai_reviews]
		if latest_review.summary then
			for _, line in ipairs(vim.split(latest_review.summary, "\n")) do
				table.insert(lines, "  " .. line)
			end
		end

		table.insert(lines, "")
		table.insert(lines, string.format("Findings: %d", #(latest_review.findings or {})))
		table.insert(lines, "")

		-- Show findings
		for i, finding in ipairs(latest_review.findings or {}) do
			table.insert(lines, string.format("%d. %s", i, finding.title or "Untitled"))
			table.insert(lines, string.format("   File: %s:%d", finding.file, finding.line or 0))
			table.insert(lines, string.format("   Severity: %s", finding.severity or "info"))
			table.insert(lines, "")
		end
	else
		table.insert(lines, "🚀 Ready to Review")
		table.insert(lines, "")
		table.insert(lines, "AI Review Features:")
		table.insert(lines, "  • Context-aware code analysis")
		table.insert(lines, "  • Automatic issue detection")
		table.insert(lines, "  • Best practice suggestions")
		table.insert(lines, "  • Security vulnerability scanning")
		table.insert(lines, "")
	end

	table.insert(lines, "⌨️  Commands")
	table.insert(
		lines,
		"─────────────────────────────────────────────────────────"
	)
	table.insert(lines, "  r    Start full PR review")
	table.insert(lines, "  f    Review current file only")
	table.insert(lines, "  c    Clear review results")
	table.insert(lines, "  e    Export findings as comments")

	buffer_utils.set_lines(bufnr, lines, { modifiable = false })

	-- Set up keymaps
	M._setup_keymaps(bufnr)
end

-- Set up keymaps
---@param bufnr number
function M._setup_keymaps(bufnr)
	-- r: Start full PR review
	buffer_utils.set_keymap(bufnr, "n", "r", function()
		M.start_full_review()
	end, { desc = "Start AI review of PR" })

	-- f: Review current file
	buffer_utils.set_keymap(bufnr, "n", "f", function()
		M.review_current_file()
	end, { desc = "Review current file" })

	-- c: Clear results
	buffer_utils.set_keymap(bufnr, "n", "c", function()
		M.clear_review()
	end, { desc = "Clear review results" })

	-- e: Export as comments
	buffer_utils.set_keymap(bufnr, "n", "e", function()
		M.export_as_comments()
	end, { desc = "Export findings as draft comments" })
end

-- Start full PR review
function M.start_full_review()
	if M.is_reviewing then
		vim.notify("Review already in progress", vim.log.levels.WARN)
		return
	end

	if not state.current_pr then
		vim.notify("No PR loaded", vim.log.levels.WARN)
		return
	end

	M.is_reviewing = true
	M.review_output = {}

	-- Refresh UI
	local right_pane = require("remora.ui.right_pane")
	right_pane.render()

	-- Start AI review
	local ai_client = require("remora.core.claude")

	ai_client.review_pr({
		pr = state.current_pr,
		files = state.files,
		mode = "full",
		on_progress = function(line)
			table.insert(M.review_output, line)
			right_pane.render()
		end,
		on_complete = function(review, err)
			M.is_reviewing = false

			if err then
				vim.notify("AI review failed: " .. err, vim.log.levels.ERROR)
				right_pane.render()
				return
			end

			-- Store review results
			state.ai_reviews = state.ai_reviews or {}
			table.insert(state.ai_reviews, review)

			-- Mark files as AI reviewed
			for _, finding in ipairs(review.findings or {}) do
				if state.files[finding.file] then
					state.files[finding.file].ai_reviewed = true
				end
			end

			state.save()

			vim.notify("AI review complete!", vim.log.levels.INFO)
			right_pane.render()
		end,
	})
end

-- Review current file only
function M.review_current_file()
	-- Extract relative path
	-- TODO: Improve file path detection

	vim.notify("File-specific review coming soon", vim.log.levels.INFO)
end

-- Clear review results
function M.clear_review()
	state.ai_reviews = {}
	M.review_output = {}
	state.save()

	vim.notify("Review results cleared", vim.log.levels.INFO)

	local right_pane = require("remora.ui.right_pane")
	right_pane.render()
end

-- Export AI findings as draft comments
function M.export_as_comments()
	if not state.ai_reviews or #state.ai_reviews == 0 then
		vim.notify("No AI review findings to export", vim.log.levels.WARN)
		return
	end

	local latest_review = state.ai_reviews[#state.ai_reviews]
	local findings = latest_review.findings or {}

	if #findings == 0 then
		vim.notify("No findings in review", vim.log.levels.WARN)
		return
	end

	-- Convert findings to draft comments
	local exported_count = 0

	for _, finding in ipairs(findings) do
		if finding.file and finding.line then
			local comment_body = string.format(
				"[AI] %s\n\n%s\n\nSeverity: %s",
				finding.title or "AI Finding",
				finding.description or "",
				finding.severity or "info"
			)

			state.add_draft_comment({
				path = finding.file,
				line = finding.line,
				position = nil,
				body = comment_body,
				is_suggestion = false,
			})

			exported_count = exported_count + 1
		end
	end

	vim.notify(string.format("Exported %d AI findings as draft comments", exported_count), vim.log.levels.INFO)

	-- Switch to PR Comments mode
	state.ui.right_pane_mode = "pr_comments"
	local events = require("remora.events")
	events.emit(events.MODE_CHANGED, "pr_comments")

	local right_pane = require("remora.ui.right_pane")
	right_pane.render()
end

return M

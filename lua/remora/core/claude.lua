-- Claude Code CLI integration for remora.nvim

local M = {}

local config = require("remora.config")
local Job = require("plenary.job")

-- Check if Claude CLI is available
---@return boolean
function M.is_available()
	local claude_path = config.get("ai.claude_cli_path")
	local result = vim.fn.executable(claude_path)
	return result == 1
end

-- Ask Claude Code a question (no context injection)
---@param opts table {question, conversation?, on_response}
function M.ask(opts)
	if not M.is_available() then
		opts.on_response(nil, "Claude Code CLI not found")
		return
	end

	local claude_path = config.get("ai.claude_cli_path")

	-- Build prompt
	local prompt = opts.question

	-- Execute Claude CLI
	local response_lines = {}

	Job:new({
		command = claude_path,
		args = { "ask", prompt },
		on_stdout = function(_, line)
			table.insert(response_lines, line)
		end,
		on_exit = function(j, return_val)
			vim.schedule(function()
				if return_val ~= 0 then
					local error_msg = table.concat(j:stderr_result(), "\n")
					opts.on_response(nil, error_msg)
					return
				end

				local response = table.concat(response_lines, "\n")
				opts.on_response(response, nil)
			end)
		end,
	}):start()
end

-- Review PR with Claude Code (with context injection)
---@param opts table {pr, files, mode, on_progress?, on_complete}
function M.review_pr(opts)
	if not M.is_available() then
		opts.on_complete(nil, "Claude Code CLI not found")
		return
	end

	-- Build context-injected prompt
	local prompt = M._build_review_prompt(opts.pr, opts.files, opts.mode)

	-- Execute review
	local response_lines = {}
	local claude_path = config.get("ai.claude_cli_path")

	Job:new({
		command = claude_path,
		args = { "review", "--context", prompt },
		on_stdout = function(_, line)
			table.insert(response_lines, line)

			if opts.on_progress then
				vim.schedule(function()
					opts.on_progress(line)
				end)
			end
		end,
		on_exit = function(j, return_val)
			vim.schedule(function()
				if return_val ~= 0 then
					local error_msg = table.concat(j:stderr_result(), "\n")
					opts.on_complete(nil, error_msg)
					return
				end

				local response = table.concat(response_lines, "\n")

				-- Parse review response
				local review = M._parse_review_response(response)

				opts.on_complete(review, nil)
			end)
		end,
	}):start()
end

-- Build review prompt with context injection
---@param pr table PR data
---@param files table Files state
---@param mode string Review mode (full, file, changes)
---@return string prompt
function M._build_review_prompt(pr, files, mode)
	local lines = {}

	table.insert(lines, "# Pull Request Review Request")
	table.insert(lines, "")
	table.insert(lines, string.format("## PR #%d: %s", pr.number, pr.title))
	table.insert(lines, "")

	if pr.body and pr.body ~= "" then
		table.insert(lines, "## Description")
		table.insert(lines, pr.body)
		table.insert(lines, "")
	end

	table.insert(lines, "## Changes")
	table.insert(lines, string.format("Base: %s (%s)", pr.base_branch, pr.base_sha:sub(1, 7)))
	table.insert(lines, string.format("Head: %s (%s)", pr.head_branch, pr.head_sha:sub(1, 7)))
	table.insert(lines, "")

	table.insert(lines, "## Files Changed")
	for path, file_state in pairs(files) do
		table.insert(lines, string.format("- %s (%s)", path, file_state.status))
		if file_state.additions and file_state.deletions then
			table.insert(lines, string.format("  +%d -%d", file_state.additions, file_state.deletions))
		end
	end

	table.insert(lines, "")
	table.insert(lines, "## Review Instructions")
	table.insert(lines, "Please review this pull request and provide:")
	table.insert(lines, "1. A summary of the changes")
	table.insert(lines, "2. Potential issues or concerns")
	table.insert(lines, "3. Suggestions for improvement")
	table.insert(lines, "4. Security vulnerabilities (if any)")
	table.insert(lines, "5. Best practice recommendations")
	table.insert(lines, "")
	table.insert(lines, "Format your findings as:")
	table.insert(lines, "```")
	table.insert(lines, "SUMMARY: [brief summary]")
	table.insert(lines, "")
	table.insert(lines, "FINDING: [file]:[line]")
	table.insert(lines, "SEVERITY: [critical|high|medium|low|info]")
	table.insert(lines, "TITLE: [short title]")
	table.insert(lines, "DESCRIPTION: [detailed description]")
	table.insert(lines, "---")
	table.insert(lines, "```")

	return table.concat(lines, "\n")
end

-- Parse AI review response
---@param response string Raw response from Claude
---@return table review {summary, findings}
function M._parse_review_response(response)
	local parser = require("remora.core.parser")
	return parser.parse_ai_review(response)
end

-- Review specific file
---@param opts table {pr, file_path, patch, on_complete}
function M.review_file(opts)
	if not M.is_available() then
		opts.on_complete(nil, "Claude Code CLI not found")
		return
	end

	local pr = opts.pr
	local file_path = opts.file_path
	local patch = opts.patch

	-- Build file-specific prompt
	local prompt = string.format(
		[[
# File Review Request

## PR #%d: %s

## File: %s

## Changes:
%s

## Instructions:
Please review this file and identify:
1. Potential bugs or logic errors
2. Security vulnerabilities
3. Performance issues
4. Code quality improvements
5. Best practice violations

Provide specific line-by-line feedback where applicable.
]],
		pr.number,
		pr.title,
		file_path,
		patch or "[No patch available]"
	)

	local claude_path = config.get("ai.claude_cli_path")
	local response_lines = {}

	Job:new({
		command = claude_path,
		args = { "review", "--file", file_path, "--context", prompt },
		on_stdout = function(_, line)
			table.insert(response_lines, line)
		end,
		on_exit = function(j, return_val)
			vim.schedule(function()
				if return_val ~= 0 then
					local error_msg = table.concat(j:stderr_result(), "\n")
					opts.on_complete(nil, error_msg)
					return
				end

				local response = table.concat(response_lines, "\n")
				local review = M._parse_review_response(response)

				opts.on_complete(review, nil)
			end)
		end,
	}):start()
end

return M

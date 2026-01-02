-- Global state management for remora.nvim

local M = {}

local storage = require("remora.core.storage")

-- State flags
M.is_open = false
M.is_initialized = false

-- Current PR data
M.current_pr = nil -- { owner, repo, number, title, author, ... }

-- Files state
M.files = {} -- { [path] = { status, viewed, reviewed, ... } }

-- UI state
M.ui = {
	view_mode = "tree", -- tree | flat | status
	filters = {
		show_viewed = true,
		show_reviewed = true,
		file_types = {},
	},
	right_pane_mode = "ai_review", -- ai_review | ai_ask | pr_comments | local_memo
	selected_file = nil,
}

-- Local notes
M.notes = {
	global = {},
	by_file = {},
}

-- Draft comments (not yet published to GitHub)
M.draft_comments = {}

-- AI reviews
M.ai_reviews = {}

-- Local git changes (unstaged, staged, unpushed commits)
M.local_changes = {
  loaded = false,
  staged = {},           -- { { path, status } }
  unstaged = {},         -- { { path, status } }
  unpushed_commits = {}, -- { { sha, message, author, date } }
}

-- Initialize state
function M.init()
	if M.is_initialized then
		return
	end

	M.is_initialized = true
end

-- Load PR data and restore state
---@param pr_data table PR data from GitHub API
function M.load_pr(pr_data)
	M.current_pr = {
		owner = pr_data.owner,
		repo = pr_data.repo,
		number = pr_data.number,
		title = pr_data.title,
		author = pr_data.author,
		base_branch = pr_data.base_branch,
		head_branch = pr_data.head_branch,
		base_sha = pr_data.base_sha,
		head_sha = pr_data.head_sha,
		state = pr_data.state,
		created_at = pr_data.created_at,
		updated_at = pr_data.updated_at,
		body = pr_data.body,
	}

	-- Initialize files state
	M.files = {}
	for _, file in ipairs(pr_data.files or {}) do
		M.files[file.path] = {
			status = file.status,
			additions = file.additions,
			deletions = file.deletions,
			patch = file.patch,
			viewed = false,
			reviewed = false,
			comments_count = #(file.comments or {}),
			ai_reviewed = false,
			has_local_notes = false,
		}
	end

	-- Load persisted state
	M.load()

	M.is_open = true
end

-- Load persisted state from disk
function M.load()
	if not M.current_pr then
		return
	end

	local pr_key = string.format("%s_%s_%d", M.current_pr.owner, M.current_pr.repo, M.current_pr.number)

	-- Load state.json
	local state_data = storage.load(pr_key, "state.json")
	if state_data then
		-- Merge file states
		if state_data.files then
			for path, file_state in pairs(state_data.files) do
				if M.files[path] then
					M.files[path].viewed = file_state.viewed or false
					M.files[path].reviewed = file_state.reviewed or false
				end
			end
		end

		-- Restore UI state
		if state_data.view_mode then
			M.ui.view_mode = state_data.view_mode
		end
		if state_data.filters then
			M.ui.filters = state_data.filters
		end
	end

	-- Load local notes
	local notes_data = storage.load(pr_key, "local_notes.json")
	if notes_data then
		M.notes = notes_data
	end

	-- Load draft comments
	local drafts_data = storage.load(pr_key, "draft_comments.json")
	if drafts_data then
		M.draft_comments = drafts_data.comments or {}
	end

	-- Load AI reviews
	local ai_reviews_data = storage.load(pr_key, "ai_reviews.json")
	if ai_reviews_data then
		M.ai_reviews = ai_reviews_data
	end

	-- Update has_local_notes flags
	for path, _ in pairs(M.notes.by_file or {}) do
		if M.files[path] then
			M.files[path].has_local_notes = true
		end
	end
end

-- Save current state to disk
function M.save()
	if not M.current_pr then
		return
	end

	local pr_key = string.format("%s_%s_%d", M.current_pr.owner, M.current_pr.repo, M.current_pr.number)

	-- Save state.json
	local state_data = {
		pr = M.current_pr,
		files = {},
		view_mode = M.ui.view_mode,
		filters = M.ui.filters,
	}

	for path, file_state in pairs(M.files) do
		state_data.files[path] = {
			status = file_state.status,
			viewed = file_state.viewed,
			reviewed = file_state.reviewed,
			comments_count = file_state.comments_count,
			ai_reviewed = file_state.ai_reviewed,
			has_local_notes = file_state.has_local_notes,
		}
	end

	storage.save(pr_key, "state.json", state_data)

	-- Save local notes
	storage.save(pr_key, "local_notes.json", M.notes)

	-- Save draft comments
	storage.save(pr_key, "draft_comments.json", {
		comments = M.draft_comments,
		pending_review = M.pending_review or {},
	})

	-- Save AI reviews
	storage.save(pr_key, "ai_reviews.json", M.ai_reviews)
end

-- Mark file as viewed
---@param file_path string
function M.mark_file_viewed(file_path)
	if M.files[file_path] then
		M.files[file_path].viewed = true
		M.save()
	end
end

-- Mark file as reviewed
---@param file_path string
function M.mark_file_reviewed(file_path)
	if M.files[file_path] then
		M.files[file_path].reviewed = true
		M.save()
	end
end

-- Toggle file reviewed status
---@param file_path string
function M.toggle_file_reviewed(file_path)
	if M.files[file_path] then
		M.files[file_path].reviewed = not M.files[file_path].reviewed
		M.save()
	end
end

-- Get files list with optional filtering
---@param filter_fn function|nil Optional filter function
---@return table files List of file paths
function M.get_files(filter_fn)
	local files = {}

	for path, file_state in pairs(M.files) do
		if not filter_fn or filter_fn(path, file_state) then
			table.insert(files, {
				path = path,
				state = file_state,
			})
		end
	end

	-- Sort by path
	table.sort(files, function(a, b)
		return a.path < b.path
	end)

	return files
end

-- Add local note
---@param note table { type, content, file_path?, line? }
function M.add_note(note)
	note.id = vim.fn.uuid()
	note.created_at = os.date("%Y-%m-%dT%H:%M:%S")

	if note.file_path then
		M.notes.by_file[note.file_path] = M.notes.by_file[note.file_path] or {}
		table.insert(M.notes.by_file[note.file_path], note)

		if M.files[note.file_path] then
			M.files[note.file_path].has_local_notes = true
		end
	else
		table.insert(M.notes.global, note)
	end

	M.save()
end

-- Add draft comment
---@param comment table { path, position, line, body, is_suggestion?, suggestion_code? }
function M.add_draft_comment(comment)
	comment.id = vim.fn.uuid()
	comment.created_at = os.date("%Y-%m-%dT%H:%M:%S")
	comment.updated_at = comment.created_at

	table.insert(M.draft_comments, comment)

	-- Update comments count
	if M.files[comment.path] then
		M.files[comment.path].comments_count = (M.files[comment.path].comments_count or 0) + 1
	end

	M.save()
end

-- Refresh local git changes
function M.refresh_local_changes()
  local git = require('remora.core.git')
  local events = require('remora.events')

  -- git statusを取得
  git.get_status(function(changes, err)
    if err then
      vim.notify('Failed to get git status: ' .. err, vim.log.levels.WARN)
      return
    end

    M.local_changes.staged = changes.staged
    M.local_changes.unstaged = changes.unstaged
    M.local_changes.loaded = true

    events.emit(events.LOCAL_CHANGES_UPDATED)
  end)

  -- unpushed commitsを取得
  if M.current_pr and M.current_pr.base_branch then
    git.get_unpushed_commits(M.current_pr.base_branch, function(commits, err)
      if not err then
        M.local_changes.unpushed_commits = commits
        events.emit(events.LOCAL_CHANGES_UPDATED)
      end
    end)
  end
end

-- Reset local changes state
function M.reset_local_changes()
  M.local_changes = {
    loaded = false,
    staged = {},
    unstaged = {},
    unpushed_commits = {},
  }
end

return M

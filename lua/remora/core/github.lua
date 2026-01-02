-- GitHub GraphQL API client for remora.nvim

local M = {}

local config = require("remora.config")
local Job = require("plenary.job")

-- Get GitHub token
---@return string|nil token
local function get_token()
	local token = config.get("github.token")

	if token then
		return token
	end

	-- Try to get from gh CLI
	local result = vim.fn.system("gh auth token")
	if vim.v.shell_error == 0 then
		return vim.trim(result)
	end

	-- Try to get from environment
	token = os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN")
	if token then
		return token
	end

	return nil
end

-- Execute GraphQL query
---@param query string GraphQL query
---@param variables table|nil Query variables
---@param callback function Callback(data, error)
local function execute_query(query, variables, callback)
	local token = get_token()
	if not token then
		callback(nil, 'No GitHub token found. Run "gh auth login" or set GITHUB_TOKEN')
		return
	end

	local api_url = config.get("github.api_url")
	local payload = vim.json.encode({
		query = query,
		variables = variables or {},
	})

	Job:new({
		command = "curl",
		args = {
			"-X",
			"POST",
			"-H",
			"Authorization: Bearer " .. token,
			"-H",
			"Content-Type: application/json",
			"-d",
			payload,
			api_url,
		},
		on_exit = function(j, return_val)
			if return_val ~= 0 then
				vim.schedule(function()
					callback(nil, "GitHub API request failed: " .. table.concat(j:stderr_result(), "\n"))
				end)
				return
			end

			local response_text = table.concat(j:result(), "\n")
			local success, response = pcall(vim.json.decode, response_text)

			if not success then
				vim.schedule(function()
					callback(nil, "Failed to parse GitHub API response: " .. response)
				end)
				return
			end

			if response.errors then
				vim.schedule(function()
					local error_msg = vim.tbl_map(function(e)
						return e.message
					end, response.errors)
					callback(nil, "GitHub API errors: " .. table.concat(error_msg, ", "))
				end)
				return
			end

			vim.schedule(function()
				callback(response.data, nil)
			end)
		end,
	}):start()
end

-- Fetch PR data
---@param owner string Repository owner
---@param repo string Repository name
---@param number number PR number
---@param callback function Callback(pr_data, error)
function M.fetch_pr(owner, repo, number, callback)
	local query = [[
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $number) {
          id
          number
          title
          body
          state
          author {
            login
          }
          baseRefName
          headRefName
          baseRefOid
          headRefOid
          createdAt
          updatedAt
          files(first: 100) {
            nodes {
              path
              additions
              deletions
              changeType
            }
          }
          comments(first: 100) {
            nodes {
              id
              body
              author {
                login
              }
              createdAt
              path
              position
            }
          }
          reviews(first: 50) {
            nodes {
              id
              author {
                login
              }
              state
              body
              createdAt
            }
          }
        }
      }
    }
  ]]

	execute_query(query, { owner = owner, repo = repo, number = number }, function(data, err)
		if err then
			callback(nil, err)
			return
		end

		local pr = data.repository.pullRequest
		local pr_data = {
			owner = owner,
			repo = repo,
			id = pr.id,
			number = pr.number,
			title = pr.title,
			body = pr.body or "",
			state = pr.state,
			author = pr.author.login,
			base_branch = pr.baseRefName,
			head_branch = pr.headRefName,
			base_sha = pr.baseRefOid,
			head_sha = pr.headRefOid,
			created_at = pr.createdAt,
			updated_at = pr.updatedAt,
			files = {},
			comments = {},
			reviews = {},
		}

		-- Parse files
		for _, file in ipairs(pr.files.nodes or {}) do
			table.insert(pr_data.files, {
				path = file.path,
				additions = file.additions,
				deletions = file.deletions,
				status = file.changeType:lower(),
			})
		end

		-- Parse comments
		for _, comment in ipairs(pr.comments.nodes or {}) do
			table.insert(pr_data.comments, {
				id = comment.id,
				body = comment.body,
				author = comment.author.login,
				created_at = comment.createdAt,
				path = comment.path,
				position = comment.position,
			})
		end

		-- Parse reviews
		for _, review in ipairs(pr.reviews.nodes or {}) do
			table.insert(pr_data.reviews, {
				id = review.id,
				author = review.author.login,
				state = review.state,
				body = review.body or "",
				created_at = review.createdAt,
			})
		end

		callback(pr_data, nil)
	end)
end

-- Fetch file diff/patch
---@param owner string
---@param repo string
---@param base_sha string
---@param head_sha string
---@param file_path string
---@param callback function Callback(patch, error)
function M.fetch_file_diff(owner, repo, base_sha, head_sha, file_path, callback)
	-- Use git diff via GitHub API
	local url = string.format("https://api.github.com/repos/%s/%s/compare/%s...%s", owner, repo, base_sha, head_sha)

	local token = get_token()
	if not token then
		callback(nil, "No GitHub token found")
		return
	end

	Job:new({
		command = "curl",
		args = {
			"-H",
			"Authorization: Bearer " .. token,
			"-H",
			"Accept: application/vnd.github.v3.diff",
			url,
		},
		on_exit = function(j, return_val)
			if return_val ~= 0 then
				vim.schedule(function()
					callback(nil, "Failed to fetch diff")
				end)
				return
			end

			local diff = table.concat(j:result(), "\n")
			vim.schedule(function()
				callback(diff, nil)
			end)
		end,
	}):start()
end

-- Add PR review comment
---@param pr_id string
---@param path string File path
---@param position number Diff position
---@param body string Comment body
---@param callback function Callback(comment, error)
function M.add_comment(pr_id, path, position, body, callback)
	local mutation = [[
    mutation($input: AddPullRequestReviewCommentInput!) {
      addPullRequestReviewComment(input: $input) {
        comment {
          id
          body
          createdAt
        }
      }
    }
  ]]

	local input = {
		pullRequestId = pr_id,
		path = path,
		position = position,
		body = body,
	}

	execute_query(mutation, { input = input }, function(data, err)
		if err then
			callback(nil, err)
			return
		end

		callback(data.addPullRequestReviewComment.comment, nil)
	end)
end

-- Submit PR review
---@param pr_id string
---@param event string COMMENT | APPROVE | REQUEST_CHANGES
---@param body string|nil Review body
---@param comments table|nil List of {path, position, body}
---@param callback function Callback(review, error)
function M.submit_review(pr_id, event, body, comments, callback)
	-- First, add review comments if any
	-- Then submit the review
	local mutation = [[
    mutation($input: SubmitPullRequestReviewInput!) {
      submitPullRequestReview(input: $input) {
        pullRequestReview {
          id
          state
          body
          createdAt
        }
      }
    }
  ]]

	local input = {
		pullRequestId = pr_id,
		event = event,
		body = body or "",
	}

	execute_query(mutation, { input = input }, function(data, err)
		if err then
			callback(nil, err)
			return
		end

		callback(data.submitPullRequestReview.pullRequestReview, nil)
	end)
end

return M

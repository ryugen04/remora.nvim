-- PR Comments mode for remora.nvim right pane

local M = {}

local state = require('remora.state')
local events = require('remora.events')
local buffer_utils = require('remora.utils.buffer')
local comments_component = require('remora.ui.components.comments')

-- Render PR Comments mode
---@param bufnr number
function M.render(bufnr)
  local lines = comments_component.render_comments_list()

  buffer_utils.set_lines(bufnr, lines, { modifiable = false })

  -- Set up keymaps
  M._setup_keymaps(bufnr)
end

-- Set up keymaps for PR Comments mode
---@param bufnr number
function M._setup_keymaps(bufnr)
  -- e: Edit comment
  buffer_utils.set_keymap(bufnr, 'n', 'e', function()
    M._edit_comment()
  end, { desc = 'Edit comment' })

  -- d: Delete comment
  buffer_utils.set_keymap(bufnr, 'n', 'd', function()
    M._delete_comment()
  end, { desc = 'Delete comment' })

  -- s: Submit review
  buffer_utils.set_keymap(bufnr, 'n', 's', function()
    M.submit_review()
  end, { desc = 'Submit review' })

  -- a: Add comment (opens diffview of current file)
  buffer_utils.set_keymap(bufnr, 'n', 'a', function()
    vim.notify('Open a file from left pane and use <leader>rc to add comments', vim.log.levels.INFO)
  end, { desc = 'Add comment help' })
end

-- Edit comment
function M._edit_comment()
  -- Prompt for comment number
  vim.ui.input({ prompt = 'Comment number to edit: ' }, function(input)
    if not input then
      return
    end

    local comment_idx = tonumber(input)
    if not comment_idx or comment_idx < 1 or comment_idx > #state.draft_comments then
      vim.notify('Invalid comment number', vim.log.levels.ERROR)
      return
    end

    local comment = state.draft_comments[comment_idx]

    -- Prompt for new body
    vim.ui.input({ prompt = 'New comment: ', default = comment.body }, function(new_body)
      if not new_body or new_body == '' then
        return
      end

      -- Update comment
      comment.body = new_body
      comment.updated_at = os.date('%Y-%m-%dT%H:%M:%S')

      state.save()
      events.emit(events.COMMENT_UPDATED, comment)

      vim.notify('Comment updated', vim.log.levels.INFO)

      -- Refresh right pane
      local right_pane = require('remora.ui.right_pane')
      right_pane.render()
    end)
  end)
end

-- Delete comment
function M._delete_comment()
  if #state.draft_comments == 0 then
    vim.notify('No comments to delete', vim.log.levels.WARN)
    return
  end

  -- Prompt for comment number
  vim.ui.input({ prompt = 'Comment number to delete: ' }, function(input)
    if not input then
      return
    end

    local comment_idx = tonumber(input)
    if not comment_idx or comment_idx < 1 or comment_idx > #state.draft_comments then
      vim.notify('Invalid comment number', vim.log.levels.ERROR)
      return
    end

    local comment = table.remove(state.draft_comments, comment_idx)

    -- Update file state
    if state.files[comment.path] then
      state.files[comment.path].comments_count = math.max(0, (state.files[comment.path].comments_count or 0) - 1)
    end

    state.save()
    events.emit(events.COMMENT_DELETED, comment)

    vim.notify('Comment deleted', vim.log.levels.INFO)

    -- Refresh right pane
    local right_pane = require('remora.ui.right_pane')
    right_pane.render()
  end)
end

-- Submit review to GitHub
function M.submit_review()
  if not state.current_pr then
    vim.notify('No PR loaded', vim.log.levels.WARN)
    return
  end

  if #state.draft_comments == 0 then
    vim.notify('No draft comments to submit', vim.log.levels.WARN)
    return
  end

  -- Show review type selection
  M._show_review_type_selection()
end

-- Show review type selection dialog
function M._show_review_type_selection()
  local choices = {
    'COMMENT - General feedback',
    'APPROVE - Approve changes',
    'REQUEST_CHANGES - Request changes before merge',
  }

  vim.ui.select(choices, {
    prompt = 'Select review type:',
  }, function(choice, idx)
    if not choice then
      return
    end

    local review_events = { 'COMMENT', 'APPROVE', 'REQUEST_CHANGES' }
    local review_event = review_events[idx]

    -- Prompt for overall review comment
    vim.ui.input({ prompt = 'Overall review comment (optional): ' }, function(overall_comment)
      M._submit_review_to_github(review_event, overall_comment or '')
    end)
  end)
end

-- Submit review to GitHub
---@param review_event string COMMENT | APPROVE | REQUEST_CHANGES
---@param overall_comment string
function M._submit_review_to_github(review_event, overall_comment)
  local github = require('remora.core.github')
  local pr = state.current_pr

  vim.notify('Submitting review...', vim.log.levels.INFO)

  -- Prepare comments for GitHub
  local formatted_comments = {}
  for _, comment in ipairs(state.draft_comments) do
    table.insert(formatted_comments, {
      path = comment.path,
      position = comment.position or 1, -- TODO: Calculate proper diff position
      body = comments_component.format_for_github(comment),
    })
  end

  -- Submit review
  github.submit_review(pr.id, review_event, overall_comment, formatted_comments, function(review, err)
    if err then
      vim.notify('Failed to submit review: ' .. err, vim.log.levels.ERROR)
      return
    end

    vim.notify('Review submitted successfully!', vim.log.levels.INFO)

    -- Clear draft comments
    state.draft_comments = {}
    state.save()

    events.emit(events.REVIEW_SUBMITTED, review)

    -- Refresh UI
    local right_pane = require('remora.ui.right_pane')
    right_pane.render()

    -- Refresh PR data from GitHub
    require('remora').refresh()
  end)
end

return M

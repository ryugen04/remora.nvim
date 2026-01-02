-- Comments component for remora.nvim

local M = {}

local state = require('remora.state')

-- Render comments list (for PR Comments mode in right pane)
---@return table lines
function M.render_comments_list()
  local lines = {}

  table.insert(lines, '═══════════════════════════════════════════════════════════')
  table.insert(lines, ' PR Comments & Suggestions')
  table.insert(lines, '═══════════════════════════════════════════════════════════')
  table.insert(lines, '')

  local draft_count = #state.draft_comments

  if draft_count == 0 then
    table.insert(lines, '📭 No draft comments')
    table.insert(lines, '')
    table.insert(lines, 'To add a comment:')
    table.insert(lines, '  1. Open a file with <CR> in left pane')
    table.insert(lines, '  2. Navigate to a line in diffview')
    table.insert(lines, '  3. Press <leader>rc to add comment')
    table.insert(lines, '  4. Press <leader>rs (visual mode) for suggestion')
    table.insert(lines, '')
    table.insert(lines, 'Keybindings:')
    table.insert(lines, '  <leader>rc  Add review comment')
    table.insert(lines, '  <leader>rs  Add suggestion (visual mode)')
    return lines
  end

  -- Draft comments section
  table.insert(lines, string.format('📝 Draft Comments (%d)', draft_count))
  table.insert(lines, '─────────────────────────────────────────────────────────')
  table.insert(lines, '')

  for i, comment in ipairs(state.draft_comments) do
    local icon = comment.is_suggestion and '💡' or '💬'
    local line_info = comment.line and string.format(':%d', comment.line) or ''

    table.insert(lines, string.format('%d. %s %s%s', i, icon, comment.path, line_info))

    -- Split body into lines
    for _, body_line in ipairs(vim.split(comment.body, '\n')) do
      table.insert(lines, '   ' .. body_line)
    end

    -- Show suggestion code if present
    if comment.is_suggestion and comment.suggestion_code then
      table.insert(lines, '')
      table.insert(lines, '   Suggested code:')
      for _, code_line in ipairs(vim.split(comment.suggestion_code, '\n')) do
        table.insert(lines, '   │ ' .. code_line)
      end
    end

    table.insert(lines, '')
    table.insert(lines, string.format('   Created: %s', M._format_date(comment.created_at)))
    table.insert(lines, '')
  end

  -- Actions
  table.insert(lines, '⌨️  Actions')
  table.insert(lines, '─────────────────────────────────────────────────────────')
  table.insert(lines, '  e    Edit comment')
  table.insert(lines, '  d    Delete comment')
  table.insert(lines, '  s    Submit all as review')

  return lines
end

-- Render review submission dialog
---@return table lines
function M.render_review_dialog()
  local lines = {}

  table.insert(lines, '═══════════════════════════════════════════════════════════')
  table.insert(lines, ' Submit Review')
  table.insert(lines, '═══════════════════════════════════════════════════════════')
  table.insert(lines, '')

  local draft_count = #state.draft_comments

  table.insert(lines, string.format('You have %d draft comment%s', draft_count, draft_count == 1 and '' or 's'))
  table.insert(lines, '')

  if draft_count > 0 then
    table.insert(lines, 'Comments to submit:')
    table.insert(lines, '')

    for i, comment in ipairs(state.draft_comments) do
      local icon = comment.is_suggestion and '💡' or '💬'
      table.insert(lines, string.format('  %d. %s %s:%d', i, icon, comment.path, comment.line or 0))
    end

    table.insert(lines, '')
  end

  table.insert(lines, 'Review Type:')
  table.insert(lines, '  1. Comment      - General feedback')
  table.insert(lines, '  2. Approve      - Approve changes')
  table.insert(lines, '  3. Request Changes - Request changes before merge')
  table.insert(lines, '')

  table.insert(lines, 'Overall Review Comment (optional):')
  table.insert(lines, '[Press <Enter> to add overall comment]')
  table.insert(lines, '')

  table.insert(lines, 'Press:')
  table.insert(lines, '  1/2/3  Select review type and submit')
  table.insert(lines, '  q      Cancel')

  return lines
end

-- Format comment for GitHub API
---@param comment table Draft comment
---@return string body Formatted comment body
function M.format_for_github(comment)
  local body = comment.body

  if comment.is_suggestion and comment.suggestion_code then
    -- Format as GitHub suggestion
    body = body .. '\n\n```suggestion\n' .. comment.suggestion_code .. '\n```'
  end

  return body
end

-- Parse GitHub comment to extract suggestion
---@param github_comment table Comment from GitHub API
---@return table parsed {body, is_suggestion, suggestion_code}
function M.parse_github_comment(github_comment)
  local body = github_comment.body
  local is_suggestion = false
  local suggestion_code = nil

  -- Check for suggestion block
  local suggestion_pattern = '```suggestion\n(.-)```'
  local suggestion = body:match(suggestion_pattern)

  if suggestion then
    is_suggestion = true
    suggestion_code = suggestion
    -- Remove suggestion block from body
    body = body:gsub(suggestion_pattern, ''):gsub('\n\n+', '\n\n')
  end

  return {
    body = vim.trim(body),
    is_suggestion = is_suggestion,
    suggestion_code = suggestion_code,
  }
end

-- Format date
---@param date_str string
---@return string
function M._format_date(date_str)
  if not date_str then
    return 'N/A'
  end

  local date_part = date_str:match('^(%d%d%d%d%-%d%d%-%d%d)')
  local time_part = date_str:match('T(%d%d:%d%d)')

  if date_part and time_part then
    return date_part .. ' ' .. time_part
  end

  return date_part or date_str
end

return M

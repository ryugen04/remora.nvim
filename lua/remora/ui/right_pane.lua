-- Right pane management for remora.nvim

local M = {}

local state = require('remora.state')
local events = require('remora.events')
local buffer_utils = require('remora.utils.buffer')

-- Pane state
M.bufnr = nil
M.ns = nil

-- Available modes
M.modes = {
  { id = 'ai_review', label = 'Review' },
  { id = 'ai_ask', label = 'Ask' },
  { id = 'pr_comments', label = 'PR' },
  { id = 'local_memo', label = 'Memo' },
}

-- Initialize right pane
---@param bufnr number
function M.init(bufnr)
  M.bufnr = bufnr
  M.ns = buffer_utils.create_namespace('remora-right-pane')

  -- Set up keymaps
  M._setup_keymaps()

  -- Initial render
  M.render()

  -- Listen to events
  events.on(events.MODE_CHANGED, function()
    M.render()
  end)
end

-- Render right pane
function M.render()
  if not buffer_utils.is_valid(M.bufnr) then
    return
  end

  local lines = {}

  -- Mode tabs
  local tabs = {}
  for i, mode in ipairs(M.modes) do
    local is_active = state.ui.right_pane_mode == mode.id
    local bracket_left = is_active and '[' or ' '
    local bracket_right = is_active and ']' or ' '
    table.insert(tabs, string.format('%s%s%s', bracket_left, mode.label, bracket_right))
  end

  table.insert(lines, table.concat(tabs, ' '))
  table.insert(lines, string.rep('─', 50))
  table.insert(lines, '')

  -- Render mode content
  local mode_lines = M._render_mode_content()
  for _, line in ipairs(mode_lines) do
    table.insert(lines, line)
  end

  -- Update buffer
  buffer_utils.set_lines(M.bufnr, lines)
end

-- Render content for current mode
---@return table lines
function M._render_mode_content()
  local mode = state.ui.right_pane_mode

  if mode == 'ai_review' then
    return M._render_ai_review()
  elseif mode == 'ai_ask' then
    return M._render_ai_ask()
  elseif mode == 'pr_comments' then
    return M._render_pr_comments()
  elseif mode == 'local_memo' then
    return M._render_local_memo()
  end

  return { 'Unknown mode: ' .. mode }
end

-- Render AI Review mode
---@return table lines
function M._render_ai_review()
  local lines = {}

  table.insert(lines, '🤖 AI Review Mode')
  table.insert(lines, '')
  table.insert(lines, 'Use this mode to request AI-powered code reviews.')
  table.insert(lines, '')
  table.insert(lines, 'Features:')
  table.insert(lines, '  • Context injection from PR description')
  table.insert(lines, '  • Automatic issue detection')
  table.insert(lines, '  • Suggestion generation')
  table.insert(lines, '')
  table.insert(lines, 'Commands:')
  table.insert(lines, '  :RemoraAIReview       Start AI review')
  table.insert(lines, '  :RemoraAIReviewFile   Review current file')
  table.insert(lines, '')
  table.insert(lines, '[AI Review integration coming in Phase 5]')

  return lines
end

-- Render AI Ask mode
---@return table lines
function M._render_ai_ask()
  local lines = {}

  table.insert(lines, '💬 AI Ask Mode')
  table.insert(lines, '')
  table.insert(lines, 'Use this mode for general questions to Claude Code.')
  table.insert(lines, '')
  table.insert(lines, 'Features:')
  table.insert(lines, '  • No context injection')
  table.insert(lines, '  • Direct access to Claude Code CLI')
  table.insert(lines, '  • General programming assistance')
  table.insert(lines, '')
  table.insert(lines, 'Commands:')
  table.insert(lines, '  :RemoraAsk <question>   Ask Claude Code')
  table.insert(lines, '')
  table.insert(lines, '[AI Ask integration coming in Phase 5]')

  return lines
end

-- Render PR Comments mode
---@return table lines
function M._render_pr_comments()
  local lines = {}

  table.insert(lines, '💬 PR Comments')
  table.insert(lines, '')

  local draft_count = #state.draft_comments

  if draft_count > 0 then
    table.insert(lines, string.format('Draft Comments: %d', draft_count))
    table.insert(lines, '')

    for i, comment in ipairs(state.draft_comments) do
      table.insert(lines, string.format('%d. %s:%d', i, comment.path, comment.line))
      table.insert(lines, '   ' .. comment.body)
      table.insert(lines, '')
    end

    table.insert(lines, '')
    table.insert(lines, 'Commands:')
    table.insert(lines, '  s    Submit review')
    table.insert(lines, '  d    Delete comment')
  else
    table.insert(lines, 'No draft comments')
    table.insert(lines, '')
    table.insert(lines, 'To add a comment:')
    table.insert(lines, '  1. Open a file in diffview')
    table.insert(lines, '  2. Navigate to a line')
    table.insert(lines, '  3. Press <leader>rc to add comment')
  end

  return lines
end

-- Render Local Memo mode
---@return table lines
function M._render_local_memo()
  local memos_component = require('remora.ui.components.memos')
  return memos_component.render_detail()
end

-- Set up keymaps
function M._setup_keymaps()
  -- Tab navigation: 1, 2, 3, 4
  for i, mode in ipairs(M.modes) do
    buffer_utils.set_keymap(M.bufnr, 'n', tostring(i), function()
      M._switch_mode(mode.id)
    end, { desc = 'Switch to ' .. mode.label })
  end

  -- Tab/Shift-Tab to cycle modes
  buffer_utils.set_keymap(M.bufnr, 'n', '<Tab>', function()
    M._next_mode()
  end, { desc = 'Next mode' })

  buffer_utils.set_keymap(M.bufnr, 'n', '<S-Tab>', function()
    M._prev_mode()
  end, { desc = 'Previous mode' })
end

-- Switch to a specific mode
---@param mode_id string
function M._switch_mode(mode_id)
  state.ui.right_pane_mode = mode_id
  events.emit(events.MODE_CHANGED, mode_id)
  M.render()
end

-- Switch to next mode
function M._next_mode()
  local current_idx = 1
  for i, mode in ipairs(M.modes) do
    if mode.id == state.ui.right_pane_mode then
      current_idx = i
      break
    end
  end

  local next_idx = (current_idx % #M.modes) + 1
  M._switch_mode(M.modes[next_idx].id)
end

-- Switch to previous mode
function M._prev_mode()
  local current_idx = 1
  for i, mode in ipairs(M.modes) do
    if mode.id == state.ui.right_pane_mode then
      current_idx = i
      break
    end
  end

  local prev_idx = current_idx == 1 and #M.modes or (current_idx - 1)
  M._switch_mode(M.modes[prev_idx].id)
end

return M

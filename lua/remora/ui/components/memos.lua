-- Memos component for remora.nvim

local M = {}

local state = require('remora.state')

-- Render memos section
---@return table lines
function M.render()
  local lines = {}

  -- Global notes
  local global_notes = state.notes.global or {}
  local todos = vim.tbl_filter(function(note) return note.type == 'TODO' end, global_notes)
  local notes = vim.tbl_filter(function(note) return note.type == 'NOTE' end, global_notes)

  -- Count file-specific notes
  local file_note_count = 0
  for _, file_notes in pairs(state.notes.by_file or {}) do
    file_note_count = file_note_count + #file_notes
  end

  -- TODOs
  if #todos > 0 then
    table.insert(lines, string.format('▼ TODOs (%d)', #todos))

    for _, todo in ipairs(todos) do
      table.insert(lines, string.format('  ☐ %s', todo.content))
    end
  else
    table.insert(lines, '▼ TODOs (0)')
  end

  table.insert(lines, '')

  -- Notes
  if #notes > 0 then
    table.insert(lines, string.format('▼ Notes (%d)', #notes))

    for _, note in ipairs(notes) do
      table.insert(lines, string.format('  📝 %s', note.content))
    end
  else
    table.insert(lines, '▼ Notes (0)')
  end

  table.insert(lines, '')

  -- File notes summary
  if file_note_count > 0 then
    table.insert(lines, string.format('📎 %d notes in files', file_note_count))
  end

  return lines
end

-- Render detailed memos (for right pane memo mode)
---@return table lines
function M.render_detail()
  local lines = {}

  table.insert(lines, '═══════════════════════════════════════════════════════════')
  table.insert(lines, ' Local Memos')
  table.insert(lines, '═══════════════════════════════════════════════════════════')
  table.insert(lines, '')

  -- Global TODOs
  local global_notes = state.notes.global or {}
  local todos = vim.tbl_filter(function(note) return note.type == 'TODO' end, global_notes)

  if #todos > 0 then
    table.insert(lines, '☐ TODOs')
    table.insert(lines, '─────────────────────────────────────────────────────────')

    for i, todo in ipairs(todos) do
      table.insert(lines, string.format('%d. %s', i, todo.content))
      table.insert(lines, string.format('   Created: %s', M._format_date(todo.created_at)))
      table.insert(lines, '')
    end
  else
    table.insert(lines, '☐ No TODOs')
    table.insert(lines, '')
  end

  -- Global Notes
  local notes = vim.tbl_filter(function(note) return note.type == 'NOTE' end, global_notes)

  if #notes > 0 then
    table.insert(lines, '📝 Notes')
    table.insert(lines, '─────────────────────────────────────────────────────────')

    for i, note in ipairs(notes) do
      table.insert(lines, string.format('%d. %s', i, note.content))
      table.insert(lines, string.format('   Created: %s', M._format_date(note.created_at)))
      table.insert(lines, '')
    end
  else
    table.insert(lines, '📝 No Notes')
    table.insert(lines, '')
  end

  -- File-specific notes
  local file_notes = state.notes.by_file or {}
  local has_file_notes = false

  for file_path, notes_list in pairs(file_notes) do
    if #notes_list > 0 then
      has_file_notes = true
      break
    end
  end

  if has_file_notes then
    table.insert(lines, '📎 File Notes')
    table.insert(lines, '─────────────────────────────────────────────────────────')

    for file_path, notes_list in pairs(file_notes) do
      if #notes_list > 0 then
        table.insert(lines, string.format('  %s', file_path))

        for _, note in ipairs(notes_list) do
          local line_info = note.line and string.format(' (line %d)', note.line) or ''
          table.insert(lines, string.format('    • %s%s', note.content, line_info))
        end

        table.insert(lines, '')
      end
    end
  end

  -- Instructions
  table.insert(lines, '⌨️  Actions')
  table.insert(lines, '─────────────────────────────────────────────────────────')
  table.insert(lines, '  a        Add new TODO')
  table.insert(lines, '  n        Add new note')
  table.insert(lines, '  d        Delete note')

  return lines
end

-- Format date
---@param date_str string
---@return string
function M._format_date(date_str)
  if not date_str then
    return 'N/A'
  end

  local date_part = date_str:match('^(%d%d%d%d%-%d%d%-%d%d)')
  return date_part or date_str
end

return M

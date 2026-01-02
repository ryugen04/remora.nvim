-- Local changes component for remora.nvim

local M = {}

local state = require('remora.state')

-- Render local changes section
---@return table lines, table metadata
function M.render()
  local lines = {}
  local metadata = {}

  local local_changes = state.local_changes

  if not local_changes or not local_changes.loaded then
    table.insert(lines, '  Loading...')
    table.insert(metadata, { type = 'local_changes_info' })
    return lines, metadata
  end

  -- Unpushed Commits
  local commits = local_changes.unpushed_commits or {}
  if #commits > 0 then
    table.insert(lines, string.format('Unpushed Commits (%d)', #commits))
    table.insert(metadata, { type = 'local_changes_header', subtype = 'commits' })

    for _, commit in ipairs(commits) do
      local line = string.format('  %s %s', commit.sha, commit.message)
      if #line > 38 then
        line = line:sub(1, 35) .. '...'
      end
      table.insert(lines, line)
      table.insert(metadata, { type = 'commit', sha = commit.sha })
    end

    table.insert(lines, '')
    table.insert(metadata, { type = 'blank' })
  end

  -- Staged Changes
  local staged = local_changes.staged or {}
  if #staged > 0 then
    table.insert(lines, string.format('Staged (%d)', #staged))
    table.insert(metadata, { type = 'local_changes_header', subtype = 'staged' })

    for _, file in ipairs(staged) do
      local icon = M._get_status_icon(file.status)
      table.insert(lines, string.format('  %s %s', icon, file.path))
      table.insert(metadata, {
        type = 'local_file',
        path = file.path,
        status = file.status,
        is_staged = true,
        hl_group = M._get_status_hl(file.status),
      })
    end

    table.insert(lines, '')
    table.insert(metadata, { type = 'blank' })
  end

  -- Unstaged Changes
  local unstaged = local_changes.unstaged or {}
  if #unstaged > 0 then
    table.insert(lines, string.format('Unstaged (%d)', #unstaged))
    table.insert(metadata, { type = 'local_changes_header', subtype = 'unstaged' })

    for _, file in ipairs(unstaged) do
      local icon = M._get_status_icon(file.status)
      table.insert(lines, string.format('  %s %s', icon, file.path))
      table.insert(metadata, {
        type = 'local_file',
        path = file.path,
        status = file.status,
        is_staged = false,
        hl_group = M._get_status_hl(file.status),
      })
    end
  end

  -- 変更がない場合
  if #commits == 0 and #staged == 0 and #unstaged == 0 then
    table.insert(lines, '  No local changes')
    table.insert(metadata, { type = 'local_changes_info' })
  end

  return lines, metadata
end

-- ステータスアイコン
function M._get_status_icon(status)
  local icons = {
    A = '+',  -- Added
    M = '~',  -- Modified
    D = '-',  -- Deleted
    R = '>',  -- Renamed
    C = 'C',  -- Copied
    ['?'] = '?',  -- Untracked
    untracked = '?',
  }
  return icons[status] or '*'
end

-- ステータスハイライト
function M._get_status_hl(status)
  if status == 'A' or status == '?' or status == 'untracked' then
    return 'RemoraFileAdded'
  elseif status == 'M' then
    return 'RemoraFileModified'
  elseif status == 'D' then
    return 'RemoraFileDeleted'
  elseif status == 'R' then
    return 'RemoraFileRenamed'
  end
  return 'Normal'
end

return M

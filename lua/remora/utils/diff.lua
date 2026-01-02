-- Diff utilities for remora.nvim

local M = {}

-- Parse unified diff output into structured hunks
---@param diff_text string Output from vim.diff()
---@return table hunks List of {old_start, old_count, new_start, new_count, lines}
function M.parse_diff(diff_text)
  local hunks = {}
  local current_hunk = nil

  for line in diff_text:gmatch('[^\n]+') do
    -- Match hunk header: @@ -old_start,old_count +new_start,new_count @@
    local old_start, old_count, new_start, new_count = line:match('^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@')
    if old_start then
      if current_hunk then
        table.insert(hunks, current_hunk)
      end
      current_hunk = {
        old_start = tonumber(old_start),
        old_count = tonumber(old_count) or 1,
        new_start = tonumber(new_start),
        new_count = tonumber(new_count) or 1,
        lines = {},
      }
    elseif current_hunk then
      table.insert(current_hunk.lines, line)
    end
  end

  if current_hunk then
    table.insert(hunks, current_hunk)
  end

  return hunks
end

-- Create aligned diff lines for side-by-side view
---@param base_lines table Lines from base version
---@param head_lines table Lines from head version
---@return table result {left_lines, right_lines, left_hl, right_hl, left_lnum, right_lnum}
function M.create_aligned_diff(base_lines, head_lines)
  local base_text = table.concat(base_lines, '\n')
  local head_text = table.concat(head_lines, '\n')

  -- Get diff
  local diff_text = vim.diff(base_text, head_text, {
    algorithm = 'histogram',
    ctxlen = 0,
  })

  if not diff_text or diff_text == '' then
    -- No changes - return as is
    local left_hl = {}
    local right_hl = {}
    local left_lnum = {}
    local right_lnum = {}
    for i = 1, #base_lines do
      left_hl[i] = 'normal'
      right_hl[i] = 'normal'
      left_lnum[i] = i
      right_lnum[i] = i
    end
    return {
      left_lines = base_lines,
      right_lines = head_lines,
      left_hl = left_hl,
      right_hl = right_hl,
      left_lnum = left_lnum,
      right_lnum = right_lnum,
    }
  end

  local hunks = M.parse_diff(diff_text)

  -- Build aligned output
  local left_lines = {}
  local right_lines = {}
  local left_hl = {}  -- 'normal', 'delete', 'change'
  local right_hl = {} -- 'normal', 'add', 'change'
  local left_lnum = {}  -- オリジナル行番号 (nilはパディング)
  local right_lnum = {} -- オリジナル行番号 (nilはパディング)

  local base_idx = 1
  local head_idx = 1

  for _, hunk in ipairs(hunks) do
    -- Add unchanged lines before this hunk
    while base_idx < hunk.old_start and head_idx < hunk.new_start do
      table.insert(left_lines, base_lines[base_idx] or '')
      table.insert(right_lines, head_lines[head_idx] or '')
      table.insert(left_hl, 'normal')
      table.insert(right_hl, 'normal')
      table.insert(left_lnum, base_idx)
      table.insert(right_lnum, head_idx)
      base_idx = base_idx + 1
      head_idx = head_idx + 1
    end

    -- Process hunk lines
    local del_lines = {}
    local add_lines = {}
    local del_lnums = {}
    local add_lnums = {}

    local del_idx = hunk.old_start
    local add_idx = hunk.new_start

    for _, line in ipairs(hunk.lines) do
      local prefix = line:sub(1, 1)
      local content = line:sub(2)
      if prefix == '-' then
        table.insert(del_lines, content)
        table.insert(del_lnums, del_idx)
        del_idx = del_idx + 1
      elseif prefix == '+' then
        table.insert(add_lines, content)
        table.insert(add_lnums, add_idx)
        add_idx = add_idx + 1
      end
    end

    -- Align deletions and additions
    local max_lines = math.max(#del_lines, #add_lines)
    for i = 1, max_lines do
      local del_line = del_lines[i]
      local add_line = add_lines[i]

      if del_line and add_line then
        -- Both exist - likely a change
        table.insert(left_lines, del_line)
        table.insert(right_lines, add_line)
        table.insert(left_hl, 'change')
        table.insert(right_hl, 'change')
        table.insert(left_lnum, del_lnums[i])
        table.insert(right_lnum, add_lnums[i])
      elseif del_line then
        -- Only deletion
        table.insert(left_lines, del_line)
        table.insert(right_lines, '')
        table.insert(left_hl, 'delete')
        table.insert(right_hl, 'padding')
        table.insert(left_lnum, del_lnums[i])
        table.insert(right_lnum, false)  -- パディング行
      else
        -- Only addition
        table.insert(left_lines, '')
        table.insert(right_lines, add_line)
        table.insert(left_hl, 'padding')
        table.insert(right_hl, 'add')
        table.insert(left_lnum, false)  -- パディング行
        table.insert(right_lnum, add_lnums[i])
      end
    end

    -- 次の開始位置（最低1から）
    base_idx = math.max(1, hunk.old_start + hunk.old_count)
    head_idx = math.max(1, hunk.new_start + hunk.new_count)
  end

  -- Add remaining unchanged lines
  while base_idx <= #base_lines or head_idx <= #head_lines do
    table.insert(left_lines, base_lines[base_idx] or '')
    table.insert(right_lines, head_lines[head_idx] or '')
    table.insert(left_hl, 'normal')
    table.insert(right_hl, 'normal')
    table.insert(left_lnum, base_idx <= #base_lines and base_idx or false)
    table.insert(right_lnum, head_idx <= #head_lines and head_idx or false)
    base_idx = base_idx + 1
    head_idx = head_idx + 1
  end

  return {
    left_lines = left_lines,
    right_lines = right_lines,
    left_hl = left_hl,
    right_hl = right_hl,
    left_lnum = left_lnum,
    right_lnum = right_lnum,
  }
end

-- Get highlight group for diff type
---@param diff_type string 'normal', 'add', 'delete', 'change', 'padding'
---@param side string 'left' or 'right'
---@return string hl_group
function M.get_highlight(diff_type, side)
  if diff_type == 'add' then
    return 'DiffAdd'
  elseif diff_type == 'delete' then
    return 'DiffDelete'
  elseif diff_type == 'change' then
    return side == 'left' and 'DiffChange' or 'DiffText'
  elseif diff_type == 'padding' then
    return 'DiffDelete'
  end
  return nil
end

return M

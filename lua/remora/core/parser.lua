-- Parser for AI review responses and diffs

local M = {}

-- Parse AI review response
---@param response string Raw AI response
---@return table review {summary, findings}
function M.parse_ai_review(response)
  local review = {
    summary = '',
    findings = {},
    raw_response = response,
    timestamp = os.date('%Y-%m-%dT%H:%M:%S'),
  }

  -- Extract summary
  local summary = response:match('SUMMARY:%s*(.-)[\n\r][\n\r]')
  if summary then
    review.summary = vim.trim(summary)
  else
    -- If no formatted summary, use first paragraph
    local first_para = response:match('^(.-)[\n\r][\n\r]')
    if first_para then
      review.summary = vim.trim(first_para)
    else
      review.summary = response:sub(1, 200)
    end
  end

  -- Extract findings
  local findings_text = response:match('FINDING:.-$') or response

  -- Split by --- or FINDING: markers
  local finding_blocks = vim.split(findings_text, '\n%-%-%-\n')

  for _, block in ipairs(finding_blocks) do
    local finding = M._parse_finding_block(block)
    if finding then
      table.insert(review.findings, finding)
    end
  end

  return review
end

-- Parse individual finding block
---@param block string Finding text block
---@return table|nil finding {file, line, severity, title, description}
function M._parse_finding_block(block)
  if not block or vim.trim(block) == '' then
    return nil
  end

  local finding = {}

  -- Extract file and line
  local file_line = block:match('FINDING:%s*([^%s]+):(%d+)')
  if file_line then
    finding.file, finding.line = file_line:match('([^:]+):(%d+)')
    finding.line = tonumber(finding.line)
  else
    -- Try alternate format
    local file = block:match('File:%s*([^%s\n]+)')
    local line = block:match('Line:%s*(%d+)')

    if file then
      finding.file = file
      finding.line = tonumber(line) or 0
    else
      -- No specific file/line, skip this finding
      return nil
    end
  end

  -- Extract severity
  local severity = block:match('SEVERITY:%s*(%w+)')
  finding.severity = severity and vim.trim(severity:lower()) or 'info'

  -- Extract title
  local title = block:match('TITLE:%s*([^\n]+)')
  finding.title = title and vim.trim(title) or 'Issue Found'

  -- Extract description
  local description = block:match('DESCRIPTION:%s*(.+)')
  finding.description = description and vim.trim(description) or block

  return finding
end

-- Parse diff to calculate positions
---@param diff string Git diff text
---@return table positions Map of line -> diff position
function M.parse_diff_positions(diff)
  local positions = {}
  local current_line = 0
  local position = 0

  for line in diff:gmatch('[^\n]+') do
    position = position + 1

    -- Check if this is a hunk header
    local new_start = line:match('^@@.-\\+(%d+)')
    if new_start then
      current_line = tonumber(new_start)
    elseif line:match('^%+') and not line:match('^%+%+%+') then
      -- This is an added line
      positions[current_line] = position
      current_line = current_line + 1
    elseif not line:match('^%-') then
      -- Context line
      current_line = current_line + 1
    end
  end

  return positions
end

-- Extract suggestion code from comment body
---@param body string Comment body
---@return string|nil suggestion_code
function M.extract_suggestion(body)
  local suggestion = body:match('```suggestion\n(.-)```')
  if suggestion then
    return vim.trim(suggestion)
  end
  return nil
end

-- Build suggestion markdown
---@param code string Suggested code
---@return string markdown
function M.build_suggestion_markdown(code)
  return string.format('```suggestion\n%s\n```', code)
end

-- Parse GitHub diff to get file changes
---@param diff string Full diff text
---@return table files List of {path, additions, deletions, patch}
function M.parse_github_diff(diff)
  local files = {}
  local current_file = nil

  for line in diff:gmatch('[^\n]+') do
    -- Check for new file
    local file_path = line:match('^diff %-%-git a/(.-) b/')
    if file_path then
      if current_file then
        table.insert(files, current_file)
      end

      current_file = {
        path = file_path,
        additions = 0,
        deletions = 0,
        patch = '',
      }
    elseif current_file then
      -- Add to patch
      current_file.patch = current_file.patch .. line .. '\n'

      -- Count additions/deletions
      if line:match('^%+') and not line:match('^%+%+%+') then
        current_file.additions = current_file.additions + 1
      elseif line:match('^%-') and not line:match('^%-%-%-') then
        current_file.deletions = current_file.deletions + 1
      end
    end
  end

  if current_file then
    table.insert(files, current_file)
  end

  return files
end

-- Parse PR description for key information
---@param description string PR body
---@return table info {related_issues, breaking_changes, testing_notes}
function M.parse_pr_description(description)
  local info = {
    related_issues = {},
    breaking_changes = {},
    testing_notes = '',
  }

  if not description then
    return info
  end

  -- Extract issue references
  for issue_num in description:gmatch('#(%d+)') do
    table.insert(info.related_issues, tonumber(issue_num))
  end

  -- Extract breaking changes section
  local breaking = description:match('## Breaking Changes\n(.-)##') or
    description:match('BREAKING CHANGE:%s*(.-)[\n\r][\n\r]')

  if breaking then
    for line in vim.gsplit(breaking, '\n') do
      local trimmed = vim.trim(line)
      if trimmed ~= '' then
        table.insert(info.breaking_changes, trimmed)
      end
    end
  end

  -- Extract testing notes
  local testing = description:match('## Testing\n(.-)##') or
    description:match('## Test Plan\n(.-)##')

  if testing then
    info.testing_notes = vim.trim(testing)
  end

  return info
end

return M

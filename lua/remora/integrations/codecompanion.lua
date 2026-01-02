-- codecompanion.nvim integration for remora.nvim

local M = {}

local state = require('remora.state')
local config = require('remora.config')

-- Check if codecompanion is available
---@return boolean
function M.is_available()
  if not config.get('ai.codecompanion_enabled') then
    return false
  end

  local ok, _ = pcall(require, 'codecompanion')
  return ok
end

-- Start AI review with codecompanion
---@param opts table {pr, files, on_complete}
function M.start_review(opts)
  if not M.is_available() then
    opts.on_complete(nil, 'codecompanion.nvim is not installed or not enabled')
    return
  end

  local codecompanion = require('codecompanion')

  -- Build context for injection
  local context = M._build_review_context(opts.pr, opts.files)

  -- Start codecompanion chat with injected context
  vim.notify('Starting AI review with codecompanion...', vim.log.levels.INFO)

  -- Create a review prompt
  local prompt = M._build_review_prompt(opts.pr, opts.files)

  -- Open codecompanion chat
  vim.cmd('CodeCompanionChat')

  -- Inject the review prompt
  vim.defer_fn(function()
    -- Send the prompt to codecompanion
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('i' .. prompt .. '<CR>', true, false, true), 'n', false)

    -- Note: This is a simplified implementation
    -- In practice, we'd want to use codecompanion's API more directly
  end, 100)
end

-- Build review context for injection
---@param pr table
---@param files table
---@return table context
function M._build_review_context(pr, files)
  local context = {
    pr_number = pr.number,
    pr_title = pr.title,
    pr_author = pr.author,
    pr_body = pr.body,
    base_branch = pr.base_branch,
    head_branch = pr.head_branch,
    files_changed = {},
  }

  for path, file_state in pairs(files) do
    table.insert(context.files_changed, {
      path = path,
      status = file_state.status,
      additions = file_state.additions,
      deletions = file_state.deletions,
    })
  end

  return context
end

-- Build review prompt with context
---@param pr table
---@param files table
---@return string prompt
function M._build_review_prompt(pr, files)
  local lines = {}

  table.insert(lines, 'Please review the following Pull Request:')
  table.insert(lines, '')
  table.insert(lines, string.format('# PR #%d: %s', pr.number, pr.title))
  table.insert(lines, string.format('Author: %s', pr.author))
  table.insert(lines, string.format('Base: %s <- Head: %s', pr.base_branch, pr.head_branch))
  table.insert(lines, '')

  if pr.body and pr.body ~= '' then
    table.insert(lines, '## Description')
    table.insert(lines, pr.body)
    table.insert(lines, '')
  end

  table.insert(lines, '## Files Changed')

  local file_count = 0
  for path, file_state in pairs(files) do
    file_count = file_count + 1
    table.insert(lines, string.format('%d. %s (%s) [+%d -%d]',
      file_count, path, file_state.status,
      file_state.additions or 0, file_state.deletions or 0))
  end

  table.insert(lines, '')
  table.insert(lines, 'Please provide:')
  table.insert(lines, '1. A summary of the changes')
  table.insert(lines, '2. Potential issues or bugs')
  table.insert(lines, '3. Security concerns')
  table.insert(lines, '4. Performance considerations')
  table.insert(lines, '5. Best practice recommendations')
  table.insert(lines, '')
  table.insert(lines, 'Format findings as: [FILE:LINE] SEVERITY - Description')

  return table.concat(lines, '\n')
end

-- Parse codecompanion response
---@param response string Response from codecompanion
---@return table review {summary, findings}
function M.parse_response(response)
  local parser = require('remora.core.parser')
  return parser.parse_ai_review(response)
end

-- Review specific file with codecompanion
---@param file_path string
---@param opts table {pr, patch, on_complete}
function M.review_file(file_path, opts)
  if not M.is_available() then
    opts.on_complete(nil, 'codecompanion.nvim is not installed or not enabled')
    return
  end

  local pr = opts.pr
  local patch = opts.patch

  local prompt = string.format([[
Please review this file from PR #%d:

File: %s

Changes:
%s

Provide specific feedback on:
1. Code quality
2. Potential bugs
3. Security issues
4. Performance
5. Best practices

Format: [LINE] SEVERITY - Description
]], pr.number, file_path, patch or '[No diff available]')

  -- Open codecompanion with file review prompt
  vim.cmd('CodeCompanionChat')

  vim.defer_fn(function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('i' .. prompt .. '<CR>', true, false, true), 'n', false)
  end, 100)
end

-- Extract suggestions from codecompanion response
---@param response string
---@return table suggestions List of {file, line, code, description}
function M.extract_suggestions(response)
  local suggestions = {}

  -- Look for code blocks in response
  for code_block in response:gmatch('```(%w+)\n(.-)```') do
    local lang, code = code_block:match('(%w+)\n(.+)')

    if lang and code then
      -- Try to extract file/line context before the code block
      local context = response:match('(.-)```' .. lang)

      if context then
        local file, line = context:match('%[([^:]+):(%d+)%]')

        if file and line then
          table.insert(suggestions, {
            file = file,
            line = tonumber(line),
            code = vim.trim(code),
            description = context:match('%-(.-)$') or '',
          })
        end
      end
    end
  end

  return suggestions
end

return M

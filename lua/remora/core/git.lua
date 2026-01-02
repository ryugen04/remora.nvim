-- Local git operations for remora.nvim

local M = {}

local Job = require('plenary.job')

-- git show でファイル内容取得
---@param ref string Git ref (commit SHA, branch, etc.)
---@param file_path string File path relative to repo root
---@param callback function Callback(content, error, error_type)
-- error_type: 'ref_not_found' | 'file_not_found' | nil
function M.show_file_at_ref(ref, file_path, callback)
  Job:new({
    command = 'git',
    args = { 'show', ref .. ':' .. file_path },
    cwd = vim.fn.getcwd(),
    on_exit = function(j, return_val)
      vim.schedule(function()
        if return_val ~= 0 then
          local stderr = table.concat(j:stderr_result(), '\n')
          -- refが見つからない場合
          if stderr:match('unknown revision') or stderr:match('bad revision') then
            callback(nil, stderr, 'ref_not_found')
          -- ファイルが見つからない場合（新規追加ファイル等）
          elseif stderr:match('does not exist') or stderr:match('path.*does not exist') then
            callback(nil, stderr, 'file_not_found')
          else
            callback(nil, stderr, 'unknown')
          end
        else
          local content = table.concat(j:result(), '\n')
          callback(content, nil, nil)
        end
      end)
    end,
  }):start()
end

-- git status --porcelain を実行
---@param callback function Callback(changes, error)
-- changes: { staged = {{path, status}}, unstaged = {{path, status}} }
function M.get_status(callback)
  Job:new({
    command = 'git',
    args = { 'status', '--porcelain' },
    cwd = vim.fn.getcwd(),
    on_exit = function(j, return_val)
      if return_val ~= 0 then
        vim.schedule(function()
          callback(nil, 'git status failed')
        end)
        return
      end

      local lines = j:result()
      local staged = {}
      local unstaged = {}

      for _, line in ipairs(lines) do
        if #line >= 3 then
          local index_status = line:sub(1, 1)
          local worktree_status = line:sub(2, 2)
          local path = line:sub(4)

          -- stagedの変更
          if index_status ~= ' ' and index_status ~= '?' then
            table.insert(staged, { path = path, status = index_status })
          end

          -- unstagedの変更
          if worktree_status ~= ' ' then
            local status = worktree_status == '?' and 'untracked' or worktree_status
            table.insert(unstaged, { path = path, status = status })
          end
        end
      end

      vim.schedule(function()
        callback({ staged = staged, unstaged = unstaged }, nil)
      end)
    end,
  }):start()
end

-- push前のコミットを取得
---@param base_branch string Base branch name (e.g., "main")
---@param callback function Callback(commits, error)
-- commits: { {sha, message, author, date} }
function M.get_unpushed_commits(base_branch, callback)
  Job:new({
    command = 'git',
    args = {
      'log',
      '--oneline',
      '--format=%h|%s|%an|%ad',
      '--date=short',
      string.format('origin/%s..HEAD', base_branch),
    },
    cwd = vim.fn.getcwd(),
    on_exit = function(j, return_val)
      if return_val ~= 0 then
        vim.schedule(function()
          callback({}, nil) -- エラー時は空リスト
        end)
        return
      end

      local lines = j:result()
      local commits = {}

      for _, line in ipairs(lines) do
        local sha, message, author, date = line:match('^([^|]+)|([^|]*)|([^|]*)|(.*)$')
        if sha then
          table.insert(commits, {
            sha = sha,
            message = message or '',
            author = author or '',
            date = date or '',
          })
        end
      end

      vim.schedule(function()
        callback(commits, nil)
      end)
    end,
  }):start()
end

-- refがローカルに存在するか確認
---@param ref string Git ref
---@param callback function Callback(exists: boolean)
function M.has_ref(ref, callback)
  Job:new({
    command = 'git',
    args = { 'rev-parse', '--verify', ref },
    cwd = vim.fn.getcwd(),
    on_exit = function(_, return_val)
      vim.schedule(function()
        callback(return_val == 0)
      end)
    end,
  }):start()
end

return M

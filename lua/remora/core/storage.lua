-- Local persistence layer for remora.nvim

local M = {}

local config = require('remora.config')

-- Get PR-specific storage directory
---@param pr_key string Format: "owner_repo_number"
---@return string directory_path
function M.get_pr_dir(pr_key)
  local base_path = config.get('storage.path')
  local pr_dir = base_path .. '/reviews/' .. pr_key
  return pr_dir
end

-- Ensure PR directory exists
---@param pr_key string
---@return string directory_path
function M.ensure_pr_dir(pr_key)
  local dir = M.get_pr_dir(pr_key)
  vim.fn.mkdir(dir, 'p')
  return dir
end

-- Load JSON data from file
---@param pr_key string
---@param filename string
---@return table|nil data
function M.load(pr_key, filename)
  local dir = M.get_pr_dir(pr_key)
  local filepath = dir .. '/' .. filename

  if vim.fn.filereadable(filepath) == 0 then
    return nil
  end

  local content = table.concat(vim.fn.readfile(filepath), '\n')
  local success, data = pcall(vim.json.decode, content)

  if not success then
    vim.notify(
      string.format('Failed to parse %s: %s', filename, data),
      vim.log.levels.ERROR
    )
    return nil
  end

  return data
end

-- Save JSON data to file
---@param pr_key string
---@param filename string
---@param data table
function M.save(pr_key, filename, data)
  local dir = M.ensure_pr_dir(pr_key)
  local filepath = dir .. '/' .. filename

  local success, json = pcall(vim.json.encode, data)
  if not success then
    vim.notify(
      string.format('Failed to encode %s: %s', filename, json),
      vim.log.levels.ERROR
    )
    return
  end

  -- Pretty print JSON
  vim.fn.writefile(vim.split(json, '\n'), filepath)
end

-- Delete PR data
---@param pr_key string
function M.delete_pr(pr_key)
  local dir = M.get_pr_dir(pr_key)
  if vim.fn.isdirectory(dir) == 1 then
    vim.fn.delete(dir, 'rf')
  end
end

-- List all stored PRs
---@return table pr_keys List of pr_key strings
function M.list_prs()
  local base_path = config.get('storage.path') .. '/reviews'
  local prs = {}

  if vim.fn.isdirectory(base_path) == 0 then
    return prs
  end

  local dirs = vim.fn.readdir(base_path)
  for _, dir in ipairs(dirs) do
    if vim.fn.isdirectory(base_path .. '/' .. dir) == 1 then
      table.insert(prs, dir)
    end
  end

  return prs
end

return M

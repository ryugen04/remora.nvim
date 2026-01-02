-- Plugin initialization for remora.nvim

-- Prevent loading the plugin multiple times
if vim.g.loaded_remora then
  return
end
vim.g.loaded_remora = true

-- Check for required dependencies
local function check_dependency(name)
  local ok = pcall(require, name)
  if not ok then
    vim.notify(
      string.format('remora.nvim requires %s to be installed', name),
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

-- Check plenary.nvim
if not check_dependency('plenary') then
  return
end

-- Plugin is ready, but setup() must be called explicitly by the user

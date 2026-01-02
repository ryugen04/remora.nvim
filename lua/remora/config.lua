-- Configuration management for remora.nvim

local M = {}

-- Default configuration
M.defaults = {
  -- Layout
  layout = {
    left_width = 40,
    right_width = 50,
    open_on_startup = false,
  },

  -- File tree
  file_tree = {
    default_mode = 'tree', -- tree | flat | status
    icons = true,
    git_icons = true,
    show_hidden = false,
  },

  -- GitHub
  github = {
    token = nil, -- Read from gh CLI or env if nil
    api_url = 'https://api.github.com/graphql',
  },

  -- AI
  ai = {
    claude_cli_path = 'claude',
    codecompanion_enabled = true,
    auto_review = false,
  },

  -- Storage
  storage = {
    path = vim.fn.stdpath('data') .. '/remora',
  },

  -- Keymaps
  keymaps = {
    toggle = '<leader>rt',
    refresh = '<leader>rr',
    submit_review = '<leader>rs',
  },

  -- UI
  ui = {
    badges = {
      viewed = '👀',
      reviewed = '✅',
      commented = '💬',
      noted = '📝',
      pinned = '📌',
      ai_reviewed = '🤖',
    },
    comment_display = 'hover', -- hover | inline | both
  },
}

-- Current options (merged defaults + user config)
M.options = {}

-- Setup configuration
---@param opts table|nil User configuration
function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', M.defaults, opts or {})

  -- Ensure storage directory exists
  vim.fn.mkdir(M.options.storage.path, 'p')
end

-- Get configuration value
---@param key string Dot-separated key (e.g., 'layout.left_width')
---@return any
function M.get(key)
  local keys = vim.split(key, '.', { plain = true })
  local value = M.options

  for _, k in ipairs(keys) do
    value = value[k]
    if value == nil then
      return nil
    end
  end

  return value
end

-- Set configuration value
---@param key string Dot-separated key
---@param value any
function M.set(key, value)
  local keys = vim.split(key, '.', { plain = true })
  local tbl = M.options

  for i = 1, #keys - 1 do
    local k = keys[i]
    if tbl[k] == nil then
      tbl[k] = {}
    end
    tbl = tbl[k]
  end

  tbl[keys[#keys]] = value
end

return M

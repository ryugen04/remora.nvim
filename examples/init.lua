-- Example configuration for remora.nvim

-- Basic setup
require('remora').setup({
  layout = {
    left_width = 45,
    right_width = 60,
  },

  file_tree = {
    default_mode = 'tree',
    icons = true,
  },

  ai = {
    claude_cli_path = 'claude',
    codecompanion_enabled = true,
    auto_review = false,
  },

  keymaps = {
    toggle = '<leader>pr',
    refresh = '<leader>pR',
    submit_review = '<leader>ps',
  },
})

-- Example: Open a specific PR
vim.keymap.set('n', '<leader>po', function()
  vim.ui.input({ prompt = 'PR (owner/repo#num): ' }, function(pr_id)
    if pr_id then
      vim.cmd('RemoraOpen ' .. pr_id)
    end
  end)
end, { desc = 'Open PR in Remora' })

-- Example: Quick review workflow
vim.keymap.set('n', '<leader>prw', function()
  -- Open remora
  vim.cmd('RemoraToggle')

  -- Wait for PR to load
  vim.defer_fn(function()
    -- Auto-start AI review
    local state = require('remora.state')
    if state.current_pr then
      local ai_review = require('remora.ui.modes.ai_review')
      ai_review.start_full_review()
    end
  end, 1000)
end, { desc = 'Remora: Quick review workflow' })

-- Example: Export all unreviewed files to AI
vim.keymap.set('n', '<leader>pra', function()
  local state = require('remora.state')

  if not state.current_pr then
    vim.notify('No PR loaded', vim.log.levels.WARN)
    return
  end

  local unreviewed = state.get_files(function(path, file_state)
    return not file_state.reviewed
  end)

  if #unreviewed == 0 then
    vim.notify('All files reviewed!', vim.log.levels.INFO)
    return
  end

  vim.notify(string.format('Starting AI review of %d unreviewed files...', #unreviewed), vim.log.levels.INFO)

  local ai_review = require('remora.ui.modes.ai_review')
  ai_review.start_full_review()
end, { desc = 'Remora: AI review unreviewed files' })

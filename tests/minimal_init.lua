-- Minimal init.lua for running tests

-- Add plenary to runtimepath
local plenary_dir = os.getenv('PLENARY_DIR') or '/tmp/plenary.nvim'
vim.opt.rtp:append('.')
vim.opt.rtp:append(plenary_dir)

-- Set up test environment
vim.cmd('runtime! plugin/plenary.vim')

-- Disable swap files
vim.opt.swapfile = false

-- Set data directory for tests
vim.fn.setenv('XDG_DATA_HOME', '/tmp/remora-test-data')

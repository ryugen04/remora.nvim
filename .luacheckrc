-- luacheck configuration for remora.nvim

-- Use LuaJIT standard library
std = "luajit"

-- Define Neovim globals
globals = {
  "vim",
}

-- Read-only globals (Neovim API)
read_globals = {
  "vim",
}

-- Ignore specific warnings
ignore = {
  "122", -- Setting a read-only field of a global variable
  "212", -- Unused argument (sometimes intentional for callbacks)
}

-- Exclude specific files/directories
exclude_files = {
  ".luarocks",
  ".git",
}

-- Maximum line length
max_line_length = 120

-- Maximum cyclomatic complexity
max_cyclomatic_complexity = 20

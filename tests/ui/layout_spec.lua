-- Tests for ui/layout.lua

local layout = require("remora.ui.layout")

describe("layout", function()
	after_each(function()
		-- Clean up after each test
		if layout.is_open then
			layout.close()
		end
	end)

	describe("open", function()
		it("should open three-pane layout", function()
			layout.open()

			assert.is_true(layout.is_open)
			assert.is_not_nil(layout.windows.left)
			assert.is_not_nil(layout.windows.center)
			assert.is_not_nil(layout.windows.right)
			assert.is_not_nil(layout.buffers.left)
			assert.is_not_nil(layout.buffers.right)
		end)

		it("should create valid windows", function()
			layout.open()

			assert.is_true(vim.api.nvim_win_is_valid(layout.windows.left))
			assert.is_true(vim.api.nvim_win_is_valid(layout.windows.center))
			assert.is_true(vim.api.nvim_win_is_valid(layout.windows.right))
		end)

		it("should create valid buffers", function()
			layout.open()

			assert.is_true(vim.api.nvim_buf_is_valid(layout.buffers.left))
			assert.is_true(vim.api.nvim_buf_is_valid(layout.buffers.right))
		end)

		it("should set buffer names", function()
			layout.open()

			local left_name = vim.api.nvim_buf_get_name(layout.buffers.left)
			local right_name = vim.api.nvim_buf_get_name(layout.buffers.right)

			assert.matches("Remora: PR Browser", left_name)
			assert.matches("Remora: Review", right_name)
		end)

		it("should not reopen if already open", function()
			layout.open()
			local initial_windows = vim.deepcopy(layout.windows)

			layout.open()

			assert.equals(initial_windows.left, layout.windows.left)
			assert.equals(initial_windows.center, layout.windows.center)
			assert.equals(initial_windows.right, layout.windows.right)
		end)

		it("should focus left pane after opening", function()
			layout.open()

			local current_win = vim.api.nvim_get_current_win()
			assert.equals(layout.windows.left, current_win)
		end)
	end)

	describe("close", function()
		it("should close all windows and buffers", function()
			layout.open()
			local left_win = layout.windows.left
			local right_win = layout.windows.right
			local left_buf = layout.buffers.left
			local right_buf = layout.buffers.right

			layout.close()

			assert.is_false(layout.is_open)
			assert.is_false(vim.api.nvim_win_is_valid(left_win))
			assert.is_false(vim.api.nvim_win_is_valid(right_win))
			assert.is_false(vim.api.nvim_buf_is_valid(left_buf))
			assert.is_false(vim.api.nvim_buf_is_valid(right_buf))
		end)

		it("should reset window state", function()
			layout.open()
			layout.close()

			assert.is_nil(layout.windows.left)
			assert.is_nil(layout.windows.center)
			assert.is_nil(layout.windows.right)
		end)

		it("should reset buffer state", function()
			layout.open()
			layout.close()

			assert.is_nil(layout.buffers.left)
			assert.is_nil(layout.buffers.right)
		end)

		it("should handle closing when not open", function()
			assert.has_no.errors(function()
				layout.close()
			end)
		end)
	end)

	describe("get_focused_pane", function()
		it("should return left when left pane is focused", function()
			layout.open()
			vim.api.nvim_set_current_win(layout.windows.left)

			local pane = layout.get_focused_pane()
			assert.equals("left", pane)
		end)

		it("should return center when center pane is focused", function()
			layout.open()
			vim.api.nvim_set_current_win(layout.windows.center)

			local pane = layout.get_focused_pane()
			assert.equals("center", pane)
		end)

		it("should return right when right pane is focused", function()
			layout.open()
			vim.api.nvim_set_current_win(layout.windows.right)

			local pane = layout.get_focused_pane()
			assert.equals("right", pane)
		end)

		it("should return nil when layout is not open", function()
			local pane = layout.get_focused_pane()
			assert.is_nil(pane)
		end)
	end)

	describe("focus_pane", function()
		it("should focus left pane", function()
			layout.open()

			layout.focus_pane("left")
			local current_win = vim.api.nvim_get_current_win()
			assert.equals(layout.windows.left, current_win)
		end)

		it("should focus center pane", function()
			layout.open()

			layout.focus_pane("center")
			local current_win = vim.api.nvim_get_current_win()
			assert.equals(layout.windows.center, current_win)
		end)

		it("should focus right pane", function()
			layout.open()

			layout.focus_pane("right")
			local current_win = vim.api.nvim_get_current_win()
			assert.equals(layout.windows.right, current_win)
		end)

		it("should handle invalid pane gracefully", function()
			layout.open()

			assert.has_no.errors(function()
				layout.focus_pane("invalid")
			end)
		end)

		it("should handle when layout is not open", function()
			assert.has_no.errors(function()
				layout.focus_pane("left")
			end)
		end)
	end)

	describe("refresh", function()
		it("should not error when layout is open", function()
			layout.open()

			assert.has_no.errors(function()
				layout.refresh()
			end)
		end)

		it("should handle when layout is not open", function()
			assert.has_no.errors(function()
				layout.refresh()
			end)
		end)
	end)

	describe("window configuration", function()
		it("should configure left pane options", function()
			layout.open()

			local number = vim.api.nvim_win_get_option(layout.windows.left, "number")
			local relativenumber = vim.api.nvim_win_get_option(layout.windows.left, "relativenumber")
			local signcolumn = vim.api.nvim_win_get_option(layout.windows.left, "signcolumn")
			local wrap = vim.api.nvim_win_get_option(layout.windows.left, "wrap")
			local cursorline = vim.api.nvim_win_get_option(layout.windows.left, "cursorline")

			assert.is_false(number)
			assert.is_false(relativenumber)
			assert.equals("no", signcolumn)
			assert.is_false(wrap)
			assert.is_true(cursorline)
		end)

		it("should configure right pane options", function()
			layout.open()

			local number = vim.api.nvim_win_get_option(layout.windows.right, "number")
			local relativenumber = vim.api.nvim_win_get_option(layout.windows.right, "relativenumber")
			local signcolumn = vim.api.nvim_win_get_option(layout.windows.right, "signcolumn")
			local wrap = vim.api.nvim_win_get_option(layout.windows.right, "wrap")

			assert.is_false(number)
			assert.is_false(relativenumber)
			assert.equals("no", signcolumn)
			assert.is_true(wrap)
		end)
	end)
end)

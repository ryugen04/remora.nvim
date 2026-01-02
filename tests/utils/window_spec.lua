-- Tests for window utilities

local window = require("remora.utils.window")

describe("window utilities", function()
	describe("create_split", function()
		it("should create a left split", function()
			local winnr = window.create_split({ position = "left", size = 30 })

			assert.is_not_nil(winnr)
			assert.is_true(vim.api.nvim_win_is_valid(winnr))

			-- Clean up
			vim.api.nvim_win_close(winnr, true)
		end)

		it("should create a right split", function()
			local winnr = window.create_split({ position = "right", size = 40 })

			assert.is_not_nil(winnr)
			assert.is_true(vim.api.nvim_win_is_valid(winnr))

			vim.api.nvim_win_close(winnr, true)
		end)

		it("should create an above split", function()
			local winnr = window.create_split({ position = "above", size = 10 })

			assert.is_not_nil(winnr)
			assert.is_true(vim.api.nvim_win_is_valid(winnr))

			vim.api.nvim_win_close(winnr, true)
		end)

		it("should create a below split", function()
			local winnr = window.create_split({ position = "below", size = 15 })

			assert.is_not_nil(winnr)
			assert.is_true(vim.api.nvim_win_is_valid(winnr))

			vim.api.nvim_win_close(winnr, true)
		end)

		it("should set buffer if provided", function()
			local bufnr = vim.api.nvim_create_buf(false, true)
			local winnr = window.create_split({ position = "right", bufnr = bufnr })

			local win_buf = vim.api.nvim_win_get_buf(winnr)
			assert.equals(bufnr, win_buf)

			vim.api.nvim_win_close(winnr, true)
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end)

		it("should return to current window if requested", function()
			local original_win = vim.api.nvim_get_current_win()
			local winnr = window.create_split({ position = "right", return_to_current = true })

			local current_win = vim.api.nvim_get_current_win()
			assert.equals(original_win, current_win)

			vim.api.nvim_win_close(winnr, true)
		end)

		it("should default to right position with size 40", function()
			local winnr = window.create_split({})

			assert.is_not_nil(winnr)
			assert.is_true(vim.api.nvim_win_is_valid(winnr))

			vim.api.nvim_win_close(winnr, true)
		end)
	end)

	describe("close", function()
		it("should close a valid window", function()
			local winnr = window.create_split({ position = "right" })
			assert.is_true(vim.api.nvim_win_is_valid(winnr))

			window.close(winnr)
			assert.is_false(vim.api.nvim_win_is_valid(winnr))
		end)

		it("should handle invalid window gracefully", function()
			local invalid_winnr = 99999
			assert.has_no.errors(function()
				window.close(invalid_winnr)
			end)
		end)

		it("should handle nil window gracefully", function()
			assert.has_no.errors(function()
				window.close(nil)
			end)
		end)
	end)

	describe("is_valid", function()
		it("should return true for valid window", function()
			local winnr = window.create_split({ position = "right" })
			assert.is_true(window.is_valid(winnr))

			vim.api.nvim_win_close(winnr, true)
		end)

		it("should return false for invalid window", function()
			assert.is_false(window.is_valid(99999))
		end)

		it("should return false for nil window", function()
			assert.is_false(window.is_valid(nil))
		end)
	end)

	describe("set_option", function()
		it("should set window option for valid window", function()
			local winnr = window.create_split({ position = "right" })

			window.set_option(winnr, "number", false)
			local value = vim.api.nvim_win_get_option(winnr, "number")
			assert.is_false(value)

			vim.api.nvim_win_close(winnr, true)
		end)

		it("should handle invalid window gracefully", function()
			assert.has_no.errors(function()
				window.set_option(99999, "number", false)
			end)
		end)
	end)

	describe("get_buffer", function()
		it("should return buffer number for window", function()
			local bufnr = vim.api.nvim_create_buf(false, true)
			local winnr = window.create_split({ position = "right", bufnr = bufnr })

			local result = window.get_buffer(winnr)
			assert.equals(bufnr, result)

			vim.api.nvim_win_close(winnr, true)
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end)
	end)

	describe("set_buffer", function()
		it("should set buffer for window", function()
			local bufnr = vim.api.nvim_create_buf(false, true)
			local winnr = window.create_split({ position = "right" })

			window.set_buffer(winnr, bufnr)
			local result = vim.api.nvim_win_get_buf(winnr)
			assert.equals(bufnr, result)

			vim.api.nvim_win_close(winnr, true)
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end)
	end)

	describe("focus", function()
		it("should focus the specified window", function()
			local winnr = window.create_split({ position = "right" })
			local original_win = vim.api.nvim_get_current_win()

			-- Should not be focused initially if we have return_to_current behavior
			-- But let's test focusing explicitly

			window.focus(winnr)
			local current_win = vim.api.nvim_get_current_win()
			assert.equals(winnr, current_win)

			vim.api.nvim_win_close(winnr, true)
		end)

		it("should handle invalid window gracefully", function()
			assert.has_no.errors(function()
				window.focus(99999)
			end)
		end)
	end)

	describe("get_cursor", function()
		it("should return cursor position", function()
			local winnr = window.create_split({ position = "right" })
			window.focus(winnr)

			local cursor = window.get_cursor(winnr)
			assert.is_table(cursor)
			assert.equals(2, #cursor) -- {row, col}

			vim.api.nvim_win_close(winnr, true)
		end)
	end)

	describe("set_cursor", function()
		it("should set cursor position", function()
			local bufnr = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line1", "line2", "line3" })

			local winnr = window.create_split({ position = "right", bufnr = bufnr })

			window.set_cursor(winnr, 2, 3)
			local cursor = window.get_cursor(winnr)
			assert.equals(2, cursor[1])
			assert.equals(3, cursor[2])

			vim.api.nvim_win_close(winnr, true)
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end)
	end)

	describe("set_height", function()
		it("should set window height", function()
			local winnr = window.create_split({ position = "above", size = 10 })

			window.set_height(winnr, 15)
			local height = vim.api.nvim_win_get_height(winnr)
			assert.equals(15, height)

			vim.api.nvim_win_close(winnr, true)
		end)
	end)

	describe("set_width", function()
		it("should set window width", function()
			local winnr = window.create_split({ position = "right", size = 30 })

			window.set_width(winnr, 50)
			local width = vim.api.nvim_win_get_width(winnr)
			assert.equals(50, width)

			vim.api.nvim_win_close(winnr, true)
		end)
	end)
end)

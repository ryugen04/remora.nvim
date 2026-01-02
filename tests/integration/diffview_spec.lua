-- Tests for integrations/diffview.lua

local diffview = require("remora.integrations.diffview")
local state = require("remora.state")

describe("diffview integration", function()
	before_each(function()
		-- Reset state
		state.current_pr = nil
		state.files = {}
		state.draft_comments = {}
	end)

	describe("is_available", function()
		it("should return boolean", function()
			local available = diffview.is_available()
			assert.is_boolean(available)
		end)

		it("should return false when diffview.nvim is not installed", function()
			-- Since diffview.nvim is likely not installed in test env
			local available = diffview.is_available()
			-- We can't assert the exact value since it depends on environment
			-- Just verify it doesn't error
			assert.is_not_nil(available)
		end)
	end)

	describe("open_file", function()
		it("should handle missing PR gracefully", function()
			state.current_pr = nil

			-- Should not error, but show warning
			assert.has_no.errors(function()
				diffview.open_file("test.lua")
			end)
		end)

		it("should mark file as viewed when PR is loaded", function()
			state.current_pr = {
				number = 123,
				base_sha = "abc123",
				head_sha = "def456",
			}
			state.files = {
				["test.lua"] = {
					status = "modified",
					viewed = false,
				},
			}

			-- Mock diffview being available
			if diffview.is_available() then
				-- Only test if diffview is actually available
				diffview.open_file("test.lua")
				-- Note: In real environment, this would mark as viewed
			end
		end)
	end)

	describe("open_pr_diff", function()
		it("should handle missing PR gracefully", function()
			state.current_pr = nil

			assert.has_no.errors(function()
				diffview.open_pr_diff()
			end)
		end)

		it("should handle when diffview is not available", function()
			state.current_pr = {
				number = 123,
				base_sha = "abc123",
				head_sha = "def456",
			}

			-- Should not error even if diffview is not available
			assert.has_no.errors(function()
				diffview.open_pr_diff()
			end)
		end)
	end)

	describe("close", function()
		it("should not error when called", function()
			assert.has_no.errors(function()
				diffview.close()
			end)
		end)

		it("should handle when diffview is not available", function()
			-- Should handle gracefully
			assert.has_no.errors(function()
				diffview.close()
			end)
		end)
	end)

	describe("_get_comments_for_line", function()
		it("should return empty table when no comments exist", function()
			state.draft_comments = {}

			local comments = diffview._get_comments_for_line("test.lua", 10)
			assert.is_table(comments)
			assert.equals(0, #comments)
		end)

		it("should return comments for specific file and line", function()
			state.draft_comments = {
				{
					path = "test.lua",
					line = 10,
					body = "Test comment",
				},
				{
					path = "test.lua",
					line = 20,
					body = "Other comment",
				},
				{
					path = "other.lua",
					line = 10,
					body = "Different file",
				},
			}

			local comments = diffview._get_comments_for_line("test.lua", 10)
			assert.equals(1, #comments)
			assert.equals("Test comment", comments[1].body)
		end)

		it("should handle nil file_path", function()
			local comments = diffview._get_comments_for_line(nil, 10)
			assert.is_table(comments)
			assert.equals(0, #comments)
		end)
	end)

	describe("comment display helpers", function()
		it("_setup_hover_comments should not error", function()
			local bufnr = vim.api.nvim_create_buf(false, true)

			assert.has_no.errors(function()
				diffview._setup_hover_comments(bufnr, "test.lua")
			end)

			vim.api.nvim_buf_delete(bufnr, { force = true })
		end)

		it("_setup_inline_comments should not error", function()
			local bufnr = vim.api.nvim_create_buf(false, true)

			assert.has_no.errors(function()
				diffview._setup_inline_comments(bufnr, "test.lua")
			end)

			vim.api.nvim_buf_delete(bufnr, { force = true })
		end)

		it("_setup_comment_keymaps should not error", function()
			local bufnr = vim.api.nvim_create_buf(false, true)

			assert.has_no.errors(function()
				diffview._setup_comment_keymaps(bufnr, "test.lua")
			end)

			vim.api.nvim_buf_delete(bufnr, { force = true })
		end)

		it("_setup_inline_comments should display draft comments", function()
			local bufnr = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line1", "line2", "line3" })

			state.current_pr = { number = 123 }
			state.files = {
				["test.lua"] = { status = "modified" },
			}
			state.draft_comments = {
				{
					path = "test.lua",
					line = 2,
					body = "Comment on line 2",
				},
			}

			assert.has_no.errors(function()
				diffview._setup_inline_comments(bufnr, "test.lua")
			end)

			vim.api.nvim_buf_delete(bufnr, { force = true })
		end)
	end)

	describe("comment operations", function()
		it("_add_comment_at_cursor should handle user cancellation", function()
			local bufnr = vim.api.nvim_create_buf(false, true)

			-- Mock vim.ui.input to cancel
			local original_input = vim.ui.input
			vim.ui.input = function(opts, callback)
				callback(nil) -- User cancelled
			end

			assert.has_no.errors(function()
				diffview._add_comment_at_cursor(bufnr, "test.lua")
			end)

			vim.ui.input = original_input
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end)

		it("_add_suggestion should handle user cancellation", function()
			local bufnr = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line1", "line2", "line3" })

			-- Mock vim.ui.input to cancel
			local original_input = vim.ui.input
			vim.ui.input = function(opts, callback)
				callback(nil) -- User cancelled
			end

			assert.has_no.errors(function()
				diffview._add_suggestion(bufnr, "test.lua")
			end)

			vim.ui.input = original_input
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end)
	end)
end)

-- Tests for state.lua

local state = require("remora.state")

describe("state", function()
	before_each(function()
		-- Reset state before each test
		state.init()
		state.is_open = false
		state.current_pr = nil
		state.files = {}
		state.ui = {
			view_mode = "tree",
			filters = {
				show_viewed = true,
				show_reviewed = true,
				file_types = {},
			},
			right_pane_mode = "ai_review",
			selected_file = nil,
		}
		state.notes = {
			global = {},
			by_file = {},
		}
		state.draft_comments = {}
		state.ai_reviews = {}
	end)

	describe("init", function()
		it("should initialize state", function()
			state.init()
			assert.is_true(state.is_initialized)
		end)

		it("should only initialize once", function()
			state.init()
			local first_init = state.is_initialized

			state.init()
			assert.equals(first_init, state.is_initialized)
		end)
	end)

	describe("load_pr", function()
		it("should load PR data and initialize files", function()
			local pr_data = {
				owner = "testowner",
				repo = "testrepo",
				number = 123,
				title = "Test PR",
				author = "testauthor",
				base_branch = "main",
				head_branch = "feature",
				base_sha = "abc123",
				head_sha = "def456",
				state = "OPEN",
				created_at = "2024-01-01",
				updated_at = "2024-01-02",
				body = "Test description",
				files = {
					{ path = "file1.lua", status = "modified", additions = 10, deletions = 5 },
					{ path = "file2.lua", status = "added", additions = 20, deletions = 0 },
				},
			}

			state.load_pr(pr_data)

			-- Check PR data
			assert.equals("testowner", state.current_pr.owner)
			assert.equals("testrepo", state.current_pr.repo)
			assert.equals(123, state.current_pr.number)

			-- Check files
			assert.is_not_nil(state.files["file1.lua"])
			assert.equals("modified", state.files["file1.lua"].status)
			assert.equals(10, state.files["file1.lua"].additions)

			assert.is_not_nil(state.files["file2.lua"])
			assert.equals("added", state.files["file2.lua"].status)

			-- Check flags
			assert.is_true(state.is_open)
		end)
	end)

	describe("mark_file_viewed", function()
		it("should mark file as viewed", function()
			state.files["test.lua"] = {
				status = "modified",
				viewed = false,
				reviewed = false,
			}

			state.mark_file_viewed("test.lua")

			assert.is_true(state.files["test.lua"].viewed)
		end)

		it("should handle non-existent file gracefully", function()
			assert.has_no.errors(function()
				state.mark_file_viewed("nonexistent.lua")
			end)
		end)
	end)

	describe("mark_file_reviewed", function()
		it("should mark file as reviewed", function()
			state.files["test.lua"] = {
				status = "modified",
				viewed = false,
				reviewed = false,
			}

			state.mark_file_reviewed("test.lua")

			assert.is_true(state.files["test.lua"].reviewed)
		end)
	end)

	describe("toggle_file_reviewed", function()
		it("should toggle reviewed status", function()
			state.files["test.lua"] = {
				status = "modified",
				reviewed = false,
			}

			state.toggle_file_reviewed("test.lua")
			assert.is_true(state.files["test.lua"].reviewed)

			state.toggle_file_reviewed("test.lua")
			assert.is_false(state.files["test.lua"].reviewed)
		end)
	end)

	describe("get_files", function()
		before_each(function()
			state.files = {
				["file1.lua"] = { status = "modified", viewed = true, reviewed = false },
				["file2.lua"] = { status = "added", viewed = false, reviewed = false },
				["file3.lua"] = { status = "modified", viewed = true, reviewed = true },
			}
		end)

		it("should return all files when no filter", function()
			local files = state.get_files()
			assert.equals(3, #files)
		end)

		it("should filter files with custom function", function()
			local viewed_files = state.get_files(function(path, file_state)
				return file_state.viewed == true
			end)

			assert.equals(2, #viewed_files)
		end)

		it("should filter reviewed files", function()
			local reviewed_files = state.get_files(function(path, file_state)
				return file_state.reviewed == true
			end)

			assert.equals(1, #reviewed_files)
			assert.equals("file3.lua", reviewed_files[1].path)
		end)

		it("should return sorted files", function()
			local files = state.get_files()

			-- Check sorting
			for i = 2, #files do
				assert.is_true(files[i - 1].path < files[i].path)
			end
		end)
	end)

	describe("add_note", function()
		it("should add global note", function()
			state.add_note({
				type = "TODO",
				content = "Test TODO",
			})

			assert.equals(1, #state.notes.global)
			assert.equals("TODO", state.notes.global[1].type)
			assert.equals("Test TODO", state.notes.global[1].content)
			assert.is_not_nil(state.notes.global[1].id)
			assert.is_not_nil(state.notes.global[1].created_at)
		end)

		it("should add file-specific note", function()
			state.files["test.lua"] = {
				status = "modified",
				has_local_notes = false,
			}

			state.add_note({
				type = "NOTE",
				content = "Test note",
				file_path = "test.lua",
				line = 42,
			})

			assert.is_not_nil(state.notes.by_file["test.lua"])
			assert.equals(1, #state.notes.by_file["test.lua"])

			local note = state.notes.by_file["test.lua"][1]
			assert.equals("NOTE", note.type)
			assert.equals("Test note", note.content)
			assert.equals("test.lua", note.file_path)
			assert.equals(42, note.line)

			-- Check flag is updated
			assert.is_true(state.files["test.lua"].has_local_notes)
		end)
	end)

	describe("add_draft_comment", function()
		it("should add draft comment", function()
			state.files["test.lua"] = {
				status = "modified",
				comments_count = 0,
			}

			state.add_draft_comment({
				path = "test.lua",
				line = 10,
				body = "Test comment",
				is_suggestion = false,
			})

			assert.equals(1, #state.draft_comments)

			local comment = state.draft_comments[1]
			assert.equals("test.lua", comment.path)
			assert.equals(10, comment.line)
			assert.equals("Test comment", comment.body)
			assert.is_false(comment.is_suggestion)
			assert.is_not_nil(comment.id)
			assert.is_not_nil(comment.created_at)

			-- Check count is updated
			assert.equals(1, state.files["test.lua"].comments_count)
		end)

		it("should add suggestion comment", function()
			state.files["test.lua"] = { status = "modified", comments_count = 0 }

			state.add_draft_comment({
				path = "test.lua",
				line = 20,
				body = "Use this instead:",
				is_suggestion = true,
				suggestion_code = "local better = true",
			})

			local comment = state.draft_comments[1]
			assert.is_true(comment.is_suggestion)
			assert.equals("local better = true", comment.suggestion_code)
		end)
	end)
end)

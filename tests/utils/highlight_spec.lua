-- Tests for highlight utilities

local highlight = require("remora.utils.highlight")

describe("highlight utilities", function()
	before_each(function()
		-- Setup highlights before each test
		highlight.setup()
	end)

	describe("setup", function()
		it("should setup all highlight groups", function()
			-- Call setup
			highlight.setup()

			-- Verify some key highlights exist
			local title_hl = vim.api.nvim_get_hl(0, { name = "RemoraTitle" })
			assert.is_not_nil(title_hl)

			local file_added_hl = vim.api.nvim_get_hl(0, { name = "RemoraFileAdded" })
			assert.is_not_nil(file_added_hl)

			local badge_viewed_hl = vim.api.nvim_get_hl(0, { name = "RemoraBadgeViewed" })
			assert.is_not_nil(badge_viewed_hl)
		end)

		it("should setup PR status highlights", function()
			highlight.setup()

			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraTitle" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraComment" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraString" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraNumber" }))
		end)

		it("should setup file status highlights", function()
			highlight.setup()

			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraFileAdded" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraFileModified" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraFileDeleted" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraFileRenamed" }))
		end)

		it("should setup badge highlights", function()
			highlight.setup()

			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraBadgeViewed" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraBadgeReviewed" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraBadgeCommented" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraBadgeNoted" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraBadgePinned" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraBadgeAI" }))
		end)

		it("should setup tree highlights", function()
			highlight.setup()

			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraTreeFolder" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraTreeFile" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraTreeSelected" }))
		end)

		it("should setup section highlights", function()
			highlight.setup()

			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraSectionTitle" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraSectionSeparator" }))
		end)

		it("should setup mode highlights", function()
			highlight.setup()

			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraModeActive" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraModeInactive" }))
		end)

		it("should setup diff highlights", function()
			highlight.setup()

			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraDiffAdd" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraDiffDelete" }))
			assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "RemoraDiffChange" }))
		end)
	end)

	describe("get_status_highlight", function()
		it("should return correct highlight for added status", function()
			local hl = highlight.get_status_highlight("added")
			assert.equals("RemoraFileAdded", hl)
		end)

		it("should return correct highlight for modified status", function()
			local hl = highlight.get_status_highlight("modified")
			assert.equals("RemoraFileModified", hl)
		end)

		it("should return correct highlight for deleted status", function()
			local hl = highlight.get_status_highlight("deleted")
			assert.equals("RemoraFileDeleted", hl)
		end)

		it("should return correct highlight for renamed status", function()
			local hl = highlight.get_status_highlight("renamed")
			assert.equals("RemoraFileRenamed", hl)
		end)

		it("should return Normal for unknown status", function()
			local hl = highlight.get_status_highlight("unknown")
			assert.equals("Normal", hl)
		end)

		it("should return Normal for nil status", function()
			local hl = highlight.get_status_highlight(nil)
			assert.equals("Normal", hl)
		end)
	end)

	describe("get_badge_highlight", function()
		it("should return correct highlight for viewed badge", function()
			local hl = highlight.get_badge_highlight("viewed")
			assert.equals("RemoraBadgeViewed", hl)
		end)

		it("should return correct highlight for reviewed badge", function()
			local hl = highlight.get_badge_highlight("reviewed")
			assert.equals("RemoraBadgeReviewed", hl)
		end)

		it("should return correct highlight for commented badge", function()
			local hl = highlight.get_badge_highlight("commented")
			assert.equals("RemoraBadgeCommented", hl)
		end)

		it("should return correct highlight for noted badge", function()
			local hl = highlight.get_badge_highlight("noted")
			assert.equals("RemoraBadgeNoted", hl)
		end)

		it("should return correct highlight for pinned badge", function()
			local hl = highlight.get_badge_highlight("pinned")
			assert.equals("RemoraBadgePinned", hl)
		end)

		it("should return correct highlight for ai_reviewed badge", function()
			local hl = highlight.get_badge_highlight("ai_reviewed")
			assert.equals("RemoraBadgeAI", hl)
		end)

		it("should return Normal for unknown badge type", function()
			local hl = highlight.get_badge_highlight("unknown")
			assert.equals("Normal", hl)
		end)

		it("should return Normal for nil badge type", function()
			local hl = highlight.get_badge_highlight(nil)
			assert.equals("Normal", hl)
		end)
	end)
end)

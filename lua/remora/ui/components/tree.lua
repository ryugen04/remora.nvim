-- File tree component for remora.nvim

local M = {}

local state = require("remora.state")
local config = require("remora.config")
local highlight = require("remora.utils.highlight")

-- Build tree structure from file list
---@param files table List of {path, state}
---@return table tree Nested tree structure
local function build_tree_structure(files)
	local tree = {}

	for _, file in ipairs(files) do
		local parts = vim.split(file.path, "/", { plain = true })
		local current = tree

		for i, part in ipairs(parts) do
			local is_last = (i == #parts)

			if is_last then
				-- It's a file
				table.insert(current, {
					type = "file",
					name = part,
					path = file.path,
					state = file.state,
				})
			else
				-- It's a directory
				local found = false
				for _, child in ipairs(current) do
					if child.type == "dir" and child.name == part then
						current = child.children
						found = true
						break
					end
				end

				if not found then
					local dir = {
						type = "dir",
						name = part,
						children = {},
					}
					table.insert(current, dir)
					current = dir.children
				end
			end
		end
	end

	return tree
end

-- Render tree recursively
---@param tree table Tree structure
---@param depth number Current depth
---@param lines table Output lines
---@param metadata table Line metadata
local function render_tree_recursive(tree, depth, lines, metadata)
	-- Sort: directories first, then files
	table.sort(tree, function(a, b)
		if a.type ~= b.type then
			return a.type == "dir"
		end
		return a.name < b.name
	end)

	for _, node in ipairs(tree) do
		local indent = string.rep("  ", depth)
		local icon

		if node.type == "dir" then
			icon = " "
			local line = indent .. icon .. " " .. node.name
			table.insert(lines, line)
			table.insert(metadata, { type = "dir", path = node.name })

			-- Recursively render children
			render_tree_recursive(node.children, depth + 1, lines, metadata)
		else
			-- File
			icon = " "
			local hl_group = highlight.get_status_highlight(node.state.status)

			-- Build badges
			local badges = M.get_file_badges(node.state)
			local badges_str = #badges > 0 and " " .. table.concat(badges, " ") or ""

			local line = indent .. icon .. " " .. node.name .. badges_str
			table.insert(lines, line)
			table.insert(metadata, {
				type = "file",
				path = node.path,
				state = node.state,
				hl_group = hl_group,
			})
		end
	end
end

-- Render flat file list
---@param files table List of {path, state}
---@return table lines, table metadata
local function render_flat(files)
	local lines = {}
	local metadata = {}

	for _, file in ipairs(files) do
		local icon = " "
		local badges = M.get_file_badges(file.state)
		local badges_str = #badges > 0 and " " .. table.concat(badges, " ") or ""
		local hl_group = highlight.get_status_highlight(file.state.status)

		local line = icon .. " " .. file.path .. badges_str
		table.insert(lines, line)
		table.insert(metadata, {
			type = "file",
			path = file.path,
			state = file.state,
			hl_group = hl_group,
		})
	end

	return lines, metadata
end

-- Render status-grouped list
---@param files table List of {path, state}
---@return table lines, table metadata
local function render_status(files)
	local lines = {}
	local metadata = {}

	-- Group files by status
	local groups = {
		{ status = "added", title = "Added", files = {} },
		{ status = "modified", title = "Modified", files = {} },
		{ status = "deleted", title = "Deleted", files = {} },
		{ status = "renamed", title = "Renamed", files = {} },
	}

	for _, file in ipairs(files) do
		for _, group in ipairs(groups) do
			if file.state.status == group.status then
				table.insert(group.files, file)
				break
			end
		end
	end

	-- Render each group
	for _, group in ipairs(groups) do
		if #group.files > 0 then
			local header = string.format("▼ %s (%d)", group.title, #group.files)
			table.insert(lines, header)
			table.insert(metadata, { type = "header", status = group.status })

			for _, file in ipairs(group.files) do
				local icon = " "
				local badges = M.get_file_badges(file.state)
				local badges_str = #badges > 0 and " " .. table.concat(badges, " ") or ""
				local hl_group = highlight.get_status_highlight(file.state.status)

				local line = "  " .. icon .. " " .. file.path .. badges_str
				table.insert(lines, line)
				table.insert(metadata, {
					type = "file",
					path = file.path,
					state = file.state,
					hl_group = hl_group,
				})
			end

			-- Add blank line between groups
			table.insert(lines, "")
			table.insert(metadata, { type = "blank" })
		end
	end

	return lines, metadata
end

-- Get file badges
---@param file_state table File state from state.files[path]
---@return table badges List of badge strings
function M.get_file_badges(file_state)
	local badges = {}
	local badge_config = config.get("ui.badges")

	if file_state.viewed then
		table.insert(badges, badge_config.viewed)
	end

	if file_state.reviewed then
		table.insert(badges, badge_config.reviewed)
	end

	if file_state.comments_count > 0 then
		table.insert(badges, badge_config.commented)
	end

	if file_state.has_local_notes then
		table.insert(badges, badge_config.noted)
	end

	if file_state.ai_reviewed then
		table.insert(badges, badge_config.ai_reviewed)
	end

	return badges
end

-- Render file tree
---@param view_mode string "tree" | "flat" | "status"
---@return table lines, table metadata
function M.render(view_mode)
	view_mode = view_mode or state.ui.view_mode or "tree"

	local files = state.get_files()

	if view_mode == "tree" then
		local tree = build_tree_structure(files)
		local lines = {}
		local metadata = {}
		render_tree_recursive(tree, 0, lines, metadata)
		return lines, metadata
	elseif view_mode == "flat" then
		return render_flat(files)
	elseif view_mode == "status" then
		return render_status(files)
	end

	return {}, {}
end

-- Get file path at line
---@param metadata table Line metadata
---@param line_nr number 1-indexed line number
---@return string|nil file_path
function M.get_file_at_line(metadata, line_nr)
	local item = metadata[line_nr]
	if item and item.type == "file" then
		return item.path
	end
	return nil
end

return M

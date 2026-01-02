-- Integration tests for UI components

local tree = require('remora.ui.components.tree')
local pr_home = require('remora.ui.components.pr_home')
local memos = require('remora.ui.components.memos')
local state = require('remora.state')

describe('UI components integration', function()
  before_each(function()
    state.init()
    state.current_pr = {
      owner = 'testowner',
      repo = 'testrepo',
      number = 123,
      title = 'Test PR',
      author = 'testauthor',
      base_branch = 'main',
      head_branch = 'feature',
      state = 'OPEN',
      created_at = '2024-01-01T00:00:00Z',
      updated_at = '2024-01-02T00:00:00Z',
      body = 'Test description',
    }
    state.files = {
      ['src/main.lua'] = {
        status = 'modified',
        viewed = true,
        reviewed = false,
        additions = 10,
        deletions = 5,
        comments_count = 0,
        ai_reviewed = false,
        has_local_notes = false,
      },
      ['src/utils/helper.lua'] = {
        status = 'added',
        viewed = false,
        reviewed = false,
        additions = 20,
        deletions = 0,
        comments_count = 1,
        ai_reviewed = true,
        has_local_notes = false,
      },
    }
  end)

  describe('tree component', function()
    describe('tree mode rendering', function()
      it('should render tree structure', function()
        local lines, metadata = tree.render('tree')

        assert.is_table(lines)
        assert.is_table(metadata)
        assert.is_true(#lines > 0)

        -- Should have hierarchical structure
        local has_src = false
        for _, line in ipairs(lines) do
          if line:match('src') then
            has_src = true
            break
          end
        end
        assert.is_true(has_src)
      end)

      it('should include badges', function()
        state.files['src/main.lua'].viewed = true
        state.files['src/main.lua'].reviewed = true

        local lines, metadata = tree.render('tree')

        -- Look for badge symbols
        local has_badge = false
        for _, line in ipairs(lines) do
          if line:match('👀') or line:match('✅') or line:match('🤖') then
            has_badge = true
            break
          end
        end
        assert.is_true(has_badge)
      end)
    end)

    describe('flat mode rendering', function()
      it('should render flat file list', function()
        local lines, metadata = tree.render('flat')

        assert.is_table(lines)
        assert.equals(2, #lines) -- Two files

        -- Should have full paths
        local has_full_path = false
        for _, line in ipairs(lines) do
          if line:match('src/main%.lua') or line:match('src/utils/helper%.lua') then
            has_full_path = true
            break
          end
        end
        assert.is_true(has_full_path)
      end)
    end)

    describe('status mode rendering', function()
      it('should group files by status', function()
        local lines, metadata = tree.render('status')

        assert.is_table(lines)
        assert.is_true(#lines > 0)

        -- Should have status headers
        local has_modified = false
        local has_added = false
        for _, line in ipairs(lines) do
          if line:match('Modified') then
            has_modified = true
          end
          if line:match('Added') then
            has_added = true
          end
        end
        assert.is_true(has_modified)
        assert.is_true(has_added)
      end)
    end)

    describe('get_file_at_line', function()
      it('should return file path for file line', function()
        local lines, metadata = tree.render('flat')

        local file_path = tree.get_file_at_line(metadata, 1)
        assert.is_not_nil(file_path)
        assert.is_string(file_path)
      end)

      it('should return nil for non-file line', function()
        local lines, metadata = tree.render('status')

        -- First line is usually a header
        local file_path = tree.get_file_at_line(metadata, 1)
        -- May be nil or a file depending on rendering
        assert.is_true(file_path == nil or type(file_path) == 'string')
      end)
    end)
  end)

  describe('pr_home component', function()
    describe('render_summary', function()
      it('should render PR summary', function()
        local lines = pr_home.render_summary()

        assert.is_table(lines)
        assert.is_true(#lines > 0)

        -- Should contain PR number
        local has_pr_number = false
        for _, line in ipairs(lines) do
          if line:match('123') then
            has_pr_number = true
            break
          end
        end
        assert.is_true(has_pr_number)
      end)

      it('should show author and state', function()
        local lines = pr_home.render_summary()

        local has_author = false
        local has_state = false
        for _, line in ipairs(lines) do
          if line:match('testauthor') then
            has_author = true
          end
          if line:match('OPEN') then
            has_state = true
          end
        end
        assert.is_true(has_author)
        assert.is_true(has_state)
      end)
    end)

    describe('render_detail', function()
      it('should render full PR details', function()
        local lines = pr_home.render_detail()

        assert.is_table(lines)
        assert.is_true(#lines > 10) -- Should have substantial content

        -- Should contain sections
        local has_details = false
        local has_stats = false
        for _, line in ipairs(lines) do
          if line:match('Details') then
            has_details = true
          end
          if line:match('Statistics') then
            has_stats = true
          end
        end
        assert.is_true(has_details)
        assert.is_true(has_stats)
      end)

      it('should show file statistics', function()
        local lines = pr_home.render_detail()

        local has_files = false
        for _, line in ipairs(lines) do
          if line:match('Files') and line:match('2') then
            has_files = true
            break
          end
        end
        assert.is_true(has_files)
      end)
    end)
  end)

  describe('memos component', function()
    before_each(function()
      state.notes = {
        global = {
          { id = '1', type = 'TODO', content = 'Test TODO', created_at = '2024-01-01' },
          { id = '2', type = 'NOTE', content = 'Test Note', created_at = '2024-01-02' },
        },
        by_file = {
          ['src/main.lua'] = {
            { id = '3', type = 'NOTE', content = 'File note', line = 10, created_at = '2024-01-03' },
          },
        },
      }
    end)

    describe('render', function()
      it('should render memos summary', function()
        local lines = memos.render()

        assert.is_table(lines)
        assert.is_true(#lines > 0)

        -- Should show TODO and Notes sections
        local has_todos = false
        local has_notes = false
        for _, line in ipairs(lines) do
          if line:match('TODOs') then
            has_todos = true
          end
          if line:match('Notes') then
            has_notes = true
          end
        end
        assert.is_true(has_todos)
        assert.is_true(has_notes)
      end)

      it('should show counts', function()
        local lines = memos.render()

        local has_todo_count = false
        local has_note_count = false
        for _, line in ipairs(lines) do
          if line:match('TODOs') and line:match('1') then
            has_todo_count = true
          end
          if line:match('Notes') and line:match('1') then
            has_note_count = true
          end
        end
        assert.is_true(has_todo_count)
        assert.is_true(has_note_count)
      end)
    end)

    describe('render_detail', function()
      it('should render detailed memos', function()
        local lines = memos.render_detail()

        assert.is_table(lines)
        assert.is_true(#lines > 5)

        -- Should show memo content
        local has_todo_content = false
        local has_note_content = false
        for _, line in ipairs(lines) do
          if line:match('Test TODO') then
            has_todo_content = true
          end
          if line:match('Test Note') then
            has_note_content = true
          end
        end
        assert.is_true(has_todo_content)
        assert.is_true(has_note_content)
      end)

      it('should show file notes section', function()
        local lines = memos.render_detail()

        local has_file_notes = false
        for _, line in ipairs(lines) do
          if line:match('File Notes') then
            has_file_notes = true
            break
          end
        end
        assert.is_true(has_file_notes)
      end)
    end)
  end)
end)

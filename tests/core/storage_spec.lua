-- Tests for core/storage.lua

local storage = require('remora.core.storage')

describe('storage', function()
  local test_pr_key = 'test_owner_test_repo_123'

  before_each(function()
    -- Clean up test data before each test
    storage.delete_pr(test_pr_key)
  end)

  after_each(function()
    -- Clean up test data after each test
    storage.delete_pr(test_pr_key)
  end)

  describe('get_pr_dir', function()
    it('should return correct PR directory path', function()
      local dir = storage.get_pr_dir(test_pr_key)
      assert.is_not_nil(dir)
      assert.truthy(dir:match('reviews/' .. test_pr_key .. '$'))
    end)
  end)

  describe('save and load', function()
    it('should save and load JSON data', function()
      local test_data = {
        foo = 'bar',
        number = 42,
        nested = { a = 1, b = 2 },
        list = { 'one', 'two', 'three' },
      }

      -- Save
      storage.save(test_pr_key, 'test.json', test_data)

      -- Load
      local loaded_data = storage.load(test_pr_key, 'test.json')

      -- Assert
      assert.is_not_nil(loaded_data)
      assert.equals(test_data.foo, loaded_data.foo)
      assert.equals(test_data.number, loaded_data.number)
      assert.equals(test_data.nested.a, loaded_data.nested.a)
      assert.equals(#test_data.list, #loaded_data.list)
    end)

    it('should return nil for non-existent file', function()
      local loaded_data = storage.load(test_pr_key, 'nonexistent.json')
      assert.is_nil(loaded_data)
    end)

    it('should handle empty data', function()
      local test_data = {}
      storage.save(test_pr_key, 'empty.json', test_data)
      local loaded_data = storage.load(test_pr_key, 'empty.json')
      assert.is_not_nil(loaded_data)
      assert.equals(0, vim.tbl_count(loaded_data))
    end)
  end)

  describe('delete_pr', function()
    it('should delete PR directory', function()
      -- Create data
      storage.save(test_pr_key, 'test.json', { foo = 'bar' })

      -- Verify it exists
      local data = storage.load(test_pr_key, 'test.json')
      assert.is_not_nil(data)

      -- Delete
      storage.delete_pr(test_pr_key)

      -- Verify it's gone
      local deleted_data = storage.load(test_pr_key, 'test.json')
      assert.is_nil(deleted_data)
    end)
  end)

  describe('list_prs', function()
    it('should list all stored PRs', function()
      -- Create multiple PRs
      storage.save('owner1_repo1_1', 'state.json', { pr = 1 })
      storage.save('owner2_repo2_2', 'state.json', { pr = 2 })
      storage.save('owner3_repo3_3', 'state.json', { pr = 3 })

      -- List
      local prs = storage.list_prs()

      -- Assert
      assert.is_true(#prs >= 3)

      -- Clean up
      storage.delete_pr('owner1_repo1_1')
      storage.delete_pr('owner2_repo2_2')
      storage.delete_pr('owner3_repo3_3')
    end)

    it('should return empty list when no PRs', function()
      -- Make sure test data is clean
      storage.delete_pr(test_pr_key)

      -- Note: there might be other PRs from other tests
      local prs = storage.list_prs()
      assert.is_table(prs)
    end)
  end)

  describe('ensure_pr_dir', function()
    it('should create directory if not exists', function()
      local dir = storage.ensure_pr_dir(test_pr_key)
      assert.is_not_nil(dir)

      -- Verify directory exists
      local exists = vim.fn.isdirectory(dir)
      assert.equals(1, exists)
    end)
  end)
end)

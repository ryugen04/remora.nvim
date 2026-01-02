-- Tests for utils/buffer.lua

local buffer_utils = require('remora.utils.buffer')

describe('buffer_utils', function()
  local test_bufnr

  after_each(function()
    -- Clean up test buffers
    if test_bufnr and buffer_utils.is_valid(test_bufnr) then
      buffer_utils.delete(test_bufnr)
    end
  end)

  describe('create_scratch', function()
    it('should create a scratch buffer', function()
      test_bufnr = buffer_utils.create_scratch()

      assert.is_not_nil(test_bufnr)
      assert.is_true(buffer_utils.is_valid(test_bufnr))

      -- Check buffer options
      local buftype = vim.api.nvim_buf_get_option(test_bufnr, 'buftype')
      assert.equals('nofile', buftype)
    end)

    it('should create buffer with custom options', function()
      test_bufnr = buffer_utils.create_scratch({
        filetype = 'lua',
        buftype = 'acwrite',
      })

      assert.is_true(buffer_utils.is_valid(test_bufnr))

      local filetype = vim.api.nvim_buf_get_option(test_bufnr, 'filetype')
      assert.equals('lua', filetype)
    end)
  end)

  describe('set_lines', function()
    it('should set buffer lines', function()
      test_bufnr = buffer_utils.create_scratch()

      local lines = { 'line 1', 'line 2', 'line 3' }
      buffer_utils.set_lines(test_bufnr, lines)

      local result = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.equals(3, #result)
      assert.equals('line 1', result[1])
      assert.equals('line 3', result[3])
    end)

    it('should handle empty lines', function()
      test_bufnr = buffer_utils.create_scratch()

      buffer_utils.set_lines(test_bufnr, { 'initial' })
      buffer_utils.set_lines(test_bufnr, {})

      local result = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.equals(1, #result)
      assert.equals('', result[1])
    end)
  end)

  describe('append_lines', function()
    it('should append lines to buffer', function()
      test_bufnr = buffer_utils.create_scratch()

      buffer_utils.set_lines(test_bufnr, { 'line 1' })
      buffer_utils.append_lines(test_bufnr, { 'line 2', 'line 3' })

      local result = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.equals(3, #result)
      assert.equals('line 3', result[3])
    end)
  end)

  describe('clear', function()
    it('should clear buffer content', function()
      test_bufnr = buffer_utils.create_scratch()

      buffer_utils.set_lines(test_bufnr, { 'line 1', 'line 2' })
      buffer_utils.clear(test_bufnr)

      local result = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.equals(1, #result)
      assert.equals('', result[1])
    end)
  end)

  describe('is_valid', function()
    it('should return true for valid buffer', function()
      test_bufnr = buffer_utils.create_scratch()
      assert.is_true(buffer_utils.is_valid(test_bufnr))
    end)

    it('should return false for invalid buffer', function()
      assert.is_false(buffer_utils.is_valid(99999))
      assert.is_false(buffer_utils.is_valid(nil))
    end)
  end)

  describe('delete', function()
    it('should delete buffer', function()
      test_bufnr = buffer_utils.create_scratch()
      assert.is_true(buffer_utils.is_valid(test_bufnr))

      buffer_utils.delete(test_bufnr)
      assert.is_false(buffer_utils.is_valid(test_bufnr))

      test_bufnr = nil -- Prevent cleanup error
    end)

    it('should handle invalid buffer gracefully', function()
      assert.has_no.errors(function()
        buffer_utils.delete(99999)
      end)
    end)
  end)

  describe('set_keymap', function()
    it('should set buffer-local keymap', function()
      test_bufnr = buffer_utils.create_scratch()

      buffer_utils.set_keymap(test_bufnr, 'n', 'K', function()
        -- Keymap callback
      end, { desc = 'Test keymap' })

      -- Note: Testing actual keymap execution is complex in tests
      -- We just verify it doesn't error
      assert.is_true(buffer_utils.is_valid(test_bufnr))
    end)
  end)

  describe('create_namespace', function()
    it('should create namespace', function()
      local ns = buffer_utils.create_namespace('test-namespace')
      assert.is_not_nil(ns)
      assert.is_number(ns)
    end)

    it('should return same namespace for same name', function()
      local ns1 = buffer_utils.create_namespace('test-ns')
      local ns2 = buffer_utils.create_namespace('test-ns')
      assert.equals(ns1, ns2)
    end)
  end)

  describe('add_highlight and clear_namespace', function()
    it('should add and clear highlights', function()
      test_bufnr = buffer_utils.create_scratch()
      buffer_utils.set_lines(test_bufnr, { 'test line' })

      local ns = buffer_utils.create_namespace('test-hl')

      -- Add highlight
      buffer_utils.add_highlight(test_bufnr, ns, 'String', 0, 0, 4)

      -- Clear namespace
      assert.has_no.errors(function()
        buffer_utils.clear_namespace(test_bufnr, ns)
      end)
    end)
  end)
end)

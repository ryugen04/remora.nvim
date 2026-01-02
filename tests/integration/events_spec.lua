-- Integration tests for events system

local events = require('remora.events')

describe('events integration', function()
  before_each(function()
    events.init()
  end)

  describe('event emission and handling', function()
    it('should emit and receive events', function()
      local received = false
      local received_data = nil

      events.on(events.PR_LOADED, function(data)
        received = true
        received_data = data
      end)

      local test_data = { pr_number = 123 }
      events.emit(events.PR_LOADED, test_data)

      assert.is_true(received)
      assert.equals(123, received_data.pr_number)
    end)

    it('should support multiple listeners', function()
      local count = 0

      events.on(events.FILE_VIEWED, function()
        count = count + 1
      end)

      events.on(events.FILE_VIEWED, function()
        count = count + 10
      end)

      events.emit(events.FILE_VIEWED)

      assert.equals(11, count)
    end)

    it('should pass multiple arguments to listeners', function()
      local arg1, arg2, arg3

      events.on(events.COMMENT_ADDED, function(a, b, c)
        arg1, arg2, arg3 = a, b, c
      end)

      events.emit(events.COMMENT_ADDED, 'foo', 'bar', 'baz')

      assert.equals('foo', arg1)
      assert.equals('bar', arg2)
      assert.equals('baz', arg3)
    end)
  end)

  describe('event unsubscription', function()
    it('should unsubscribe listener', function()
      local count = 0

      local listener_id = events.on(events.PR_REFRESHED, function()
        count = count + 1
      end)

      events.emit(events.PR_REFRESHED)
      assert.equals(1, count)

      events.off(events.PR_REFRESHED, listener_id)
      events.emit(events.PR_REFRESHED)

      -- Count should not increase after unsubscribing
      assert.equals(1, count)
    end)
  end)

  describe('once listener', function()
    it('should only trigger once', function()
      local count = 0

      events.once(events.FILE_REVIEWED, function()
        count = count + 1
      end)

      events.emit(events.FILE_REVIEWED)
      events.emit(events.FILE_REVIEWED)
      events.emit(events.FILE_REVIEWED)

      -- Should only trigger once
      assert.equals(1, count)
    end)
  end)

  describe('error handling', function()
    it('should not stop other listeners on error', function()
      local good_listener_called = false

      -- Add a listener that throws error
      events.on(events.PANE_CHANGED, function()
        error('Test error')
      end)

      -- Add a good listener
      events.on(events.PANE_CHANGED, function()
        good_listener_called = true
      end)

      -- Emit event
      events.emit(events.PANE_CHANGED)

      -- Good listener should still be called
      assert.is_true(good_listener_called)
    end)
  end)

  describe('event types', function()
    it('should have all expected event types', function()
      -- PR Events
      assert.is_string(events.PR_LOADED)
      assert.is_string(events.PR_REFRESHED)

      -- File Events
      assert.is_string(events.FILE_SELECTED)
      assert.is_string(events.FILE_VIEWED)
      assert.is_string(events.FILE_REVIEWED)

      -- UI Events
      assert.is_string(events.PANE_CHANGED)
      assert.is_string(events.MODE_CHANGED)

      -- Comment Events
      assert.is_string(events.COMMENT_ADDED)
      assert.is_string(events.COMMENT_UPDATED)
      assert.is_string(events.COMMENT_DELETED)

      -- Review Events
      assert.is_string(events.REVIEW_SUBMITTED)
      assert.is_string(events.AI_REVIEW_COMPLETED)
    end)
  end)
end)

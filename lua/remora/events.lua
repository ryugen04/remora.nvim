-- Event system for remora.nvim

local M = {}

-- Event types
M.PR_LOADED = 'pr_loaded'
M.PR_REFRESHED = 'pr_refreshed'
M.FILE_SELECTED = 'file_selected'
M.FILE_VIEWED = 'file_viewed'
M.FILE_REVIEWED = 'file_reviewed'
M.PANE_CHANGED = 'pane_changed'
M.MODE_CHANGED = 'mode_changed'
M.COMMENT_ADDED = 'comment_added'
M.COMMENT_UPDATED = 'comment_updated'
M.COMMENT_DELETED = 'comment_deleted'
M.NOTE_ADDED = 'note_added'
M.REVIEW_SUBMITTED = 'review_submitted'
M.AI_REVIEW_COMPLETED = 'ai_review_completed'

-- Event listeners
local listeners = {}

-- Initialize event system
function M.init()
  listeners = {}
end

-- Subscribe to an event
---@param event string Event name
---@param callback function Callback function
---@return number listener_id
function M.on(event, callback)
  if not listeners[event] then
    listeners[event] = {}
  end

  local id = #listeners[event] + 1
  listeners[event][id] = callback

  return id
end

-- Unsubscribe from an event
---@param event string Event name
---@param listener_id number Listener ID from on()
function M.off(event, listener_id)
  if listeners[event] then
    listeners[event][listener_id] = nil
  end
end

-- Emit an event
---@param event string Event name
---@param ... any Event data
function M.emit(event, ...)
  if not listeners[event] then
    return
  end

  for _, callback in pairs(listeners[event]) do
    -- Call callback in protected mode
    local success, err = pcall(callback, ...)
    if not success then
      vim.notify(
        string.format('Error in event listener for %s: %s', event, err),
        vim.log.levels.ERROR
      )
    end
  end
end

-- Subscribe to an event once
---@param event string Event name
---@param callback function Callback function
function M.once(event, callback)
  local listener_id
  listener_id = M.on(event, function(...)
    M.off(event, listener_id)
    callback(...)
  end)
end

return M

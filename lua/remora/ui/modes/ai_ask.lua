-- AI Ask mode for remora.nvim right pane

local M = {}

local state = require('remora.state')
local buffer_utils = require('remora.utils.buffer')

-- Conversation history
M.conversation = {}
M.is_asking = false

-- Render AI Ask mode
---@param bufnr number
function M.render(bufnr)
  local lines = {}

  table.insert(lines, '═══════════════════════════════════════════════════════════')
  table.insert(lines, ' 💬 AI Ask Mode')
  table.insert(lines, '═══════════════════════════════════════════════════════════')
  table.insert(lines, '')

  if #M.conversation == 0 then
    table.insert(lines, '👋 Ask Claude Code Anything')
    table.insert(lines, '')
    table.insert(lines, 'This mode provides direct access to Claude Code CLI')
    table.insert(lines, 'without PR context injection.')
    table.insert(lines, '')
    table.insert(lines, 'You can ask about:')
    table.insert(lines, '  • Code explanations')
    table.insert(lines, '  • Best practices')
    table.insert(lines, '  • Debugging help')
    table.insert(lines, '  • Architecture questions')
    table.insert(lines, '  • General programming')
    table.insert(lines, '')
    table.insert(lines, '⌨️  Commands')
    table.insert(lines, '─────────────────────────────────────────────────────────')
    table.insert(lines, '  a    Ask a question')
    table.insert(lines, '  c    Clear conversation')
  else
    -- Show conversation history
    table.insert(lines, '📜 Conversation')
    table.insert(lines, '─────────────────────────────────────────────────────────')
    table.insert(lines, '')

    for i, message in ipairs(M.conversation) do
      local prefix = message.role == 'user' and '👤 You:' or '🤖 Claude:'
      table.insert(lines, prefix)

      for _, line in ipairs(vim.split(message.content, '\n')) do
        table.insert(lines, '  ' .. line)
      end

      table.insert(lines, '')

      if i < #M.conversation then
        table.insert(lines, '···')
        table.insert(lines, '')
      end
    end

    if M.is_asking then
      table.insert(lines, '⏳ Waiting for response...')
      table.insert(lines, '')
    end

    table.insert(lines, '⌨️  Commands')
    table.insert(lines, '─────────────────────────────────────────────────────────')
    table.insert(lines, '  a    Ask another question')
    table.insert(lines, '  c    Clear conversation')
  end

  buffer_utils.set_lines(bufnr, lines, { modifiable = false })

  -- Set up keymaps
  M._setup_keymaps(bufnr)
end

-- Set up keymaps
---@param bufnr number
function M._setup_keymaps(bufnr)
  -- a: Ask question
  buffer_utils.set_keymap(bufnr, 'n', 'a', function()
    M.ask_question()
  end, { desc = 'Ask Claude Code' })

  -- c: Clear conversation
  buffer_utils.set_keymap(bufnr, 'n', 'c', function()
    M.clear_conversation()
  end, { desc = 'Clear conversation' })
end

-- Ask a question
function M.ask_question()
  if M.is_asking then
    vim.notify('Already waiting for a response', vim.log.levels.WARN)
    return
  end

  -- Prompt for question
  vim.ui.input({ prompt = 'Ask Claude Code: ' }, function(question)
    if not question or question == '' then
      return
    end

    -- Add user message to conversation
    table.insert(M.conversation, {
      role = 'user',
      content = question,
      timestamp = os.date('%Y-%m-%dT%H:%M:%S'),
    })

    M.is_asking = true

    -- Refresh UI
    local right_pane = require('remora.ui.right_pane')
    right_pane.render()

    -- Send to Claude Code CLI
    local claude = require('remora.core.claude')

    claude.ask({
      question = question,
      conversation = M.conversation,
      on_response = function(response, err)
        M.is_asking = false

        if err then
          vim.notify('Error: ' .. err, vim.log.levels.ERROR)
          right_pane.render()
          return
        end

        -- Add assistant response to conversation
        table.insert(M.conversation, {
          role = 'assistant',
          content = response,
          timestamp = os.date('%Y-%m-%dT%H:%M:%S'),
        })

        -- Save conversation history
        M._save_conversation()

        right_pane.render()
      end,
    })
  end)
end

-- Clear conversation
function M.clear_conversation()
  M.conversation = {}
  M._save_conversation()

  vim.notify('Conversation cleared', vim.log.levels.INFO)

  local right_pane = require('remora.ui.right_pane')
  right_pane.render()
end

-- Save conversation to disk
function M._save_conversation()
  if not state.current_pr then
    return
  end

  -- Store in ai_history.json
  local storage = require('remora.core.storage')
  local pr_key = string.format('%s_%s_%d', state.current_pr.owner, state.current_pr.repo, state.current_pr.number)

  storage.save(pr_key, 'ai_history.json', {
    ask_mode_conversations = M.conversation,
    last_updated = os.date('%Y-%m-%dT%H:%M:%S'),
  })
end

-- Load conversation from disk
function M.load_conversation()
  if not state.current_pr then
    return
  end

  local storage = require('remora.core.storage')
  local pr_key = string.format('%s_%s_%d', state.current_pr.owner, state.current_pr.repo, state.current_pr.number)

  local history_data = storage.load(pr_key, 'ai_history.json')

  if history_data and history_data.ask_mode_conversations then
    M.conversation = history_data.ask_mode_conversations
  end
end

return M

# remora.nvim Architecture Design

## Overview

remora.nvim is a local PR review tool for Neovim that integrates with GitHub GraphQL API, diffview.nvim, and Claude Code CLI to provide an AI-enhanced code review experience.

## Core Principles

1. **Modular Design**: Each component is independent and communicable via events
2. **Local-First**: All review state persisted locally before GitHub sync
3. **UI Separation**: Clear separation between panes and their responsibilities
4. **Plugin Integration**: Leverage existing plugins (diffview, codecompanion) instead of reimplementing

---

## Directory Structure

```
remora.nvim/
├── lua/
│   └── remora/
│       ├── init.lua                 # Plugin entry point
│       ├── config.lua               # Configuration management
│       ├── state.lua                # Global state management
│       ├── events.lua               # Event system
│       │
│       ├── core/
│       │   ├── github.lua           # GitHub GraphQL API client
│       │   ├── storage.lua          # Local persistence layer
│       │   ├── parser.lua           # Diff/comment parsing
│       │   └── claude.lua           # Claude Code CLI integration
│       │
│       ├── ui/
│       │   ├── layout.lua           # Main layout management
│       │   ├── left_pane.lua        # Left sidebar (PR/Files/Memos)
│       │   ├── center_pane.lua      # Center content area
│       │   ├── right_pane.lua       # Right sidebar (modes)
│       │   ├── components/
│       │   │   ├── tree.lua         # File tree component
│       │   │   ├── pr_home.lua      # PR summary component
│       │   │   ├── memos.lua        # Memos component
│       │   │   ├── comments.lua     # Comment display/edit
│       │   │   └── badges.lua       # Status badges
│       │   └── modes/
│       │       ├── ai_review.lua    # AI Review mode
│       │       ├── ai_ask.lua       # AI Ask mode
│       │       ├── pr_comments.lua  # PR Comments mode
│       │       └── local_memo.lua   # Local Memo mode
│       │
│       ├── integrations/
│       │   ├── diffview.lua         # diffview.nvim integration
│       │   └── codecompanion.lua    # codecompanion.nvim integration
│       │
│       └── utils/
│           ├── buffer.lua           # Buffer utilities
│           ├── window.lua           # Window utilities
│           ├── highlight.lua        # Syntax highlighting
│           └── keymaps.lua          # Keymap management
│
├── plugin/
│   └── remora.lua                   # Plugin initialization
│
├── doc/
│   └── remora.txt                   # Vim help documentation
│
└── tests/
    └── ...                          # Test files
```

---

## Data Model

### Storage Structure

```
~/.local/share/nvim/remora/
└── reviews/{owner}_{repo}_{pr_number}/
    ├── state.json              # Review state (viewed files, status)
    ├── local_notes.json        # User memos and TODOs
    ├── ai_reviews.json         # AI-generated review comments
    ├── ai_history.json         # AI conversation history
    └── draft_comments.json     # Draft PR comments (not yet published)
```

### State Schema

```lua
-- state.json
{
  pr = {
    number = 123,
    title = "...",
    author = "...",
    base_branch = "main",
    head_branch = "feature",
    state = "OPEN",
    created_at = "...",
    updated_at = "..."
  },
  files = {
    ["path/to/file.lua"] = {
      status = "modified" | "added" | "deleted" | "renamed",
      viewed = true | false,
      reviewed = true | false,
      comments_count = 0,
      ai_reviewed = true | false,
      has_local_notes = true | false
    }
  },
  view_mode = "tree" | "flat" | "status",
  filters = {
    show_viewed = true,
    show_reviewed = true,
    file_types = []
  }
}
```

```lua
-- local_notes.json
{
  global_notes = [
    { id = "uuid", type = "TODO" | "NOTE", content = "...", created_at = "..." }
  ],
  file_notes = {
    ["path/to/file.lua"] = [
      { id = "uuid", line = 10, type = "TODO", content = "...", created_at = "..." }
    ]
  }
}
```

```lua
-- draft_comments.json
{
  comments = [
    {
      id = "uuid",
      path = "file.lua",
      position = 10,  -- diff position
      line = 42,      -- original line number
      body = "...",
      is_suggestion = false,
      suggestion_code = nil,
      created_at = "...",
      updated_at = "..."
    }
  ],
  pending_review = {
    event = "COMMENT" | "APPROVE" | "REQUEST_CHANGES",
    body = "Overall review comment"
  }
}
```

---

## Component Interaction

### Event System

```lua
-- events.lua
local Events = {
  -- PR Events
  PR_LOADED = "pr_loaded",
  PR_REFRESHED = "pr_refreshed",

  -- File Events
  FILE_SELECTED = "file_selected",
  FILE_VIEWED = "file_viewed",
  FILE_REVIEWED = "file_reviewed",

  -- UI Events
  PANE_CHANGED = "pane_changed",
  MODE_CHANGED = "mode_changed",

  -- Comment Events
  COMMENT_ADDED = "comment_added",
  COMMENT_UPDATED = "comment_updated",
  COMMENT_DELETED = "comment_deleted",

  -- Review Events
  REVIEW_SUBMITTED = "review_submitted",
  AI_REVIEW_COMPLETED = "ai_review_completed",
}
```

### Communication Flow

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  Left Pane  │ Events  │    State     │ Events  │ Right Pane  │
│             │────────>│   Manager    │<────────│             │
└─────────────┘         └──────────────┘         └─────────────┘
      │                        │                        │
      │                        │                        │
      v                        v                        v
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Storage   │         │    GitHub    │         │   Claude    │
│   Layer     │         │     API      │         │     CLI     │
└─────────────┘         └──────────────┘         └─────────────┘
```

---

## UI Layout Management

### Pane System

```lua
-- Three-pane layout with dynamic content
Layout = {
  left = {
    width = 40,  -- configurable
    sections = { "pr_home", "files", "memos" },
    current_focus = "files"
  },
  center = {
    type = "pr_detail" | "diffview",
    buffer = nil,
    diffview_active = false
  },
  right = {
    width = 50,  -- configurable
    mode = "ai_review" | "ai_ask" | "pr_comments" | "local_memo",
    tabs = { "Review", "Ask", "PR", "Memo" }
  }
}
```

### File Tree Modes

1. **Tree Mode**: Hierarchical directory structure
2. **Flat Mode**: Linear file list
3. **Status Mode**: Grouped by change type (added/modified/deleted)

### Badge System

```lua
Badges = {
  VIEWED = "👀",     -- File has been viewed
  REVIEWED = "✅",   -- File marked as reviewed
  COMMENTED = "💬", -- Has PR comments
  NOTED = "📝",     -- Has local notes
  PINNED = "📌",    -- Pinned for attention
  AI_REVIEWED = "🤖" -- AI review completed
}
```

---

## Integration Points

### 1. diffview.nvim

```lua
-- Open file in diffview with PR context
local diffview = require('remora.integrations.diffview')

diffview.open_file({
  file_path = "path/to/file.lua",
  base_commit = pr.base_sha,
  head_commit = pr.head_sha,
  on_close = function()
    -- Mark file as viewed
    state.mark_file_viewed(file_path)
  end
})
```

### 2. codecompanion.nvim

```lua
-- AI Review mode with context injection
local codecompanion = require('remora.integrations.codecompanion')

codecompanion.start_review({
  injection_context = {
    pr_description = pr.body,
    diff_content = diff,
    existing_comments = comments
  },
  on_response = function(review)
    -- Parse and store AI review
    parser.extract_comments(review)
  end
})
```

### 3. Claude Code CLI

```lua
-- Direct CLI invocation for AI Ask mode
local claude = require('remora.core.claude')

claude.execute({
  mode = "ask",  -- no injection
  context = selected_text,
  on_output = function(response)
    ui.display_response(response)
  end
})
```

---

## GitHub GraphQL Integration

### Key Operations

```lua
-- github.lua
local GitHub = {}

-- Fetch PR data
function GitHub:fetch_pr(owner, repo, number)
  -- Query: repository.pullRequest with files, comments, reviews
end

-- Add review comment
function GitHub:add_comment(pr_id, comment)
  -- Mutation: addPullRequestReviewComment
end

-- Add suggestion
function GitHub:add_suggestion(pr_id, path, position, suggestion)
  -- Mutation: addPullRequestReviewComment with suggestion syntax
end

-- Submit review
function GitHub:submit_review(pr_id, event, body, comments)
  -- Mutation: submitPullRequestReview
end
```

### Comment Display

**Hover Popup:**
```lua
-- On cursor hover in diffview
vim.lsp.buf.hover() -- style popup with comments
```

**Inline Expand:**
```lua
-- Virtual text + foldable section
vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
  virt_lines = comment_lines,
  virt_lines_above = true
})
```

---

## Phase Implementation Details

### Phase 1: Left Pane Foundation

**Components:**
- File tree (tree/flat/status modes)
- PR Home summary (title, author, status)
- Memos section (TODO/Notes list)

**Deliverables:**
- `ui/left_pane.lua`
- `ui/components/tree.lua`
- `ui/components/pr_home.lua`
- `ui/components/memos.lua`

### Phase 2: Center Pane PR Detail

**Components:**
- PR description rendering
- Metadata display (author, reviewers, labels, checks)
- Comment timeline view

**Deliverables:**
- `ui/center_pane.lua`
- PR detail buffer rendering

### Phase 3: diffview Integration + Comments

**Components:**
- diffview.nvim wrapper
- Hover comment popup
- Inline comment expansion

**Deliverables:**
- `integrations/diffview.lua`
- `ui/components/comments.lua`

### Phase 4: Right Pane Mode System

**Components:**
- Mode tabs (Review/Ask/PR/Memo)
- Mode switching logic
- Base UI for each mode

**Deliverables:**
- `ui/right_pane.lua`
- `ui/modes/*.lua` (4 files)

### Phase 5: AI Review Mode

**Components:**
- Context injection system
- codecompanion integration
- Review parsing and storage

**Deliverables:**
- `integrations/codecompanion.lua`
- `core/parser.lua`
- AI review workflow

### Phase 6: GitHub GraphQL

**Components:**
- GraphQL client
- Comment/suggestion posting
- Draft management

**Deliverables:**
- `core/github.lua`
- Comment submission workflow

### Phase 7: Review Submission

**Components:**
- Review finalization UI
- Approve/Request Changes/Comment events
- Batch comment submission

**Deliverables:**
- Review submission workflow
- Final polish and testing

---

## Configuration

```lua
-- Default configuration
require('remora').setup({
  -- Layout
  layout = {
    left_width = 40,
    right_width = 50,
    open_on_startup = false
  },

  -- File tree
  file_tree = {
    default_mode = "tree",  -- tree | flat | status
    icons = true,
    git_icons = true
  },

  -- GitHub
  github = {
    token = nil,  -- Read from gh CLI or env
    api_url = "https://api.github.com/graphql"
  },

  -- AI
  ai = {
    claude_cli_path = "claude",
    codecompanion_enabled = true,
    auto_review = false
  },

  -- Storage
  storage = {
    path = vim.fn.stdpath('data') .. '/remora'
  },

  -- Keymaps
  keymaps = {
    toggle = "<leader>rt",
    refresh = "<leader>rr",
    submit_review = "<leader>rs"
  }
})
```

---

## Testing Strategy

1. **Unit Tests**: Each module independently
2. **Integration Tests**: GitHub API, diffview, codecompanion
3. **UI Tests**: Buffer rendering, keymaps
4. **Manual Testing**: Full workflow with real PRs

---

## Future Enhancements

- Multi-PR session support
- Offline mode improvements
- Custom review templates
- Team review coordination
- CI/CD status integration
- Code search within PR context

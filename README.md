# remora.nvim

🐟 A local PR review tool for Neovim with GitHub integration and AI-powered assistance.

## Overview

remora.nvim is a comprehensive pull request review tool that runs entirely within Neovim. It integrates with GitHub's GraphQL API, diffview.nvim for diff visualization, and Claude Code CLI for AI-powered code reviews.

### Key Features

- **📋 Three-Pane Layout**: Left sidebar for PR/file navigation, center pane for content, right sidebar for review modes
- **🌳 Multiple File Views**: Tree, flat, and status-grouped views
- **💬 PR Comments**: Draft, edit, and submit GitHub PR comments with suggestions
- **📝 Local Memos**: Keep TODO lists and notes attached to files or globally
- **🤖 AI Review**: Leverage Claude Code for intelligent code reviews with context injection
- **💾 Persistent State**: All review progress saved locally
- **🎨 Rich UI**: Badges, syntax highlighting, and intuitive navigation

## Installation

### Requirements

- Neovim 0.8+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [diffview.nvim](https://github.com/sindrets/diffview.nvim) (for diff visualization)
- [codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim) (optional, for AI features)
- [Claude Code CLI](https://github.com/anthropics/claude-code) (optional, for AI features)
- GitHub CLI (`gh`) or `GITHUB_TOKEN` environment variable

### Using lazy.nvim

```lua
{
  'ryugen04/remora.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'sindrets/diffview.nvim',
    'olimorris/codecompanion.nvim', -- optional
  },
  config = function()
    require('remora').setup({
      -- Configuration options (see below)
    })
  end,
}
```

### Using packer.nvim

```lua
use {
  'ryugen04/remora.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'sindrets/diffview.nvim',
    'olimorris/codecompanion.nvim', -- optional
  },
  config = function()
    require('remora').setup({})
  end,
}
```

## Quick Start

1. **Authenticate with GitHub**:
   ```bash
   gh auth login
   # OR set environment variable
   export GITHUB_TOKEN=ghp_xxxxxxxxxxxxx
   ```

2. **Open a PR**:
   ```vim
   :RemoraOpen owner/repo#123
   ```

3. **Navigate and Review**:
   - Use `<CR>` on files to open them in diffview
   - Press `r` to mark files as reviewed
   - Press `v` to cycle through tree/flat/status views
   - Press `1-4` in right pane to switch modes

4. **Submit Review**:
   ```vim
   :RemoraSubmitReview
   ```

## Configuration

### Default Configuration

```lua
require('remora').setup({
  -- Layout
  layout = {
    left_width = 40,        -- Left sidebar width
    right_width = 50,       -- Right sidebar width
    open_on_startup = false,
  },

  -- File tree
  file_tree = {
    default_mode = 'tree',  -- tree | flat | status
    icons = true,
    git_icons = true,
    show_hidden = false,
  },

  -- GitHub
  github = {
    token = nil,            -- nil = auto-detect from gh CLI or env
    api_url = 'https://api.github.com/graphql',
  },

  -- AI
  ai = {
    claude_cli_path = 'claude',
    codecompanion_enabled = true,
    auto_review = false,
  },

  -- Storage
  storage = {
    path = vim.fn.stdpath('data') .. '/remora',
  },

  -- Keymaps
  keymaps = {
    toggle = '<leader>rt',
    refresh = '<leader>rr',
    submit_review = '<leader>rs',
  },

  -- UI
  ui = {
    badges = {
      viewed = '👀',
      reviewed = '✅',
      commented = '💬',
      noted = '📝',
      pinned = '📌',
      ai_reviewed = '🤖',
    },
    comment_display = 'hover', -- hover | inline | both
  },
})
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:RemoraOpen [owner/repo#num]` | Open PR review (auto-detects if omitted) |
| `:RemoraClose` | Close remora |
| `:RemoraToggle` | Toggle remora |
| `:RemoraRefresh` | Refresh PR data from GitHub |
| `:RemoraSubmitReview` | Submit review to GitHub |

### Left Pane Navigation

| Key | Action |
|-----|--------|
| `<CR>` | Open file in diffview or show PR detail |
| `r` | Toggle file reviewed status |
| `v` | Cycle view mode (tree/flat/status) |
| `R` | Refresh PR from GitHub |
| `q` | Close remora |

### Right Pane Modes

| Key | Mode | Description |
|-----|------|-------------|
| `1` | AI Review | AI-powered code review with context |
| `2` | AI Ask | General questions to Claude Code |
| `3` | PR Comments | Manage draft/published comments |
| `4` | Local Memo | TODO lists and notes |

Use `<Tab>` and `<S-Tab>` to cycle through modes.

### File View Modes

**Tree Mode** (default):
```
  src/
    components/
      Button.tsx ✅
      Input.tsx 👀
    utils/
      helpers.ts 💬
```

**Flat Mode**:
```
  src/components/Button.tsx ✅
  src/components/Input.tsx 👀
  src/utils/helpers.ts 💬
```

**Status Mode**:
```
▼ Modified (2)
    src/components/Button.tsx ✅
    src/utils/helpers.ts 💬

▼ Added (1)
    src/components/Input.tsx 👀
```

## Workflow

### Basic Review Workflow

1. **Load PR**: `:RemoraOpen owner/repo#123`
2. **Browse Files**: Navigate in left pane
3. **Review Files**:
   - Press `<CR>` to open in diffview
   - Review changes
   - Press `r` to mark as reviewed
4. **Add Comments**: (Phase 6 - coming soon)
5. **Submit Review**: `:RemoraSubmitReview`

### AI-Enhanced Workflow

1. **Load PR**: `:RemoraOpen owner/repo#123`
2. **AI Review**: Switch to AI Review mode (`1` in right pane)
3. **Request Review**: `:RemoraAIReview` (Phase 5 - coming soon)
4. **Review Suggestions**: Check AI-generated comments
5. **Add Your Comments**: Supplement AI findings
6. **Submit**: `:RemoraSubmitReview`

### Local Notes Workflow

1. **Add Global TODO**: In Memo mode, press `a`
2. **Add File Note**: Navigate to file, add inline note
3. **View All Memos**: Switch to Memo mode (`4` in right pane)
4. **Export**: Notes saved locally in `~/.local/share/nvim/remora/`

## Data Storage

All review data is stored locally:

```
~/.local/share/nvim/remora/
└── reviews/
    └── owner_repo_123/
        ├── state.json          # Review progress
        ├── local_notes.json    # TODO/Notes
        ├── ai_reviews.json     # AI review history
        ├── ai_history.json     # AI conversation
        └── draft_comments.json # Uncommitted comments
```

## Implementation Roadmap

- [x] **Phase 1**: Left pane (File Tree + Memos + PR Home)
- [x] **Phase 2**: Center pane PR detail screen
- [ ] **Phase 3**: diffview integration + comment display
- [ ] **Phase 4**: Right pane mode system
- [ ] **Phase 5**: AI Review mode (codecompanion integration)
- [ ] **Phase 6**: GitHub GraphQL (comment/suggestion posting)
- [ ] **Phase 7**: Review submission (Approve/Request Changes)

**Current Status**: Phase 1-2 Complete ✅

## Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed design documentation.

### Key Components

```
remora.nvim/
├── lua/remora/
│   ├── init.lua              # Main entry point
│   ├── config.lua            # Configuration
│   ├── state.lua             # Global state
│   ├── events.lua            # Event system
│   ├── core/                 # Core functionality
│   │   ├── github.lua        # GitHub API client
│   │   ├── storage.lua       # Local persistence
│   │   └── claude.lua        # Claude Code integration
│   └── ui/                   # User interface
│       ├── layout.lua        # Layout manager
│       ├── left_pane.lua     # Left sidebar
│       ├── right_pane.lua    # Right sidebar
│       ├── center_pane.lua   # Center content
│       └── components/       # UI components
```

## Contributing

Contributions welcome! This plugin is in active development.

### Development Setup

1. Clone the repository
2. Install dependencies (plenary, diffview)
3. Read [ARCHITECTURE.md](./ARCHITECTURE.md)
4. Check open issues or create a new one

### Testing

```bash
# Run tests (coming soon)
make test
```

## FAQ

**Q: Does this work with private repositories?**
A: Yes, as long as your GitHub token has appropriate permissions.

**Q: Can I use this without AI features?**
A: Yes! AI features are optional. The core PR review workflow works independently.

**Q: Does this support GitHub Enterprise?**
A: Yes, configure `github.api_url` to your GHE instance.

**Q: How do I auto-detect PR from current branch?**
A: Currently manual specification required. Auto-detection coming in future update.

## License

MIT License - See [LICENSE](./LICENSE) for details.

## Credits

Built with ❤️ using:
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [diffview.nvim](https://github.com/sindrets/diffview.nvim)
- [codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim)
- [Claude Code](https://github.com/anthropics/claude-code)

## Related Projects

- [octo.nvim](https://github.com/pwntester/octo.nvim) - GitHub issues and PRs in Neovim
- [gh.nvim](https://github.com/ldelossa/gh.nvim) - GitHub integration for Neovim
- [diffview.nvim](https://github.com/sindrets/diffview.nvim) - Git diff viewer

---

**Note**: This plugin is in active development. Phase 1-2 are complete. Phases 3-7 are planned for upcoming releases. See the roadmap above for details.

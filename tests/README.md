# remora.nvim Tests

このディレクトリには、remora.nvimのユニットテストと統合テストが含まれています。

## 📁 テスト構造

```
tests/
├── minimal_init.lua          # テスト用の最小init.lua
├── README.md                 # このファイル
│
├── core/                     # コアモジュールのユニットテスト
│   ├── storage_spec.lua      # ストレージ層のテスト
│   └── parser_spec.lua       # パーサーのテスト
│
├── utils/                    # ユーティリティのユニットテスト
│   └── buffer_spec.lua       # バッファユーティリティのテスト
│
├── state_spec.lua            # 状態管理のテスト
│
└── integration/              # 統合テスト
    ├── events_spec.lua       # イベントシステムのテスト
    ├── ui_components_spec.lua # UIコンポーネントのテスト
    └── github_spec.lua       # GitHub API統合のテスト
```

## 🚀 テストの実行

### 前提条件

- Neovim (0.8+)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### すべてのテストを実行

```bash
make test
```

### ユニットテストのみ実行

```bash
make test-unit
```

### 統合テストのみ実行

```bash
make test-integration
```

### 特定のテストファイルを実行

```bash
make test-file FILE=tests/core/storage_spec.lua
```

## 🔧 セットアップ

### テスト依存関係のインストール

```bash
make install-deps
```

これにより、plenary.nvimが `/tmp/plenary.nvim` にクローンされます。

### 手動セットアップ

```bash
# plenary.nvimをクローン
git clone https://github.com/nvim-lua/plenary.nvim /tmp/plenary.nvim

# テスト実行
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"
```

## 📝 テストの書き方

### ユニットテストの例

```lua
-- tests/my_module_spec.lua
local my_module = require('remora.my_module')

describe('my_module', function()
  describe('my_function', function()
    it('should do something', function()
      local result = my_module.my_function('input')
      assert.equals('expected', result)
    end)

    it('should handle edge cases', function()
      local result = my_module.my_function(nil)
      assert.is_nil(result)
    end)
  end)
end)
```

### 統合テストの例

```lua
-- tests/integration/my_integration_spec.lua
local module_a = require('remora.module_a')
local module_b = require('remora.module_b')

describe('module integration', function()
  it('should work together', function()
    module_a.setup()
    local result = module_b.process()
    assert.is_not_nil(result)
  end)
end)
```

## 🧪 テストカバレッジ

### ユニットテスト

- [x] **core/storage.lua** - ローカルストレージの読み書き
- [x] **core/parser.lua** - AIレスポンス、diff、PRデスクリプションのパース
- [x] **state.lua** - グローバル状態管理
- [x] **utils/buffer.lua** - バッファユーティリティ

### 統合テスト

- [x] **events.lua** - イベントシステムの発火と購読
- [x] **ui/components** - UIコンポーネントのレンダリング
- [x] **core/github.lua** - GitHub API統合（モック）

### 今後のテスト追加予定

- [ ] utils/window.lua - ウィンドウ管理
- [ ] utils/highlight.lua - シンタックスハイライト
- [ ] ui/layout.lua - レイアウト管理
- [ ] integrations/diffview.lua - diffview統合
- [ ] integrations/codecompanion.lua - codecompanion統合

## 🔍 リント

### luacheckの実行

```bash
make lint
```

### luacheckのインストール

```bash
luarocks install luacheck
```

## 🤖 CI/CD

GitHub Actionsで自動的にテストが実行されます：

- **push時**: すべてのブランチでテスト実行
- **PR時**: mainブランチへのPRでテスト実行
- **マトリックステスト**: Neovim stable と nightly でテスト

ワークフロー設定: `.github/workflows/ci.yml`

## 🐛 デバッグ

### テスト実行時のデバッグ出力

```bash
# ヘッドレスモードを外して実行
nvim -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/core/storage_spec.lua"
```

### 特定のテストケースのみ実行

```lua
-- テストファイル内で
describe('my_module', function()
  -- 'only' を使用
  it.only('should run only this test', function()
    assert.is_true(true)
  end)

  it('should skip this test', function()
    assert.is_true(false)
  end)
end)
```

## 📊 テストのベストプラクティス

1. **各テストは独立させる** - テスト間で状態を共有しない
2. **before_each/after_eachを使用** - セットアップとクリーンアップを明示的に
3. **わかりやすいテスト名** - `should do something` 形式を推奨
4. **エッジケースをテスト** - nil, 空文字列, 大きな値など
5. **モックを適切に使用** - 外部依存（GitHub API等）はモック化

## 🔗 参考リンク

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - テストフレームワーク
- [busted](https://olivinelabs.com/busted/) - Luaテストフレームワーク（plenaryの基盤）
- [luacheck](https://github.com/mpeterv/luacheck) - Lintツール

## ❓ FAQ

**Q: テストが失敗する**
A: `make install-deps` を実行して依存関係をインストールしてください。

**Q: 特定のテストだけスキップしたい**
A: テストに `pending()` を追加するか、`it` を `pending` に変更してください。

**Q: GitHub APIのテストが実際にAPIを叩いてしまう**
A: 現在はモック実装が不完全です。将来的にはHTTPレイヤーをモック化予定です。

**Q: テストデータはどこに保存される？**
A: `/tmp/remora-test-data` に保存されます。`make clean` でクリーンアップできます。

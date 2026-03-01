# LLMエージェント 実装→テスト→レビュー サイクル強制ツール調査

> 調査日: 2026-03-01
>
> 目的: Claude Codeで「実装 → テスト実行 → OpenAI Codexによるコードレビュー」というサイクルを強制的に回す仕組みの調査

## 目次

- [1. エグゼクティブサマリー](#1-エグゼクティブサマリー)
- [2. Claude Code Hooks](#2-claude-code-hooks)
- [3. Claude Code Skills](#3-claude-code-skills)
- [4. MCP (Model Context Protocol)](#4-mcp-model-context-protocol)
- [5. 外部ツール・フレームワーク](#5-外部ツールフレームワーク)
- [6. CI/CD統合](#6-cicd統合)
- [7. マルチLLMエージェント管理](#7-マルチllmエージェント管理)
- [8. 比較表・実現可能性評価](#8-比較表実現可能性評価)
- [9. 推奨アプローチ](#9-推奨アプローチ)
- [参考リンク](#参考リンク)

---

## 1. エグゼクティブサマリー

### 結論

「実装→テスト→Codexレビュー」サイクルの強制は、**Claude Code Hooks（特にStop Hook）+ codex exec** の組み合わせで実現可能。既に [claude-review-loop](https://github.com/hamelsmu/claude-review-loop) というプラグインがこのパターンを実装済み。

### 推奨アプローチ（優先順）

| 順位 | アプローチ | 実現可能性 | 実装コスト |
|------|-----------|-----------|-----------|
| 1 | **claude-review-loop プラグイン** | 高 | 低（即利用可能） |
| 2 | **Claude Code Hooks + codex exec スクリプト** | 高 | 低〜中 |
| 3 | **MCPサーバー（ワークフローステートマシン）** | 中 | 中 |
| 4 | **GitHub Agentic Workflows** | 中 | 中（テクニカルプレビュー段階） |
| 5 | **LangGraph カスタムオーケストレーション** | 高 | 高 |

---

## 2. Claude Code Hooks

### 概要

Hooksは Claude Code のライフサイクルの特定ポイントで**決定論的に**実行されるユーザー定義ハンドラ。CLAUDE.md の指示（アドバイス的、無視されうる）とは異なり、**毎回必ず実行される**点が最大の強み。

### 主要イベント

| イベント | 発火時点 | サイクルでの用途 |
|---------|--------|----------------|
| `PostToolUse` | ツール実行成功後 | コード編集後にテスト自動実行 |
| `Stop` | Claude応答終了時 | **品質ゲート**: テストPASS + レビュー完了まで停止をブロック |
| `PreToolUse` | ツール実行前 | 危険なコマンドのブロック |
| `SessionStart` | セッション開始時 | コンテキスト注入 |

### ハンドラタイプ

```json
{ "type": "command" }   // シェルコマンド実行（最も一般的）
{ "type": "prompt" }    // 単一ターン LLM 評価
{ "type": "agent" }     // マルチターン LLM + ツール（複雑な検証用）
{ "type": "http" }      // HTTP POST（外部サービス連携用）
```

### パターン1: PostToolUse でテスト自動実行

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/run-tests.sh"
          }
        ]
      }
    ]
  }
}
```

```bash
#!/bin/bash
# .claude/hooks/run-tests.sh
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path')
TEST_FILE=${FILE_PATH%/*}/$(basename "${FILE_PATH%.*}").test.ts

if [ -f "$TEST_FILE" ]; then
  npm test -- "$TEST_FILE"
  if [ $? -ne 0 ]; then
    echo "Tests failed for $TEST_FILE" >&2
    exit 2  # exit 2 = Claude にフィードバックして修正を促す
  fi
fi
exit 0
```

### パターン2: Stop Hook で品質ゲート（最も強力）

Claude が「完了」と言う前に品質チェックを強制。テストFAILなら停止をブロックし修正を続行させる。

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/quality-gate.sh"
          }
        ]
      }
    ]
  }
}
```

```bash
#!/bin/bash
# .claude/hooks/quality-gate.sh
# 1. テスト実行
npm test 2>&1
if [ $? -ne 0 ]; then
  echo "テストが失敗しています。修正してください。" >&2
  exit 2
fi

# 2. Codex レビュー実行
REVIEW=$(codex exec "このdiffをレビューしてください: $(git diff HEAD)" 2>/dev/null)
if echo "$REVIEW" | grep -qi "REVISE\|問題あり"; then
  echo "Codexレビューで問題が検出されました: $REVIEW" >&2
  exit 2
fi

exit 0
```

### メリット・デメリット

| メリット | デメリット |
|---------|----------|
| 決定論的（100%実行保証） | ツール呼び出し順序の「強制」はできない（ブロック or フィードバック） |
| CLAUDE.md と異なりコンテキスト圧縮で消えない | PostToolUseは実行後なのでUndo不可 |
| シェルスクリプトで柔軟に拡張可能 | デフォルトタイムアウト10分（設定変更可） |
| exit 2 でClaude にフィードバック可能 | Hook内から新規ツール呼び出しは不可 |

### 実現可能性: **高**

---

## 3. Claude Code Skills

### 概要

Skills は `.claude/skills/<name>/SKILL.md` に定義する再利用可能な指示セット。Claude が関連時に自動検出・起動するか、`/skill-name` で明示起動。

### ワークフロースキルの例

```yaml
---
name: implement-test-review
description: |
  機能実装後にテスト実行とCodexレビューを行うワークフロー
  新機能を実装する時に自動起動
disable-model-invocation: false
context: fork
agent: general-purpose
---

## タスク: $ARGUMENTS を実装してください

### ステップ 1: 実装
指定された機能を実装してください。

### ステップ 2: テスト実行（必須）
実装完了後、必ずテストを実行してください:
```bash
npm test
```
テストが FAIL したら修正してください。PASS するまで繰り返してください。

### ステップ 3: Codex レビュー
テスト PASS 後、Codex CLI でレビューを実行:
```bash
codex exec "変更内容をレビューしてください: $(git diff HEAD~1)"
```
レビュー結果に基づいて改善があれば実施してください。
```

### メリット・デメリット

| メリット | デメリット |
|---------|----------|
| 複数ステップのワークフローを記述可能 | Claudeの判断に依存（強制力はHookより弱い） |
| `context: fork` でサブエージェント実行可能 | 長いセッションでcontext予算を圧迫 |
| Hookより高レベルな判断が可能 | 起動はClaude の判断 or 明示的呼び出し |

### 実現可能性: **中**（Hookとの組み合わせで効果的）

---

## 4. MCP (Model Context Protocol)

### 4.1 ワークフロー制御用MCPサーバー

MCPサーバー内部にステートマシンを持ち、不正な順序のツール呼び出しをエラーで拒否するパターン。

```python
from fastmcp import FastMCP, Context
from enum import Enum

mcp = FastMCP("dev-workflow")

class State(Enum):
    IDLE = "idle"
    IMPLEMENTING = "implementing"
    TESTING = "testing"
    REVIEWING = "reviewing"

state = State.IDLE

@mcp.tool(description="コード実装。完了後は run_tests を呼んでください。")
async def implement(ctx: Context, task: str) -> str:
    global state
    if state not in (State.IDLE,):
        return f"エラー: 現在 {state.value} 状態。IDLEでのみ実行可能。"
    state = State.TESTING
    return "実装完了。次に run_tests を呼んでください。"

@mcp.tool(description="テスト実行。PASS後は code_review を呼んでください。")
async def run_tests(ctx: Context) -> str:
    global state
    if state != State.TESTING:
        return f"エラー: TESTING状態でのみ実行可能。現在: {state.value}"
    # テスト実行ロジック
    state = State.REVIEWING
    return "テスト完了。次に code_review を呼んでください。"

@mcp.tool(description="Codexによるコードレビュー。最終ステップ。")
async def code_review(ctx: Context, diff: str) -> str:
    global state
    if state != State.REVIEWING:
        return f"エラー: REVIEWING状態でのみ実行可能。現在: {state.value}"
    # codex exec でレビュー実行
    state = State.IDLE
    return "レビュー完了。"
```

### 4.2 既存のCodex MCPサーバー

| プロジェクト | 特徴 | URL |
|---|---|---|
| tuannvm/codex-mcp-server | セッション対応、レビュー機能内蔵 | [GitHub](https://github.com/tuannvm/codex-mcp-server) |
| cexll/codex-mcp-server | `codex exec`による非対話自動化 | [GitHub](https://github.com/cexll/codex-mcp-server) |
| kky42/codex-as-mcp | Claude CodeからCodex CLIに作業委譲 | [GitHub](https://github.com/kky42/codex-as-mcp) |
| BeehiveInnovations/pal-mcp-server | Claude + Codex + Gemini統合 | [GitHub](https://github.com/BeehiveInnovations/pal-mcp-server) |

### 4.3 MCP Tasks（実験的機能、2025-11-25仕様）

非同期タスク管理プリミティブ。ステートマシンとして設計されており、working → input_required → completed/failed/cancelled の状態遷移をサポート。

### 4.4 MCPの制限事項

| 制限 | 詳細 |
|------|------|
| **ツール呼び出し順序の強制は不可能** | LLMがどのツールをいつ呼ぶかはLLMの判断。descriptionで誘導は可能だが強制はできない |
| ツール数増加でLLM精度低下 | MCPサーバー・ツールが増えるほど、LLMの選択精度が下がる |
| サブエージェントからのMCPアクセス制限 | Claude CodeのサブエージェントからプロジェクトレベルのMCPサーバーにアクセスできない |

### 実現可能性: **中**（ステートマシンで誘導可能だが強制力に限界）

---

## 5. 外部ツール・フレームワーク

### 5.1 AIコーディングツール

| ツール | ワークフロー定義 | Codex連携 | 評価 |
|--------|----------------|----------|------|
| **Aider** | Pythonスクリプトから制御可能、Git統合強い | 直接統合なし（subprocess経由） | 中 |
| **Continue.dev** | MCPサポート、CI/CD統合あり | MCPサーバー経由で可能 | 中 |
| **Mentat** | カスタムワークフロー機能なし | なし | 低 |

### 5.2 LLMオーケストレーションフレームワーク

#### LangGraph（LangChain）
- **グラフベースのワークフロー定義**: ノード（エージェント/ツール）とエッジ（遷移条件）で表現
- **永続的状態管理**: 任意のポイントで保存・復元可能
- **Human-in-the-loop**: 人間のレビューのために実行を一時停止するパターンをサポート
- **評価**: 「実装→テスト→レビュー→判定→修正ループ」を明示的にグラフ定義可能。最もフレキシブルだが実装コストが高い

#### CrewAI
- **ロールベース設計**: 実装エージェント、テストエージェント、レビューエージェントのように役割を分離
- **Crews + Flows**: エージェントチーム + イベント駆動ワークフロー
- **評価**: 役割分離モデルは概念的にフィットするが、CLI（Claude Code/Codex）のラッパー実装が必要

#### OpenAI Agents SDK
- **Codex CLIとの直接統合**: Codex CLIをMCPサーバーとして公開しAgents SDKからオーケストレーション
- **公式Cookbook**: マルチエージェントワークフローの実装例あり
- **評価**: Codex側のエコシステムに統合する場合に有効だが、Claude Code統合は公式サポート外

#### Microsoft AutoGen → Agent Framework
- AutoGen + Semantic Kernel が統合され「Microsoft Agent Framework」に移行中
- **Agent Framework 1.0 GA は 2026年Q1末目標**
- **評価**: 移行期のため新規プロジェクトでの採用リスクが高い

---

## 6. CI/CD統合

### 6.1 GitHub Agentic Workflows（2026年2月テクニカルプレビュー）

- **Markdownでワークフロー定義**: YAMLではなくMarkdownで記述し、GitHub CLIでActions YAMLにコンパイル
- **複数エージェントエンジン対応**: Copilot CLI、Claude Code、OpenAI Codexを設定で切り替え可能
- **セキュリティ**: デフォルト読み取り専用、隔離コンテナ実行、ファイアウォール制限

### 6.2 Claude Code ヘッドレスモード + Codex exec パイプライン

```bash
# ステップ1: Claude Codeで実装（非対話モード）
SESSION_ID=$(uuidgen)
claude -p "UserServiceを実装してください" \
  --session-id "$SESSION_ID" \
  --allowedTools "Edit,Write,Read,Bash" \
  --output-format json

# ステップ2: テスト実行
npm test
if [ $? -ne 0 ]; then
  claude -p "テストが失敗しました。修正してください。" \
    --session-id "$SESSION_ID"
fi

# ステップ3: Codexでレビュー
REVIEW=$(codex exec "以下のdiffをレビューしてください: $(git diff HEAD~1)" \
  --output-schema '{"verdict":"string","issues":"array"}')

# ステップ4: レビュー結果に基づいて修正ループ
if echo "$REVIEW" | jq -r '.verdict' | grep -qi "revise"; then
  claude -p "Codexレビュー結果: $REVIEW を反映してください" \
    --session-id "$SESSION_ID"
fi
```

### 6.3 Qodo PR-Agent

- オープンソースPRレビューツール（GitHub Actions Docker image）
- `/review`、`/improve`、`/ask` の3ツール
- GPT、Claude、DeepSeek等の複数LLMに対応

---

## 7. マルチLLMエージェント管理

### 7.1 claude-review-loop（最も直接的な解決策）

[claude-review-loop](https://github.com/hamelsmu/claude-review-loop) は Claude Code + Codex のレビューループを実現するプラグイン。

**動作原理:**
1. Claude Code の **Stop Hook** を利用
2. Claude が実装タスクを終了しようとすると、フックが `codex exec` を呼び出して独立レビュー実行
3. レビュー結果を `reviews/review-<id>.md` に書き出し
4. Claude の終了をブロックし、フィードバックへの対応を求める
5. Codex が `VERDICT: APPROVED` を返すまでループ継続（最大5ラウンド）

**実績**: 3ラウンドで14の問題を検出し、手動作業ゼロで粗いドラフトを本番品質の仕様に変換した報告あり。

### 7.2 Claude Squad

[Claude Squad](https://github.com/smtg-ai/claude-squad) は複数AIエージェント（Claude Code、Codex、Aider、Gemini等）を並列管理するターミナルアプリ。tmux + git worktree で分離環境を提供。

### 7.3 Claude Code Agent Teams（公式機能）

Anthropic公式のマルチエージェント機能。チームリーダーがタスク配分、メンバーが独立コンテキストで作業。`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` で有効化。

### 7.4 Workmux

[Workmux](https://github.com/raine/workmux) は git worktrees + tmux windows によるゼロフリクション並列開発ツール。タスクごとに分離されたworktreeとtmuxタブを自動作成。

---

## 8. 比較表・実現可能性評価

### ツール/手法の総合評価

| アプローチ | 実現可能性 | 強制力 | 実装コスト | Codex統合 | 備考 |
|-----------|-----------|--------|-----------|----------|------|
| **claude-review-loop** | 高 | 高 | 低 | 内蔵 | 即利用可能。最もシンプル |
| **Claude Code Hooks (Stop)** | 高 | 最高 | 低〜中 | codex exec呼び出し | 決定論的。カスタマイズ自由度高い |
| **Claude Code Skills** | 中 | 中 | 低 | スクリプト経由 | Claudeの判断に依存 |
| **MCPワークフローサーバー** | 中 | 中 | 中 | MCP経由 | ステートマシンで誘導。強制は不可 |
| **GitHub Agentic Workflows** | 中 | 高 | 中 | 設定で切替 | テクニカルプレビュー段階 |
| **ヘッドレスモード+スクリプト** | 高 | 高 | 中 | codex exec | CI/CDパイプラインに最適 |
| **LangGraph** | 高 | 最高 | 高 | カスタムノード | 最もフレキシブル。実装重い |
| **CrewAI** | 中 | 高 | 高 | ラッパー必要 | ロールベースモデル |
| **OpenAI Agents SDK** | 中 | 高 | 中 | 公式サポート | Claude Code統合は非公式 |
| **CLAUDE.md** | 低 | 最低 | 最低 | 記述のみ | アドバイス。長セッションで消失リスク |

### 強制力の比較

```
Hook (Stop/PostToolUse)  ████████████ 決定論的。100%実行
claude-review-loop       ███████████  Stop Hookベース。自動ループ
ヘッドレス+スクリプト     ██████████   外部スクリプトで制御
LangGraph                ██████████   グラフで遷移を定義
GitHub Agentic Workflows ████████     CI/CDレベルで強制
MCPステートマシン          ██████       エラーで拒否できるが強制は不可
Skills                   ████         Claudeの判断に依存
CLAUDE.md                ██           アドバイスのみ。無視されうる
```

---

## 9. 推奨アプローチ

### 即座に使える: claude-review-loop

最小限のセットアップで「Claude Code実装 → Codexレビュー → 修正ループ」を実現。

```bash
# インストール
# (プラグインマーケットプレイスから)
claude plugin marketplace add hamelsmu/claude-review-loop
claude plugin install review-loop@hamel-review
```

### カスタムで構築する場合の推奨アーキテクチャ

```
.claude/
├── settings.json          # Hook設定
│   └── hooks:
│       ├── PostToolUse    # Edit/Write後にテスト自動実行
│       └── Stop           # 品質ゲート（テスト + Codexレビュー）
├── hooks/
│   ├── run-tests.sh       # PostToolUse: 関連テスト実行
│   └── quality-gate.sh    # Stop: テスト全Pass + Codexレビュー
└── skills/
    └── dev-cycle/
        └── SKILL.md       # ワークフロー全体のガイド
```

**動作フロー:**
```
ユーザー: "UserServiceを実装して"
    ↓
Claude がコード作成 → Edit ツール実行
    ↓
[PostToolUse Hook] テスト自動実行
    ├─ FAIL → Claude に stderr フィードバック → 修正
    └─ PASS → 続行
    ↓
Claude が「完了」しようとする
    ↓
[Stop Hook] 品質ゲート
    ├─ npm test → FAIL → Claude に戻って修正
    ├─ codex exec → REVISE → Claude に戻って修正
    └─ テストPASS + APPROVED → 停止許可
```

### 段階的導入の推奨

1. **Phase 1**: PostToolUse Hook でテスト自動実行（最小投資、即効果）
2. **Phase 2**: Stop Hook で Codex レビュー統合（品質ゲート強化）
3. **Phase 3**: MCPサーバーでワークフロー状態管理（複雑なプロジェクト向け）
4. **Phase 4**: GitHub Agentic Workflows でCI/CDレベル統合（チーム開発向け）

---

## 参考リンク

### Claude Code 公式ドキュメント
- [Hooks ガイド](https://code.claude.com/docs/en/hooks-guide)
- [Hooks リファレンス](https://code.claude.com/docs/en/hooks)
- [Skills](https://code.claude.com/docs/en/skills)
- [ヘッドレスモード](https://code.claude.com/docs/en/headless)
- [Agent Teams](https://code.claude.com/docs/en/agent-teams)

### OpenAI Codex
- [Codex CLI Features](https://developers.openai.com/codex/cli/features/)
- [非対話モード (codex exec)](https://developers.openai.com/codex/noninteractive/)
- [Codex MCP](https://developers.openai.com/codex/mcp/)
- [Codex + Agents SDK Cookbook](https://cookbook.openai.com/examples/codex/codex_mcp_agents_sdk/building_consistent_workflows_codex_cli_agents_sdk)

### マルチエージェント管理
- [claude-review-loop](https://github.com/hamelsmu/claude-review-loop) - Claude Code + Codex レビューループ
- [Claude Squad](https://github.com/smtg-ai/claude-squad) - 複数AIエージェント並列管理
- [Workmux](https://github.com/raine/workmux) - git worktree並列開発

### MCP
- [MCP仕様 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25)
- [MCP Tasks](https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/tasks)
- [FastMCP Elicitation](https://gofastmcp.com/servers/elicitation)
- [tuannvm/codex-mcp-server](https://github.com/tuannvm/codex-mcp-server)
- [kky42/codex-as-mcp](https://github.com/kky42/codex-as-mcp)

### オーケストレーション
- [LangGraph](https://www.langchain.com/langgraph)
- [CrewAI](https://crewai.com/)
- [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/)

### CI/CD
- [GitHub Agentic Workflows](https://github.blog/ai-and-ml/automate-repository-tasks-with-github-agentic-workflows/)
- [Qodo PR-Agent](https://github.com/qodo-ai/pr-agent)
- [Codex GitHub Action](https://developers.openai.com/codex/github-action/)

### 解説記事
- [Auto-Reviewing Claude's Code (O'Reilly)](https://www.oreilly.com/radar/auto-reviewing-claudes-code/)
- [Claude Code Hooks実践テクニック (Qiita)](https://qiita.com/dai_chi/items/dc7d68e0e9c18e95ac09)
- [Claude Code完全攻略ガイド (AQUA)](https://aquallc.jp/2026/01/19/claude-code-complete-guide)

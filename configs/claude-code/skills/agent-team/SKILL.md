---
name: agent-team
description: >-
  Agent Teams を使って並列作業を開始する。タスクを分析してチーム構成を決定し、
  ベストプラクティスに基づいてチームを編成・管理する。複数モジュールの並列実装、
  調査・レビュー、デバッグの仮説検証、クロスレイヤー変更に使う。
allowed-tools: Bash, Write, Read, Task
---

# Agent Team Orchestrator

ユーザーからタスクを受け取り、Agent Teams で並列作業を開始するスキル。

## 前提条件

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` が設定済みであること
- Claude Code v2.1.32 以降

## 判断フロー: Agent Teams vs Subagents vs 単独

まずタスクの性質を分析し、適切なアプローチを選択する。

| 条件 | アプローチ |
|------|-----------|
| メンバー間で議論・検証・調整が必要 | **Agent Teams** |
| 独立したタスクで結果を返すだけ | **Subagents**（Task ツール） |
| 順序付き作業、同一ファイル編集、依存関係が多い | **単独セッション** |

Agent Teams が不適切と判断したら、その理由を説明して代替手段を提案する。

## チーム編成手順

### 1. タスク分解

ユーザーのリクエストを独立した作業単位に分解する。

**良いタスクの基準:**
- 明確な成果物がある（関数、テストファイル、レビューレポート等）
- 他のタスクと独立して完了できる
- 小さすぎない（調整オーバーヘッド > 利益にならない）
- 大きすぎない（長時間チェックインなしは無駄のリスク）

### 2. チームサイズ決定

- **3〜5人** を基本とする
- チームメンバーあたり **5〜6タスク** が目安
- 3人の集中したメンバー > 5人の散漫なメンバー
- タスク数で割る: 15タスクなら3人、25タスクなら5人

### 3. ファイル所有権の分離

**2人が同じファイルを編集すると上書きが発生する。** チーム編成時に必ず
各メンバーが担当するファイル/ディレクトリを明確に分ける。

### 4. チーム作成プロンプトの構成

各メンバーへの生成プロンプトには以下を含める:

- **役割と担当範囲**: 何を実装/調査するか
- **担当ファイル**: 触ってよいファイル/ディレクトリの明示
- **タスク固有の詳細**: 仕様、制約、技術的コンテキスト
- **完了条件**: 何をもって完了とするか

**注意:** メンバーはリーダーの会話履歴を継承しない。プロンプトは自己完結させる。
メンバーは CLAUDE.md、MCP servers、skills は自動的にロードする。

### 5. プラン承認（リスクの高いタスク）

破壊的変更やアーキテクチャ変更を含む場合:

```text
Require plan approval before they make any changes.
Only approve plans that include test coverage.
Reject plans that modify database schemas without migration scripts.
```

### 6. モデル選択

- 実装作業: メイン会話と同じモデル（inherit）
- 調査・レビュー: Sonnet で十分な場合はコスト節約

## チーム管理

### 監視

- チームを長時間放置しない
- 機能していないアプローチは早めにリダイレクト
- タスクリストで進捗を確認

### リーダーの自己実装を防止

リーダーがメンバーの作業を自分で始めた場合:

```text
Wait for your teammates to complete their tasks before proceeding.
```

### シャットダウンとクリーンアップ

1. 全メンバーをシャットダウン
2. **リーダーから** `Clean up the team` を実行
3. メンバーからクリーンアップしない（不整合状態のリスク）

## ユースケース別テンプレート

### 並列実装（新機能・リファクタ）

```text
Create an agent team with N teammates:
- "auth": Implement authentication module in src/auth/. <detailed spec>
- "api": Implement API endpoints in src/api/. <detailed spec>
- "tests": Write integration tests in tests/. <detailed spec>

Each teammate owns their directory exclusively. Do not edit files
outside your assigned directory. Require plan approval before changes.
Use Sonnet for each teammate.
```

### 並列コードレビュー

```text
Create an agent team to review PR #N. Spawn three reviewers:
- One focused on security implications
- One checking performance impact
- One validating test coverage
Have them each review independently, then share findings to cross-validate.
```

### 競合仮説デバッグ

```text
<problem description>
Spawn N agent teammates to investigate different hypotheses.
Have them talk to each other to try to disprove each other's theories,
like a scientific debate. Update the findings doc with whatever
consensus emerges.
```

### クロスレイヤー変更

```text
Create an agent team for this feature:
- "frontend": Implement UI components in src/components/. <spec>
- "backend": Implement API in src/api/. <spec>
- "tests": Write E2E tests in tests/e2e/. <spec>

Frontend and backend should communicate about the API contract.
Tests teammate should wait for both to finish core implementation
before writing E2E tests (use task dependencies).
```

## アンチパターン

- **全員が同じファイルを触る** → 上書き地獄
- **タスクが細かすぎる** → 調整オーバーヘッドが利益を超える
- **メンバーに会話の文脈を期待** → 会話履歴は継承されない
- **放置** → 無駄な作業が累積する
- **順序依存タスクにチーム** → 単独セッションかsubagentsの方が良い

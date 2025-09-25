# TODO for CODEX — SynapseTasks UI差分実装（Board / Weeklyの可視化）

## Context
現在の `01_home.png`, `02_board.png`, `03_weekly.png` が同一レイアウトに見える。  
Board と Weekly の UI を **機能的にも視覚的にも** 明確に差別化し、スクリーンショットで誰が見ても違いが分かる状態にする。  
ビルドターゲット: **iPhone Simulator (iOS 26)**, Scheme: **SynapseTasks**, Config: **Debug**。

## Goals
- Home: 既存の「タスク一覧 + 追加」UIを維持（微修正可）。
- Board: カンバン(3列)ビューを実装。**Todo / Doing / Done** の列を横並びで表示し、タスクカードを列内でリスト表示。
- Weekly: 週表示。**月〜日の7日** を上部チップで表示し、選択日に紐づくタスクを下部のセクションで表示。
- 3画面の**見た目のコントラスト**を強める（ヘッダー/チップ/列背景/バッジ等）。
- UIキャプチャスクリプトで3画面のスクショを自動取得する。

## Acceptance Criteria
- `ui_captures/<date>/01_home.png`, `02_board.png`, `03_weekly.png` の3枚が**明らかに異なるUI**になっていること。
- Board: 画面上部に「Todo / Doing / Done」列が**横並び**で見える（横スクロール可）。各列の見出しバッジ色を変える。
- Weekly: 画面上部に **7つの曜日チップ**（例: 月, 火, … 日）が並び、選択状態が視覚で分かる。下部に「◯/◯(曜)」のセクション見出しとタスクが並ぶ。
- Home/Board/Weekly で**同じ空状態テキスト**は使わない（重複禁止）。
- `report.md` に変更点サマリ、`runs/build.log` にビルド成功ログがある。

## Required Changes

### 1) 画面構成
- タブ/セグメント切替をヘッダー直下に実装（3セグメント：`リスト` / `ボード` / `週間`）。
  - 既存の「Edit」ボタンは右上のまま残してOK。
  - 既定は `リスト`。

### 2) Home（リスト）
- 現状維持＋空状態文言を変更：
  - `まずはタスクを追加してみてください` → `ここにタスクが一覧表示されます`

### 3) Board（カンバン）
- `HStack` で **3列**（横スクロール）。各列は `VStack` のカード一覧。
- 列ヘッダー：
  - Todo → **グレー**バッジ
  - Doing → **ブルー**バッジ
  - Done → **グリーン**バッジ
- タスクカード：丸角・影・小さなステータス点（左端）。長押しメニューで `状態を変更`（Todo/Doing/Done）。
- 空状態テキスト：`ボードは空です。タスクを追加して列に振り分けましょう`

### 4) Weekly（週表示）
- 上部に `月 火 水 木 金 土 日` の**7チップ**。選択中は太字＋背景強調。
- 下部：選択日のセクション見出し（例：`9/25(木)`）と、その日のタスクのリスト。
- 空状態テキスト：`この日はまだ予定がありません`

### 5) シードデータ（スクショ用）
- デバッグ時はメモリ内のモックデータをロードする仕組みを追加：
  - 例）
    - 「仕様確認」(Todo)
    - 「API実装」(Doing, 期限=本日)
    - 「コードレビュー」(Done)
    - 「週次ミーティング」(今週金曜)
- `#if DEBUG` ブロックでのみ投入。実機/Releaseでは無効。

### 6) UIキャプチャの自動化
- `scripts/ui_capture.sh` を更新して、起動後に：
  1. 既定の Home を撮る → `01_home.png`
  2. セグメントで `ボード` を選択 → `02_board.png`
  3. セグメントで `週間` を選択し、曜日チップから **金** を選択 → `03_weekly.png`
- `xcrun simctl io $UDID screenshot ...` のファイルパスは既存と同じディレクトリ命名を踏襲。

## File Hints（候補）
- `SynapseTasks/SynapseTasksApp.swift`
- `SynapseTasks/Views/HomeView.swift`（既存）
- `SynapseTasks/Views/BoardView.swift`（新規）
- `SynapseTasks/Views/WeeklyView.swift`（新規）
- `SynapseTasks/Models/TaskItem.swift`（既存/新規いずれか）
- `SynapseTasks/State/AppState.swift`（選択タブ/シード注入）
- `scripts/ui_capture.sh`（UI操作の追加）

## Notes
- 文字列は日本語のまま。フォント/余白は現行トーン（丸角・やわらかいグレー）を踏襲しつつ、各画面で**一目で分かる要素**を加える。
- ダークモードでも崩れないよう Color は `semantic` を優先（`secondaryBackground`, `label` 等または SwiftUI の `secondary` 系）。


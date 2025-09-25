# CODEX Report – 2025-09-25

## 実施内容
- タスクデータモデルに `status` / `dueDate` を追加し、カンバン & 週間ビュー向けのロジックを整備
- `TaskListView` をセグメント切替式のダッシュボード化（リスト / ボード / 週間）し、各画面の空状態文言を差別化
- デバッグビルド限定のシードデータ投入と Launch 引数による初期タブ選択に対応
- `scripts/ui_capture.sh` を Home → Board → Weekly の順に自動撮影 & デバッグ用環境変数を注入するフローへ更新

## ビルド / UIキャプチャ状況
- `xcodebuild -scheme SynapseTasks -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -configuration Debug build`
  - **失敗**: CoreSimulatorService と DerivedData への書き込みがサンドボックスにより拒否されビルド不可
- `make uishot`（未実行）: CoreSimulatorService が利用不能なため、UIキャプチャは実施できず

## 次のアクション案
1. サンドボックス外もしくは CoreSimulatorService を再起動できる環境で `make build` / `make uishot` を再試行
2. UIキャプチャ生成後、`ui_captures/<date>/` を目視確認し、必要なら `feedback/todo.md` を更新

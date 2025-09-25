# How to apply and run CI (minimal human steps)

## Option A: パッチ適用
git apply runs/last/codex_ui_capture.patch
git add -A
git commit -m "ci(ui-capture): add GH Actions workflow + robust simulator picker"
git push origin <your-branch>

## Option B: 変更ファイルをZip展開で上書き
# リポジトリ直下で解凍し上書き
tar -xzf runs/last/ci_bundle.tar.gz
git add -A
git commit -m "ci(ui-capture): add GH Actions workflow + robust simulator picker"
git push origin <your-branch>

## CI実行
- GitHub → Actions → 「UI Capture」→ Run workflow（workflow_dispatch）
  もしくは main / develop へ push すれば自動実行

## 成果物
- Workflow完了後、Artifacts に `ui_captures` が出ます（Board/Weekly差分入りPNG）

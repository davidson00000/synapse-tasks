# タスクシナプスマップ・UI更新レポート（2025-09-25）

## 変更サマリ
- TaskStore: `TASKS_FORCE_SEED` / `TASKS_DISABLE_PERSISTENCE` を Release でも解釈し、CIでのシード挙動を統一
- Homeリスト空状態: デバッグシードの有無が分かる案内テキストへ更新
- scripts/ui_capture.sh: Launch引数をログ出力し、Release指定でも動くように改修
- UIキャプチャ: CoreSimulatorService がサンドボックスで拒否され実行失敗（要ローカル再実行）

## スクリーンショット（最新）
ローカル環境でCoreSimulatorが使用できない場合は、GitHub Actionsの **UI Capture** ワークフローを実行してください。  
成果物は `ui_captures` アーティファクトとして保存されます（`build/ui/*.png` も同梱）。

## 次アクション（提案）
1. CoreSimulatorService を再起動し、`scripts/ui_capture.sh` を実行して最新差分を取得
2. Board: ドラッグ＆ドロップで列移動
3. Weekly: 週送り/日付ピッカー

# UI Capture on CI
- This repo contains a GitHub Actions workflow `.github/workflows/ui-capture.yml`.
- It runs on `macos-15`, boots an iOS Simulator, builds the app, launches with env:
  - TASKS_FORCE_SEED=1
  - TASKS_DISABLE_PERSISTENCE=1
  - TASKS_SCREENSHOT_TAB=list/board/weekly (per script)
  - TASKS_SELECTED_WEEKDAY=3
- The resulting images are uploaded as the `ui_captures` artifact.

## How to run
1. Push to `main` or `develop`, or trigger `workflow_dispatch` manually.
2. Download artifacts from the workflow run page.

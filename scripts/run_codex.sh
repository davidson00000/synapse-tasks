#!/usr/bin/env bash
set -euo pipefail

CONFIG=${1:-codex.yaml}
mkdir -p runs/last

echo ">>> Running CODEX with $CONFIG"

# feedback_file（yq→awk フォールバック）
if command -v yq >/dev/null 2>&1; then
  FEEDBACK_FILE=$(yq -r '.inputs.feedback_file // "feedback/todo.md"' "$CONFIG")
else
  FEEDBACK_FILE=$(awk '$1 ~ /feedback_file:/{sub(/^[ \t]*feedback_file:[ \t]*/,""); print; exit}' "$CONFIG")
  FEEDBACK_FILE=${FEEDBACK_FILE:-feedback/todo.md}
fi

# steps 抽出
STEPS_FILE=$(mktemp)
trap 'rm -f "$STEPS_FILE"' EXIT

if command -v yq >/dev/null 2>&1; then
  yq -r '.steps[].id' "$CONFIG" > "$STEPS_FILE"
else
  awk '/^[ \t]*-[ \t]*id:[ \t]*/{sub(/.*id:[ \t]*/,""); print}' "$CONFIG" > "$STEPS_FILE"
fi

while IFS= read -r step || [ -n "$step" ]; do
  [ -z "$step" ] && continue
  echo "Step: $step"
  case "$step" in
    plan)
      {
        echo "# PLAN"
        echo "feedback: $FEEDBACK_FILE"
        date +"generated: %F %T"
      } > runs/last/plan.md
      ;;
    impl)
      echo "- impl: placeholder" >> runs/last/plan.md
      ;;
    build)
      : "${UDID:?ERROR: export UDID=<your-udid>}"
      make build
      ;;
    test)
      : "${UDID:?ERROR: export UDID=<your-udid>}"
      make test
      ;;
    ui-capture)
      : "${UDID:?ERROR: export UDID=<your-udid>}"
      make uishot || { echo "WARN: ui-capture failed; continue"; }
      ;;
    report)
      {
        echo "# CODEX Report"
        echo "- plan: runs/last/plan.md"
        echo "- feedback: $FEEDBACK_FILE"
        [ -d ui_captures ] && echo "- latest shots: $(ls -1 ui_captures | tail -n 1)" || true
        date +"generated: %F %T"
      } > runs/last/report.md
      ;;
    commit)
      echo "Commit placeholder" >> runs/last/report.md
      ;;
    *)
      echo "(no-op: $step)"
      ;;
  esac
done < "$STEPS_FILE"

echo ">>> Done. See runs/last/plan.md and runs/last/report.md"


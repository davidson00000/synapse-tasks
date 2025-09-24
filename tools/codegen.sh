#!/usr/bin/env bash
set -e
SPEC="$1"

# ここに CODEX の自動生成処理を後で差し替える。
# いまは雛形フォルダとメモを出すだけのダミー。
mkdir -p App Model Features/ListUI Features/Graph Shared

# 生成の痕跡（差分）を作ってCIのpushを確認
echo "// generated from $SPEC at $(date)" >> Generated.md

# 最小のダミーSwift（あとで上書きされる想定）
if [ ! -f App/Placeholder.swift ]; then
cat > App/Placeholder.swift <<'SWIFT'
import Foundation
// Placeholder file. Will be replaced by CODEX outputs.
SWIFT
fi

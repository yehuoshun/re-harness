#!/usr/bin/env bash
# 把分析产物推到私有库 re-results（绝不推原始二进制）
set -euo pipefail

TARGET_REPO="${RESULTS_REPO:-yehuoshun/re-results}"
OUT="${OUT_DIR:?}"
NAME="${BINARY_NAME:-target}"
RUN="${GITHUB_RUN_NUMBER:-0}"
DIR_NAME="${RUN}-${NAME}"

if [ -z "${RE_PUSH_TOKEN:-}" ]; then
  echo "⚠️ 无 RE_PUSH_TOKEN，跳过推送（产物只留在 runner，随 job 销毁）"
  exit 0
fi

WORK=/tmp/re-results
rm -rf "$WORK"
git clone --depth 1 "https://x-access-token:${RE_PUSH_TOKEN}@github.com/${TARGET_REPO}.git" "$WORK"

DEST="$WORK/$DIR_NAME"
mkdir -p "$DEST"
cp -r "$OUT"/. "$DEST"/
# 原始二进制绝不入库
rm -f "$DEST"/*.bin "$DEST"/*.exe "$DEST"/*.dll "$DEST"/smoke_target 2>/dev/null || true

cat > "$DEST/meta.json" <<EOF
{
  "run_url": "${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-0}",
  "run_number": ${RUN},
  "mode": "${MODE:-}",
  "binary_name": "${NAME}",
  "binary_sha256": "$(cat "${TARGET:-/dev/null}.sha256" 2>/dev/null | awk '{print $1}')",
  "ghidra_version": "${GHIDRA_VERSION:-}",
  "maxmem": "${MAXMEM:-}",
  "max_functions": "${MAX_FUNCTIONS:-}",
  "runner": "$(nproc) vCPU / $(free -g | awk '/^Mem:/{print $2}') GB RAM",
  "git_sha": "${GITHUB_SHA:-}",
  "created_at": "$(date -u +%FT%TZ)"
}
EOF

cd "$WORK"
git config user.name "re-harness-bot"
git config user.email "yehuoshun@users.noreply.github.com"
git add -A
if git diff --cached --quiet; then
  echo "无变更可推"
  exit 0
fi
git commit -q -m "results: run #${RUN} ${NAME} (${MODE:-})"
git push -q origin HEAD:main
echo "✅ 已推送 → ${TARGET_REPO}/${DIR_NAME}"

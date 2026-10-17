#!/usr/bin/env bash
# Ghidra headless 反编译 + 字符串抽取
set -euo pipefail

AD="${GHIDRA_DIR:?}/support/analyzeHeadless"
[ -x "$AD" ] || { echo "analyzeHeadless 不可执行: $AD"; exit 1; }

OUT="${OUT_DIR:?}"
PROJ="${PROJECT_DIR:?}"
TARGET="${TARGET:?}"
MAXF="${MAX_FUNCTIONS:-50}"
MAXMEM="${MAXMEM:-4g}"

mkdir -p "$OUT" "$PROJ"

# 双保险封顶 JVM 堆（Ghidra launch.sh 读 MAXMEM，JAVA_TOOL_OPTIONS 兜底）
export MAXMEM
export JAVA_TOOL_OPTIONS="-Xmx${MAXMEM} -XX:+UseSerialGC"

echo "== analyzeHeadless 开始（MAXMEM=$MAXMEM, max_functions=$MAXF）=="
set +e
"$AD" "$PROJ" re \
  -import "$TARGET" \
  -scriptPath "$GITHUB_WORKSPACE/ghidra_scripts" \
  -postScript DumpDecomp.java "$OUT" "$MAXF" \
  -analysisTimeoutPerFile 900 \
  -deleteProject 2>&1 | tee "$OUT/analyze.log"
RC=${PIPESTATUS[0]}
set -e
echo "== analyzeHeadless 退出码: $RC =="

strings -n 6 -a "$TARGET" 2>/dev/null | head -3000 > "$OUT/strings.txt" || true

ls -la "$OUT"
# 脚本自身出错但分析完成时不算致命；只有产物全无才失败
[ -s "$OUT/summary.txt" ] || { echo "❌ 未生成 summary.txt"; exit 1; }
echo "✅ 产物就绪"

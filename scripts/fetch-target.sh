#!/usr/bin/env bash
# 取目标物：
#   smoke   = 现场编译一个带符号的小 ELF
#   analyze = 下载 binary_url
#   in-repo = 从 samples 分支取老板手动上传的样本
set -euo pipefail

MODE="${MODE:?}"
TARGET="${TARGET:?目标路径未设置}"
PROXY="${GH_PROXY:-https://gh-proxy.com/}"
SAMPLE_PATH="${SAMPLE_PATH:-}"

mkdir -p "$(dirname "$TARGET")"

case "$MODE" in
  smoke)
    echo "== smoke：编译测试二进制（自有产物，无版权问题）=="
    cat > /tmp/smoke_target.c <<'EOF'
#include <stdio.h>
#include <string.h>
static int checksum(const char *s) {
    int h = 5381;
    while (*s) h = ((h << 5) + h) ^ (unsigned char)*s++;
    return h;
}
int verify_license(const char *key) {
    if (!key) return 0;
    if (strlen(key) != 19) return 0;
    return checksum(key) == 1234567;
}
int main(int argc, char **argv) {
    if (argc < 2) { puts("usage: smoke <key>"); return 1; }
    printf("checksum=%d valid=%d\n", checksum(argv[1]), verify_license(argv[1]));
    return 0;
}
EOF
    gcc -O1 -g -o "$TARGET" /tmp/smoke_target.c
    ;;

  analyze)
    echo "== analyze：下载 $BINARY_URL =="
    [ -n "${BINARY_URL:-}" ] || { echo "analyze 模式必须给 binary_url"; exit 1; }
    if ! curl -fL --max-time 600 --retry 2 -o "$TARGET" "$BINARY_URL"; then
      echo "  直连失败 → ${PROXY}${BINARY_URL}"
      curl -fL --max-time 900 --retry 3 -o "$TARGET" "${PROXY}${BINARY_URL}"
    fi
    ;;

  in-repo)
    echo "== in-repo：从 samples 分支取样本 =="
    git fetch --depth=1 origin samples
    if [ -z "$SAMPLE_PATH" ]; then
      SAMPLES=$(git ls-tree -r --name-only origin/samples | grep -vE '(^|/)\.(gitkeep|gitignore|README)' || true)
      COUNT=$(echo "$SAMPLES" | grep -c . || true)
      echo "  samples 分支文件: ${COUNT} 个"
      echo "$SAMPLES" | sed 's/^/    /'
      [ "$COUNT" = "1" ] || { echo "❌ 样本必须恰好 1 个（当前 $COUNT）——请清空 samples 分支后重新上传"; exit 1; }
      SAMPLE_PATH="$SAMPLES"
    fi
    git show "origin/samples:${SAMPLE_PATH}" > "$TARGET"
    echo "  样本: ${SAMPLE_PATH}"
    ;;

  *)
    echo "未知 mode: $MODE"; exit 1 ;;
esac

file "$TARGET" || true
ls -lh "$TARGET"
sha256sum "$TARGET" | tee "$TARGET.sha256"

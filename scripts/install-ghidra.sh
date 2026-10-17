#!/usr/bin/env bash
# 下载并解包 Ghidra 到 $GHIDRA_DIR（被 actions/cache 缓存，命中即跳过）
set -euo pipefail

V="${GHIDRA_VERSION:?GHIDRA_VERSION 未设置}"
DEST="${GHIDRA_DIR:?GHIDRA_DIR 未设置}"
PROXY="${GH_PROXY:-https://gh-proxy.com/}"

mkdir -p "$(dirname "$DEST")"
cd "$(dirname "$DEST")"

echo "== 查询 ghidra_${V}_PUBLIC 资产 =="
ASSET=$(curl -sSL --max-time 60 \
  "https://api.github.com/repos/NationalSecurityAgency/ghidra/releases?per_page=100" \
  | python3 -c "
import json,sys,re
v='${V}'
try:
    rel=json.load(sys.stdin)
except Exception as e:
    sys.exit('API 解析失败: %s' % e)
for r in rel:
    for a in r.get('assets',[]):
        if re.match(r'^ghidra_%s_PUBLIC_.*\.zip$' % re.escape(v), a['name']):
            print('%s\t%s' % (a['name'], a['browser_download_url'])); sys.exit(0)
sys.exit('未找到 ghidra_%s_PUBLIC_*.zip' % v)
" )
NAME=$(echo "$ASSET" | cut -f1)
URL=$(echo "$ASSET" | cut -f2)
echo "  asset: $NAME"

echo "== 下载（先直连，失败走 gh-proxy）=="
if ! curl -fL --max-time 600 --retry 2 -o "$NAME" "$URL"; then
  echo "  直连失败 → ${PROXY}${URL}"
  curl -fL --max-time 900 --retry 3 -o "$NAME" "${PROXY}${URL}"
fi
ls -lh "$NAME"

command -v unzip >/dev/null || sudo apt-get install -y -qq unzip
unzip -q "$NAME" -d .
rm -f "$NAME"
EXTRACTED=$(find . -maxdepth 1 -type d -name 'ghidra_*_PUBLIC' | head -1)
[ -n "$EXTRACTED" ] || { echo "解包后找不到目录"; exit 1; }
chmod +x "$EXTRACTED"/support/*.sh "$EXTRACTED"/support/analyzeHeadless 2>/dev/null || true
rm -rf "$DEST"
mv "$EXTRACTED" "$DEST"
echo "== Ghidra 就位: $DEST =="
"$DEST"/support/analyzeHeadless 2>&1 | head -3 || true

#!/usr/bin/env bash
# 分析成功后清掉样本：删除 samples 分支 → 重建一个空的 samples 分支（供下次上传）
#
# 为什么要删分支而不是删文件：样本 commit 一次就成了历史，删文件只是再叠一个 commit，
# 旧 commit 里文件还在。删掉整个 ref 后那些对象成孤儿，GitHub GC 后彻底消失。
set -euo pipefail

REPO="${GITHUB_REPOSITORY:?}"
TOKEN="${GITHUB_TOKEN:?}"

echo "== 清样本：删除 samples 分支 =="
git push "https://x-access-token:${TOKEN}@github.com/${REPO}.git" --delete samples 2>&1 | tail -3 || echo "（分支已不存在，跳过）"

echo "== 重建空 samples 分支 =="
TMP=$(mktemp -d)
cd "$TMP"
git init -q
git checkout -q --orphan samples
git -c user.name="re-harness-bot" -c user.email="yehuoshun@users.noreply.github.com" \
    commit -q --allow-empty -m "samples: 空（等待上传样本）"
git remote add origin "https://x-access-token:${TOKEN}@github.com/${REPO}.git"
git push -q origin samples
echo "✅ samples 分支已清空重建（下次可直接拖拽上传）"

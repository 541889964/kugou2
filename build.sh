#!/data/data/com.termux/files/usr/bin/bash
# 用法: bash ~/kugou/build.sh [commit信息]
set -e
cd "$HOME/kugou"

TOKEN=$(grep -oE 'ghp_[A-Za-z0-9]{20,}' /storage/emulated/0/MT2/密码.txt 2>/dev/null | head -1)
[ -z "$TOKEN" ] && { echo "✗ 找不到 token"; exit 1; }

OWNER="541889964"; REPO="kugou2"
PUSH_URL="https://${OWNER}:${TOKEN}@github.com/${OWNER}/${REPO}.git"

echo ""
echo "═══ [1/4] 提交本地改动 ═══"
git add -A
if git diff --cached --quiet; then
  echo "  没有新改动"
else
  MSG="${1:-update $(date '+%m-%d %H:%M')}"
  git -c user.name="$OWNER" -c user.email="${OWNER}@users.noreply.github.com" commit -m "$MSG"
  echo "  ✓ $MSG"
fi

echo ""
echo "═══ [2/4] 推送 ═══"
git push --force "$PUSH_URL" main
echo "  ✓ 已推送"

echo ""
echo "═══ [3/4] 等待 Actions ═══"
sleep 10

RUN_ID=""
for i in {1..20}; do
  RUN_ID=$(curl -s -H "Authorization: token $TOKEN" \
    "https://api.github.com/repos/${OWNER}/${REPO}/actions/runs?per_page=1" \
    | grep -oE '"id": ?[0-9]+' | head -1 | grep -oE '[0-9]+')
  [ -n "$RUN_ID" ] && break
  sleep 3
done
[ -z "$RUN_ID" ] && { echo "  ✗ 拿不到 run id"; exit 1; }
echo "  Run: https://github.com/${OWNER}/${REPO}/actions/runs/${RUN_ID}"
echo ""

STATUS="queued"; CONCLUSION=""
for i in {1..120}; do
  INFO=$(curl -s -H "Authorization: token $TOKEN" \
    "https://api.github.com/repos/${OWNER}/${REPO}/actions/runs/${RUN_ID}")
  STATUS=$(echo "$INFO" | grep -oE '"status": ?"[^"]+"' | head -1 | cut -d'"' -f4)
  CONCLUSION=$(echo "$INFO" | grep -oE '"conclusion": ?"[^"]+"' | head -1 | cut -d'"' -f4)
  printf "\r  状态: %-12s 结论: %-12s [%3ds] " "$STATUS" "${CONCLUSION:-—}" "$((i*5))"
  [ "$STATUS" = "completed" ] && break
  sleep 5
done
echo ""

if [ "$CONCLUSION" != "success" ]; then
  echo ""
  echo "✗ 编译失败"
  if command -v unzip >/dev/null 2>&1; then
    echo "  拉取日志…"
    curl -sL -H "Authorization: token $TOKEN" \
      "https://api.github.com/repos/${OWNER}/${REPO}/actions/runs/${RUN_ID}/logs" \
      -o /tmp/kglogs.zip
    rm -rf /tmp/kglogs && mkdir -p /tmp/kglogs && cd /tmp/kglogs
    unzip -q /tmp/kglogs.zip 2>/dev/null || true
    echo ""
    echo "── 错误摘要 ──"
    grep -rhnE "Error|error:|FAILURE|Exception" . 2>/dev/null | head -30
    echo ""
    echo "完整日志: /tmp/kglogs/"
  else
    echo "  去网页看: https://github.com/${OWNER}/${REPO}/actions/runs/${RUN_ID}"
    echo "  (想自动拉日志: pkg install unzip)"
  fi
  exit 1
fi

echo ""
echo "═══ [4/4] 下载 APK ═══"
OUT="$HOME/kugou/KuGou-$(date +%m%d-%H%M).apk"
URL="https://github.com/${OWNER}/${REPO}/releases/latest/download/KuGou.apk"
echo "  $URL"
curl -fL --progress-bar -H "Authorization: token $TOKEN" -o "$OUT" "$URL"

if [ -s "$OUT" ]; then
  SIZE=$(du -h "$OUT" | cut -f1)
  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║  ✓ 编译成功"
  echo "║  APK : $OUT"
  echo "║  大小: $SIZE"
  echo "╚══════════════════════════════════════╝"
  echo ""
  echo "安装:  termux-open $OUT"
else
  echo "✗ 下载失败"
  exit 1
fi

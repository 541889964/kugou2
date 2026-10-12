#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/kugou"

TS=$(date +%Y%m%d_%H%M%S)
mkdir -p ".backup_vip_$TS"
for f in android_native/MainActivity.kt lib/kugou.dart lib/backend_manager.dart lib/ui/terminal_page.dart; do
  [ -f "$f" ] && cp "$f" ".backup_vip_$TS/$(basename $f)"
done
echo "✓ 备份到 .backup_vip_$TS/"
echo ""

# ══════ 1) MainActivity.kt：加 platform=lite ══════
python3 <<'PY'
import io
p = "android_native/MainActivity.kt"
src = io.open(p, encoding="utf-8").read()

if 'env["platform"]' in src:
    print("✓ MainActivity.kt 已含 platform，跳过")
else:
    # 优先插在 SSL_CERT_DIR 后面
    old = '        env["SSL_CERT_DIR"] = "/system/etc/security/cacerts"\n\n        nodeProc = pb.start()'
    new = '        env["SSL_CERT_DIR"] = "/system/etc/security/cacerts"\n        env["platform"] = "lite"\n\n        nodeProc = pb.start()'
    if old in src:
        src = src.replace(old, new, 1)
        print("✓ MainActivity.kt: +env[platform]=lite")
    else:
        old2 = '        env["OPENSSL_CONF"] = "/dev/null"'
        new2 = '        env["OPENSSL_CONF"] = "/dev/null"\n        env["platform"] = "lite"'
        if old2 in src:
            src = src.replace(old2, new2, 1)
            print("✓ MainActivity.kt: +platform（兜底）")
        else:
            print("✗ MainActivity.kt 未匹配！")
            raise SystemExit(1)
    io.open(p, "w", encoding="utf-8").write(src)
PY

# ══════ 2) kugou.dart：quality=flac + priv_status ══════
python3 <<'PY'
import io
p = "lib/kugou.dart"
src = io.open(p, encoding="utf-8").read()

# 加 quality=flac
if "'quality': 'flac'" in src:
    print("✓ kugou.dart 已含 quality=flac")
else:
    variants = [
        ("final params = <String, dynamic>{'id': hash};",
         "final params = <String, dynamic>{'id': hash, 'quality': 'flac'};"),
        ("final params = <String, dynamic>{'id': hash,};",
         "final params = <String, dynamic>{'id': hash, 'quality': 'flac'};"),
    ]
    done = False
    for old, new in variants:
        if old in src:
            src = src.replace(old, new, 1)
            print("✓ kugou.dart: +quality=flac")
            done = True
            break
    if not done:
        # 正则兜底
        import re
        pat = re.compile(r"final params = <String, dynamic>\{'id': hash[^}]*\};")
        m = pat.search(src)
        if m:
            src = src[:m.start()] + "final params = <String, dynamic>{'id': hash, 'quality': 'flac'};" + src[m.end():]
            print("✓ kugou.dart: +quality=flac（正则）")
        else:
            print("⚠ kugou.dart: params 行没找到，跳过")

# priv_status 透传
old2 = "if (d['error_code'] == 20018) return {'error':'VIP_ONLY','message':'VIP 权限不足'};"
if old2 in src:
    new2 = """final ec = d['error_code'];
      if (ec == 20018) {
        return {'error':'VIP_ONLY','message':'VIP 权限不足',
                'error_code': ec, 'priv_status': d['priv_status']};
      }"""
    src = src.replace(old2, new2, 1)
    print("✓ kugou.dart: +priv_status 透传")

io.open(p, "w", encoding="utf-8").write(src)
PY

echo ""
echo "════════════ 文件状态 ════════════"
for f in \
  lib/har_analyzer.dart \
  lib/ui/har_terminal_page.dart \
  lib/ui/terminal_page.dart \
  lib/backend_manager.dart \
  lib/kugou.dart \
  android_native/MainActivity.kt; do
  if [ -f "$f" ]; then
    printf "  ✓ %-42s %s 行\n" "$f" "$(wc -l < $f)"
  else
    printf "  ✗ %-42s 缺失\n" "$f"
  fi
done

echo ""
echo "════════════ 关键改动验证 ════════════"
printf "  MainActivity  platform=lite : %s\n" "$(grep -c 'platform.*lite' android_native/MainActivity.kt || echo 0)"
printf "  kugou.dart    quality=flac  : %s\n" "$(grep -c "'quality': 'flac'" lib/kugou.dart || echo 0)"
printf "  backend_mgr   writeOnly     : %s\n" "$(grep -c 'FileMode.writeOnly' lib/backend_manager.dart || echo 0)"
printf "  backend_mgr   truncate      : %s\n" "$(grep -c 'raf0.truncate' lib/backend_manager.dart || echo 0)"
printf "  terminal_page 测试Cookie    : %s\n" "$(grep -c '_testCookie' lib/ui/terminal_page.dart || echo 0)"
printf "  har_analyzer  类            : %s\n" "$(grep -c 'class HarAnalyzer' lib/har_analyzer.dart 2>/dev/null || echo 0)"
printf "  har_terminal  类            : %s\n" "$(grep -c 'class HarTerminalPage' lib/ui/har_terminal_page.dart 2>/dev/null || echo 0)"

echo ""
echo "═════════════════════════════════════════"
echo "  ✓ 修复脚本执行完毕"
echo "  → 下一步：bash build.sh \"lite 模式 + FLAC\""
echo "═════════════════════════════════════════"

#!/data/data/com.termux/files/usr/bin/bash
set -e
cd ~/kugou
G='\033[0;32m'; C='\033[0;36m'; N='\033[0m'
ok(){ echo -e "${G}✓${N} $1"; }
say(){ echo -e "${C}▸${N} $1"; }

TOKEN=$(grep -oE 'gh[pousr]_[A-Za-z0-9]{20,}' /storage/emulated/0/MT2/密码.txt | head -1)
PUSH_URL="https://541889964:${TOKEN}@github.com/541889964/kugou2.git"

say "1/3 修改 MainActivity.kt"
python3 << 'PY'
p = 'android_native/MainActivity.kt'
s = open(p).read()

# 在 env 设置块里加 OPENSSL_CONF
old = '''        env["HOME"] = root.absolutePath
        env["TMPDIR"] = cacheDir.absolutePath'''

new = '''        env["HOME"] = root.absolutePath
        env["TMPDIR"] = cacheDir.absolutePath
        // ✅ 关键修复：OpenSSL 编译时 OPENSSLDIR 硬编码为 Termux 路径
        // App 沙箱访问不了 → 设空配置绕过
        env["OPENSSL_CONF"] = "/dev/null"
        // 证书路径（部分 node 版本会读）
        env["SSL_CERT_FILE"] = "/system/etc/security/cacerts"
        env["SSL_CERT_DIR"] = "/system/etc/security/cacerts"'''

if old in s:
    s = s.replace(old, new)
    print('✓ 加 OPENSSL_CONF 环境变量')
else:
    # 尝试宽松匹配
    import re
    if 'env["HOME"] = root.absolutePath' in s:
        s = s.replace(
            'env["HOME"] = root.absolutePath',
            '''env["HOME"] = root.absolutePath
        env["OPENSSL_CONF"] = "/dev/null"
        env["SSL_CERT_FILE"] = "/system/etc/security/cacerts"
        env["SSL_CERT_DIR"] = "/system/etc/security/cacerts"''')
        print('✓ 用宽松方式加（只找到 HOME 那行）')
    else:
        print('✗ 找不到 env 设置块')
        import sys; sys.exit(1)

open(p, 'w').write(s)

# 验证
if 'OPENSSL_CONF' in s:
    for line in s.split('\n'):
        if 'OPENSSL_CONF' in line or 'SSL_CERT' in line:
            print(f'  {line.strip()}')
PY
ok

say "2/3 推送"
git add -A
git commit -q -m "fix: OPENSSL_CONF=/dev/null 绕过 Termux OpenSSL 路径权限" || true
for i in $(seq 1 15); do
  echo "── 推送 $i/15 ──"
  git push --force "$PUSH_URL" main 2>&1 | tail -3
  if git ls-remote "$PUSH_URL" refs/heads/main 2>/dev/null | grep -q "$(git rev-parse HEAD)"; then
    echo "✓ 推送成功"; break
  fi
  sleep $((i * 3))
done
LOCAL=$(git rev-parse HEAD); REMOTE=$(git ls-remote "$PUSH_URL" refs/heads/main | cut -f1)
echo "本地: ${LOCAL:0:8}  远端: ${REMOTE:0:8}"
[ "$LOCAL" = "$REMOTE" ] && ok "✓ 一致" || echo "✗ 不一致"

say "3/3 监控编译"
echo ""
echo "════════════════════════════════════════"
echo "  监控（每 15 秒）"
echo "════════════════════════════════════════"
python3 << 'PY'
import urllib.request, json, re, time, sys
tok = re.search(r'gh[pousr]_[A-Za-z0-9]{20,}',
    open('/storage/emulated/0/MT2/密码.txt').read()).group(0)
H = {'Authorization': 'token ' + tok,
     'Accept': 'application/vnd.github+json',
     'User-Agent': 'K'}
def get(u):
    return json.loads(urllib.request.urlopen(
        urllib.request.Request(u, headers=H)).read())
run = None
for _ in range(20):
    runs = get('https://api.github.com/repos/541889964/kugou2/actions/runs?per_page=1')
    if runs['workflow_runs']:
        run = runs['workflow_runs'][0]; break
    time.sleep(3)
if not run: print('✗ 未找到'); sys.exit(1)
print(f"Run #{run['run_number']}  sha={run['head_sha'][:8]}")
last = ''
for i in range(120):
    time.sleep(15)
    r = get(f"https://api.github.com/repos/541889964/kugou2/actions/runs/{run['id']}")
    jobs = get(f"https://api.github.com/repos/541889964/kugou2/actions/runs/{run['id']}/jobs")
    parts = [f"{j['name']}={j['status']}/{j['conclusion'] or '-'}" for j in jobs['jobs']]
    line = ' '.join(parts)
    tag = f"[{i*15//60:02d}:{i*15%60:02d}]"
    print(f"  {tag} {line}" if line != last else f"  {tag}", flush=True)
    last = line
    if r['status'] == 'completed':
        print()
        if r['conclusion'] == 'success':
            print(f"  ✓ 编译成功 Run #{r['run_number']}")
            sys.exit(0)
        else:
            print(f"  ✗ 失败 ({r['conclusion']})")
            for job in jobs['jobs']:
                if job['conclusion'] == 'failure' and job['name'] == 'apk':
                    try:
                        log = urllib.request.urlopen(urllib.request.Request(
                            f"https://api.github.com/repos/541889964/kugou2/actions/jobs/{job['id']}/logs",
                            headers=H)).read().decode('utf-8', 'replace')
                        for l in log.splitlines():
                            if re.search(r'(Error:|error:|\.dart:\d+:\d+:|\.kt:\d+:)', l):
                                print(f"  {l}")
                    except: pass
            sys.exit(1)
print('✗ 超时'); sys.exit(2)
PY
RC=$?

if [ "$RC" = "0" ]; then
  URL="https://gh-proxy.com/https://github.com/541889964/kugou2/releases/latest/download/KuGou.apk"
  echo "  加速下载: $URL"
  read -p "  下载并安装？(Y/n) " yn
  yn=${yn:-Y}
  if [ "$yn" = "Y" ] || [ "$yn" = "y" ]; then
    DL="/storage/emulated/0/Download/KuGou-latest.apk"
    rm -f "$DL"
    if curl -fL --retry 3 -o "$DL" "$URL"; then
      ok "已保存 $DL ($(du -h "$DL" | cut -f1))"
      command -v termux-open >/dev/null 2>&1 && termux-open "$DL"
    fi
  fi
fi

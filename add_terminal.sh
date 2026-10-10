#!/data/data/com.termux/files/usr/bin/bash
set -e
cd ~/kugou
G='\033[0;32m'; C='\033[0;36m'; R='\033[0;31m'; N='\033[0m'
ok(){ echo -e "${G}✓${N} $1"; }
say(){ echo -e "${C}▸${N} $1"; }
err(){ echo -e "${R}✗${N} $1"; }

# 1. terminal_page.dart 检查
if [ ! -f lib/ui/terminal_page.dart ]; then
    err "lib/ui/terminal_page.dart 不存在！请先跑 all.sh"
    exit 1
fi
ok "terminal_page.dart 存在"

# 2. settings.dart 精准插入
say "修改 settings.dart"

python3 << 'PY'
p = 'lib/ui/settings.dart'
s = open(p).read()

# 已存在就不重复
if 'TerminalPage' in s:
    print('· 已有 TerminalPage 入口，跳过')
    exit(0)

# import
if "import 'terminal_page.dart';" not in s:
    if "import 'server_page.dart';" in s:
        s = s.replace("import 'server_page.dart';",
                      "import 'server_page.dart';\nimport 'terminal_page.dart';")
    else:
        # 兜底：加在最后一个 import 后面
        idx = s.rfind("import ")
        end = s.find("\n", idx)
        s = s[:end+1] + "import 'terminal_page.dart';\n" + s[end+1:]
    print('✓ 加 import')

# 定位 _label('后端与下载') 后紧跟的 _card([
key = "_label('后端与下载'),"
idx = s.find(key)
if idx < 0:
    print('✗ 未找到 后端与下载 分组')
    exit(1)

# 从 idx 往后找 "_card(["
card_idx = s.find("_card([", idx)
if card_idx < 0:
    print('✗ 未找到 后端分组 的 _card([')
    exit(1)

# 在 _card([ 后面换行处插入
insert_at = card_idx + len("_card([")
insert_block = '''
            ListTile(
              leading: const IconTile(icon: Icons.terminal,
                c1: AppTheme.p, c2: AppTheme.s),
              title: const Text('启动后端终端', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: const Text('联网下载 · 解压 · 启动（实时显示）', style: TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final ok = await Navigator.push<bool>(context,
                  MaterialPageRoute(builder: (_) => const TerminalPage()));
                if (!mounted) return;
                if (ok == true) _toast('后端已就绪');
                await _refresh();
              }),
            const Divider(height: 1),'''

s = s[:insert_at] + insert_block + s[insert_at:]
open(p,'w').write(s)
print('✓ 已插入「启动后端终端」到「后端与下载」分组顶部')
PY

# 3. 括号平衡自检
o=$(tr -cd '(' < lib/ui/settings.dart | wc -c)
c=$(tr -cd ')' < lib/ui/settings.dart | wc -c)
ob=$(tr -cd '{' < lib/ui/settings.dart | wc -c)
cb=$(tr -cd '}' < lib/ui/settings.dart | wc -c)
if [ "$o" = "$c" ] && [ "$ob" = "$cb" ]; then
    ok "括号平衡 ( $o/$c  {$ob/$cb}"
else
    err "括号不平衡！ ( $o/$c  {$ob/$cb}"
    exit 1
fi

# 4. 确认
say "确认插入位置"
grep -n "启动后端终端\|TerminalPage" lib/ui/settings.dart | head -5

# 5. 推送
say "推送"
TOKEN=$(grep -oE 'gh[pousr]_[A-Za-z0-9]{20,}' /storage/emulated/0/MT2/密码.txt | head -1)
PUSH_URL="https://541889964:${TOKEN}@github.com/541889964/kugou2.git"
git add -A
git commit -q -m "add: 设置页插入「启动后端终端」入口" || true
for i in $(seq 1 15); do
  echo "── 尝试 $i/15 ──"
  git push --force "$PUSH_URL" main 2>&1 | tail -3
  if git ls-remote "$PUSH_URL" refs/heads/main 2>/dev/null | grep -q "$(git rev-parse HEAD)"; then
    echo "✓ 推送成功"; break
  fi
  sleep $((i * 3))
done
LOCAL=$(git rev-parse HEAD); REMOTE=$(git ls-remote "$PUSH_URL" refs/heads/main | cut -f1)
echo ""
echo "本地: ${LOCAL:0:8}"
echo "远端: ${REMOTE:0:8}"
[ "$LOCAL" = "$REMOTE" ] && echo "✓ 一致" || echo "✗ 不一致"

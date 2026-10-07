import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int kAnnouncementVersion = 1;
const String kAnnouncementTitle = '欢迎使用 KuGou 音乐';
const String kAnnouncementVersionLabel = 'v19.0 · 液态玻璃重构版';

const List<Map<String, String>> kAnnouncementSections = [
  {'t': '一、视觉升级 · 液态玻璃',
   'b': '本次更新全面引入「液态玻璃」视觉体系。歌曲卡片、搜索框、底部迷你播放条均采用磨砂玻璃材质，配合动态模糊与光线折射，让背景壁纸自然透出。27 张随机艺术图标为每首歌匹配独一无二的封面，同一首歌在每次打开时保持一致，方便记忆和识别。'},
  {'t': '二、启动体验重构',
   'b': '全新启动动画采用 Logo 呼吸光晕、环形进度、渐显文字的三段式节奏。启动过程同步完成：签名配置加载、Cookie 健康检查、播放模式恢复、收藏数据同步、云端更新查询。整个流程控制在 1.5 秒以内，让你更快进入音乐世界。'},
  {'t': '三、Cookie 安全保障',
   'b': '引入「双存储 + 自动检测」机制。导入的 HAR Cookie 会同时保存到应用私有目录和外部存储 /storage/emulated/0/Music/KuGou/cookie.json。启动时优先读取外部文件（防止清数据丢失），并自动向后端发起健康探测，若检测到 token 过期会立即提示重新导入。'},
  {'t': '四、歌词系统增强',
   'b': '歌词接口新增网易云优先策略。当酷狗后端未返回歌词时，会自动从网易云音乐 API 拉取。下载歌词不再强制要求先下载音频，支持单独保存 .lrc 到音乐目录。歌词滚动增加平滑插值，不会再跳行。'},
  {'t': '五、播放体验优化',
   'b': '修复播放结束不自动切歌的问题。通过 250ms 定时器精确检测播放位置，支持顺序、随机、单曲三种循环模式。进度条实时刷新，封面统一使用本地图标加载，速度更快更省流量。'},
  {'t': '六、收藏数据安全',
   'b': '收藏的每首歌会实时写入两份存储：一份在应用私有目录，一份在外部存储 favorites.json。即使卸载重装、清空数据，只要外部文件还在，下次启动就会自动恢复完整收藏。如果你换手机，把这个文件复制到新手机相同位置，收藏也会跟着过去。'},
  {'t': '七、本地音乐扫描',
   'b': '扫描器支持 mp3、flac、m4a、ogg、wav、ape、aac 七种格式。扫描范围覆盖 Music、Download、Documents、DCIM、Android/media、kuGou、kgmusic 等目录。文件名支持「歌名 - 歌手」或「歌手 - 歌名」自动识别。'},
  {'t': '八、使用须知',
   'b': '本应用为个人学习研究项目，音乐数据来自酷狗官方服务器，需本地部署 KuGouMusicApi 后端（端口 3000 / 3001）。首次使用步骤：一、在 Termux 生成并运行后端启动脚本；二、用 Reqable 抓包导出 HAR；三、在「设置 - 账号」中导入 HAR；四、返回首页搜索播放。若概念版返回加密 .mgg，请切普通版；若普通版返回 VIP 限制（error_code 20018），请切概念版。'},
  {'t': '九、常见问题',
   'b': 'Q: 搜不到歌曲？A: 检查后端是否运行，在「设置 - 后端状态」查看在线状态。Q: 播放失败 error_code 20018？A: 这是 VIP 权限问题，切到概念版。Q: 歌词不显示？A: 网易云也偶尔找不到，可换一首歌试试。Q: 悬浮窗不显示？A: 去系统设置授予「显示在其他应用上层」权限，部分 ROM 还需在电池优化里允许后台活动。'},
  {'t': '十、未来计划',
   'b': '睡眠定时器、桌面小组件、云盘同步收藏、歌词偏移调整、均衡器、播放历史。以上功能会在后续版本陆续推出。'},
  {'t': '十一、免责声明',
   'b': '本应用仅用于 Flutter 技术学习与研究，不得用于任何商业用途。所有音乐版权归酷狗音乐及相应唱片公司所有。请勿传播、贩卖或用于违法行为。使用本应用产生的任何后果由用户自行承担。'},
  {'t': '十二、反馈与建议',
   'b': '如果你在使用过程中遇到问题，或对新功能有建议，欢迎在 GitHub 仓库提交 Issue。我们会在每个版本中持续优化。感谢你的支持，祝你听歌愉快！—— KuGou 开发团队'},
];

Future<void> showAnnouncement(BuildContext context, {bool force = false}) async {
  final sp = await SharedPreferences.getInstance();
  if (!force && sp.getInt('announcement_read_v') == kAnnouncementVersion) return;
  if (!context.mounted) return;
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'announcement',
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (_, __, ___) => const _AnnouncementDialog(),
    transitionBuilder: (_, a1, __, child) {
      final c = CurvedAnimation(parent: a1, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(c),
        child: FadeTransition(opacity: c, child: child),
      );
    },
  );
  await sp.setInt('announcement_read_v', kAnnouncementVersion);
}

class _AnnouncementDialog extends StatelessWidget {
  const _AnnouncementDialog();
  @override
  Widget build(BuildContext context) {
    return Center(child: Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1726).withOpacity(0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFF8B5CF6).withOpacity(0.35),
                      const Color(0xFF22D3EE).withOpacity(0.12),
                    ]),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF22D3EE)]),
                      ),
                      child: const Icon(Icons.campaign_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text(kAnnouncementTitle,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 3),
                      Text(kAnnouncementVersionLabel,
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7), letterSpacing: 0.8)),
                    ])),
                  ]),
                ),
                Expanded(child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (int i = 0; i < kAnnouncementSections.length; i++) ...[
                      Text(kAnnouncementSections[i]['t']!,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700,
                          color: Color(0xFF22D3EE), height: 1.5, letterSpacing: 0.3)),
                      const SizedBox(height: 7),
                      Text(kAnnouncementSections[i]['b']!,
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.86),
                          height: 1.8, letterSpacing: 0.3)),
                      if (i < kAnnouncementSections.length - 1) const SizedBox(height: 20),
                    ],
                  ]),
                )),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        backgroundColor: const Color(0xFF8B5CF6)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('我知道了',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    ));
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int kAnnouncementVersion = 1;
const String kAnnouncementTitle = 'KuGou 音乐 · 用户服务协议';
const String kAnnouncementVersionLabel = '版本 v30.0 · 生效 2026-10-10';

Future<bool> showAnnouncement(BuildContext context, {bool force = false}) async {
  final sp = await SharedPreferences.getInstance();
  if (!force && sp.getInt('announcement_read_v') == kAnnouncementVersion) return true;
  if (!context.mounted) return true;
  final r = await showDialog<bool>(
    context: context, barrierDismissible: false,
    builder: (_) => const _D());
  if (r == true) {
    await sp.setInt('announcement_read_v', kAnnouncementVersion);
    return true;
  }
  return false;
}

class _D extends StatelessWidget {
  const _D();
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF14141A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withOpacity(0.10))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08)))),
            child: Row(children: [
              Container(width: 38, height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFF472B6)])),
                child: const Icon(Icons.campaign_outlined, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(kAnnouncementTitle, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 3),
                Text(kAnnouncementVersionLabel, style: TextStyle(
                  fontSize: 10.5, color: Colors.white.withOpacity(0.5))),
              ])),
            ])),
          Flexible(child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            itemCount: kSections.length,
            itemBuilder: (_, i) => RepaintBoundary(child: _section(i)))),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08)))),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  side: BorderSide(color: Colors.white.withOpacity(0.20)),
                  foregroundColor: Colors.white.withOpacity(0.8)),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('不同意并退出'))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  backgroundColor: const Color(0xFF8B5CF6)),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('我已阅读并同意'))),
            ])),
        ]),
      ));
  }

  Widget _section(int i) {
    final s = kSections[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 22, height: 22, margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.20),
              borderRadius: BorderRadius.circular(6)),
            child: Center(child: Text(s.n,
              style: const TextStyle(fontSize: 10.5,
                fontWeight: FontWeight.w800, color: Color(0xFFB8A8FF))))),
          const SizedBox(width: 9),
          Expanded(child: Text(s.t, style: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w800,
            color: Colors.white, height: 1.4))),
        ]),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.only(left: 31),
          child: Text(s.b, style: TextStyle(
            fontSize: 12.5, color: Colors.white.withOpacity(0.80),
            height: 1.9, letterSpacing: 0.25))),
      ]));
  }
}

class _Sec {
  final String n, t, b;
  const _Sec(this.n, this.t, this.b);
}

const List<_Sec> kSections = [
  _Sec('01', '欢迎使用', '感谢你选择 KuGou 音乐。这是个人独立完成的 Flutter 跨平台音乐学习项目，旨在探索移动端音频播放、网络协议分析、UI 动效设计的整合实践。本应用开源、免费、可自由学习研究。请务必在使用前完整阅读本协议。'),
  _Sec('02', '服务性质', '本应用为非商业技术研究项目，不以营利为目的，不提供付费订阅、广告投放、增值服务或商业运营。本应用不隶属于酷狗音乐、腾讯音乐娱乐集团或其关联公司，也不代表官方立场。'),
  _Sec('03', '数据来源与版权', '本应用不存储、不制作、不分发任何音频、歌词、封面或元数据。所有音乐内容均通过本地部署的第三方开源后端从酷狗官方服务器实时获取。所有音乐作品、歌词、封面、商标等知识产权归原权利人所有。'),
  _Sec('04', '用户使用规范', '你承诺严格遵守《网络安全法》《著作权法》《个人信息保护法》《信息网络传播权保护条例》及所在地法律法规。不得利用本应用从事：传播盗版、破解 DRM、规避区域限制、批量下载、二次分发、商业传播、攻击服务器、逆向牟利等。'),
  _Sec('05', 'Cookie 凭证', '本应用通过你登录酷狗客户端后抓取的 Cookie 向后端发起请求。Cookie 存储于本机，同时备份到 /storage/emulated/0/Music/KuGou/cookie.json。不会向第三方上传、共享。有效期由酷狗官方决定。'),
  _Sec('06', '服务器共享', '本应用支持服务器配置共享功能。点击「上传共享」时，配置会以 XOR+Base64 加密后上传至 jsonblob.com 等公开存储，返回分享 ID。任何持有 ID 的人均可读取。请勿上传敏感信息。'),
  _Sec('07', '隐私保护', '本应用不收集、不上传、不分析任何个人信息。所有数据存储在本地。不含埋点统计、崩溃上报、广告、推送、第三方数据采集 SDK。你可随时通过卸载应用清除全部数据。'),
  _Sec('08', '下载内容风险', '音频下载仅面向你已合法获得播放权限的内容。下载文件的版权归原权利人所有，仅供个人欣赏、学习研究。不得公开传播、二次创作、商业化使用或上传到公开平台。'),
  _Sec('09', '第三方依赖', '本应用依赖 Flutter、just_audio、dio、provider、KuGouMusicApi、网易云音乐 API、jsonblob.com 等。上述依赖的可用性、合法性由其作者负责。若其中任何服务中止或变更，本应用不承担连带责任。'),
  _Sec('10', '免责声明', '在适用法律允许的最大范围内，本应用明确声明：不对服务连续性、安全性、准确性作担保；不对使用本应用产生的直接、间接、附带、特殊损失承担责任；不对第三方内容、第三方服务承担责任；不对不可抗力导致的服务中断承担责任。'),
  _Sec('11', '技术风险', '本应用为非官方客户端，可能因酷狗官方接口更新而失效。部分功能可能因账号权限、地区限制、服务器策略无法使用。遇到播放失败、VIP 限制、加密音频等情况，请自行判断处理。'),
  _Sec('12', '知识产权', '本应用源码采用开源许可发布，可自由学习、修改、分发。但名称、Logo、界面设计、代码注释、文档材料的著作权归原作者所有。不得用于商业宣传、应用商店上架、广告投放。'),
  _Sec('13', '未成年人条款', '若你为未满 18 周岁的未成年人，请在监护人陪同下阅读本协议，并在监护人指导下使用。监护人应对未成年人的使用行为承担监督责任。'),
  _Sec('14', '服务变更与终止', '我们保留在不预先通知的情况下随时修改、暂停、终止本应用全部或部分功能的权利。若本应用终止更新，已安装的旧版本仍可使用，但不再获得功能改进与安全修复。'),
  _Sec('15', '协议修改权', '我们有权根据法律法规、技术演进、服务调整修订本协议。协议修订后，本应用会在下次启动时重新展示完整内容。继续使用即视为接受修订。'),
  _Sec('16', '法律适用', '本协议适用中华人民共和国法律。若发生争议，应首先友好协商；协商不成，可向开发者所在地有管辖权的法院提起诉讼。'),
  _Sec('17', '特别声明', '本应用不提供任何音乐内容本身，所有音乐均来自酷狗官方服务器。不鼓励、不支持、不参与任何盗版行为。使用行为完全出于个人意愿，请自行评估合法性与风险。'),
  _Sec('18', '数据丢失风险', '本应用采取双存储机制保护收藏与配置数据。但仍有因设备故障、系统清理、误操作、存储损坏导致丢失的可能。强烈建议定期备份 /storage/emulated/0/Music/KuGou/ 目录。'),
  _Sec('19', '网络流量', '使用本应用时会消耗网络流量，包括搜索、播放、下载、歌词、服务器共享等。流量费用由运营商收取，本应用不对流量费用负责。建议在 WiFi 环境下使用。'),
  _Sec('20', '最终确认', '点击下方「我已阅读并同意」按钮，即表示你已完整阅读本协议全部条款，充分理解其中涉及的法律责任、版权声明、免责范围、隐私保护内容，并自愿接受全部约束。'),
];

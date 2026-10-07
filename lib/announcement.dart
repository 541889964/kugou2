import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int kAnnouncementVersion = 2;
const String kAnnouncementTitle = 'KuGou 音乐 · 用户服务协议';
const String kAnnouncementVersionLabel = '版本 v19.0 · 生效日期 2025-10-07';

/// 返回 true = 同意并继续；false = 拒绝并退出
Future<bool> showAnnouncement(BuildContext context, {bool force = false}) async {
  final sp = await SharedPreferences.getInstance();
  if (!force && sp.getInt('announcement_read_v') == kAnnouncementVersion) {
    return true;
  }
  if (!context.mounted) return true;

  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'agreement',
    barrierColor: Colors.black.withOpacity(0.65),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, __, ___) => const _AgreementDialog(),
    transitionBuilder: (_, a1, __, child) {
      final c = CurvedAnimation(parent: a1, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: c,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(c),
          child: child,
        ),
      );
    },
  );

  if (result == true) {
    await sp.setInt('announcement_read_v', kAnnouncementVersion);
    return true;
  }
  return false;
}

class _AgreementDialog extends StatelessWidget {
  const _AgreementDialog();
  @override
  Widget build(BuildContext context) {
    return Center(child: Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 700),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF14141A).withOpacity(0.96),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Column(children: [
                // 顶部标题栏（不用渐变，改用细线分割）
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07), width: 1)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C6CB0).withOpacity(0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.description_outlined,
                        color: Color(0xFF9C8FD0), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text(kAnnouncementTitle,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: 0.2)),
                      const SizedBox(height: 3),
                      Text(kAnnouncementVersionLabel,
                        style: TextStyle(fontSize: 10.5,
                          color: Colors.white.withOpacity(0.52), letterSpacing: 0.6)),
                    ])),
                  ]),
                ),
                // 正文
                Expanded(child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (int i = 0; i < kAgreementSections.length; i++) ...[
                      _sectionTitle(i + 1, kAgreementSections[i]['t']!),
                      const SizedBox(height: 7),
                      Text(kAgreementSections[i]['b']!,
                        style: TextStyle(
                          fontSize: 12.8,
                          color: Colors.white.withOpacity(0.82),
                          height: 1.85,
                          letterSpacing: 0.25)),
                      if (i < kAgreementSections.length - 1) const SizedBox(height: 18),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C6CB0).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF7C6CB0).withOpacity(0.24)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.info_outline, size: 15,
                          color: Color(0xFF9C8FD0)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          '点击「同意并继续」即视为您已完整阅读、充分理解并自愿接受上述全部条款。'
                          '若您不同意任一条款，请点击「不同意」退出本应用。',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75),
                            height: 1.7, letterSpacing: 0.2))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ]),
                )),
                // 底部双按钮
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07), width: 1)),
                  ),
                  child: Row(children: [
                    Expanded(child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: Colors.white.withOpacity(0.18), width: 1),
                        foregroundColor: Colors.white.withOpacity(0.78),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('不同意',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    )),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: const Color(0xFF7C6CB0),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('同意并继续',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    )),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _sectionTitle(int idx, String title) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 20, height: 20,
        margin: const EdgeInsets.only(top: 1),
        decoration: BoxDecoration(
          color: const Color(0xFF7C6CB0).withOpacity(0.15),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(child: Text('$idx',
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
            color: Color(0xFF9C8FD0)))),
      ),
      const SizedBox(width: 9),
      Expanded(child: Text(title,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
          color: Colors.white, height: 1.5, letterSpacing: 0.3))),
    ]);
  }
}

// ============================================================
//  企业级条款（20 条）
// ============================================================
const List<Map<String, String>> kAgreementSections = [
  {'t': '协议主体与适用范围',
   'b': '本《用户服务协议》（以下简称"本协议"）由 KuGou 音乐客户端（以下简称"本应用"或"我们"）与您（以下简称"用户"或"您"）就本应用的使用事宜达成。本应用为开源个人学习研究项目，源码托管于 GitHub 公开仓库。您下载、安装、启动、访问或以任何方式使用本应用，均视为已阅读、理解并同意接受本协议全部条款的约束。若您不同意本协议任何内容，请立即停止使用并卸载本应用。'},

  {'t': '服务性质与法律定位',
   'b': '本应用属于非商业性质的个人技术学习项目，仅用于 Flutter 跨平台开发、网络协议分析、音频播放技术的研究与教学目的。本应用不以营利为目的，不提供任何形式的付费服务、广告投放、用户付费、增值订阅或商业运营活动。本应用源代码公开、免费、可自由学习研究，但不得用于任何商业用途、二次售卖、捆绑分发或规避法律监管的行为。'},

  {'t': '数据来源与版权声明',
   'b': '本应用自身不存储、不制作、不分发任何音频内容。所有音乐元数据、歌词、播放地址均通过本地部署的第三方开源后端（KuGouMusicApi）从酷狗音乐官方服务器实时获取。所有音乐作品、歌词文本、专辑封面、商标标识等知识产权均归酷狗音乐、腾讯音乐娱乐集团及其关联唱片公司、词曲作者、表演者所有。本应用仅作为技术演示，不主张对上述任何内容享有权利。'},

  {'t': '用户使用规范',
   'b': '您承诺在使用本应用过程中严格遵守《中华人民共和国网络安全法》《中华人民共和国著作权法》《中华人民共和国个人信息保护法》《信息网络传播权保护条例》及您所在地区的一切适用法律法规。您不得利用本应用从事任何违法违规行为，包括但不限于：传播盗版内容、破解数字版权保护（DRM）、规避区域限制、批量下载、二次分发、商业传播、恶意攻击服务器、逆向工程牟利等。'},

  {'t': '账号凭证（Cookie）说明',
   'b': '本应用通过您在官方客户端登录后抓取的 Cookie（含 token、userid、dfid、mid 等字段）向后端发起请求。Cookie 存储于您本机设备，且同时保存至外部存储 /storage/emulated/0/Music/KuGou/cookie.json 以防数据丢失。我们不会以任何形式向第三方服务器上传、同步、共享您的 Cookie。Cookie 仅用于本地请求，其有效期由酷狗官方服务器决定。若检测到 Cookie 失效，本应用会提示您重新导入。'},

  {'t': '本地数据与隐私保护',
   'b': '本应用不收集、不上传、不分析任何用户个人信息。所有数据（收藏列表、播放历史、下载记录、配置项）均存储在您设备的应用私有目录与外部存储目录中。本应用不含任何埋点统计 SDK、崩溃上报 SDK、广告 SDK、推送 SDK 或第三方数据采集组件。您可以随时通过卸载应用或删除对应文件来清除全部数据。'},

  {'t': '下载内容与版权风险',
   'b': '本应用提供"下载音频到本地"的功能，该功能仅面向您已合法获得播放权限的内容。您下载的所有音频文件版权仍归原权利人所有，您仅可为个人欣赏、学习研究之目的在您自己的设备上使用。您不得将下载的内容用于任何形式的公开传播、二次创作、商业化使用或上传至任何公开平台。若您因下载、复制、传播行为侵犯他人合法权益，一切法律责任由您自行承担。'},

  {'t': '第三方服务与开源依赖',
   'b': '本应用依赖多个开源项目与第三方服务，包括但不限于：Flutter（Google 开源）、just_audio、dio、provider、KuGouMusicApi（MakcRe 开源）、网易云音乐 API 等。上述依赖的可用性、稳定性、合法性由其各自作者负责，与本应用无关。若其中任何服务因政策调整、服务器变更、接口失效、法律约束而中止或变更，本应用不承担任何连带责任。'},

  {'t': '免责声明的完整范围',
   'b': '在适用法律允许的最大范围内，本应用及其作者、贡献者、分发者明确声明：一、不对服务的连续性、及时性、安全性、准确性作任何明示或默示担保；二、不对因使用或无法使用本应用而产生的任何直接、间接、附带、特殊、惩罚性、后果性损失承担责任，包括但不限于利润损失、数据丢失、设备损坏、业务中断；三、不对第三方内容、第三方链接、第三方服务承担任何责任；四、不对因不可抗力（自然灾害、网络中断、政策变更、法律调整）导致的服务中断承担责任。'},

  {'t': '技术风险提示',
   'b': '本应用为非官方客户端，可能因酷狗官方接口更新而随时失效、报错或功能异常。部分功能（如概念版 VIP 播放、加密音频解码、高清音质获取）可能因账号权限、地区限制、服务器策略而无法使用。本应用不对上述情形作出任何可用性承诺。您在遇到播放失败、error_code 20018、加密 .mgg 等错误时，应自行判断切换模式、更换歌曲或停止使用。'},

  {'t': '知识产权归属',
   'b': '本应用源代码采用开源许可发布，您可在许可范围内自由使用、学习、修改、分发。但本应用名称、Logo、界面设计、代码注释、文档材料的著作权归原作者所有。未经许可，不得将本应用的整体或部分用于商业宣传、产品包装、应用商店上架、广告投放。任何对本应用源码的修改、再分发行为均须保留原始版权声明与开源许可协议。'},

  {'t': '未成年人条款',
   'b': '若您为未满 18 周岁的未成年人，请在监护人陪同下阅读本协议，并在监护人指导下使用本应用。监护人应对未成年人的使用行为承担相应监督责任。本应用不会主动收集未成年人信息，但不对未成年人因使用本应用产生的法律后果承担责任。'},

  {'t': '服务变更与终止',
   'b': '我们保留在不预先通知的情况下，随时修改、暂停、终止本应用全部或部分功能的权利。包括但不限于：新增或删除功能、调整用户界面、修改数据存储位置、变更依赖库、停止开源维护。若本应用终止更新，已安装的旧版本仍可继续使用，但不再获得功能改进与安全修复。'},

  {'t': '协议修改权',
   'b': '我们有权根据法律法规变化、技术演进、服务调整需要，随时修订本协议条款。协议修订后，本应用会在下次启动时重新展示完整内容。您继续使用本应用即视为接受修订后的协议；若您不接受修订内容，请立即停止使用并卸载本应用。'},

  {'t': '法律适用与争议解决',
   'b': '本协议的订立、效力、解释、履行与争议解决均适用中华人民共和国法律。若您与本应用之间发生任何争议，应首先友好协商解决；协商不成的，任何一方均可向本应用开发者所在地有管辖权的人民法院提起诉讼。若本协议任何条款被认定为无效或不可执行，不影响其他条款的效力。'},

  {'t': '特别声明',
   'b': '再次强调：本应用不提供任何音乐内容本身，所有音乐均来自酷狗音乐官方服务器。本应用不鼓励、不支持、不参与任何形式的盗版行为。您使用本应用的行为完全出于您个人意愿，您应自行评估使用行为的合法性与风险。若您所在地区禁止此类应用，请立即卸载并停止使用。'},

  {'t': '数据丢失风险',
   'b': '尽管本应用采取"双存储"机制保护您的收藏与配置数据（应用私有目录 + 外部存储 /storage/emulated/0/Music/KuGou/），但仍有因设备故障、系统清理、误操作、存储损坏、应用卸载导致的丢失可能。我们强烈建议您定期将 favorites.json、cookie.json 备份到其他位置。本应用不对任何数据丢失承担责任。'},

  {'t': '网络流量与费用',
   'b': '使用本应用时会消耗您的网络流量，包括搜索请求、播放音频流、下载音频、获取歌词等。具体流量取决于您的使用频率、音质选择、下载内容大小。流量费用由您的运营商按套餐标准收取，本应用不对流量费用负责。建议在 WiFi 环境下使用，尤其在下载大文件时。'},

  {'t': '技术交流与反馈',
   'b': '本应用为开源项目，欢迎技术交流、问题反馈、代码贡献。您可通过 GitHub 仓库提交 Issue 或 Pull Request。我们对反馈内容的采用、处理时间、修改方式拥有自主决定权。您提交的代码贡献默认同意以开源许可方式授权本应用使用。'},

  {'t': '最终确认',
   'b': '您点击下方「同意并继续」按钮，即表示您已完整阅读本协议全部 20 条条款，充分理解其中涉及的法律责任、版权声明、免责范围、隐私保护内容，并自愿接受本协议的全部约束。您点击「不同意」按钮，将立即退出本应用且无法使用任何功能。请在充分理解上述条款后再作出选择。'},
];

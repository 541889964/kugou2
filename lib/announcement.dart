import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int kAnnouncementVersion = 3;
const String kAnnouncementTitle = 'KuGou 音乐 · 用户服务协议与软件说明';
const String kAnnouncementVersionLabel = '版本 v6.0 · 生效 2026-10-10';

Future<bool> showAnnouncement(BuildContext context, {bool force = false}) async {
  final sp = await SharedPreferences.getInstance();
  if (!force && sp.getInt('announcement_read_v') == kAnnouncementVersion) return true;
  if (!context.mounted) return true;
  final r = await showDialog<bool>(
    context: context, barrierDismissible: false,
    builder: (_) => const _D());
  if (r == true) { await sp.setInt('announcement_read_v', kAnnouncementVersion); return true; }
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
                  fontSize: 10.5, color: Colors.white.withOpacity(0.5), letterSpacing: 0.5)),
              ])),
            ])),
          // 关键：ListView.builder 分帧渲染，不卡
          Flexible(child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            itemCount: kSections.length,
            itemBuilder: (_, i) => RepaintBoundary(child: _section(i)),
          )),
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
                child: const Text('不同意并退出',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  backgroundColor: const Color(0xFF8B5CF6)),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('我已阅读并同意',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)))),
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
          Container(width: 22, height: 22,
            margin: const EdgeInsets.only(top: 1),
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
  _Sec('01', '欢迎使用 KuGou 音乐', '感谢你选择 KuGou 音乐。这是一个由个人开发者独立完成的 Flutter 跨平台音乐学习项目，旨在探索移动端音频播放、网络协议分析、UI 动效设计的整合实践。本应用采用开源协议发布，源代码托管于 GitHub 公共仓库，任何人均可自由查阅、学习、修改与二次开发。本协议旨在明确你（用户）与本应用（开发者）之间的权利义务关系，请你务必在使用前完整阅读。'),
  _Sec('02', '服务性质与法律定位', '本应用是非商业性质的技术研究项目，不以营利为目的，不提供任何形式的付费订阅、广告投放、增值服务或商业运营。所有功能均免费开放，源码可自由学习研究。本应用不隶属于酷狗音乐、腾讯音乐娱乐集团或其关联公司，也不代表官方立场。使用本应用不代表你与酷狗音乐建立了任何形式的服务关系。'),
  _Sec('03', '数据来源与版权归属', '本应用自身不存储、不制作、不分发任何音频、歌词、封面或元数据。所有音乐内容均通过本地部署的第三方开源后端（KuGouMusicApi）从酷狗官方服务器实时获取。所有音乐作品、歌词文本、专辑封面、商标标识、艺人形象等知识产权归酷狗音乐、腾讯音乐娱乐集团、原始唱片公司、词曲作者、表演者所有。本应用仅作为技术演示，不主张对上述任何内容享有权利。'),
  _Sec('04', '用户使用规范', '你承诺在使用本应用过程中严格遵守《中华人民共和国网络安全法》《中华人民共和国著作权法》《中华人民共和国个人信息保护法》《信息网络传播权保护条例》《计算机软件保护条例》及你所在地区的一切适用法律法规。你不得利用本应用从事任何违法违规行为，包括但不限于：传播盗版内容、破解数字版权保护（DRM）、规避区域限制、批量下载、二次分发、商业传播、恶意攻击服务器、逆向工程牟利、利用自动化脚本刷取内容等。'),
  _Sec('05', '账号凭证（Cookie）说明', '本应用通过你在酷狗官方客户端登录后抓取的 Cookie（含 token、userid、dfid、mid、uuid、appid、clientver、kg_fake 等字段）向后端发起请求。Cookie 存储于你本机设备，同时保存至外部存储 /storage/emulated/0/Music/KuGou/cookie.json 以防数据丢失。我们不会以任何形式向第三方服务器上传、同步、共享你的 Cookie。Cookie 仅用于本地请求，有效期由酷狗官方服务器决定。若检测到 Cookie 失效，本应用会提示你重新导入。'),
  _Sec('06', '服务器配置与分享说明', '本应用提供「服务器配置共享」功能。当你在「设置 - 服务器共享」中填写后端地址、用户名、密码后点击「上传共享」，本应用会将这三项信息以 XOR+Base64 加密形式上传至公开的第三方存储服务（jsonblob.com / dpaste / npoint / jsonbin / pastebin 任选其一），系统返回一串随机分享 ID。任何持有该 ID 的人均可读取上述信息。请勿上传敏感信息；若你的密码与其它服务相同，请先修改后再使用本功能。本应用不对第三方存储服务的可用性、持久性、隐私性承担任何责任。'),
  _Sec('07', '本地数据与隐私保护', '本应用不收集、不上传、不分析任何用户个人信息。所有数据（收藏、播放历史、下载记录、配置项、服务器凭据、壁纸偏好、搜索来源偏好）均存储在你设备的应用私有目录与 /storage/emulated/0/Music/KuGou/ 目录。本应用不含任何埋点统计 SDK、崩溃上报 SDK、广告 SDK、推送 SDK 或第三方数据采集组件。你可以随时通过卸载应用或删除对应文件清除全部数据。'),
  _Sec('08', '下载内容与版权风险', '本应用提供「下载音频到本地」的功能，该功能仅面向你已合法获得播放权限的内容。你下载的所有音频文件版权仍归原权利人所有，你仅可为个人欣赏、学习研究之目的在你自己的设备上使用。你不得将下载内容用于任何形式的公开传播、二次创作、商业化使用或上传至任何公开平台。若你因下载、复制、传播行为侵犯他人合法权益，一切法律责任由你自行承担。'),
  _Sec('09', '第三方服务与开源依赖', '本应用依赖多个开源项目与第三方服务，包括但不限于：Flutter（Google 开源）、just_audio、dio、provider、KuGouMusicApi（MakcRe 开源）、网易云音乐 API、jsonblob.com、dpaste.com、npoint.io、jsonbin.io、pastebin.com 等。上述依赖的可用性、稳定性、合法性由其各自作者负责，与本应用无关。若其中任何服务因政策调整、服务器变更、接口失效、法律约束而中止或变更，本应用不承担任何连带责任。'),
  _Sec('10', '免责声明的完整范围', '在适用法律允许的最大范围内，本应用及其作者、贡献者、分发者明确声明：一、不对服务的连续性、及时性、安全性、准确性作任何明示或默示担保；二、不对因使用或无法使用本应用而产生的任何直接、间接、附带、特殊、惩罚性、后果性损失承担责任，包括但不限于利润损失、数据丢失、设备损坏、业务中断；三、不对第三方内容、第三方链接、第三方服务承担任何责任；四、不对因不可抗力（自然灾害、网络中断、政策变更、法律调整）导致的服务中断承担责任。'),
  _Sec('11', '技术风险提示', '本应用为非官方客户端，可能因酷狗官方接口更新而随时失效、报错或功能异常。部分功能（如概念版 VIP 播放、加密音频解码、高清音质获取）可能因账号权限、地区限制、服务器策略而无法使用。本应用不对上述情形作出任何可用性承诺。你在遇到播放失败、error_code 20018、加密 .mgg 等错误时，应自行判断切换模式、更换歌曲或停止使用。'),
  _Sec('12', '知识产权归属', '本应用源代码采用开源许可发布，你可在许可范围内自由使用、学习、修改、分发。但本应用名称、Logo、界面设计、代码注释、文档材料的著作权归原作者所有。未经许可，不得将本应用的整体或部分用于商业宣传、产品包装、应用商店上架、广告投放。任何对本应用源码的修改、再分发行为均须保留原始版权声明与开源许可协议。'),
  _Sec('13', '未成年人条款', '若你为未满 18 周岁的未成年人，请在监护人陪同下阅读本协议，并在监护人指导下使用本应用。监护人应对未成年人的使用行为承担相应监督责任。本应用不会主动收集未成年人信息，但不对未成年人因使用本应用产生的法律后果承担责任。若你为监护人且发现未成年人未经允许使用本应用，请立即卸载并教育。'),
  _Sec('14', '服务变更与终止', '我们保留在不预先通知的情况下，随时修改、暂停、终止本应用全部或部分功能的权利。包括但不限于：新增或删除功能、调整用户界面、修改数据存储位置、变更依赖库、停止开源维护。若本应用终止更新，已安装的旧版本仍可继续使用，但不再获得功能改进与安全修复。'),
  _Sec('15', '协议修改权', '我们有权根据法律法规变化、技术演进、服务调整需要，随时修订本协议条款。协议修订后，本应用会在下次启动时重新展示完整内容。你继续使用本应用即视为接受修订后的协议；若你不接受修订内容，请立即停止使用并卸载本应用。'),
  _Sec('16', '法律适用与争议解决', '本协议的订立、效力、解释、履行与争议解决均适用中华人民共和国法律。若你与本应用之间发生任何争议，应首先友好协商解决；协商不成的，任何一方均可向本应用开发者所在地有管辖权的人民法院提起诉讼。若本协议任何条款被认定为无效或不可执行，不影响其他条款的效力。'),
  _Sec('17', '特别声明', '再次强调：本应用不提供任何音乐内容本身，所有音乐均来自酷狗音乐官方服务器。本应用不鼓励、不支持、不参与任何形式的盗版行为。你使用本应用的行为完全出于你个人意愿，你应自行评估使用行为的合法性与风险。若你所在地区禁止此类应用，请立即卸载并停止使用。'),
  _Sec('18', '数据丢失风险', '尽管本应用采取「双存储」机制保护你的收藏与配置数据（应用私有目录 + 外部存储 /storage/emulated/0/Music/KuGou/），但仍有因设备故障、系统清理、误操作、存储损坏、应用卸载导致的丢失可能。我们强烈建议你定期将 favorites.json、cookie.json、server.json 备份到其他位置。本应用不对任何数据丢失承担责任。'),
  _Sec('19', '网络流量与费用', '使用本应用时会消耗你的网络流量，包括搜索请求、播放音频流、下载音频、获取歌词、上传/下载服务器配置等。具体流量取决于你的使用频率、音质选择、下载内容大小。流量费用由你的运营商按套餐标准收取，本应用不对流量费用负责。建议在 WiFi 环境下使用，尤其在下载大文件时。'),
  _Sec('20', '技术交流与反馈', '本应用为开源项目，欢迎技术交流、问题反馈、代码贡献。你可通过 GitHub 仓库提交 Issue 或 Pull Request。我们对反馈内容的采用、处理时间、修改方式拥有自主决定权。你提交的代码贡献默认同意以开源许可方式授权本应用使用。'),
  _Sec('21', '功能说明 · 搜索', '搜索功能支持两个来源：酷狗概念版（本地部署后端）和网易云音乐（官方公开 API）。你可在设置中切换默认来源。酷狗来源搜索精准、音源可播；网易云来源歌单丰富、榜单权威。搜索结果显示歌曲名、歌手、来源徽章。点击歌曲立即播放，长按或点击下载按钮可离线下载。'),
  _Sec('22', '功能说明 · 播放', '播放器支持顺序、随机、单曲三种循环模式。首页/本地/收藏/发现页的歌曲均可点击播放。播放时会从后端获取音频 URL 并流式播放。已下载的歌曲可直接本地播放，不消耗流量。播放页支持拖动进度条、切换上下首、收藏、下载、查看歌词。'),
  _Sec('23', '功能说明 · 歌词', '歌词优先从网易云音乐 API 获取（按歌名+歌手），失败时从酷狗概念版后端兜底。歌词支持时间轴滚动、逐行高亮。播放页底部「歌词」按钮打开歌词面板，点「下歌词」可将 .lrc 保存到 /storage/emulated/0/Music/KuGou/。'),
  _Sec('24', '功能说明 · 悬浮歌词', '悬浮歌词需要系统授予「显示在其他应用上层」权限。开启后会在屏幕底部显示当前歌词行，支持拖动位置。播放页右上角悬浮图标可开关。若部分国产 ROM 拦截，需在系统设置中单独授权。'),
  _Sec('25', '功能说明 · 收藏', '收藏的歌曲会同时保存在应用内部和 /storage/emulated/0/Music/KuGou/favorites.json。即使卸载重装或清除数据，只要外部文件存在，下次启动自动恢复完整收藏。你可以手动备份该文件到云盘或另一台设备。'),
  _Sec('26', '功能说明 · 本地音乐', '本地音乐扫描器支持 mp3、flac、m4a、ogg、wav、ape、aac 七种格式。扫描范围覆盖 Music、Download、Documents、DCIM、Android/media、kuGou、kgmusic 等目录。文件名支持「歌名 - 歌手」或「歌手 - 歌名」自动识别。'),
  _Sec('27', '功能说明 · 听歌识曲', '听歌识曲功能会录制 8 秒环境音频，加密后上传至识别服务，返回匹配歌曲信息。识别过程需要麦克风权限。识别成功后可一键在酷狗搜索并播放。识别结果仅供参考，准确率受环境噪音、音量、原曲速度影响。'),
  _Sec('28', '功能说明 · 每日推荐与榜单', '每日推荐基于网易云音乐公开 API，会依据时段和地区返回不同的推荐歌单。热歌榜、飙升榜、新歌榜、原创榜为网易云官方榜单，每日更新。点击任意歌单条目会立即在酷狗搜索同名歌曲并播放。'),
  _Sec('29', '功能说明 · 壁纸', '应用支持多张壁纸，可在「设置 - 壁纸」中预览与切换。切换后所有页面背景平滑过渡。壁纸图片存放在 assets/wallpapers/ 目录，由应用打包分发。你可以替换为自己喜欢的图片并重新编译。'),
  _Sec('30', '常见问题 · 搜索无结果', '若搜索无结果，请检查：一、KuGouMusicApi 后端是否在 Termux 中正常运行（设置 - 后端状态查看端口 3000 是否在线）；二、Cookie 是否有效（设置 - 账号查看 token 长度）；三、网络是否通畅。若使用网易云来源，请检查网络能否访问 music.163.com。'),
  _Sec('31', '常见问题 · 播放失败', '若播放失败并提示 error_code 20018，说明该歌曲为 VIP 专享，当前账号无权限。可尝试切换酷狗概念版/普通版模式，或更换歌曲。若提示「加密 .mgg」，说明概念版返回加密音频，本应用无法解码，建议换歌。'),
  _Sec('32', '常见问题 · 歌词不显示', '歌词来源优先网易云。若网易云找不到匹配歌曲，会回退到酷狗后端。若两者均失败，界面显示「暂无歌词」。你可以手动下载 .lrc 放到与音频相同目录（同名文件），播放时会自动加载。'),
  _Sec('33', '常见问题 · 悬浮歌词不显示', '悬浮歌词需要两个条件：一、系统授予「显示在其他应用上层」权限；二、部分国产 ROM 需要在「电池优化」「后台活动」中单独为 KuGou 应用放行。若仍无效，尝试在系统设置中关闭「后台限制」。'),
  _Sec('34', '常见问题 · 后端未启动', '后端未启动时搜索会返回空结果并提示「概念版未启动」。请在 Termux 中运行后端启动脚本（设置 - 后端部署中可生成）。首次运行需下载 KuGouMusicApi 源码并 npm install，耗时约 2-5 分钟。'),
  _Sec('35', '使用建议 · 首次使用流程', '一、在 Termux 中运行后端启动脚本，等待端口 3000 在线；二、用 Reqable 等抓包工具导出酷狗客户端 HAR 文件；三、在「设置 - 账号 - 导入 HAR」中选择文件；四、返回首页搜索播放。整个流程约 5 分钟即可完成。'),
  _Sec('36', '使用建议 · 数据备份', '建议定期备份 /storage/emulated/0/Music/KuGou/ 目录下的三个文件：cookie.json（登录凭证）、server.json（服务器配置）、favorites.json（收藏列表）。这三个文件包含你的全部个人数据，丢失后需重新导入/整理。'),
  _Sec('37', '使用建议 · 网络环境', '本应用需要访问：一、本机 127.0.0.1:3000（KuGouMusicApi 后端）；二、music.163.com（网易云歌词、榜单、听歌识曲）；三、jsonblob.com 等（服务器共享）。请确保网络畅通且无防火墙拦截。若使用代理，请将本机地址加入白名单。'),
  _Sec('38', '未来计划', '计划中的功能：桌面小组件、睡眠定时器、云盘同步收藏、歌词偏移调整、均衡器、播放历史、歌单导入导出、主题切换、多语言支持。以上功能会在后续版本陆续推出，具体时间取决于开发进度。'),
  _Sec('39', '致谢名单', '感谢 KuGouMusicApi（MakcRe 开源）、just_audio、dio、provider、flutter_overlay_window、cached_network_image、file_picker、permission_handler、url_launcher、record 等开源项目的作者。感谢所有在 GitHub 上提交 Issue、Pull Request 的贡献者。感谢每一位使用本应用的用户。'),
  _Sec('40', '最终确认', '你点击下方「我已阅读并同意」按钮，即表示你已完整阅读本协议全部 40 条条款，充分理解其中涉及的法律责任、版权声明、免责范围、隐私保护内容，并自愿接受本协议的全部约束。你点击「不同意并退出」按钮，将立即退出本应用且无法使用任何功能。请在充分理解上述条款后再作出选择。祝你使用愉快！'),
];

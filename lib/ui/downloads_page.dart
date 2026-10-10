import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../downloader.dart';
import 'theme.dart';
import 'glass.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});
  @override
  State<DownloadsPage> createState() => _D();
}
class _D extends State<DownloadsPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dl = context.watch<Downloader>();
    final ts = dl.tasks.values.toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
          child: Row(children: [
            const Text('下载管理', style: TextStyle(fontSize: 24,
              fontWeight: FontWeight.w900, letterSpacing: -0.4)),
            const Spacer(),
            if (ts.isNotEmpty) IconButton(
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: () => dl.clearAllDone()),
          ])),
        Expanded(child: ts.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: AppTheme.grad.withOpacity(0.3)),
                child: Icon(Icons.download_outlined, size: 52, color: Colors.white.withOpacity(0.9))),
              const SizedBox(height: 22),
              const Text('还没有下载', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('保存位置：/storage/emulated/0/Music/KuGou/',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35))),
            ]))
          : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            itemCount: ts.length, itemBuilder: (_, i) => _card(ts[i]))),
      ])),
    );
  }

  Widget _card(DownloadTask t) {
    Color c; IconData ic; String s;
    switch (t.status) {
      case 'resolving': c = Colors.amber; ic = Icons.search; s = '获取链接…'; break;
      case 'downloading': c = AppTheme.p; ic = Icons.downloading; s = '${(t.progress*100).toStringAsFixed(0)}%'; break;
      case 'done': c = AppTheme.s; ic = Icons.check_circle; s = '已完成'; break;
      case 'failed': c = Colors.redAccent; ic = Icons.error_outline; s = '失败: ${t.error ?? ""}'; break;
      default: c = Colors.white54; ic = Icons.hourglass_empty; s = '等待中';
    }
    return GlassCard(margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14), radius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ic, color: c, size: 22), const SizedBox(width: 12),
          Expanded(child: Text(t.display, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          IconButton(icon: const Icon(Icons.close, size: 20),
            onPressed: () => Downloader.I.clearTask(t.hash)),
        ]),
        const SizedBox(height: 8),
        Text(s, style: TextStyle(fontSize: 12, color: c)),
        if (t.status == 'downloading') Padding(padding: const EdgeInsets.only(top: 10),
          child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: t.progress, minHeight: 5,
              backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation(c)))),
      ]));
  }
}

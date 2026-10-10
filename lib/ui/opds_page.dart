import 'package:flutter/material.dart';

import '../services/opds_client.dart';
import '../theme/marefat_theme.dart';
import '../widgets/share_actions_sheet.dart';

class OpdsPage extends StatefulWidget {
  const OpdsPage({super.key});

  @override
  State<OpdsPage> createState() => _OpdsPageState();
}

class _OpdsPageState extends State<OpdsPage> {
  final _url = TextEditingController();
  List<OpdsEntry> _entries = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final saved = await OpdsClient.savedFeedUrl();
    if (saved != null && saved.isNotEmpty) {
      _url.text = saved;
    }
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await OpdsClient.saveFeedUrl(url);
      final entries = await OpdsClient.fetchFeed(url);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _entries = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('فهرست OPDS')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _url,
                    decoration: const InputDecoration(
                      labelText: 'آدرس فید OPDS',
                      hintText: 'https://…/opds',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.cloud_download_rounded),
                    label: const Text('بارگذاری فهرست'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'لینک دریافت EPUB را می‌توانید کپی/اشتراک کنید و فایل را به assets/books بیفزایید.',
                    style: TextStyle(fontSize: 12, color: MarefatColors.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final e = _entries[i];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tileColor: MarefatColors.mist.withValues(alpha: 0.5),
                    title: Text(
                      e.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${e.author}\n${e.summary}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.share_rounded),
                      onPressed: () => showShareActionsSheet(
                        context: context,
                        text: '${e.title}\n${e.author}\n${e.downloadUrl}',
                        title: 'اشتراک لینک EPUB',
                        subject: e.title,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/dictionary_service.dart';
import '../services/user_dictionary.dart';
import '../theme/marefat_theme.dart';

class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  Map<String, String> _custom = {};
  final _word = TextEditingController();
  final _meaning = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _word.dispose();
    _meaning.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final map = await UserDictionary.load();
    if (mounted) setState(() => _custom = map);
  }

  Future<void> _add() async {
    await UserDictionary.upsert(_word.text, _meaning.text);
    _word.clear();
    _meaning.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _custom.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('واژه‌نامهٔ شخصی')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _word,
              decoration: const InputDecoration(
                labelText: 'واژه',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _meaning,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'معنا',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('افزودن'),
            ),
            const SizedBox(height: 18),
            Text(
              'واژه‌های شما (${entries.length})',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text(
                'هنوز واژه‌ای اضافه نکرده‌اید.',
                style: TextStyle(color: MarefatColors.muted),
              )
            else
              ...entries.map(
                (e) => ListTile(
                  title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(e.value),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await UserDictionary.remove(e.key);
                      await _load();
                    },
                  ),
                ),
              ),
            const Divider(height: 28),
            const Text(
              'نمونه از واژه‌نامهٔ پیش‌فرض',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ...DictionaryService.suggestions('ا', limit: 6).map(
              (e) => ListTile(
                dense: true,
                title: Text(e.key),
                subtitle: Text(e.value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

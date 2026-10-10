import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/study_plans.dart';
import '../theme/marefat_theme.dart';

class StudyPlansPage extends StatefulWidget {
  const StudyPlansPage({
    super.key,
    required this.books,
    required this.onOpenBook,
  });

  final List<Book> books;
  final ValueChanged<Book> onOpenBook;

  @override
  State<StudyPlansPage> createState() => _StudyPlansPageState();
}

class _StudyPlansPageState extends State<StudyPlansPage> {
  List<StudyPlan> _plans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plans = await StudyPlans.load();
    if (mounted) setState(() => _plans = plans);
  }

  Future<void> _create() async {
    final titleCtrl = TextEditingController();
    final selected = <String>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            title: const Text('برنامهٔ مطالعه'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان',
                      hintText: 'مثلاً ۷ روز اخلاق',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: ListView(
                      children: [
                        for (final b in widget.books)
                          CheckboxListTile(
                            value: selected.contains(b.id),
                            title: Text(b.title, maxLines: 1),
                            onChanged: (v) => refresh(() {
                              if (v == true) {
                                selected.add(b.id);
                              } else {
                                selected.remove(b.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('لغو'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ساخت'),
              ),
            ],
          ),
        ),
      ),
    );
    final title = titleCtrl.text;
    titleCtrl.dispose();
    if (ok != true || selected.isEmpty) return;
    await StudyPlans.create(
      title: title,
      bookIds: selected.toList(),
      dueAtMs: DateTime.now()
          .add(Duration(days: selected.length.clamp(3, 30)))
          .millisecondsSinceEpoch,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('برنامه‌های مطالعه')),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'study_plans_fab',
          onPressed: _create,
          icon: const Icon(Icons.add_task_rounded),
          label: const Text('برنامهٔ جدید'),
        ),
        body: _plans.isEmpty
            ? const Center(
                child: Text(
                  'هنوز برنامه‌ای نیست.\nچند کتاب را در یک مسیر مطالعاتی بچینید.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.7, color: MarefatColors.muted),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: _plans.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final plan = _plans[index];
                  return Card(
                    child: ExpansionTile(
                      title: Text(
                        plan.title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${(plan.progress * 100).round()}٪ · ${plan.completedIds.length}/${plan.bookIds.length}',
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: LinearProgressIndicator(
                            value: plan.progress,
                            color: MarefatColors.forest,
                          ),
                        ),
                        for (final id in plan.bookIds)
                          Builder(
                            builder: (context) {
                              Book? book;
                              try {
                                book = widget.books.firstWhere((b) => b.id == id);
                              } catch (_) {}
                              final done = plan.completedIds.contains(id);
                              return ListTile(
                                leading: Icon(
                                  done
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: MarefatColors.forest,
                                ),
                                title: Text(book?.title ?? id),
                                onTap: book == null
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        widget.onOpenBook(book!);
                                      },
                                trailing: IconButton(
                                  icon: const Icon(Icons.done_all),
                                  onPressed: () async {
                                    await StudyPlans.toggleBookDone(
                                      plan.id,
                                      id,
                                    );
                                    await _load();
                                  },
                                ),
                              );
                            },
                          ),
                        TextButton(
                          onPressed: () async {
                            await StudyPlans.delete(plan.id);
                            await _load();
                          },
                          child: const Text(
                            'حذف برنامه',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

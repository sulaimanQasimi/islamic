import 'package:flutter/material.dart';

import '../services/reading_stats.dart';
import '../theme/marefat_theme.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  ReadingStatsSnapshot? _snap;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await ReadingStats.load();
    if (mounted) setState(() => _snap = snap);
  }

  @override
  Widget build(BuildContext context) {
    final s = _snap;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('آمار مطالعه')),
        body: s == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _card('امروز', '${s.todayMinutes} دقیقه', Icons.today_rounded),
                  _card('این هفته', '${s.weekMinutes} دقیقه', Icons.date_range),
                  _card('روزهای پیاپی', '${s.streak}', Icons.local_fire_department),
                  _card('هدف روزانه', '${s.goal} دقیقه', Icons.flag_rounded),
                  _card('کتاب‌های تمام‌شده', '${s.completedCount}', Icons.emoji_events),
                  _card('بازدیدهای اخیر', '${s.historyCount}', Icons.history),
                  const SizedBox(height: 16),
                  const Text(
                    '۷ روز اخیر',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(7, (i) {
                    final day = DateTime.now().subtract(Duration(days: 6 - i));
                    final key =
                        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                    final mins = s.byDay[key] ?? 0;
                    final max = s.byDay.values.fold<int>(1, (a, b) => a > b ? a : b);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              '${day.month}/${day.day}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: (mins / max).clamp(0.0, 1.0),
                                minHeight: 10,
                                color: MarefatColors.forest,
                                backgroundColor: MarefatColors.mistDeep,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$mins د'),
                        ],
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }

  Widget _card(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: MarefatColors.forest),
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: MarefatColors.forest,
          ),
        ),
      ),
    );
  }
}

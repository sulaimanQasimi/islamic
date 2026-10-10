import 'dart:convert';

import 'app_storage.dart';

class StudyPlan {
  const StudyPlan({
    required this.id,
    required this.title,
    required this.bookIds,
    required this.createdAtMs,
    this.dueAtMs,
    this.completedIds = const [],
  });

  final String id;
  final String title;
  final List<String> bookIds;
  final int createdAtMs;
  final int? dueAtMs;
  final List<String> completedIds;

  double get progress =>
      bookIds.isEmpty ? 0 : completedIds.length / bookIds.length;

  StudyPlan copyWith({
    String? title,
    List<String>? bookIds,
    int? dueAtMs,
    bool clearDue = false,
    List<String>? completedIds,
  }) =>
      StudyPlan(
        id: id,
        title: title ?? this.title,
        bookIds: bookIds ?? this.bookIds,
        createdAtMs: createdAtMs,
        dueAtMs: clearDue ? null : (dueAtMs ?? this.dueAtMs),
        completedIds: completedIds ?? this.completedIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'bookIds': bookIds,
        'createdAtMs': createdAtMs,
        if (dueAtMs != null) 'dueAtMs': dueAtMs,
        'completedIds': completedIds,
      };

  factory StudyPlan.fromJson(Map<String, dynamic> json) => StudyPlan(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'برنامه',
        bookIds: (json['bookIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[],
        createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
        dueAtMs: (json['dueAtMs'] as num?)?.toInt(),
        completedIds: (json['completedIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[],
      );
}

class StudyPlans {
  StudyPlans._();
  static const _key = 'studyPlansJson';

  static Future<List<StudyPlan>> load() async {
    final prefs = await AppStorage.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <StudyPlan>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => StudyPlan.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.id.isNotEmpty)
          .toList();
    } catch (_) {
      return <StudyPlan>[];
    }
  }

  static Future<void> save(List<StudyPlan> plans) async {
    final prefs = await AppStorage.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(plans.map((e) => e.toJson()).toList()),
    );
  }

  static Future<StudyPlan> create({
    required String title,
    required List<String> bookIds,
    int? dueAtMs,
  }) async {
    final plans = List<StudyPlan>.from(await load());
    final plan = StudyPlan(
      id: 'p_${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'برنامهٔ مطالعه' : title.trim(),
      bookIds: List<String>.from(bookIds),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      dueAtMs: dueAtMs,
    );
    plans.insert(0, plan);
    await save(plans);
    return plan;
  }

  static Future<void> update(StudyPlan plan) async {
    final plans = List<StudyPlan>.from(await load());
    final i = plans.indexWhere((p) => p.id == plan.id);
    if (i < 0) return;
    plans[i] = plan;
    await save(plans);
  }

  static Future<void> delete(String id) async {
    final plans = List<StudyPlan>.from(await load());
    plans.removeWhere((p) => p.id == id);
    await save(plans);
  }

  static Future<void> toggleBookDone(String planId, String bookId) async {
    final plans = List<StudyPlan>.from(await load());
    final i = plans.indexWhere((p) => p.id == planId);
    if (i < 0) return;
    final done = List<String>.from(plans[i].completedIds);
    if (done.contains(bookId)) {
      done.remove(bookId);
    } else {
      done.add(bookId);
    }
    plans[i] = plans[i].copyWith(completedIds: done);
    await save(plans);
  }
}

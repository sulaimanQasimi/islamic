import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic/models/book.dart';
import 'package:islamic/services/book_backend.dart';
import 'package:islamic/ui/library_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CatalogBackend extends BookBackend {
  @override
  Future<List<Book>> fetchBooks() async => const [
    Book(
      id: 'test',
      title: 'گلستان سعدی',
      author: 'سعدی',
      category: 'ادبیات',
      language: 'دری',
      direction: 'rtl',
      description: 'کتاب آزمایشی',
      color: Color(0xFF2E6757),
      icon: Icons.menu_book,
      featured: true,
      originalTitle: '',
      translator: '',
      gutenbergId: 0,
    ),
  ];
}

void main() {
  testWidgets('shows a read-only Dari book catalogue', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(home: LibraryPage(backend: _CatalogBackend())),
    );
    await tester.pumpAndSettle();
    expect(find.text('کتاب‌خانه'), findsWidgets);
    expect(find.text('گلستان سعدی'), findsWidgets);
    expect(find.text('ادبیات'), findsWidgets);
    expect(find.text('افزودن کتاب'), findsNothing);
  });
}

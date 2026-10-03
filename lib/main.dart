import 'package:flutter/material.dart';

import 'ui/library_page.dart';

const ink = Color(0xFF183B35);
const green = Color(0xFF2E6757);
const paper = Color(0xFFF7F4EC);

void main() => runApp(const KetabApp());

class KetabApp extends StatelessWidget {
  const KetabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'کتاب‌خانه',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(seedColor: green, surface: paper),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
      ),
    ),
    home: const LibraryPage(),
  );
}

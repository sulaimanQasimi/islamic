import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/app_storage.dart';
import 'theme/marefat_theme.dart';
import 'ui/home_shell.dart';
import 'ui/splash_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MarefatApp());
}

class MarefatApp extends StatefulWidget {
  const MarefatApp({super.key});

  @override
  State<MarefatApp> createState() => _MarefatAppState();
}

class _MarefatAppState extends State<MarefatApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait([
      AppStorage.getInstance(),
      Future<void>.delayed(const Duration(milliseconds: 1200)),
    ]);
    final prefs = results[0] as AppStorage;
    final theme = prefs.getString('appThemeMode');
    if (!mounted) return;
    setState(() {
      _themeMode = switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MarefatAppScope(
      themeMode: _themeMode,
      onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'معرفت',
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        theme: MarefatTheme.light(),
        darkTheme: MarefatTheme.dark(),
        themeMode: _themeMode,
        home: _ready ? const HomeShell() : const SplashPage(),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/app_storage.dart';
import 'services/night_auto.dart';
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

class _MarefatAppState extends State<MarefatApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode _displayTheme = ThemeMode.system;
  bool _ready = false;
  Timer? _nightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDisplayTheme();
    }
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
      _displayTheme = _themeMode;
      _ready = true;
    });
    await _refreshDisplayTheme();
    _nightTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _refreshDisplayTheme(),
    );
  }

  Future<void> _refreshDisplayTheme() async {
    ThemeMode next = _themeMode;
    if (await NightAuto.enabled()) {
      next = await NightAuto.isNightNow() ? ThemeMode.dark : ThemeMode.light;
    }
    if (!mounted) return;
    if (_displayTheme != next) {
      setState(() => _displayTheme = next);
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await AppStorage.getInstance();
    await prefs.setString(
      'appThemeMode',
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
    if (!mounted) return;
    setState(() => _themeMode = mode);
    await _refreshDisplayTheme();
  }

  @override
  Widget build(BuildContext context) {
    return MarefatAppScope(
      themeMode: _themeMode,
      onThemeModeChanged: _setThemeMode,
      onNightScheduleChanged: _refreshDisplayTheme,
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
        themeMode: _displayTheme,
        home: _ready ? const HomeShell() : const SplashPage(),
      ),
    );
  }
}

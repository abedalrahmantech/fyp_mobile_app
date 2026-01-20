import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/app_theme.dart';
import 'bootstrap/app_bootstrap.dart';
import 'config/app_config.dart';
import 'screens/admin/admin_portal_screen.dart';
import 'screens/auth/driver_auth_gate.dart';

Future<void> main() async {
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  final bootstrap = await AppBootstrap.initialize();
  runApp(MyApp(bootstrap: bootstrap));
}

class MyApp extends StatefulWidget {
  const MyApp({required this.bootstrap, super.key});

  final AppBootstrap bootstrap;

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  late final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => DriverAuthGate(
          bootstrap: widget.bootstrap,
        ),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminPortalScreen(),
      ),
    ],
  );

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: widget.bootstrap.config),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'OrderVista Dispatch',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _themeMode,
        routerConfig: _router,
      ),
    );
  }
}

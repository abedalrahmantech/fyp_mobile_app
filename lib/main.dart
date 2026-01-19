import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app/app_theme.dart';
import 'bootstrap/app_bootstrap.dart';
import 'config/app_config.dart';
import 'screens/admin/admin_portal_screen.dart';
import 'screens/task_list/task_list_screen.dart';
import 'viewmodels/task_view_model.dart';

Future<void> main() async {
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
        builder: (context, state) => const TaskListScreen(),
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
        ChangeNotifierProvider<TaskViewModel>(
          create: (_) => widget.bootstrap.createTaskViewModel(),
        ),
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

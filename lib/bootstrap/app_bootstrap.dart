import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../data/ordervista_database.dart';
import '../repositories/task_repository.dart';
import '../services/task_service.dart';
import '../viewmodels/task_view_model.dart';

class AppBootstrap {
  AppBootstrap._(
    this.config,
    this.database,
    this.supabaseClient,
  );

  final AppConfig config;
  final OrderVistaDatabase? database;
  final SupabaseClient supabaseClient;

  static bool _supabaseReady = false;

  static Future<AppBootstrap> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    final config = AppConfig.fromEnv();
    await _ensureSupabase(config);
    final supabaseClient = Supabase.instance.client;
    final database = kIsWeb ? null : OrderVistaDatabase();
    return AppBootstrap._(
      config,
      database,
      supabaseClient,
    );
  }

  static AppBootstrap test({
    required AppConfig config,
    required OrderVistaDatabase? database,
    required SupabaseClient supabaseClient,
  }) {
    return AppBootstrap._(
      config,
      database,
      supabaseClient,
    );
  }

  TaskViewModel createTaskViewModelForDriver({
    required String companyId,
    required String driverId,
  }) {
    final taskService = TaskService(
      client: supabaseClient,
      companyId: companyId,
      driverId: driverId,
    );
    final taskRepository = TaskRepository(
      database: database,
      taskService: taskService,
      companyId: companyId,
      driverId: driverId,
    );
    return TaskViewModel(taskRepository: taskRepository);
  }

  static Future<void> _ensureSupabase(AppConfig config) async {
    if (_supabaseReady) {
      return;
    }

    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
      realtimeClientOptions:
          const RealtimeClientOptions(logLevel: RealtimeLogLevel.error),
      debug: !config.isProduction,
    );
    _supabaseReady = true;
  }
}

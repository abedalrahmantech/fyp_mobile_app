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
    this.taskRepository,
    this.supabaseClient,
  );

  final AppConfig config;
  final OrderVistaDatabase database;
  final TaskRepository taskRepository;
  final SupabaseClient supabaseClient;

  static bool _supabaseReady = false;

  static Future<AppBootstrap> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    final config = AppConfig.fromEnv();
    await _ensureSupabase(config);
    final supabaseClient = Supabase.instance.client;
    final database = OrderVistaDatabase();
    final taskService = TaskService(
      client: supabaseClient,
      companyId: config.companyId,
      driverId: config.driverId,
    );
    final taskRepository = TaskRepository(
      database: database,
      taskService: taskService,
      companyId: config.companyId,
      driverId: config.driverId,
    );
    return AppBootstrap._(
      config,
      database,
      taskRepository,
      supabaseClient,
    );
  }

  static AppBootstrap test({
    required AppConfig config,
    required OrderVistaDatabase database,
    required TaskRepository taskRepository,
    required SupabaseClient supabaseClient,
  }) {
    return AppBootstrap._(
      config,
      database,
      taskRepository,
      supabaseClient,
    );
  }

  TaskViewModel createTaskViewModel() {
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

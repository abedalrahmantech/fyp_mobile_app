import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'connection/native_connection.dart'
    if (dart.library.html) 'connection/web_connection.dart';

part 'ordervista_database.g.dart';

class DriftTasks extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get address => text()();
  TextColumn get status => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get proofCode => text().nullable()();
  TextColumn get proofPhotoUrl => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  DateTimeColumn get scheduledStart => dateTime().nullable()();
  DateTimeColumn get scheduledEnd => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class DriftRoutes extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get status => text()();
  TextColumn get driverId => text().nullable()();
  TextColumn get vehicleId => text().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class DriftRouteTasks extends Table {
  IntColumn get sequence => integer()();
  TextColumn get routeId => text()();
  TextColumn get taskId => text()();
  IntColumn get travelDurationSeconds => integer().nullable()();
  IntColumn get travelDistanceMeters => integer().nullable()();

  @override
  Set<Column> get primaryKey => {routeId, sequence};
}

class DriftSyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get companyId => text()();
  TextColumn get driverId => text()();
  TextColumn get actionType => text()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [DriftTasks, DriftRoutes, DriftRouteTasks, DriftSyncQueue],
)
class OrderVistaDatabase extends _$OrderVistaDatabase {
  OrderVistaDatabase({QueryExecutor? executor})
      : super(executor ?? openConnection());

  factory OrderVistaDatabase.inMemory() {
    if (kIsWeb) {
      return OrderVistaDatabase(executor: openMemoryConnection());
    }

    return OrderVistaDatabase(executor: openMemoryConnection());
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add priority column to drift_tasks table
          await m.addColumn(driftTasks, driftTasks.priority);
        }
      },
    );
  }
}

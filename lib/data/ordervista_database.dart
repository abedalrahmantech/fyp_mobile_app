import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'ordervista_database.g.dart';

class DriftTasks extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get address => text()();
  TextColumn get status => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get proofCode => text().nullable()();
  TextColumn get proofPhotoUrl => text().nullable()();
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
      : super(executor ?? _openConnection());

  factory OrderVistaDatabase.inMemory() {
    return OrderVistaDatabase(
      executor: LazyDatabase(() async {
        return NativeDatabase.memory();
      }),
    );
  }

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, 'ordervista.db');
    return NativeDatabase.createInBackground(File(path));
  });
}

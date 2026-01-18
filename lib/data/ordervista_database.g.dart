// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ordervista_database.dart';

// ignore_for_file: type=lint
class $DriftTasksTable extends DriftTasks
    with TableInfo<$DriftTasksTable, DriftTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _proofCodeMeta =
      const VerificationMeta('proofCode');
  @override
  late final GeneratedColumn<String> proofCode = GeneratedColumn<String>(
      'proof_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _proofPhotoUrlMeta =
      const VerificationMeta('proofPhotoUrl');
  @override
  late final GeneratedColumn<String> proofPhotoUrl = GeneratedColumn<String>(
      'proof_photo_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scheduledStartMeta =
      const VerificationMeta('scheduledStart');
  @override
  late final GeneratedColumn<DateTime> scheduledStart =
      GeneratedColumn<DateTime>('scheduled_start', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _scheduledEndMeta =
      const VerificationMeta('scheduledEnd');
  @override
  late final GeneratedColumn<DateTime> scheduledEnd = GeneratedColumn<DateTime>(
      'scheduled_end', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        companyId,
        address,
        status,
        notes,
        proofCode,
        proofPhotoUrl,
        scheduledStart,
        scheduledEnd,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_tasks';
  @override
  VerificationContext validateIntegrity(Insertable<DriftTask> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('proof_code')) {
      context.handle(_proofCodeMeta,
          proofCode.isAcceptableOrUnknown(data['proof_code']!, _proofCodeMeta));
    }
    if (data.containsKey('proof_photo_url')) {
      context.handle(
          _proofPhotoUrlMeta,
          proofPhotoUrl.isAcceptableOrUnknown(
              data['proof_photo_url']!, _proofPhotoUrlMeta));
    }
    if (data.containsKey('scheduled_start')) {
      context.handle(
          _scheduledStartMeta,
          scheduledStart.isAcceptableOrUnknown(
              data['scheduled_start']!, _scheduledStartMeta));
    }
    if (data.containsKey('scheduled_end')) {
      context.handle(
          _scheduledEndMeta,
          scheduledEnd.isAcceptableOrUnknown(
              data['scheduled_end']!, _scheduledEndMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftTask(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id'])!,
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      proofCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}proof_code']),
      proofPhotoUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}proof_photo_url']),
      scheduledStart: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}scheduled_start']),
      scheduledEnd: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}scheduled_end']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $DriftTasksTable createAlias(String alias) {
    return $DriftTasksTable(attachedDatabase, alias);
  }
}

class DriftTask extends DataClass implements Insertable<DriftTask> {
  final String id;
  final String companyId;
  final String address;
  final String status;
  final String? notes;
  final String? proofCode;
  final String? proofPhotoUrl;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final DateTime updatedAt;
  const DriftTask(
      {required this.id,
      required this.companyId,
      required this.address,
      required this.status,
      this.notes,
      this.proofCode,
      this.proofPhotoUrl,
      this.scheduledStart,
      this.scheduledEnd,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['address'] = Variable<String>(address);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || proofCode != null) {
      map['proof_code'] = Variable<String>(proofCode);
    }
    if (!nullToAbsent || proofPhotoUrl != null) {
      map['proof_photo_url'] = Variable<String>(proofPhotoUrl);
    }
    if (!nullToAbsent || scheduledStart != null) {
      map['scheduled_start'] = Variable<DateTime>(scheduledStart);
    }
    if (!nullToAbsent || scheduledEnd != null) {
      map['scheduled_end'] = Variable<DateTime>(scheduledEnd);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DriftTasksCompanion toCompanion(bool nullToAbsent) {
    return DriftTasksCompanion(
      id: Value(id),
      companyId: Value(companyId),
      address: Value(address),
      status: Value(status),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      proofCode: proofCode == null && nullToAbsent
          ? const Value.absent()
          : Value(proofCode),
      proofPhotoUrl: proofPhotoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(proofPhotoUrl),
      scheduledStart: scheduledStart == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledStart),
      scheduledEnd: scheduledEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledEnd),
      updatedAt: Value(updatedAt),
    );
  }

  factory DriftTask.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftTask(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      address: serializer.fromJson<String>(json['address']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
      proofCode: serializer.fromJson<String?>(json['proofCode']),
      proofPhotoUrl: serializer.fromJson<String?>(json['proofPhotoUrl']),
      scheduledStart: serializer.fromJson<DateTime?>(json['scheduledStart']),
      scheduledEnd: serializer.fromJson<DateTime?>(json['scheduledEnd']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'address': serializer.toJson<String>(address),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'proofCode': serializer.toJson<String?>(proofCode),
      'proofPhotoUrl': serializer.toJson<String?>(proofPhotoUrl),
      'scheduledStart': serializer.toJson<DateTime?>(scheduledStart),
      'scheduledEnd': serializer.toJson<DateTime?>(scheduledEnd),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DriftTask copyWith(
          {String? id,
          String? companyId,
          String? address,
          String? status,
          Value<String?> notes = const Value.absent(),
          Value<String?> proofCode = const Value.absent(),
          Value<String?> proofPhotoUrl = const Value.absent(),
          Value<DateTime?> scheduledStart = const Value.absent(),
          Value<DateTime?> scheduledEnd = const Value.absent(),
          DateTime? updatedAt}) =>
      DriftTask(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        address: address ?? this.address,
        status: status ?? this.status,
        notes: notes.present ? notes.value : this.notes,
        proofCode: proofCode.present ? proofCode.value : this.proofCode,
        proofPhotoUrl:
            proofPhotoUrl.present ? proofPhotoUrl.value : this.proofPhotoUrl,
        scheduledStart:
            scheduledStart.present ? scheduledStart.value : this.scheduledStart,
        scheduledEnd:
            scheduledEnd.present ? scheduledEnd.value : this.scheduledEnd,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  @override
  String toString() {
    return (StringBuffer('DriftTask(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('address: $address, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('proofCode: $proofCode, ')
          ..write('proofPhotoUrl: $proofPhotoUrl, ')
          ..write('scheduledStart: $scheduledStart, ')
          ..write('scheduledEnd: $scheduledEnd, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, companyId, address, status, notes,
      proofCode, proofPhotoUrl, scheduledStart, scheduledEnd, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftTask &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.address == this.address &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.proofCode == this.proofCode &&
          other.proofPhotoUrl == this.proofPhotoUrl &&
          other.scheduledStart == this.scheduledStart &&
          other.scheduledEnd == this.scheduledEnd &&
          other.updatedAt == this.updatedAt);
}

class DriftTasksCompanion extends UpdateCompanion<DriftTask> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> address;
  final Value<String> status;
  final Value<String?> notes;
  final Value<String?> proofCode;
  final Value<String?> proofPhotoUrl;
  final Value<DateTime?> scheduledStart;
  final Value<DateTime?> scheduledEnd;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DriftTasksCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.address = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.proofCode = const Value.absent(),
    this.proofPhotoUrl = const Value.absent(),
    this.scheduledStart = const Value.absent(),
    this.scheduledEnd = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriftTasksCompanion.insert({
    required String id,
    required String companyId,
    required String address,
    required String status,
    this.notes = const Value.absent(),
    this.proofCode = const Value.absent(),
    this.proofPhotoUrl = const Value.absent(),
    this.scheduledStart = const Value.absent(),
    this.scheduledEnd = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        companyId = Value(companyId),
        address = Value(address),
        status = Value(status),
        updatedAt = Value(updatedAt);
  static Insertable<DriftTask> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? address,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<String>? proofCode,
    Expression<String>? proofPhotoUrl,
    Expression<DateTime>? scheduledStart,
    Expression<DateTime>? scheduledEnd,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (address != null) 'address': address,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (proofCode != null) 'proof_code': proofCode,
      if (proofPhotoUrl != null) 'proof_photo_url': proofPhotoUrl,
      if (scheduledStart != null) 'scheduled_start': scheduledStart,
      if (scheduledEnd != null) 'scheduled_end': scheduledEnd,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriftTasksCompanion copyWith(
      {Value<String>? id,
      Value<String>? companyId,
      Value<String>? address,
      Value<String>? status,
      Value<String?>? notes,
      Value<String?>? proofCode,
      Value<String?>? proofPhotoUrl,
      Value<DateTime?>? scheduledStart,
      Value<DateTime?>? scheduledEnd,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return DriftTasksCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      address: address ?? this.address,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      proofCode: proofCode ?? this.proofCode,
      proofPhotoUrl: proofPhotoUrl ?? this.proofPhotoUrl,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (proofCode.present) {
      map['proof_code'] = Variable<String>(proofCode.value);
    }
    if (proofPhotoUrl.present) {
      map['proof_photo_url'] = Variable<String>(proofPhotoUrl.value);
    }
    if (scheduledStart.present) {
      map['scheduled_start'] = Variable<DateTime>(scheduledStart.value);
    }
    if (scheduledEnd.present) {
      map['scheduled_end'] = Variable<DateTime>(scheduledEnd.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftTasksCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('address: $address, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('proofCode: $proofCode, ')
          ..write('proofPhotoUrl: $proofPhotoUrl, ')
          ..write('scheduledStart: $scheduledStart, ')
          ..write('scheduledEnd: $scheduledEnd, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DriftRoutesTable extends DriftRoutes
    with TableInfo<$DriftRoutesTable, DriftRoute> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftRoutesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _driverIdMeta =
      const VerificationMeta('driverId');
  @override
  late final GeneratedColumn<String> driverId = GeneratedColumn<String>(
      'driver_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _vehicleIdMeta =
      const VerificationMeta('vehicleId');
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
      'vehicle_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        companyId,
        status,
        driverId,
        vehicleId,
        startedAt,
        completedAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_routes';
  @override
  VerificationContext validateIntegrity(Insertable<DriftRoute> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('driver_id')) {
      context.handle(_driverIdMeta,
          driverId.isAcceptableOrUnknown(data['driver_id']!, _driverIdMeta));
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(_vehicleIdMeta,
          vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftRoute map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftRoute(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      driverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}driver_id']),
      vehicleId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vehicle_id']),
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at']),
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $DriftRoutesTable createAlias(String alias) {
    return $DriftRoutesTable(attachedDatabase, alias);
  }
}

class DriftRoute extends DataClass implements Insertable<DriftRoute> {
  final String id;
  final String companyId;
  final String status;
  final String? driverId;
  final String? vehicleId;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;
  const DriftRoute(
      {required this.id,
      required this.companyId,
      required this.status,
      this.driverId,
      this.vehicleId,
      this.startedAt,
      this.completedAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || driverId != null) {
      map['driver_id'] = Variable<String>(driverId);
    }
    if (!nullToAbsent || vehicleId != null) {
      map['vehicle_id'] = Variable<String>(vehicleId);
    }
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DriftRoutesCompanion toCompanion(bool nullToAbsent) {
    return DriftRoutesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      status: Value(status),
      driverId: driverId == null && nullToAbsent
          ? const Value.absent()
          : Value(driverId),
      vehicleId: vehicleId == null && nullToAbsent
          ? const Value.absent()
          : Value(vehicleId),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DriftRoute.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftRoute(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      status: serializer.fromJson<String>(json['status']),
      driverId: serializer.fromJson<String?>(json['driverId']),
      vehicleId: serializer.fromJson<String?>(json['vehicleId']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'status': serializer.toJson<String>(status),
      'driverId': serializer.toJson<String?>(driverId),
      'vehicleId': serializer.toJson<String?>(vehicleId),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DriftRoute copyWith(
          {String? id,
          String? companyId,
          String? status,
          Value<String?> driverId = const Value.absent(),
          Value<String?> vehicleId = const Value.absent(),
          Value<DateTime?> startedAt = const Value.absent(),
          Value<DateTime?> completedAt = const Value.absent(),
          DateTime? updatedAt}) =>
      DriftRoute(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        status: status ?? this.status,
        driverId: driverId.present ? driverId.value : this.driverId,
        vehicleId: vehicleId.present ? vehicleId.value : this.vehicleId,
        startedAt: startedAt.present ? startedAt.value : this.startedAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  @override
  String toString() {
    return (StringBuffer('DriftRoute(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('status: $status, ')
          ..write('driverId: $driverId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, companyId, status, driverId, vehicleId,
      startedAt, completedAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftRoute &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.status == this.status &&
          other.driverId == this.driverId &&
          other.vehicleId == this.vehicleId &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.updatedAt == this.updatedAt);
}

class DriftRoutesCompanion extends UpdateCompanion<DriftRoute> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> status;
  final Value<String?> driverId;
  final Value<String?> vehicleId;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> completedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DriftRoutesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.status = const Value.absent(),
    this.driverId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriftRoutesCompanion.insert({
    required String id,
    required String companyId,
    required String status,
    this.driverId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        companyId = Value(companyId),
        status = Value(status),
        updatedAt = Value(updatedAt);
  static Insertable<DriftRoute> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? status,
    Expression<String>? driverId,
    Expression<String>? vehicleId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (status != null) 'status': status,
      if (driverId != null) 'driver_id': driverId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriftRoutesCompanion copyWith(
      {Value<String>? id,
      Value<String>? companyId,
      Value<String>? status,
      Value<String?>? driverId,
      Value<String?>? vehicleId,
      Value<DateTime?>? startedAt,
      Value<DateTime?>? completedAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return DriftRoutesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      status: status ?? this.status,
      driverId: driverId ?? this.driverId,
      vehicleId: vehicleId ?? this.vehicleId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (driverId.present) {
      map['driver_id'] = Variable<String>(driverId.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftRoutesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('status: $status, ')
          ..write('driverId: $driverId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DriftRouteTasksTable extends DriftRouteTasks
    with TableInfo<$DriftRouteTasksTable, DriftRouteTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftRouteTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sequenceMeta =
      const VerificationMeta('sequence');
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
      'sequence', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _routeIdMeta =
      const VerificationMeta('routeId');
  @override
  late final GeneratedColumn<String> routeId = GeneratedColumn<String>(
      'route_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
      'task_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _travelDurationSecondsMeta =
      const VerificationMeta('travelDurationSeconds');
  @override
  late final GeneratedColumn<int> travelDurationSeconds = GeneratedColumn<int>(
      'travel_duration_seconds', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _travelDistanceMetersMeta =
      const VerificationMeta('travelDistanceMeters');
  @override
  late final GeneratedColumn<int> travelDistanceMeters = GeneratedColumn<int>(
      'travel_distance_meters', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [sequence, routeId, taskId, travelDurationSeconds, travelDistanceMeters];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_route_tasks';
  @override
  VerificationContext validateIntegrity(Insertable<DriftRouteTask> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sequence')) {
      context.handle(_sequenceMeta,
          sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta));
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('route_id')) {
      context.handle(_routeIdMeta,
          routeId.isAcceptableOrUnknown(data['route_id']!, _routeIdMeta));
    } else if (isInserting) {
      context.missing(_routeIdMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(_taskIdMeta,
          taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta));
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('travel_duration_seconds')) {
      context.handle(
          _travelDurationSecondsMeta,
          travelDurationSeconds.isAcceptableOrUnknown(
              data['travel_duration_seconds']!, _travelDurationSecondsMeta));
    }
    if (data.containsKey('travel_distance_meters')) {
      context.handle(
          _travelDistanceMetersMeta,
          travelDistanceMeters.isAcceptableOrUnknown(
              data['travel_distance_meters']!, _travelDistanceMetersMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {routeId, sequence};
  @override
  DriftRouteTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftRouteTask(
      sequence: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sequence'])!,
      routeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}route_id'])!,
      taskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_id'])!,
      travelDurationSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}travel_duration_seconds']),
      travelDistanceMeters: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}travel_distance_meters']),
    );
  }

  @override
  $DriftRouteTasksTable createAlias(String alias) {
    return $DriftRouteTasksTable(attachedDatabase, alias);
  }
}

class DriftRouteTask extends DataClass implements Insertable<DriftRouteTask> {
  final int sequence;
  final String routeId;
  final String taskId;
  final int? travelDurationSeconds;
  final int? travelDistanceMeters;
  const DriftRouteTask(
      {required this.sequence,
      required this.routeId,
      required this.taskId,
      this.travelDurationSeconds,
      this.travelDistanceMeters});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sequence'] = Variable<int>(sequence);
    map['route_id'] = Variable<String>(routeId);
    map['task_id'] = Variable<String>(taskId);
    if (!nullToAbsent || travelDurationSeconds != null) {
      map['travel_duration_seconds'] = Variable<int>(travelDurationSeconds);
    }
    if (!nullToAbsent || travelDistanceMeters != null) {
      map['travel_distance_meters'] = Variable<int>(travelDistanceMeters);
    }
    return map;
  }

  DriftRouteTasksCompanion toCompanion(bool nullToAbsent) {
    return DriftRouteTasksCompanion(
      sequence: Value(sequence),
      routeId: Value(routeId),
      taskId: Value(taskId),
      travelDurationSeconds: travelDurationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(travelDurationSeconds),
      travelDistanceMeters: travelDistanceMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(travelDistanceMeters),
    );
  }

  factory DriftRouteTask.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftRouteTask(
      sequence: serializer.fromJson<int>(json['sequence']),
      routeId: serializer.fromJson<String>(json['routeId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      travelDurationSeconds:
          serializer.fromJson<int?>(json['travelDurationSeconds']),
      travelDistanceMeters:
          serializer.fromJson<int?>(json['travelDistanceMeters']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sequence': serializer.toJson<int>(sequence),
      'routeId': serializer.toJson<String>(routeId),
      'taskId': serializer.toJson<String>(taskId),
      'travelDurationSeconds': serializer.toJson<int?>(travelDurationSeconds),
      'travelDistanceMeters': serializer.toJson<int?>(travelDistanceMeters),
    };
  }

  DriftRouteTask copyWith(
          {int? sequence,
          String? routeId,
          String? taskId,
          Value<int?> travelDurationSeconds = const Value.absent(),
          Value<int?> travelDistanceMeters = const Value.absent()}) =>
      DriftRouteTask(
        sequence: sequence ?? this.sequence,
        routeId: routeId ?? this.routeId,
        taskId: taskId ?? this.taskId,
        travelDurationSeconds: travelDurationSeconds.present
            ? travelDurationSeconds.value
            : this.travelDurationSeconds,
        travelDistanceMeters: travelDistanceMeters.present
            ? travelDistanceMeters.value
            : this.travelDistanceMeters,
      );
  @override
  String toString() {
    return (StringBuffer('DriftRouteTask(')
          ..write('sequence: $sequence, ')
          ..write('routeId: $routeId, ')
          ..write('taskId: $taskId, ')
          ..write('travelDurationSeconds: $travelDurationSeconds, ')
          ..write('travelDistanceMeters: $travelDistanceMeters')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      sequence, routeId, taskId, travelDurationSeconds, travelDistanceMeters);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftRouteTask &&
          other.sequence == this.sequence &&
          other.routeId == this.routeId &&
          other.taskId == this.taskId &&
          other.travelDurationSeconds == this.travelDurationSeconds &&
          other.travelDistanceMeters == this.travelDistanceMeters);
}

class DriftRouteTasksCompanion extends UpdateCompanion<DriftRouteTask> {
  final Value<int> sequence;
  final Value<String> routeId;
  final Value<String> taskId;
  final Value<int?> travelDurationSeconds;
  final Value<int?> travelDistanceMeters;
  final Value<int> rowid;
  const DriftRouteTasksCompanion({
    this.sequence = const Value.absent(),
    this.routeId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.travelDurationSeconds = const Value.absent(),
    this.travelDistanceMeters = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriftRouteTasksCompanion.insert({
    required int sequence,
    required String routeId,
    required String taskId,
    this.travelDurationSeconds = const Value.absent(),
    this.travelDistanceMeters = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : sequence = Value(sequence),
        routeId = Value(routeId),
        taskId = Value(taskId);
  static Insertable<DriftRouteTask> custom({
    Expression<int>? sequence,
    Expression<String>? routeId,
    Expression<String>? taskId,
    Expression<int>? travelDurationSeconds,
    Expression<int>? travelDistanceMeters,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sequence != null) 'sequence': sequence,
      if (routeId != null) 'route_id': routeId,
      if (taskId != null) 'task_id': taskId,
      if (travelDurationSeconds != null)
        'travel_duration_seconds': travelDurationSeconds,
      if (travelDistanceMeters != null)
        'travel_distance_meters': travelDistanceMeters,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriftRouteTasksCompanion copyWith(
      {Value<int>? sequence,
      Value<String>? routeId,
      Value<String>? taskId,
      Value<int?>? travelDurationSeconds,
      Value<int?>? travelDistanceMeters,
      Value<int>? rowid}) {
    return DriftRouteTasksCompanion(
      sequence: sequence ?? this.sequence,
      routeId: routeId ?? this.routeId,
      taskId: taskId ?? this.taskId,
      travelDurationSeconds:
          travelDurationSeconds ?? this.travelDurationSeconds,
      travelDistanceMeters: travelDistanceMeters ?? this.travelDistanceMeters,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (routeId.present) {
      map['route_id'] = Variable<String>(routeId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (travelDurationSeconds.present) {
      map['travel_duration_seconds'] =
          Variable<int>(travelDurationSeconds.value);
    }
    if (travelDistanceMeters.present) {
      map['travel_distance_meters'] = Variable<int>(travelDistanceMeters.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftRouteTasksCompanion(')
          ..write('sequence: $sequence, ')
          ..write('routeId: $routeId, ')
          ..write('taskId: $taskId, ')
          ..write('travelDurationSeconds: $travelDurationSeconds, ')
          ..write('travelDistanceMeters: $travelDistanceMeters, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DriftSyncQueueTable extends DriftSyncQueue
    with TableInfo<$DriftSyncQueueTable, DriftSyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftSyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _driverIdMeta =
      const VerificationMeta('driverId');
  @override
  late final GeneratedColumn<String> driverId = GeneratedColumn<String>(
      'driver_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actionTypeMeta =
      const VerificationMeta('actionType');
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
      'action_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastAttemptAtMeta =
      const VerificationMeta('lastAttemptAt');
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>('last_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        companyId,
        driverId,
        actionType,
        payloadJson,
        status,
        attempts,
        lastAttemptAt,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_sync_queue';
  @override
  VerificationContext validateIntegrity(Insertable<DriftSyncQueueData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('driver_id')) {
      context.handle(_driverIdMeta,
          driverId.isAcceptableOrUnknown(data['driver_id']!, _driverIdMeta));
    } else if (isInserting) {
      context.missing(_driverIdMeta);
    }
    if (data.containsKey('action_type')) {
      context.handle(
          _actionTypeMeta,
          actionType.isAcceptableOrUnknown(
              data['action_type']!, _actionTypeMeta));
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
          _lastAttemptAtMeta,
          lastAttemptAt.isAcceptableOrUnknown(
              data['last_attempt_at']!, _lastAttemptAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftSyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftSyncQueueData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id'])!,
      driverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}driver_id'])!,
      actionType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action_type'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_attempt_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $DriftSyncQueueTable createAlias(String alias) {
    return $DriftSyncQueueTable(attachedDatabase, alias);
  }
}

class DriftSyncQueueData extends DataClass
    implements Insertable<DriftSyncQueueData> {
  final int id;
  final String companyId;
  final String driverId;
  final String actionType;
  final String payloadJson;
  final String status;
  final int attempts;
  final DateTime? lastAttemptAt;
  final DateTime createdAt;
  const DriftSyncQueueData(
      {required this.id,
      required this.companyId,
      required this.driverId,
      required this.actionType,
      required this.payloadJson,
      required this.status,
      required this.attempts,
      this.lastAttemptAt,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['company_id'] = Variable<String>(companyId);
    map['driver_id'] = Variable<String>(driverId);
    map['action_type'] = Variable<String>(actionType);
    map['payload_json'] = Variable<String>(payloadJson);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DriftSyncQueueCompanion toCompanion(bool nullToAbsent) {
    return DriftSyncQueueCompanion(
      id: Value(id),
      companyId: Value(companyId),
      driverId: Value(driverId),
      actionType: Value(actionType),
      payloadJson: Value(payloadJson),
      status: Value(status),
      attempts: Value(attempts),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      createdAt: Value(createdAt),
    );
  }

  factory DriftSyncQueueData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftSyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      driverId: serializer.fromJson<String>(json['driverId']),
      actionType: serializer.fromJson<String>(json['actionType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'companyId': serializer.toJson<String>(companyId),
      'driverId': serializer.toJson<String>(driverId),
      'actionType': serializer.toJson<String>(actionType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DriftSyncQueueData copyWith(
          {int? id,
          String? companyId,
          String? driverId,
          String? actionType,
          String? payloadJson,
          String? status,
          int? attempts,
          Value<DateTime?> lastAttemptAt = const Value.absent(),
          DateTime? createdAt}) =>
      DriftSyncQueueData(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        driverId: driverId ?? this.driverId,
        actionType: actionType ?? this.actionType,
        payloadJson: payloadJson ?? this.payloadJson,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        lastAttemptAt:
            lastAttemptAt.present ? lastAttemptAt.value : this.lastAttemptAt,
        createdAt: createdAt ?? this.createdAt,
      );
  @override
  String toString() {
    return (StringBuffer('DriftSyncQueueData(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('driverId: $driverId, ')
          ..write('actionType: $actionType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, companyId, driverId, actionType,
      payloadJson, status, attempts, lastAttemptAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftSyncQueueData &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.driverId == this.driverId &&
          other.actionType == this.actionType &&
          other.payloadJson == this.payloadJson &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.createdAt == this.createdAt);
}

class DriftSyncQueueCompanion extends UpdateCompanion<DriftSyncQueueData> {
  final Value<int> id;
  final Value<String> companyId;
  final Value<String> driverId;
  final Value<String> actionType;
  final Value<String> payloadJson;
  final Value<String> status;
  final Value<int> attempts;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime> createdAt;
  const DriftSyncQueueCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.driverId = const Value.absent(),
    this.actionType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DriftSyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String companyId,
    required String driverId,
    required String actionType,
    required String payloadJson,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : companyId = Value(companyId),
        driverId = Value(driverId),
        actionType = Value(actionType),
        payloadJson = Value(payloadJson);
  static Insertable<DriftSyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? companyId,
    Expression<String>? driverId,
    Expression<String>? actionType,
    Expression<String>? payloadJson,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (driverId != null) 'driver_id': driverId,
      if (actionType != null) 'action_type': actionType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DriftSyncQueueCompanion copyWith(
      {Value<int>? id,
      Value<String>? companyId,
      Value<String>? driverId,
      Value<String>? actionType,
      Value<String>? payloadJson,
      Value<String>? status,
      Value<int>? attempts,
      Value<DateTime?>? lastAttemptAt,
      Value<DateTime>? createdAt}) {
    return DriftSyncQueueCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      driverId: driverId ?? this.driverId,
      actionType: actionType ?? this.actionType,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (driverId.present) {
      map['driver_id'] = Variable<String>(driverId.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftSyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('driverId: $driverId, ')
          ..write('actionType: $actionType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$OrderVistaDatabase extends GeneratedDatabase {
  _$OrderVistaDatabase(QueryExecutor e) : super(e);
  late final $DriftTasksTable driftTasks = $DriftTasksTable(this);
  late final $DriftRoutesTable driftRoutes = $DriftRoutesTable(this);
  late final $DriftRouteTasksTable driftRouteTasks =
      $DriftRouteTasksTable(this);
  late final $DriftSyncQueueTable driftSyncQueue = $DriftSyncQueueTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [driftTasks, driftRoutes, driftRouteTasks, driftSyncQueue];
}

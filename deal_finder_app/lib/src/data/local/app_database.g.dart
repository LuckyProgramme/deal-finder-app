// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TargetRowsTable extends TargetRows
    with TableInfo<$TargetRowsTable, TargetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TargetRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    normalizedName,
    payload,
    revision,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'target_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<TargetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TargetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TargetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TargetRowsTable createAlias(String alias) {
    return $TargetRowsTable(attachedDatabase, alias);
  }
}

class TargetRow extends DataClass implements Insertable<TargetRow> {
  final String id;
  final String normalizedName;
  final String payload;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TargetRow({
    required this.id,
    required this.normalizedName,
    required this.payload,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['normalized_name'] = Variable<String>(normalizedName);
    map['payload'] = Variable<String>(payload);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TargetRowsCompanion toCompanion(bool nullToAbsent) {
    return TargetRowsCompanion(
      id: Value(id),
      normalizedName: Value(normalizedName),
      payload: Value(payload),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TargetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TargetRow(
      id: serializer.fromJson<String>(json['id']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      payload: serializer.fromJson<String>(json['payload']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'payload': serializer.toJson<String>(payload),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TargetRow copyWith({
    String? id,
    String? normalizedName,
    String? payload,
    int? revision,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TargetRow(
    id: id ?? this.id,
    normalizedName: normalizedName ?? this.normalizedName,
    payload: payload ?? this.payload,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TargetRow copyWithCompanion(TargetRowsCompanion data) {
    return TargetRow(
      id: data.id.present ? data.id.value : this.id,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      payload: data.payload.present ? data.payload.value : this.payload,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TargetRow(')
          ..write('id: $id, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('payload: $payload, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, normalizedName, payload, revision, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TargetRow &&
          other.id == this.id &&
          other.normalizedName == this.normalizedName &&
          other.payload == this.payload &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TargetRowsCompanion extends UpdateCompanion<TargetRow> {
  final Value<String> id;
  final Value<String> normalizedName;
  final Value<String> payload;
  final Value<int> revision;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TargetRowsCompanion({
    this.id = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.payload = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TargetRowsCompanion.insert({
    required String id,
    required String normalizedName,
    required String payload,
    this.revision = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       normalizedName = Value(normalizedName),
       payload = Value(payload),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TargetRow> custom({
    Expression<String>? id,
    Expression<String>? normalizedName,
    Expression<String>? payload,
    Expression<int>? revision,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (payload != null) 'payload': payload,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TargetRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? normalizedName,
    Value<String>? payload,
    Value<int>? revision,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TargetRowsCompanion(
      id: id ?? this.id,
      normalizedName: normalizedName ?? this.normalizedName,
      payload: payload ?? this.payload,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
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
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('TargetRowsCompanion(')
          ..write('id: $id, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('payload: $payload, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DealRowsTable extends DealRows with TableInfo<$DealRowsTable, DealRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DealRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastRunIdMeta = const VerificationMeta(
    'lastRunId',
  );
  @override
  late final GeneratedColumn<String> lastRunId = GeneratedColumn<String>(
    'last_run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savingsMeta = const VerificationMeta(
    'savings',
  );
  @override
  late final GeneratedColumn<int> savings = GeneratedColumn<int>(
    'savings',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _favoriteMeta = const VerificationMeta(
    'favorite',
  );
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
    'favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dismissedMeta = const VerificationMeta(
    'dismissed',
  );
  @override
  late final GeneratedColumn<bool> dismissed = GeneratedColumn<bool>(
    'dismissed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dismissed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _firstSeenMeta = const VerificationMeta(
    'firstSeen',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeen = GeneratedColumn<DateTime>(
    'first_seen',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    payload,
    lastRunId,
    savings,
    favorite,
    dismissed,
    firstSeen,
    lastSeen,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deal_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<DealRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('last_run_id')) {
      context.handle(
        _lastRunIdMeta,
        lastRunId.isAcceptableOrUnknown(data['last_run_id']!, _lastRunIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lastRunIdMeta);
    }
    if (data.containsKey('savings')) {
      context.handle(
        _savingsMeta,
        savings.isAcceptableOrUnknown(data['savings']!, _savingsMeta),
      );
    } else if (isInserting) {
      context.missing(_savingsMeta);
    }
    if (data.containsKey('favorite')) {
      context.handle(
        _favoriteMeta,
        favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta),
      );
    }
    if (data.containsKey('dismissed')) {
      context.handle(
        _dismissedMeta,
        dismissed.isAcceptableOrUnknown(data['dismissed']!, _dismissedMeta),
      );
    }
    if (data.containsKey('first_seen')) {
      context.handle(
        _firstSeenMeta,
        firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_firstSeenMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DealRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DealRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      lastRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_run_id'],
      )!,
      savings: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}savings'],
      )!,
      favorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}favorite'],
      )!,
      dismissed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dismissed'],
      )!,
      firstSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_seen'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen'],
      )!,
    );
  }

  @override
  $DealRowsTable createAlias(String alias) {
    return $DealRowsTable(attachedDatabase, alias);
  }
}

class DealRow extends DataClass implements Insertable<DealRow> {
  final String id;
  final String payload;
  final String lastRunId;
  final int savings;
  final bool favorite;
  final bool dismissed;
  final DateTime firstSeen;
  final DateTime lastSeen;
  const DealRow({
    required this.id,
    required this.payload,
    required this.lastRunId,
    required this.savings,
    required this.favorite,
    required this.dismissed,
    required this.firstSeen,
    required this.lastSeen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['payload'] = Variable<String>(payload);
    map['last_run_id'] = Variable<String>(lastRunId);
    map['savings'] = Variable<int>(savings);
    map['favorite'] = Variable<bool>(favorite);
    map['dismissed'] = Variable<bool>(dismissed);
    map['first_seen'] = Variable<DateTime>(firstSeen);
    map['last_seen'] = Variable<DateTime>(lastSeen);
    return map;
  }

  DealRowsCompanion toCompanion(bool nullToAbsent) {
    return DealRowsCompanion(
      id: Value(id),
      payload: Value(payload),
      lastRunId: Value(lastRunId),
      savings: Value(savings),
      favorite: Value(favorite),
      dismissed: Value(dismissed),
      firstSeen: Value(firstSeen),
      lastSeen: Value(lastSeen),
    );
  }

  factory DealRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DealRow(
      id: serializer.fromJson<String>(json['id']),
      payload: serializer.fromJson<String>(json['payload']),
      lastRunId: serializer.fromJson<String>(json['lastRunId']),
      savings: serializer.fromJson<int>(json['savings']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      dismissed: serializer.fromJson<bool>(json['dismissed']),
      firstSeen: serializer.fromJson<DateTime>(json['firstSeen']),
      lastSeen: serializer.fromJson<DateTime>(json['lastSeen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'payload': serializer.toJson<String>(payload),
      'lastRunId': serializer.toJson<String>(lastRunId),
      'savings': serializer.toJson<int>(savings),
      'favorite': serializer.toJson<bool>(favorite),
      'dismissed': serializer.toJson<bool>(dismissed),
      'firstSeen': serializer.toJson<DateTime>(firstSeen),
      'lastSeen': serializer.toJson<DateTime>(lastSeen),
    };
  }

  DealRow copyWith({
    String? id,
    String? payload,
    String? lastRunId,
    int? savings,
    bool? favorite,
    bool? dismissed,
    DateTime? firstSeen,
    DateTime? lastSeen,
  }) => DealRow(
    id: id ?? this.id,
    payload: payload ?? this.payload,
    lastRunId: lastRunId ?? this.lastRunId,
    savings: savings ?? this.savings,
    favorite: favorite ?? this.favorite,
    dismissed: dismissed ?? this.dismissed,
    firstSeen: firstSeen ?? this.firstSeen,
    lastSeen: lastSeen ?? this.lastSeen,
  );
  DealRow copyWithCompanion(DealRowsCompanion data) {
    return DealRow(
      id: data.id.present ? data.id.value : this.id,
      payload: data.payload.present ? data.payload.value : this.payload,
      lastRunId: data.lastRunId.present ? data.lastRunId.value : this.lastRunId,
      savings: data.savings.present ? data.savings.value : this.savings,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      dismissed: data.dismissed.present ? data.dismissed.value : this.dismissed,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DealRow(')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('lastRunId: $lastRunId, ')
          ..write('savings: $savings, ')
          ..write('favorite: $favorite, ')
          ..write('dismissed: $dismissed, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    payload,
    lastRunId,
    savings,
    favorite,
    dismissed,
    firstSeen,
    lastSeen,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DealRow &&
          other.id == this.id &&
          other.payload == this.payload &&
          other.lastRunId == this.lastRunId &&
          other.savings == this.savings &&
          other.favorite == this.favorite &&
          other.dismissed == this.dismissed &&
          other.firstSeen == this.firstSeen &&
          other.lastSeen == this.lastSeen);
}

class DealRowsCompanion extends UpdateCompanion<DealRow> {
  final Value<String> id;
  final Value<String> payload;
  final Value<String> lastRunId;
  final Value<int> savings;
  final Value<bool> favorite;
  final Value<bool> dismissed;
  final Value<DateTime> firstSeen;
  final Value<DateTime> lastSeen;
  final Value<int> rowid;
  const DealRowsCompanion({
    this.id = const Value.absent(),
    this.payload = const Value.absent(),
    this.lastRunId = const Value.absent(),
    this.savings = const Value.absent(),
    this.favorite = const Value.absent(),
    this.dismissed = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DealRowsCompanion.insert({
    required String id,
    required String payload,
    required String lastRunId,
    required int savings,
    this.favorite = const Value.absent(),
    this.dismissed = const Value.absent(),
    required DateTime firstSeen,
    required DateTime lastSeen,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       payload = Value(payload),
       lastRunId = Value(lastRunId),
       savings = Value(savings),
       firstSeen = Value(firstSeen),
       lastSeen = Value(lastSeen);
  static Insertable<DealRow> custom({
    Expression<String>? id,
    Expression<String>? payload,
    Expression<String>? lastRunId,
    Expression<int>? savings,
    Expression<bool>? favorite,
    Expression<bool>? dismissed,
    Expression<DateTime>? firstSeen,
    Expression<DateTime>? lastSeen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payload != null) 'payload': payload,
      if (lastRunId != null) 'last_run_id': lastRunId,
      if (savings != null) 'savings': savings,
      if (favorite != null) 'favorite': favorite,
      if (dismissed != null) 'dismissed': dismissed,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DealRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? payload,
    Value<String>? lastRunId,
    Value<int>? savings,
    Value<bool>? favorite,
    Value<bool>? dismissed,
    Value<DateTime>? firstSeen,
    Value<DateTime>? lastSeen,
    Value<int>? rowid,
  }) {
    return DealRowsCompanion(
      id: id ?? this.id,
      payload: payload ?? this.payload,
      lastRunId: lastRunId ?? this.lastRunId,
      savings: savings ?? this.savings,
      favorite: favorite ?? this.favorite,
      dismissed: dismissed ?? this.dismissed,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (lastRunId.present) {
      map['last_run_id'] = Variable<String>(lastRunId.value);
    }
    if (savings.present) {
      map['savings'] = Variable<int>(savings.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (dismissed.present) {
      map['dismissed'] = Variable<bool>(dismissed.value);
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<DateTime>(firstSeen.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DealRowsCompanion(')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('lastRunId: $lastRunId, ')
          ..write('savings: $savings, ')
          ..write('favorite: $favorite, ')
          ..write('dismissed: $dismissed, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunRowsTable extends RunRows with TableInfo<$RunRowsTable, RunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scrapedMeta = const VerificationMeta(
    'scraped',
  );
  @override
  late final GeneratedColumn<int> scraped = GeneratedColumn<int>(
    'scraped',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dealsMeta = const VerificationMeta('deals');
  @override
  late final GeneratedColumn<int> deals = GeneratedColumn<int>(
    'deals',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _auditReportMeta = const VerificationMeta(
    'auditReport',
  );
  @override
  late final GeneratedColumn<String> auditReport = GeneratedColumn<String>(
    'audit_report',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _configurationMeta = const VerificationMeta(
    'configuration',
  );
  @override
  late final GeneratedColumn<String> configuration = GeneratedColumn<String>(
    'configuration',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    stage,
    startedAt,
    finishedAt,
    scraped,
    deals,
    error,
    auditReport,
    configuration,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    } else if (isInserting) {
      context.missing(_stageMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('scraped')) {
      context.handle(
        _scrapedMeta,
        scraped.isAcceptableOrUnknown(data['scraped']!, _scrapedMeta),
      );
    }
    if (data.containsKey('deals')) {
      context.handle(
        _dealsMeta,
        deals.isAcceptableOrUnknown(data['deals']!, _dealsMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('audit_report')) {
      context.handle(
        _auditReportMeta,
        auditReport.isAcceptableOrUnknown(
          data['audit_report']!,
          _auditReportMeta,
        ),
      );
    }
    if (data.containsKey('configuration')) {
      context.handle(
        _configurationMeta,
        configuration.isAcceptableOrUnknown(
          data['configuration']!,
          _configurationMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      scraped: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scraped'],
      )!,
      deals: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deals'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      auditReport: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audit_report'],
      ),
      configuration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}configuration'],
      ),
    );
  }

  @override
  $RunRowsTable createAlias(String alias) {
    return $RunRowsTable(attachedDatabase, alias);
  }
}

class RunRow extends DataClass implements Insertable<RunRow> {
  final String id;
  final String stage;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int scraped;
  final int deals;
  final String? error;
  final String? auditReport;
  final String? configuration;
  const RunRow({
    required this.id,
    required this.stage,
    required this.startedAt,
    this.finishedAt,
    required this.scraped,
    required this.deals,
    this.error,
    this.auditReport,
    this.configuration,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['stage'] = Variable<String>(stage);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    map['scraped'] = Variable<int>(scraped);
    map['deals'] = Variable<int>(deals);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    if (!nullToAbsent || auditReport != null) {
      map['audit_report'] = Variable<String>(auditReport);
    }
    if (!nullToAbsent || configuration != null) {
      map['configuration'] = Variable<String>(configuration);
    }
    return map;
  }

  RunRowsCompanion toCompanion(bool nullToAbsent) {
    return RunRowsCompanion(
      id: Value(id),
      stage: Value(stage),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      scraped: Value(scraped),
      deals: Value(deals),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      auditReport: auditReport == null && nullToAbsent
          ? const Value.absent()
          : Value(auditReport),
      configuration: configuration == null && nullToAbsent
          ? const Value.absent()
          : Value(configuration),
    );
  }

  factory RunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunRow(
      id: serializer.fromJson<String>(json['id']),
      stage: serializer.fromJson<String>(json['stage']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      scraped: serializer.fromJson<int>(json['scraped']),
      deals: serializer.fromJson<int>(json['deals']),
      error: serializer.fromJson<String?>(json['error']),
      auditReport: serializer.fromJson<String?>(json['auditReport']),
      configuration: serializer.fromJson<String?>(json['configuration']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'stage': serializer.toJson<String>(stage),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'scraped': serializer.toJson<int>(scraped),
      'deals': serializer.toJson<int>(deals),
      'error': serializer.toJson<String?>(error),
      'auditReport': serializer.toJson<String?>(auditReport),
      'configuration': serializer.toJson<String?>(configuration),
    };
  }

  RunRow copyWith({
    String? id,
    String? stage,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
    int? scraped,
    int? deals,
    Value<String?> error = const Value.absent(),
    Value<String?> auditReport = const Value.absent(),
    Value<String?> configuration = const Value.absent(),
  }) => RunRow(
    id: id ?? this.id,
    stage: stage ?? this.stage,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    scraped: scraped ?? this.scraped,
    deals: deals ?? this.deals,
    error: error.present ? error.value : this.error,
    auditReport: auditReport.present ? auditReport.value : this.auditReport,
    configuration: configuration.present
        ? configuration.value
        : this.configuration,
  );
  RunRow copyWithCompanion(RunRowsCompanion data) {
    return RunRow(
      id: data.id.present ? data.id.value : this.id,
      stage: data.stage.present ? data.stage.value : this.stage,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      scraped: data.scraped.present ? data.scraped.value : this.scraped,
      deals: data.deals.present ? data.deals.value : this.deals,
      error: data.error.present ? data.error.value : this.error,
      auditReport: data.auditReport.present
          ? data.auditReport.value
          : this.auditReport,
      configuration: data.configuration.present
          ? data.configuration.value
          : this.configuration,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunRow(')
          ..write('id: $id, ')
          ..write('stage: $stage, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('scraped: $scraped, ')
          ..write('deals: $deals, ')
          ..write('error: $error, ')
          ..write('auditReport: $auditReport, ')
          ..write('configuration: $configuration')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    stage,
    startedAt,
    finishedAt,
    scraped,
    deals,
    error,
    auditReport,
    configuration,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunRow &&
          other.id == this.id &&
          other.stage == this.stage &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.scraped == this.scraped &&
          other.deals == this.deals &&
          other.error == this.error &&
          other.auditReport == this.auditReport &&
          other.configuration == this.configuration);
}

class RunRowsCompanion extends UpdateCompanion<RunRow> {
  final Value<String> id;
  final Value<String> stage;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<int> scraped;
  final Value<int> deals;
  final Value<String?> error;
  final Value<String?> auditReport;
  final Value<String?> configuration;
  final Value<int> rowid;
  const RunRowsCompanion({
    this.id = const Value.absent(),
    this.stage = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.scraped = const Value.absent(),
    this.deals = const Value.absent(),
    this.error = const Value.absent(),
    this.auditReport = const Value.absent(),
    this.configuration = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunRowsCompanion.insert({
    required String id,
    required String stage,
    required DateTime startedAt,
    this.finishedAt = const Value.absent(),
    this.scraped = const Value.absent(),
    this.deals = const Value.absent(),
    this.error = const Value.absent(),
    this.auditReport = const Value.absent(),
    this.configuration = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       stage = Value(stage),
       startedAt = Value(startedAt);
  static Insertable<RunRow> custom({
    Expression<String>? id,
    Expression<String>? stage,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<int>? scraped,
    Expression<int>? deals,
    Expression<String>? error,
    Expression<String>? auditReport,
    Expression<String>? configuration,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (stage != null) 'stage': stage,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (scraped != null) 'scraped': scraped,
      if (deals != null) 'deals': deals,
      if (error != null) 'error': error,
      if (auditReport != null) 'audit_report': auditReport,
      if (configuration != null) 'configuration': configuration,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? stage,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<int>? scraped,
    Value<int>? deals,
    Value<String?>? error,
    Value<String?>? auditReport,
    Value<String?>? configuration,
    Value<int>? rowid,
  }) {
    return RunRowsCompanion(
      id: id ?? this.id,
      stage: stage ?? this.stage,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      scraped: scraped ?? this.scraped,
      deals: deals ?? this.deals,
      error: error ?? this.error,
      auditReport: auditReport ?? this.auditReport,
      configuration: configuration ?? this.configuration,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (scraped.present) {
      map['scraped'] = Variable<int>(scraped.value);
    }
    if (deals.present) {
      map['deals'] = Variable<int>(deals.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (auditReport.present) {
      map['audit_report'] = Variable<String>(auditReport.value);
    }
    if (configuration.present) {
      map['configuration'] = Variable<String>(configuration.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunRowsCompanion(')
          ..write('id: $id, ')
          ..write('stage: $stage, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('scraped: $scraped, ')
          ..write('deals: $deals, ')
          ..write('error: $error, ')
          ..write('auditReport: $auditReport, ')
          ..write('configuration: $configuration, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScanSnapshotsTable extends ScanSnapshots
    with TableInfo<$ScanSnapshotsTable, ScanSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [runId, payload, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {runId};
  @override
  ScanSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanSnapshot(
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ScanSnapshotsTable createAlias(String alias) {
    return $ScanSnapshotsTable(attachedDatabase, alias);
  }
}

class ScanSnapshot extends DataClass implements Insertable<ScanSnapshot> {
  final String runId;
  final String payload;
  final DateTime createdAt;
  const ScanSnapshot({
    required this.runId,
    required this.payload,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['run_id'] = Variable<String>(runId);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ScanSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return ScanSnapshotsCompanion(
      runId: Value(runId),
      payload: Value(payload),
      createdAt: Value(createdAt),
    );
  }

  factory ScanSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanSnapshot(
      runId: serializer.fromJson<String>(json['runId']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'runId': serializer.toJson<String>(runId),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ScanSnapshot copyWith({
    String? runId,
    String? payload,
    DateTime? createdAt,
  }) => ScanSnapshot(
    runId: runId ?? this.runId,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
  ScanSnapshot copyWithCompanion(ScanSnapshotsCompanion data) {
    return ScanSnapshot(
      runId: data.runId.present ? data.runId.value : this.runId,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanSnapshot(')
          ..write('runId: $runId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(runId, payload, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanSnapshot &&
          other.runId == this.runId &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt);
}

class ScanSnapshotsCompanion extends UpdateCompanion<ScanSnapshot> {
  final Value<String> runId;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ScanSnapshotsCompanion({
    this.runId = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScanSnapshotsCompanion.insert({
    required String runId,
    required String payload,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : runId = Value(runId),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<ScanSnapshot> custom({
    Expression<String>? runId,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (runId != null) 'run_id': runId,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScanSnapshotsCompanion copyWith({
    Value<String>? runId,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ScanSnapshotsCompanion(
      runId: runId ?? this.runId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanSnapshotsCompanion(')
          ..write('runId: $runId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppStateRowsTable extends AppStateRows
    with TableInfo<$AppStateRowsTable, AppStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppStateRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_state_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppStateRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppStateRowsTable createAlias(String alias) {
    return $AppStateRowsTable(attachedDatabase, alias);
  }
}

class AppStateRow extends DataClass implements Insertable<AppStateRow> {
  final String key;
  final String value;
  const AppStateRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppStateRowsCompanion toCompanion(bool nullToAbsent) {
    return AppStateRowsCompanion(key: Value(key), value: Value(value));
  }

  factory AppStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppStateRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppStateRow copyWith({String? key, String? value}) =>
      AppStateRow(key: key ?? this.key, value: value ?? this.value);
  AppStateRow copyWithCompanion(AppStateRowsCompanion data) {
    return AppStateRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppStateRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppStateRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppStateRowsCompanion extends UpdateCompanion<AppStateRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppStateRowsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppStateRowsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppStateRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppStateRowsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppStateRowsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppStateRowsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncJobRowsTable extends SyncJobRows
    with TableInfo<$SyncJobRowsTable, SyncJobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncJobRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_job_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncJobRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncJobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncJobRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $SyncJobRowsTable createAlias(String alias) {
    return $SyncJobRowsTable(attachedDatabase, alias);
  }
}

class SyncJobRow extends DataClass implements Insertable<SyncJobRow> {
  final String id;
  final String payload;
  const SyncJobRow({required this.id, required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  SyncJobRowsCompanion toCompanion(bool nullToAbsent) {
    return SyncJobRowsCompanion(id: Value(id), payload: Value(payload));
  }

  factory SyncJobRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncJobRow(
      id: serializer.fromJson<String>(json['id']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'payload': serializer.toJson<String>(payload),
    };
  }

  SyncJobRow copyWith({String? id, String? payload}) =>
      SyncJobRow(id: id ?? this.id, payload: payload ?? this.payload);
  SyncJobRow copyWithCompanion(SyncJobRowsCompanion data) {
    return SyncJobRow(
      id: data.id.present ? data.id.value : this.id,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncJobRow(')
          ..write('id: $id, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncJobRow &&
          other.id == this.id &&
          other.payload == this.payload);
}

class SyncJobRowsCompanion extends UpdateCompanion<SyncJobRow> {
  final Value<String> id;
  final Value<String> payload;
  final Value<int> rowid;
  const SyncJobRowsCompanion({
    this.id = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncJobRowsCompanion.insert({
    required String id,
    required String payload,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       payload = Value(payload);
  static Insertable<SyncJobRow> custom({
    Expression<String>? id,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncJobRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return SyncJobRowsCompanion(
      id: id ?? this.id,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncJobRowsCompanion(')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TargetRowsTable targetRows = $TargetRowsTable(this);
  late final $DealRowsTable dealRows = $DealRowsTable(this);
  late final $RunRowsTable runRows = $RunRowsTable(this);
  late final $ScanSnapshotsTable scanSnapshots = $ScanSnapshotsTable(this);
  late final $AppStateRowsTable appStateRows = $AppStateRowsTable(this);
  late final $SyncJobRowsTable syncJobRows = $SyncJobRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    targetRows,
    dealRows,
    runRows,
    scanSnapshots,
    appStateRows,
    syncJobRows,
  ];
}

typedef $$TargetRowsTableCreateCompanionBuilder = TargetRowsCompanion Function({
  required String id,
  required String normalizedName,
  required String payload,
  Value<int> revision,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$TargetRowsTableUpdateCompanionBuilder = TargetRowsCompanion Function({
  Value<String> id,
  Value<String> normalizedName,
  Value<String> payload,
  Value<int> revision,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$TargetRowsTableFilterComposer
    extends Composer<_$AppDatabase, $TargetRowsTable> {
  $$TargetRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TargetRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $TargetRowsTable> {
  $$TargetRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TargetRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TargetRowsTable> {
  $$TargetRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TargetRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TargetRowsTable,
          TargetRow,
          $$TargetRowsTableFilterComposer,
          $$TargetRowsTableOrderingComposer,
          $$TargetRowsTableAnnotationComposer,
          $$TargetRowsTableCreateCompanionBuilder,
          $$TargetRowsTableUpdateCompanionBuilder,
          (
            TargetRow,
            BaseReferences<_$AppDatabase, $TargetRowsTable, TargetRow>,
          ),
          TargetRow,
          PrefetchHooks Function()
        > {
  $$TargetRowsTableTableManager(_$AppDatabase db, $TargetRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TargetRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TargetRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TargetRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TargetRowsCompanion(
                id: id,
                normalizedName: normalizedName,
                payload: payload,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String normalizedName,
                required String payload,
                Value<int> revision = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TargetRowsCompanion.insert(
                id: id,
                normalizedName: normalizedName,
                payload: payload,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TargetRowsTable, TargetRow>(table),
                  BaseReferences<_$AppDatabase, $TargetRowsTable, TargetRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TargetRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TargetRowsTable,
      TargetRow,
      $$TargetRowsTableFilterComposer,
      $$TargetRowsTableOrderingComposer,
      $$TargetRowsTableAnnotationComposer,
      $$TargetRowsTableCreateCompanionBuilder,
      $$TargetRowsTableUpdateCompanionBuilder,
      (TargetRow, BaseReferences<_$AppDatabase, $TargetRowsTable, TargetRow>),
      TargetRow,
      PrefetchHooks Function()
    >;
typedef $$DealRowsTableCreateCompanionBuilder = DealRowsCompanion Function({
  required String id,
  required String payload,
  required String lastRunId,
  required int savings,
  Value<bool> favorite,
  Value<bool> dismissed,
  required DateTime firstSeen,
  required DateTime lastSeen,
  Value<int> rowid,
});
typedef $$DealRowsTableUpdateCompanionBuilder = DealRowsCompanion Function({
  Value<String> id,
  Value<String> payload,
  Value<String> lastRunId,
  Value<int> savings,
  Value<bool> favorite,
  Value<bool> dismissed,
  Value<DateTime> firstSeen,
  Value<DateTime> lastSeen,
  Value<int> rowid,
});

class $$DealRowsTableFilterComposer
    extends Composer<_$AppDatabase, $DealRowsTable> {
  $$DealRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastRunId => $composableBuilder(
    column: $table.lastRunId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get savings => $composableBuilder(
    column: $table.savings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dismissed => $composableBuilder(
    column: $table.dismissed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DealRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $DealRowsTable> {
  $$DealRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastRunId => $composableBuilder(
    column: $table.lastRunId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get savings => $composableBuilder(
    column: $table.savings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dismissed => $composableBuilder(
    column: $table.dismissed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DealRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DealRowsTable> {
  $$DealRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get lastRunId =>
      $composableBuilder(column: $table.lastRunId, builder: (column) => column);

  GeneratedColumn<int> get savings =>
      $composableBuilder(column: $table.savings, builder: (column) => column);

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  GeneratedColumn<bool> get dismissed =>
      $composableBuilder(column: $table.dismissed, builder: (column) => column);

  GeneratedColumn<DateTime> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);
}

class $$DealRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DealRowsTable,
          DealRow,
          $$DealRowsTableFilterComposer,
          $$DealRowsTableOrderingComposer,
          $$DealRowsTableAnnotationComposer,
          $$DealRowsTableCreateCompanionBuilder,
          $$DealRowsTableUpdateCompanionBuilder,
          (DealRow, BaseReferences<_$AppDatabase, $DealRowsTable, DealRow>),
          DealRow,
          PrefetchHooks Function()
        > {
  $$DealRowsTableTableManager(_$AppDatabase db, $DealRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DealRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DealRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DealRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> lastRunId = const Value.absent(),
                Value<int> savings = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
                Value<DateTime> firstSeen = const Value.absent(),
                Value<DateTime> lastSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DealRowsCompanion(
                id: id,
                payload: payload,
                lastRunId: lastRunId,
                savings: savings,
                favorite: favorite,
                dismissed: dismissed,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String payload,
                required String lastRunId,
                required int savings,
                Value<bool> favorite = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
                required DateTime firstSeen,
                required DateTime lastSeen,
                Value<int> rowid = const Value.absent(),
              }) => DealRowsCompanion.insert(
                id: id,
                payload: payload,
                lastRunId: lastRunId,
                savings: savings,
                favorite: favorite,
                dismissed: dismissed,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DealRowsTable, DealRow>(table),
                  BaseReferences<_$AppDatabase, $DealRowsTable, DealRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DealRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DealRowsTable,
      DealRow,
      $$DealRowsTableFilterComposer,
      $$DealRowsTableOrderingComposer,
      $$DealRowsTableAnnotationComposer,
      $$DealRowsTableCreateCompanionBuilder,
      $$DealRowsTableUpdateCompanionBuilder,
      (DealRow, BaseReferences<_$AppDatabase, $DealRowsTable, DealRow>),
      DealRow,
      PrefetchHooks Function()
    >;
typedef $$RunRowsTableCreateCompanionBuilder = RunRowsCompanion Function({
  required String id,
  required String stage,
  required DateTime startedAt,
  Value<DateTime?> finishedAt,
  Value<int> scraped,
  Value<int> deals,
  Value<String?> error,
  Value<String?> auditReport,
  Value<String?> configuration,
  Value<int> rowid,
});
typedef $$RunRowsTableUpdateCompanionBuilder = RunRowsCompanion Function({
  Value<String> id,
  Value<String> stage,
  Value<DateTime> startedAt,
  Value<DateTime?> finishedAt,
  Value<int> scraped,
  Value<int> deals,
  Value<String?> error,
  Value<String?> auditReport,
  Value<String?> configuration,
  Value<int> rowid,
});

class $$RunRowsTableFilterComposer
    extends Composer<_$AppDatabase, $RunRowsTable> {
  $$RunRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scraped => $composableBuilder(
    column: $table.scraped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deals => $composableBuilder(
    column: $table.deals,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get auditReport => $composableBuilder(
    column: $table.auditReport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configuration => $composableBuilder(
    column: $table.configuration,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RunRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $RunRowsTable> {
  $$RunRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scraped => $composableBuilder(
    column: $table.scraped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deals => $composableBuilder(
    column: $table.deals,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get auditReport => $composableBuilder(
    column: $table.auditReport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configuration => $composableBuilder(
    column: $table.configuration,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RunRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RunRowsTable> {
  $$RunRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scraped =>
      $composableBuilder(column: $table.scraped, builder: (column) => column);

  GeneratedColumn<int> get deals =>
      $composableBuilder(column: $table.deals, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<String> get auditReport => $composableBuilder(
    column: $table.auditReport,
    builder: (column) => column,
  );

  GeneratedColumn<String> get configuration => $composableBuilder(
    column: $table.configuration,
    builder: (column) => column,
  );
}

class $$RunRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RunRowsTable,
          RunRow,
          $$RunRowsTableFilterComposer,
          $$RunRowsTableOrderingComposer,
          $$RunRowsTableAnnotationComposer,
          $$RunRowsTableCreateCompanionBuilder,
          $$RunRowsTableUpdateCompanionBuilder,
          (RunRow, BaseReferences<_$AppDatabase, $RunRowsTable, RunRow>),
          RunRow,
          PrefetchHooks Function()
        > {
  $$RunRowsTableTableManager(_$AppDatabase db, $RunRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> scraped = const Value.absent(),
                Value<int> deals = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String?> auditReport = const Value.absent(),
                Value<String?> configuration = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunRowsCompanion(
                id: id,
                stage: stage,
                startedAt: startedAt,
                finishedAt: finishedAt,
                scraped: scraped,
                deals: deals,
                error: error,
                auditReport: auditReport,
                configuration: configuration,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String stage,
                required DateTime startedAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> scraped = const Value.absent(),
                Value<int> deals = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String?> auditReport = const Value.absent(),
                Value<String?> configuration = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunRowsCompanion.insert(
                id: id,
                stage: stage,
                startedAt: startedAt,
                finishedAt: finishedAt,
                scraped: scraped,
                deals: deals,
                error: error,
                auditReport: auditReport,
                configuration: configuration,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RunRowsTable, RunRow>(table),
                  BaseReferences<_$AppDatabase, $RunRowsTable, RunRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RunRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RunRowsTable,
      RunRow,
      $$RunRowsTableFilterComposer,
      $$RunRowsTableOrderingComposer,
      $$RunRowsTableAnnotationComposer,
      $$RunRowsTableCreateCompanionBuilder,
      $$RunRowsTableUpdateCompanionBuilder,
      (RunRow, BaseReferences<_$AppDatabase, $RunRowsTable, RunRow>),
      RunRow,
      PrefetchHooks Function()
    >;
typedef $$ScanSnapshotsTableCreateCompanionBuilder =
    ScanSnapshotsCompanion Function({
      required String runId,
      required String payload,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ScanSnapshotsTableUpdateCompanionBuilder =
    ScanSnapshotsCompanion Function({
      Value<String> runId,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ScanSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $ScanSnapshotsTable> {
  $$ScanSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanSnapshotsTable> {
  $$ScanSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanSnapshotsTable> {
  $$ScanSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ScanSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanSnapshotsTable,
          ScanSnapshot,
          $$ScanSnapshotsTableFilterComposer,
          $$ScanSnapshotsTableOrderingComposer,
          $$ScanSnapshotsTableAnnotationComposer,
          $$ScanSnapshotsTableCreateCompanionBuilder,
          $$ScanSnapshotsTableUpdateCompanionBuilder,
          (
            ScanSnapshot,
            BaseReferences<_$AppDatabase, $ScanSnapshotsTable, ScanSnapshot>,
          ),
          ScanSnapshot,
          PrefetchHooks Function()
        > {
  $$ScanSnapshotsTableTableManager(_$AppDatabase db, $ScanSnapshotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> runId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScanSnapshotsCompanion(
                runId: runId,
                payload: payload,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String runId,
                required String payload,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ScanSnapshotsCompanion.insert(
                runId: runId,
                payload: payload,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScanSnapshotsTable, ScanSnapshot>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ScanSnapshotsTable,
                    ScanSnapshot
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanSnapshotsTable,
      ScanSnapshot,
      $$ScanSnapshotsTableFilterComposer,
      $$ScanSnapshotsTableOrderingComposer,
      $$ScanSnapshotsTableAnnotationComposer,
      $$ScanSnapshotsTableCreateCompanionBuilder,
      $$ScanSnapshotsTableUpdateCompanionBuilder,
      (
        ScanSnapshot,
        BaseReferences<_$AppDatabase, $ScanSnapshotsTable, ScanSnapshot>,
      ),
      ScanSnapshot,
      PrefetchHooks Function()
    >;
typedef $$AppStateRowsTableCreateCompanionBuilder =
    AppStateRowsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppStateRowsTableUpdateCompanionBuilder =
    AppStateRowsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppStateRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AppStateRowsTable> {
  $$AppStateRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppStateRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppStateRowsTable> {
  $$AppStateRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppStateRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppStateRowsTable> {
  $$AppStateRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppStateRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppStateRowsTable,
          AppStateRow,
          $$AppStateRowsTableFilterComposer,
          $$AppStateRowsTableOrderingComposer,
          $$AppStateRowsTableAnnotationComposer,
          $$AppStateRowsTableCreateCompanionBuilder,
          $$AppStateRowsTableUpdateCompanionBuilder,
          (
            AppStateRow,
            BaseReferences<_$AppDatabase, $AppStateRowsTable, AppStateRow>,
          ),
          AppStateRow,
          PrefetchHooks Function()
        > {
  $$AppStateRowsTableTableManager(_$AppDatabase db, $AppStateRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppStateRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppStateRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppStateRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppStateRowsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppStateRowsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppStateRowsTable, AppStateRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AppStateRowsTable,
                    AppStateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppStateRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppStateRowsTable,
      AppStateRow,
      $$AppStateRowsTableFilterComposer,
      $$AppStateRowsTableOrderingComposer,
      $$AppStateRowsTableAnnotationComposer,
      $$AppStateRowsTableCreateCompanionBuilder,
      $$AppStateRowsTableUpdateCompanionBuilder,
      (
        AppStateRow,
        BaseReferences<_$AppDatabase, $AppStateRowsTable, AppStateRow>,
      ),
      AppStateRow,
      PrefetchHooks Function()
    >;
typedef $$SyncJobRowsTableCreateCompanionBuilder =
    SyncJobRowsCompanion Function({
      required String id,
      required String payload,
      Value<int> rowid,
    });
typedef $$SyncJobRowsTableUpdateCompanionBuilder =
    SyncJobRowsCompanion Function({
      Value<String> id,
      Value<String> payload,
      Value<int> rowid,
    });

class $$SyncJobRowsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncJobRowsTable> {
  $$SyncJobRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncJobRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncJobRowsTable> {
  $$SyncJobRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncJobRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncJobRowsTable> {
  $$SyncJobRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$SyncJobRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncJobRowsTable,
          SyncJobRow,
          $$SyncJobRowsTableFilterComposer,
          $$SyncJobRowsTableOrderingComposer,
          $$SyncJobRowsTableAnnotationComposer,
          $$SyncJobRowsTableCreateCompanionBuilder,
          $$SyncJobRowsTableUpdateCompanionBuilder,
          (
            SyncJobRow,
            BaseReferences<_$AppDatabase, $SyncJobRowsTable, SyncJobRow>,
          ),
          SyncJobRow,
          PrefetchHooks Function()
        > {
  $$SyncJobRowsTableTableManager(_$AppDatabase db, $SyncJobRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncJobRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncJobRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncJobRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncJobRowsCompanion(id: id, payload: payload, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => SyncJobRowsCompanion.insert(
                id: id,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncJobRowsTable, SyncJobRow>(table),
                  BaseReferences<_$AppDatabase, $SyncJobRowsTable, SyncJobRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncJobRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncJobRowsTable,
      SyncJobRow,
      $$SyncJobRowsTableFilterComposer,
      $$SyncJobRowsTableOrderingComposer,
      $$SyncJobRowsTableAnnotationComposer,
      $$SyncJobRowsTableCreateCompanionBuilder,
      $$SyncJobRowsTableUpdateCompanionBuilder,
      (
        SyncJobRow,
        BaseReferences<_$AppDatabase, $SyncJobRowsTable, SyncJobRow>,
      ),
      SyncJobRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TargetRowsTableTableManager get targetRows =>
      $$TargetRowsTableTableManager(_db, _db.targetRows);
  $$DealRowsTableTableManager get dealRows =>
      $$DealRowsTableTableManager(_db, _db.dealRows);
  $$RunRowsTableTableManager get runRows =>
      $$RunRowsTableTableManager(_db, _db.runRows);
  $$ScanSnapshotsTableTableManager get scanSnapshots =>
      $$ScanSnapshotsTableTableManager(_db, _db.scanSnapshots);
  $$AppStateRowsTableTableManager get appStateRows =>
      $$AppStateRowsTableTableManager(_db, _db.appStateRows);
  $$SyncJobRowsTableTableManager get syncJobRows =>
      $$SyncJobRowsTableTableManager(_db, _db.syncJobRows);
}

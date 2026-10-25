// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DevicesTable extends Devices with TableInfo<$DevicesTable, SavedDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serviceNameMeta = const VerificationMeta(
    'serviceName',
  );
  @override
  late final GeneratedColumn<String> serviceName = GeneratedColumn<String>(
    'service_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastHostMeta = const VerificationMeta(
    'lastHost',
  );
  @override
  late final GeneratedColumn<String> lastHost = GeneratedColumn<String>(
    'last_host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wolMacMeta = const VerificationMeta('wolMac');
  @override
  late final GeneratedColumn<String> wolMac = GeneratedColumn<String>(
    'wol_mac',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverKeyPinMeta = const VerificationMeta(
    'serverKeyPin',
  );
  @override
  late final GeneratedColumn<String> serverKeyPin = GeneratedColumn<String>(
    'server_key_pin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastConnectedAtMeta = const VerificationMeta(
    'lastConnectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastConnectedAt =
      GeneratedColumn<DateTime>(
        'last_connected_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    serviceName,
    displayName,
    lastHost,
    port,
    nickname,
    wolMac,
    serverKeyPin,
    lastConnectedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedDevice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('service_name')) {
      context.handle(
        _serviceNameMeta,
        serviceName.isAcceptableOrUnknown(
          data['service_name']!,
          _serviceNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serviceNameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('last_host')) {
      context.handle(
        _lastHostMeta,
        lastHost.isAcceptableOrUnknown(data['last_host']!, _lastHostMeta),
      );
    } else if (isInserting) {
      context.missing(_lastHostMeta);
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    } else if (isInserting) {
      context.missing(_portMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    }
    if (data.containsKey('wol_mac')) {
      context.handle(
        _wolMacMeta,
        wolMac.isAcceptableOrUnknown(data['wol_mac']!, _wolMacMeta),
      );
    }
    if (data.containsKey('server_key_pin')) {
      context.handle(
        _serverKeyPinMeta,
        serverKeyPin.isAcceptableOrUnknown(
          data['server_key_pin']!,
          _serverKeyPinMeta,
        ),
      );
    }
    if (data.containsKey('last_connected_at')) {
      context.handle(
        _lastConnectedAtMeta,
        lastConnectedAt.isAcceptableOrUnknown(
          data['last_connected_at']!,
          _lastConnectedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastConnectedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serviceName};
  @override
  SavedDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedDevice(
      serviceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      lastHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_host'],
      )!,
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      )!,
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      ),
      wolMac: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wol_mac'],
      ),
      serverKeyPin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_key_pin'],
      ),
      lastConnectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_connected_at'],
      )!,
    );
  }

  @override
  $DevicesTable createAlias(String alias) {
    return $DevicesTable(attachedDatabase, alias);
  }
}

class SavedDevice extends DataClass implements Insertable<SavedDevice> {
  /// mDNS service name; stable identity of the TV.
  final String serviceName;

  /// Name shown for the TV when no nickname is set.
  final String displayName;

  /// Last known host (IP address or hostname).
  final String lastHost;

  /// Remote-service TCP port.
  final int port;

  /// User-chosen name; `null` means use [displayName].
  final String? nickname;

  /// MAC address used for Wake-on-LAN, if the user set one.
  final String? wolMac;

  /// Hex SHA-256 of the TV's server key pinned at pairing; `null` means no
  /// trusted key and the TV must be paired again.
  final String? serverKeyPin;

  /// When the app last connected to this TV.
  final DateTime lastConnectedAt;
  const SavedDevice({
    required this.serviceName,
    required this.displayName,
    required this.lastHost,
    required this.port,
    this.nickname,
    this.wolMac,
    this.serverKeyPin,
    required this.lastConnectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['service_name'] = Variable<String>(serviceName);
    map['display_name'] = Variable<String>(displayName);
    map['last_host'] = Variable<String>(lastHost);
    map['port'] = Variable<int>(port);
    if (!nullToAbsent || nickname != null) {
      map['nickname'] = Variable<String>(nickname);
    }
    if (!nullToAbsent || wolMac != null) {
      map['wol_mac'] = Variable<String>(wolMac);
    }
    if (!nullToAbsent || serverKeyPin != null) {
      map['server_key_pin'] = Variable<String>(serverKeyPin);
    }
    map['last_connected_at'] = Variable<DateTime>(lastConnectedAt);
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      serviceName: Value(serviceName),
      displayName: Value(displayName),
      lastHost: Value(lastHost),
      port: Value(port),
      nickname: nickname == null && nullToAbsent
          ? const Value.absent()
          : Value(nickname),
      wolMac: wolMac == null && nullToAbsent
          ? const Value.absent()
          : Value(wolMac),
      serverKeyPin: serverKeyPin == null && nullToAbsent
          ? const Value.absent()
          : Value(serverKeyPin),
      lastConnectedAt: Value(lastConnectedAt),
    );
  }

  factory SavedDevice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedDevice(
      serviceName: serializer.fromJson<String>(json['serviceName']),
      displayName: serializer.fromJson<String>(json['displayName']),
      lastHost: serializer.fromJson<String>(json['lastHost']),
      port: serializer.fromJson<int>(json['port']),
      nickname: serializer.fromJson<String?>(json['nickname']),
      wolMac: serializer.fromJson<String?>(json['wolMac']),
      serverKeyPin: serializer.fromJson<String?>(json['serverKeyPin']),
      lastConnectedAt: serializer.fromJson<DateTime>(json['lastConnectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serviceName': serializer.toJson<String>(serviceName),
      'displayName': serializer.toJson<String>(displayName),
      'lastHost': serializer.toJson<String>(lastHost),
      'port': serializer.toJson<int>(port),
      'nickname': serializer.toJson<String?>(nickname),
      'wolMac': serializer.toJson<String?>(wolMac),
      'serverKeyPin': serializer.toJson<String?>(serverKeyPin),
      'lastConnectedAt': serializer.toJson<DateTime>(lastConnectedAt),
    };
  }

  SavedDevice copyWith({
    String? serviceName,
    String? displayName,
    String? lastHost,
    int? port,
    Value<String?> nickname = const Value.absent(),
    Value<String?> wolMac = const Value.absent(),
    Value<String?> serverKeyPin = const Value.absent(),
    DateTime? lastConnectedAt,
  }) => SavedDevice(
    serviceName: serviceName ?? this.serviceName,
    displayName: displayName ?? this.displayName,
    lastHost: lastHost ?? this.lastHost,
    port: port ?? this.port,
    nickname: nickname.present ? nickname.value : this.nickname,
    wolMac: wolMac.present ? wolMac.value : this.wolMac,
    serverKeyPin: serverKeyPin.present ? serverKeyPin.value : this.serverKeyPin,
    lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
  );
  SavedDevice copyWithCompanion(DevicesCompanion data) {
    return SavedDevice(
      serviceName: data.serviceName.present
          ? data.serviceName.value
          : this.serviceName,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      lastHost: data.lastHost.present ? data.lastHost.value : this.lastHost,
      port: data.port.present ? data.port.value : this.port,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      wolMac: data.wolMac.present ? data.wolMac.value : this.wolMac,
      serverKeyPin: data.serverKeyPin.present
          ? data.serverKeyPin.value
          : this.serverKeyPin,
      lastConnectedAt: data.lastConnectedAt.present
          ? data.lastConnectedAt.value
          : this.lastConnectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedDevice(')
          ..write('serviceName: $serviceName, ')
          ..write('displayName: $displayName, ')
          ..write('lastHost: $lastHost, ')
          ..write('port: $port, ')
          ..write('nickname: $nickname, ')
          ..write('wolMac: $wolMac, ')
          ..write('serverKeyPin: $serverKeyPin, ')
          ..write('lastConnectedAt: $lastConnectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serviceName,
    displayName,
    lastHost,
    port,
    nickname,
    wolMac,
    serverKeyPin,
    lastConnectedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedDevice &&
          other.serviceName == this.serviceName &&
          other.displayName == this.displayName &&
          other.lastHost == this.lastHost &&
          other.port == this.port &&
          other.nickname == this.nickname &&
          other.wolMac == this.wolMac &&
          other.serverKeyPin == this.serverKeyPin &&
          other.lastConnectedAt == this.lastConnectedAt);
}

class DevicesCompanion extends UpdateCompanion<SavedDevice> {
  final Value<String> serviceName;
  final Value<String> displayName;
  final Value<String> lastHost;
  final Value<int> port;
  final Value<String?> nickname;
  final Value<String?> wolMac;
  final Value<String?> serverKeyPin;
  final Value<DateTime> lastConnectedAt;
  final Value<int> rowid;
  const DevicesCompanion({
    this.serviceName = const Value.absent(),
    this.displayName = const Value.absent(),
    this.lastHost = const Value.absent(),
    this.port = const Value.absent(),
    this.nickname = const Value.absent(),
    this.wolMac = const Value.absent(),
    this.serverKeyPin = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicesCompanion.insert({
    required String serviceName,
    required String displayName,
    required String lastHost,
    required int port,
    this.nickname = const Value.absent(),
    this.wolMac = const Value.absent(),
    this.serverKeyPin = const Value.absent(),
    required DateTime lastConnectedAt,
    this.rowid = const Value.absent(),
  }) : serviceName = Value(serviceName),
       displayName = Value(displayName),
       lastHost = Value(lastHost),
       port = Value(port),
       lastConnectedAt = Value(lastConnectedAt);
  static Insertable<SavedDevice> custom({
    Expression<String>? serviceName,
    Expression<String>? displayName,
    Expression<String>? lastHost,
    Expression<int>? port,
    Expression<String>? nickname,
    Expression<String>? wolMac,
    Expression<String>? serverKeyPin,
    Expression<DateTime>? lastConnectedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serviceName != null) 'service_name': serviceName,
      if (displayName != null) 'display_name': displayName,
      if (lastHost != null) 'last_host': lastHost,
      if (port != null) 'port': port,
      if (nickname != null) 'nickname': nickname,
      if (wolMac != null) 'wol_mac': wolMac,
      if (serverKeyPin != null) 'server_key_pin': serverKeyPin,
      if (lastConnectedAt != null) 'last_connected_at': lastConnectedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicesCompanion copyWith({
    Value<String>? serviceName,
    Value<String>? displayName,
    Value<String>? lastHost,
    Value<int>? port,
    Value<String?>? nickname,
    Value<String?>? wolMac,
    Value<String?>? serverKeyPin,
    Value<DateTime>? lastConnectedAt,
    Value<int>? rowid,
  }) {
    return DevicesCompanion(
      serviceName: serviceName ?? this.serviceName,
      displayName: displayName ?? this.displayName,
      lastHost: lastHost ?? this.lastHost,
      port: port ?? this.port,
      nickname: nickname ?? this.nickname,
      wolMac: wolMac ?? this.wolMac,
      serverKeyPin: serverKeyPin ?? this.serverKeyPin,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serviceName.present) {
      map['service_name'] = Variable<String>(serviceName.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (lastHost.present) {
      map['last_host'] = Variable<String>(lastHost.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (wolMac.present) {
      map['wol_mac'] = Variable<String>(wolMac.value);
    }
    if (serverKeyPin.present) {
      map['server_key_pin'] = Variable<String>(serverKeyPin.value);
    }
    if (lastConnectedAt.present) {
      map['last_connected_at'] = Variable<DateTime>(lastConnectedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('serviceName: $serviceName, ')
          ..write('displayName: $displayName, ')
          ..write('lastHost: $lastHost, ')
          ..write('port: $port, ')
          ..write('nickname: $nickname, ')
          ..write('wolMac: $wolMac, ')
          ..write('serverKeyPin: $serverKeyPin, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShortcutsTable extends Shortcuts
    with TableInfo<$ShortcutsTable, ShortcutRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShortcutsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _packageMeta = const VerificationMeta(
    'package',
  );
  @override
  late final GeneratedColumn<String> package = GeneratedColumn<String>(
    'package',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _launchLinkMeta = const VerificationMeta(
    'launchLink',
  );
  @override
  late final GeneratedColumn<String> launchLink = GeneratedColumn<String>(
    'launch_link',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconUrlMeta = const VerificationMeta(
    'iconUrl',
  );
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
    'icon_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _customColorMeta = const VerificationMeta(
    'customColor',
  );
  @override
  late final GeneratedColumn<int> customColor = GeneratedColumn<int>(
    'custom_color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customIconMeta = const VerificationMeta(
    'customIcon',
  );
  @override
  late final GeneratedColumn<String> customIcon = GeneratedColumn<String>(
    'custom_icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    package,
    name,
    launchLink,
    iconUrl,
    isCustom,
    customColor,
    customIcon,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shortcuts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShortcutRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('package')) {
      context.handle(
        _packageMeta,
        package.isAcceptableOrUnknown(data['package']!, _packageMeta),
      );
    } else if (isInserting) {
      context.missing(_packageMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('launch_link')) {
      context.handle(
        _launchLinkMeta,
        launchLink.isAcceptableOrUnknown(data['launch_link']!, _launchLinkMeta),
      );
    } else if (isInserting) {
      context.missing(_launchLinkMeta);
    }
    if (data.containsKey('icon_url')) {
      context.handle(
        _iconUrlMeta,
        iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta),
      );
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('custom_color')) {
      context.handle(
        _customColorMeta,
        customColor.isAcceptableOrUnknown(
          data['custom_color']!,
          _customColorMeta,
        ),
      );
    }
    if (data.containsKey('custom_icon')) {
      context.handle(
        _customIconMeta,
        customIcon.isAcceptableOrUnknown(data['custom_icon']!, _customIconMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShortcutRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShortcutRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      package: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      launchLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}launch_link'],
      )!,
      iconUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_url'],
      ),
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      customColor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}custom_color'],
      ),
      customIcon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_icon'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $ShortcutsTable createAlias(String alias) {
    return $ShortcutsTable(attachedDatabase, alias);
  }
}

class ShortcutRow extends DataClass implements Insertable<ShortcutRow> {
  /// Row id.
  final int id;

  /// Android package name.
  final String package;

  /// Label shown on the shortcut.
  final String name;

  /// Deep link or market link used to launch the app.
  final String launchLink;

  /// Icon URL, if known.
  final String? iconUrl;

  /// Whether the user created this shortcut by hand.
  final bool isCustom;

  /// Custom tile colour as ARGB.
  final int? customColor;

  /// Custom icon identifier.
  final String? customIcon;

  /// Sort position in the shortcut row.
  final int position;
  const ShortcutRow({
    required this.id,
    required this.package,
    required this.name,
    required this.launchLink,
    this.iconUrl,
    required this.isCustom,
    this.customColor,
    this.customIcon,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['package'] = Variable<String>(package);
    map['name'] = Variable<String>(name);
    map['launch_link'] = Variable<String>(launchLink);
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    map['is_custom'] = Variable<bool>(isCustom);
    if (!nullToAbsent || customColor != null) {
      map['custom_color'] = Variable<int>(customColor);
    }
    if (!nullToAbsent || customIcon != null) {
      map['custom_icon'] = Variable<String>(customIcon);
    }
    map['position'] = Variable<int>(position);
    return map;
  }

  ShortcutsCompanion toCompanion(bool nullToAbsent) {
    return ShortcutsCompanion(
      id: Value(id),
      package: Value(package),
      name: Value(name),
      launchLink: Value(launchLink),
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
      isCustom: Value(isCustom),
      customColor: customColor == null && nullToAbsent
          ? const Value.absent()
          : Value(customColor),
      customIcon: customIcon == null && nullToAbsent
          ? const Value.absent()
          : Value(customIcon),
      position: Value(position),
    );
  }

  factory ShortcutRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShortcutRow(
      id: serializer.fromJson<int>(json['id']),
      package: serializer.fromJson<String>(json['package']),
      name: serializer.fromJson<String>(json['name']),
      launchLink: serializer.fromJson<String>(json['launchLink']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      customColor: serializer.fromJson<int?>(json['customColor']),
      customIcon: serializer.fromJson<String?>(json['customIcon']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'package': serializer.toJson<String>(package),
      'name': serializer.toJson<String>(name),
      'launchLink': serializer.toJson<String>(launchLink),
      'iconUrl': serializer.toJson<String?>(iconUrl),
      'isCustom': serializer.toJson<bool>(isCustom),
      'customColor': serializer.toJson<int?>(customColor),
      'customIcon': serializer.toJson<String?>(customIcon),
      'position': serializer.toJson<int>(position),
    };
  }

  ShortcutRow copyWith({
    int? id,
    String? package,
    String? name,
    String? launchLink,
    Value<String?> iconUrl = const Value.absent(),
    bool? isCustom,
    Value<int?> customColor = const Value.absent(),
    Value<String?> customIcon = const Value.absent(),
    int? position,
  }) => ShortcutRow(
    id: id ?? this.id,
    package: package ?? this.package,
    name: name ?? this.name,
    launchLink: launchLink ?? this.launchLink,
    iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
    isCustom: isCustom ?? this.isCustom,
    customColor: customColor.present ? customColor.value : this.customColor,
    customIcon: customIcon.present ? customIcon.value : this.customIcon,
    position: position ?? this.position,
  );
  ShortcutRow copyWithCompanion(ShortcutsCompanion data) {
    return ShortcutRow(
      id: data.id.present ? data.id.value : this.id,
      package: data.package.present ? data.package.value : this.package,
      name: data.name.present ? data.name.value : this.name,
      launchLink: data.launchLink.present
          ? data.launchLink.value
          : this.launchLink,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      customColor: data.customColor.present
          ? data.customColor.value
          : this.customColor,
      customIcon: data.customIcon.present
          ? data.customIcon.value
          : this.customIcon,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShortcutRow(')
          ..write('id: $id, ')
          ..write('package: $package, ')
          ..write('name: $name, ')
          ..write('launchLink: $launchLink, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('isCustom: $isCustom, ')
          ..write('customColor: $customColor, ')
          ..write('customIcon: $customIcon, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    package,
    name,
    launchLink,
    iconUrl,
    isCustom,
    customColor,
    customIcon,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShortcutRow &&
          other.id == this.id &&
          other.package == this.package &&
          other.name == this.name &&
          other.launchLink == this.launchLink &&
          other.iconUrl == this.iconUrl &&
          other.isCustom == this.isCustom &&
          other.customColor == this.customColor &&
          other.customIcon == this.customIcon &&
          other.position == this.position);
}

class ShortcutsCompanion extends UpdateCompanion<ShortcutRow> {
  final Value<int> id;
  final Value<String> package;
  final Value<String> name;
  final Value<String> launchLink;
  final Value<String?> iconUrl;
  final Value<bool> isCustom;
  final Value<int?> customColor;
  final Value<String?> customIcon;
  final Value<int> position;
  const ShortcutsCompanion({
    this.id = const Value.absent(),
    this.package = const Value.absent(),
    this.name = const Value.absent(),
    this.launchLink = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.customColor = const Value.absent(),
    this.customIcon = const Value.absent(),
    this.position = const Value.absent(),
  });
  ShortcutsCompanion.insert({
    this.id = const Value.absent(),
    required String package,
    required String name,
    required String launchLink,
    this.iconUrl = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.customColor = const Value.absent(),
    this.customIcon = const Value.absent(),
    required int position,
  }) : package = Value(package),
       name = Value(name),
       launchLink = Value(launchLink),
       position = Value(position);
  static Insertable<ShortcutRow> custom({
    Expression<int>? id,
    Expression<String>? package,
    Expression<String>? name,
    Expression<String>? launchLink,
    Expression<String>? iconUrl,
    Expression<bool>? isCustom,
    Expression<int>? customColor,
    Expression<String>? customIcon,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (package != null) 'package': package,
      if (name != null) 'name': name,
      if (launchLink != null) 'launch_link': launchLink,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (isCustom != null) 'is_custom': isCustom,
      if (customColor != null) 'custom_color': customColor,
      if (customIcon != null) 'custom_icon': customIcon,
      if (position != null) 'position': position,
    });
  }

  ShortcutsCompanion copyWith({
    Value<int>? id,
    Value<String>? package,
    Value<String>? name,
    Value<String>? launchLink,
    Value<String?>? iconUrl,
    Value<bool>? isCustom,
    Value<int?>? customColor,
    Value<String?>? customIcon,
    Value<int>? position,
  }) {
    return ShortcutsCompanion(
      id: id ?? this.id,
      package: package ?? this.package,
      name: name ?? this.name,
      launchLink: launchLink ?? this.launchLink,
      iconUrl: iconUrl ?? this.iconUrl,
      isCustom: isCustom ?? this.isCustom,
      customColor: customColor ?? this.customColor,
      customIcon: customIcon ?? this.customIcon,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (package.present) {
      map['package'] = Variable<String>(package.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (launchLink.present) {
      map['launch_link'] = Variable<String>(launchLink.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (customColor.present) {
      map['custom_color'] = Variable<int>(customColor.value);
    }
    if (customIcon.present) {
      map['custom_icon'] = Variable<String>(customIcon.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShortcutsCompanion(')
          ..write('id: $id, ')
          ..write('package: $package, ')
          ..write('name: $name, ')
          ..write('launchLink: $launchLink, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('isCustom: $isCustom, ')
          ..write('customColor: $customColor, ')
          ..write('customIcon: $customIcon, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

class $AppUsageTable extends AppUsage
    with TableInfo<$AppUsageTable, AppUsageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppUsageTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _packageMeta = const VerificationMeta(
    'package',
  );
  @override
  late final GeneratedColumn<String> package = GeneratedColumn<String>(
    'package',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seenCountMeta = const VerificationMeta(
    'seenCount',
  );
  @override
  late final GeneratedColumn<int> seenCount = GeneratedColumn<int>(
    'seen_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [package, seenCount, lastSeenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_usage';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppUsageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('package')) {
      context.handle(
        _packageMeta,
        package.isAcceptableOrUnknown(data['package']!, _packageMeta),
      );
    } else if (isInserting) {
      context.missing(_packageMeta);
    }
    if (data.containsKey('seen_count')) {
      context.handle(
        _seenCountMeta,
        seenCount.isAcceptableOrUnknown(data['seen_count']!, _seenCountMeta),
      );
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {package};
  @override
  AppUsageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUsageRow(
      package: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package'],
      )!,
      seenCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seen_count'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
    );
  }

  @override
  $AppUsageTable createAlias(String alias) {
    return $AppUsageTable(attachedDatabase, alias);
  }
}

class AppUsageRow extends DataClass implements Insertable<AppUsageRow> {
  /// Android package name.
  final String package;

  /// Number of times the app has been seen.
  final int seenCount;

  /// When the app was last seen.
  final DateTime lastSeenAt;
  const AppUsageRow({
    required this.package,
    required this.seenCount,
    required this.lastSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['package'] = Variable<String>(package);
    map['seen_count'] = Variable<int>(seenCount);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    return map;
  }

  AppUsageCompanion toCompanion(bool nullToAbsent) {
    return AppUsageCompanion(
      package: Value(package),
      seenCount: Value(seenCount),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory AppUsageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppUsageRow(
      package: serializer.fromJson<String>(json['package']),
      seenCount: serializer.fromJson<int>(json['seenCount']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'package': serializer.toJson<String>(package),
      'seenCount': serializer.toJson<int>(seenCount),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
    };
  }

  AppUsageRow copyWith({
    String? package,
    int? seenCount,
    DateTime? lastSeenAt,
  }) => AppUsageRow(
    package: package ?? this.package,
    seenCount: seenCount ?? this.seenCount,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );
  AppUsageRow copyWithCompanion(AppUsageCompanion data) {
    return AppUsageRow(
      package: data.package.present ? data.package.value : this.package,
      seenCount: data.seenCount.present ? data.seenCount.value : this.seenCount,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppUsageRow(')
          ..write('package: $package, ')
          ..write('seenCount: $seenCount, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(package, seenCount, lastSeenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUsageRow &&
          other.package == this.package &&
          other.seenCount == this.seenCount &&
          other.lastSeenAt == this.lastSeenAt);
}

class AppUsageCompanion extends UpdateCompanion<AppUsageRow> {
  final Value<String> package;
  final Value<int> seenCount;
  final Value<DateTime> lastSeenAt;
  final Value<int> rowid;
  const AppUsageCompanion({
    this.package = const Value.absent(),
    this.seenCount = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppUsageCompanion.insert({
    required String package,
    this.seenCount = const Value.absent(),
    required DateTime lastSeenAt,
    this.rowid = const Value.absent(),
  }) : package = Value(package),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<AppUsageRow> custom({
    Expression<String>? package,
    Expression<int>? seenCount,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (package != null) 'package': package,
      if (seenCount != null) 'seen_count': seenCount,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppUsageCompanion copyWith({
    Value<String>? package,
    Value<int>? seenCount,
    Value<DateTime>? lastSeenAt,
    Value<int>? rowid,
  }) {
    return AppUsageCompanion(
      package: package ?? this.package,
      seenCount: seenCount ?? this.seenCount,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (package.present) {
      map['package'] = Variable<String>(package.value);
    }
    if (seenCount.present) {
      map['seen_count'] = Variable<int>(seenCount.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppUsageCompanion(')
          ..write('package: $package, ')
          ..write('seenCount: $seenCount, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DevicesTable devices = $DevicesTable(this);
  late final $ShortcutsTable shortcuts = $ShortcutsTable(this);
  late final $AppUsageTable appUsage = $AppUsageTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    devices,
    shortcuts,
    appUsage,
  ];
}

typedef $$DevicesTableCreateCompanionBuilder =
    DevicesCompanion Function({
      required String serviceName,
      required String displayName,
      required String lastHost,
      required int port,
      Value<String?> nickname,
      Value<String?> wolMac,
      Value<String?> serverKeyPin,
      required DateTime lastConnectedAt,
      Value<int> rowid,
    });
typedef $$DevicesTableUpdateCompanionBuilder =
    DevicesCompanion Function({
      Value<String> serviceName,
      Value<String> displayName,
      Value<String> lastHost,
      Value<int> port,
      Value<String?> nickname,
      Value<String?> wolMac,
      Value<String?> serverKeyPin,
      Value<DateTime> lastConnectedAt,
      Value<int> rowid,
    });

class $$DevicesTableFilterComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serviceName => $composableBuilder(
    column: $table.serviceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastHost => $composableBuilder(
    column: $table.lastHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wolMac => $composableBuilder(
    column: $table.wolMac,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverKeyPin => $composableBuilder(
    column: $table.serverKeyPin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serviceName => $composableBuilder(
    column: $table.serviceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastHost => $composableBuilder(
    column: $table.lastHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wolMac => $composableBuilder(
    column: $table.wolMac,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverKeyPin => $composableBuilder(
    column: $table.serverKeyPin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serviceName => $composableBuilder(
    column: $table.serviceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastHost =>
      $composableBuilder(column: $table.lastHost, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get wolMac =>
      $composableBuilder(column: $table.wolMac, builder: (column) => column);

  GeneratedColumn<String> get serverKeyPin => $composableBuilder(
    column: $table.serverKeyPin,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => column,
  );
}

class $$DevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DevicesTable,
          SavedDevice,
          $$DevicesTableFilterComposer,
          $$DevicesTableOrderingComposer,
          $$DevicesTableAnnotationComposer,
          $$DevicesTableCreateCompanionBuilder,
          $$DevicesTableUpdateCompanionBuilder,
          (
            SavedDevice,
            BaseReferences<_$AppDatabase, $DevicesTable, SavedDevice>,
          ),
          SavedDevice,
          PrefetchHooks Function()
        > {
  $$DevicesTableTableManager(_$AppDatabase db, $DevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serviceName = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> lastHost = const Value.absent(),
                Value<int> port = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                Value<String?> wolMac = const Value.absent(),
                Value<String?> serverKeyPin = const Value.absent(),
                Value<DateTime> lastConnectedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion(
                serviceName: serviceName,
                displayName: displayName,
                lastHost: lastHost,
                port: port,
                nickname: nickname,
                wolMac: wolMac,
                serverKeyPin: serverKeyPin,
                lastConnectedAt: lastConnectedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serviceName,
                required String displayName,
                required String lastHost,
                required int port,
                Value<String?> nickname = const Value.absent(),
                Value<String?> wolMac = const Value.absent(),
                Value<String?> serverKeyPin = const Value.absent(),
                required DateTime lastConnectedAt,
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion.insert(
                serviceName: serviceName,
                displayName: displayName,
                lastHost: lastHost,
                port: port,
                nickname: nickname,
                wolMac: wolMac,
                serverKeyPin: serverKeyPin,
                lastConnectedAt: lastConnectedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DevicesTable,
      SavedDevice,
      $$DevicesTableFilterComposer,
      $$DevicesTableOrderingComposer,
      $$DevicesTableAnnotationComposer,
      $$DevicesTableCreateCompanionBuilder,
      $$DevicesTableUpdateCompanionBuilder,
      (SavedDevice, BaseReferences<_$AppDatabase, $DevicesTable, SavedDevice>),
      SavedDevice,
      PrefetchHooks Function()
    >;
typedef $$ShortcutsTableCreateCompanionBuilder =
    ShortcutsCompanion Function({
      Value<int> id,
      required String package,
      required String name,
      required String launchLink,
      Value<String?> iconUrl,
      Value<bool> isCustom,
      Value<int?> customColor,
      Value<String?> customIcon,
      required int position,
    });
typedef $$ShortcutsTableUpdateCompanionBuilder =
    ShortcutsCompanion Function({
      Value<int> id,
      Value<String> package,
      Value<String> name,
      Value<String> launchLink,
      Value<String?> iconUrl,
      Value<bool> isCustom,
      Value<int?> customColor,
      Value<String?> customIcon,
      Value<int> position,
    });

class $$ShortcutsTableFilterComposer
    extends Composer<_$AppDatabase, $ShortcutsTable> {
  $$ShortcutsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get package => $composableBuilder(
    column: $table.package,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get launchLink => $composableBuilder(
    column: $table.launchLink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customColor => $composableBuilder(
    column: $table.customColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customIcon => $composableBuilder(
    column: $table.customIcon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShortcutsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShortcutsTable> {
  $$ShortcutsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get package => $composableBuilder(
    column: $table.package,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get launchLink => $composableBuilder(
    column: $table.launchLink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customColor => $composableBuilder(
    column: $table.customColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customIcon => $composableBuilder(
    column: $table.customIcon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShortcutsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShortcutsTable> {
  $$ShortcutsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get package =>
      $composableBuilder(column: $table.package, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get launchLink => $composableBuilder(
    column: $table.launchLink,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<int> get customColor => $composableBuilder(
    column: $table.customColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customIcon => $composableBuilder(
    column: $table.customIcon,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$ShortcutsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShortcutsTable,
          ShortcutRow,
          $$ShortcutsTableFilterComposer,
          $$ShortcutsTableOrderingComposer,
          $$ShortcutsTableAnnotationComposer,
          $$ShortcutsTableCreateCompanionBuilder,
          $$ShortcutsTableUpdateCompanionBuilder,
          (
            ShortcutRow,
            BaseReferences<_$AppDatabase, $ShortcutsTable, ShortcutRow>,
          ),
          ShortcutRow,
          PrefetchHooks Function()
        > {
  $$ShortcutsTableTableManager(_$AppDatabase db, $ShortcutsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShortcutsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShortcutsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShortcutsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> package = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> launchLink = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<int?> customColor = const Value.absent(),
                Value<String?> customIcon = const Value.absent(),
                Value<int> position = const Value.absent(),
              }) => ShortcutsCompanion(
                id: id,
                package: package,
                name: name,
                launchLink: launchLink,
                iconUrl: iconUrl,
                isCustom: isCustom,
                customColor: customColor,
                customIcon: customIcon,
                position: position,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String package,
                required String name,
                required String launchLink,
                Value<String?> iconUrl = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<int?> customColor = const Value.absent(),
                Value<String?> customIcon = const Value.absent(),
                required int position,
              }) => ShortcutsCompanion.insert(
                id: id,
                package: package,
                name: name,
                launchLink: launchLink,
                iconUrl: iconUrl,
                isCustom: isCustom,
                customColor: customColor,
                customIcon: customIcon,
                position: position,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShortcutsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShortcutsTable,
      ShortcutRow,
      $$ShortcutsTableFilterComposer,
      $$ShortcutsTableOrderingComposer,
      $$ShortcutsTableAnnotationComposer,
      $$ShortcutsTableCreateCompanionBuilder,
      $$ShortcutsTableUpdateCompanionBuilder,
      (
        ShortcutRow,
        BaseReferences<_$AppDatabase, $ShortcutsTable, ShortcutRow>,
      ),
      ShortcutRow,
      PrefetchHooks Function()
    >;
typedef $$AppUsageTableCreateCompanionBuilder =
    AppUsageCompanion Function({
      required String package,
      Value<int> seenCount,
      required DateTime lastSeenAt,
      Value<int> rowid,
    });
typedef $$AppUsageTableUpdateCompanionBuilder =
    AppUsageCompanion Function({
      Value<String> package,
      Value<int> seenCount,
      Value<DateTime> lastSeenAt,
      Value<int> rowid,
    });

class $$AppUsageTableFilterComposer
    extends Composer<_$AppDatabase, $AppUsageTable> {
  $$AppUsageTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get package => $composableBuilder(
    column: $table.package,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seenCount => $composableBuilder(
    column: $table.seenCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppUsageTableOrderingComposer
    extends Composer<_$AppDatabase, $AppUsageTable> {
  $$AppUsageTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get package => $composableBuilder(
    column: $table.package,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seenCount => $composableBuilder(
    column: $table.seenCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppUsageTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppUsageTable> {
  $$AppUsageTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get package =>
      $composableBuilder(column: $table.package, builder: (column) => column);

  GeneratedColumn<int> get seenCount =>
      $composableBuilder(column: $table.seenCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );
}

class $$AppUsageTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppUsageTable,
          AppUsageRow,
          $$AppUsageTableFilterComposer,
          $$AppUsageTableOrderingComposer,
          $$AppUsageTableAnnotationComposer,
          $$AppUsageTableCreateCompanionBuilder,
          $$AppUsageTableUpdateCompanionBuilder,
          (
            AppUsageRow,
            BaseReferences<_$AppDatabase, $AppUsageTable, AppUsageRow>,
          ),
          AppUsageRow,
          PrefetchHooks Function()
        > {
  $$AppUsageTableTableManager(_$AppDatabase db, $AppUsageTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppUsageTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppUsageTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppUsageTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> package = const Value.absent(),
                Value<int> seenCount = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppUsageCompanion(
                package: package,
                seenCount: seenCount,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String package,
                Value<int> seenCount = const Value.absent(),
                required DateTime lastSeenAt,
                Value<int> rowid = const Value.absent(),
              }) => AppUsageCompanion.insert(
                package: package,
                seenCount: seenCount,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppUsageTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppUsageTable,
      AppUsageRow,
      $$AppUsageTableFilterComposer,
      $$AppUsageTableOrderingComposer,
      $$AppUsageTableAnnotationComposer,
      $$AppUsageTableCreateCompanionBuilder,
      $$AppUsageTableUpdateCompanionBuilder,
      (AppUsageRow, BaseReferences<_$AppDatabase, $AppUsageTable, AppUsageRow>),
      AppUsageRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
  $$ShortcutsTableTableManager get shortcuts =>
      $$ShortcutsTableTableManager(_db, _db.shortcuts);
  $$AppUsageTableTableManager get appUsage =>
      $$AppUsageTableTableManager(_db, _db.appUsage);
}

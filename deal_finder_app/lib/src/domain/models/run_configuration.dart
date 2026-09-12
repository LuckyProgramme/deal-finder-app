import 'dart:convert';

import 'json_structure.dart';
import 'target.dart';

/// A credential-free allowlist, not an arbitrary adapter metadata map.
final class AuditConfiguration {
  AuditConfiguration({
    required this.model,
    required this.endpointClass,
    required this.chunkSize,
    required this.promptSha256,
    required this.schemaSha256,
  }) {
    if (!RegExp(r'^[a-zA-Z0-9._-]{1,128}$').hasMatch(model) ||
        !RegExp(r'^[a-zA-Z][a-zA-Z0-9]{0,63}$').hasMatch(endpointClass) ||
        chunkSize < 1 ||
        chunkSize > 9007199254740991 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(promptSha256) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(schemaSha256)) {
      _invalid();
    }
  }
  final String model, endpointClass, promptSha256, schemaSha256;
  final int chunkSize;
  Map<String, Object?> toJson() => {
    'model': model,
    'endpointClass': endpointClass,
    'chunkSize': chunkSize,
    'promptSha256': promptSha256,
    'schemaSha256': schemaSha256,
  };
  factory AuditConfiguration.fromJson(Object? value) {
    final j = _object(value, {
      'model',
      'endpointClass',
      'chunkSize',
      'promptSha256',
      'schemaSha256',
    });
    return AuditConfiguration(
      model: _text(j['model']),
      endpointClass: _text(j['endpointClass']),
      chunkSize: _integer(j['chunkSize'], min: 1),
      promptSha256: _text(j['promptSha256']),
      schemaSha256: _text(j['schemaSha256']),
    );
  }
}

/// Exact execution inputs, stored separately from lossy/redacted diagnostics.
/// Null targets/auditor/sync mean preparation did not resolve that input, not an
/// empty selection or disabled sync. Credentials and non-execution notes have
/// no fields in this format. Local target policy text is private library data.
final class RunConfiguration {
  RunConfiguration({
    required this.auditMode,
    Iterable<String>? requestedTargetIds,
    this.limitPerSource,
    Iterable<Target>? targets,
    this.auditor,
    this.postRunSyncEnabled,
  }) : requestedTargetIds = requestedTargetIds == null
           ? null
           : Set.unmodifiable(requestedTargetIds),
       targets = targets == null
           ? null
           : List.unmodifiable(
               targets.map(
                 (target) => Target.fromJson({...target.toJson(), 'notes': ''}),
               ),
             ) {
    if (limitPerSource != null) _integer(limitPerSource, min: 1);
    final ids = this.requestedTargetIds;
    if (ids != null) {
      if (ids.length > maxTargets) _invalid();
      for (final id in ids) {
        _id(id);
      }
    }
    final captured = this.targets;
    if (captured != null) {
      if (captured.length > maxTargets) _invalid();
      final capturedIds = <String>{}, names = <String>{};
      for (final t in captured) {
        final policy = _policy(t.toJson()..remove('notes'));
        if (!policy.enabled ||
            !capturedIds.add(t.id) ||
            !names.add(t.name.toLowerCase()) ||
            (ids != null && !ids.contains(t.id))) {
          _invalid();
        }
      }
    }
    if (auditMode && postRunSyncEnabled == true) _invalid();
    _json = jsonEncode(_data());
    if (_json.length > maxBytes || utf8.encode(_json).length > maxBytes) {
      throw const FormatException(
        'Scan configuration exceeds the 16 MiB limit.',
      );
    }
  }

  static const version = 1;
  static const maxTargets = 20000;
  static const maxBytes = 16 * 1024 * 1024;
  final bool auditMode;
  final Set<String>? requestedTargetIds;
  final int? limitPerSource;
  final List<Target>? targets;
  final AuditConfiguration? auditor;
  final bool? postRunSyncEnabled;
  late final String _json;

  Map<String, Object?> _data() => {
    'version': version,
    'auditMode': auditMode,
    'requestedTargetIds': requestedTargetIds?.toList(),
    'limitPerSource': limitPerSource,
    'targets': targets?.map((t) => t.toJson()..remove('notes')).toList(),
    'auditor': auditor?.toJson(),
    'postRunSyncEnabled': postRunSyncEnabled,
  };
  String encode() => _json;
  Map<String, dynamic> toJson() => jsonDecode(_json) as Map<String, dynamic>;

  RunConfiguration withResolved({
    Iterable<Target>? targets,
    AuditConfiguration? auditor,
    bool? postRunSyncEnabled,
  }) => RunConfiguration(
    auditMode: auditMode,
    requestedTargetIds: requestedTargetIds,
    limitPerSource: limitPerSource,
    targets: targets ?? this.targets,
    auditor: auditor ?? this.auditor,
    postRunSyncEnabled: postRunSyncEnabled ?? this.postRunSyncEnabled,
  );

  factory RunConfiguration.decode(String text) {
    try {
      if (text.length > maxBytes || utf8.encode(text).length > maxBytes) {
        _invalid();
      }
      validateJsonStructure(text);
      return RunConfiguration.fromJson(jsonDecode(text));
    } catch (_) {
      throw const FormatException('Invalid scan configuration.');
    }
  }

  factory RunConfiguration.fromJson(Object? value) {
    try {
      final j = _object(value, {
        'version',
        'auditMode',
        'requestedTargetIds',
        'limitPerSource',
        'targets',
        'auditor',
        'postRunSyncEnabled',
      });
      if (j['version'] is! int ||
          j['version'] != version ||
          j['auditMode'] is! bool ||
          (j['postRunSyncEnabled'] != null &&
              j['postRunSyncEnabled'] is! bool)) {
        _invalid();
      }
      final requested = j['requestedTargetIds'] == null
          ? null
          : _strings(j['requestedTargetIds'], maxCount: maxTargets);
      if (requested != null && requested.toSet().length != requested.length) {
        _invalid();
      }
      final rawTargets = j['targets'];
      if (rawTargets != null &&
          (rawTargets is! List || rawTargets.length > maxTargets)) {
        _invalid();
      }
      return RunConfiguration(
        auditMode: j['auditMode'] as bool,
        requestedTargetIds: requested,
        limitPerSource: j['limitPerSource'] == null
            ? null
            : _integer(j['limitPerSource'], min: 1),
        targets: rawTargets == null ? null : (rawTargets as List).map(_policy),
        auditor: j['auditor'] == null
            ? null
            : AuditConfiguration.fromJson(j['auditor']),
        postRunSyncEnabled: j['postRunSyncEnabled'] as bool?,
      );
    } catch (_) {
      throw const FormatException('Invalid scan configuration.');
    }
  }
}

Never _invalid() => throw const FormatException('Invalid scan configuration.');
Map<String, dynamic> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      !value.keys.every(keys.contains)) {
    _invalid();
  }
  return value;
}

String _text(Object? value, {int max = 65536}) {
  if (value is! String || value.length > max || value.contains('\u0000')) {
    _invalid();
  }
  return value;
}

String _id(Object? value) {
  final id = _text(value, max: 200);
  if (id.trim().isEmpty ||
      id != id.trim() ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(id)) {
    _invalid();
  }
  return id;
}

int _integer(Object? value, {int min = 0}) {
  if (value is! int || value < min || value > 9007199254740991) _invalid();
  return value;
}

List<String> _strings(Object? value, {int maxCount = 1000}) {
  if (value is! List || value.length > maxCount) _invalid();
  return value.map((s) => _text(s)).toList();
}

Target _policy(Object? value) {
  final j = _object(value, {
    'id',
    'name',
    'category',
    'dealPrice',
    'retailPrice',
    'searchMode',
    'type',
    'allowBundle',
    'enabled',
    'downsizingKeywords',
    'freebieKeywords',
    'revision',
  });
  _id(j['id']);
  if (_text(j['name']).trim() != j['name']) _invalid();
  _text(j['category']);
  _integer(j['revision']);
  _integer(j['dealPrice'], min: 1);
  if (j['retailPrice'] != null) _integer(j['retailPrice'], min: 1);
  _strings(j['downsizingKeywords']);
  _strings(j['freebieKeywords']);
  return Target.fromJson({...j, 'notes': ''});
}

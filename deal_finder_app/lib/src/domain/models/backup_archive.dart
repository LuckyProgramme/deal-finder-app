import 'dart:convert';

import 'deal.dart';
import 'listing.dart';
import 'run_snapshot.dart';
import 'sync_job.dart';
import 'target.dart';
import 'run_configuration.dart';
import 'json_structure.dart';

/// Portable library data, never secure-storage entries or arbitrary app state.
/// Keep the validated representation private: a preview cannot be mutated before
/// its replacement transaction. The version is independent of Drift's schema.
final class BackupArchive {
  BackupArchive._(this._json, this.createdAt, this.counts);
  static const maxBytes = 32 * 1024 * 1024;
  static const maxRows = 20000;
  static const version = 2;
  final String _json;
  final DateTime createdAt;
  final Map<String, int> counts;
  String encode() => _json;
  Map<String, dynamic> toJson() => jsonDecode(_json) as Map<String, dynamic>;

  factory BackupArchive.decode(String text) {
    try {
      if (text.length > maxBytes || utf8.encode(text).length > maxBytes) {
        throw const FormatException('Backup exceeds the 32 MiB limit.');
      }
      validateJsonStructure(text);
      final root = _object(jsonDecode(text), {
        'format',
        'version',
        'databaseSchema',
        'createdAt',
        'targets',
        'deals',
        'runs',
        'snapshots',
        'syncJobs',
        'currentRunId',
      });
      final legacy = root['version'] == 1 && root['databaseSchema'] == 2;
      final compatible =
          root['version'] == version && {3, 4}.contains(root['databaseSchema']);
      if (root['format'] != 'deal-finder-library' ||
          root['version'] is! int ||
          root['databaseSchema'] is! int ||
          (!legacy && !compatible)) {
        throw const FormatException('Unsupported Deal Finder backup version.');
      }
      final created = _date(root['createdAt']);
      final targets = _rows(root['targets']);
      final deals = _rows(root['deals']);
      final runs = _rows(root['runs']);
      final snapshots = _rows(root['snapshots']);
      final jobs = _rows(root['syncJobs']);
      final names = <String>{};
      _unique(targets, (raw) {
        final row = _object(raw, {'target', 'createdAt', 'updatedAt'});
        final target = _target(row['target']);
        if (!names.add(target.name.toLowerCase())) _invalid();
        if (_date(row['updatedAt']).isBefore(_date(row['createdAt']))) {
          _invalid();
        }
        return target.id;
      });
      _unique(deals, (raw) {
        final row = _object(raw, {'deal', 'lastRunId'});
        _id(row['lastRunId']);
        return _deal(row['deal']).id;
      });
      _unique(runs, (raw) {
        final row = _object(raw, {
          'id',
          'stage',
          'startedAt',
          'finishedAt',
          'scraped',
          'deals',
          'error',
          'auditReport',
          if (!legacy) 'configuration',
        });
        _id(row['id']);
        const stages = {
          'preparing',
          'scraping',
          'filtering',
          'auditing',
          'persisting',
          'syncingSheets',
          'cancelling',
          'cancelled',
          'failed',
          'completed',
          'completedWithWarnings',
          'interrupted',
        };
        if (!stages.contains(row['stage'])) _invalid();
        final start = _date(row['startedAt']);
        if (row['finishedAt'] != null &&
            _date(row['finishedAt']).isBefore(start)) {
          _invalid();
        }
        _integer(row['scraped']);
        _integer(row['deals']);
        _nullableText(row['error'], max: 4096);
        _nullableText(row['auditReport'], max: 1024 * 1024);
        if (!legacy && row['configuration'] != null) {
          RunConfiguration.fromJson(row['configuration']);
        }
        return row['id'] as String;
      });
      final snapshotIds = _unique(snapshots, (raw) => _snapshot(raw).runId);
      if (root['currentRunId'] != null &&
          !snapshotIds.contains(root['currentRunId'])) {
        _invalid();
      }
      if (root['currentRunId'] != null) {
        final current = snapshots.cast<Map<String, dynamic>>().singleWhere(
          (s) => s['runId'] == root['currentRunId'],
        );
        final observedIds = (current['deals'] as List)
            .map((d) => d['listing']['id'])
            .toSet();
        final currentIds = deals
            .where((d) => d['lastRunId'] == root['currentRunId'])
            .map((d) => d['deal']['listing']['id'])
            .toSet();
        if (observedIds.length != currentIds.length ||
            !observedIds.containsAll(currentIds)) {
          _invalid();
        }
      }
      _unique(jobs, (raw) {
        final row = _object(raw, {
          'id',
          'destination',
          'snapshot',
          'payloadHash',
          'attempts',
          'state',
          'error',
          'completedTabs',
        });
        _id(row['id'], max: 512);
        if (!RegExp(r'^[A-Za-z0-9_-]{20,200}$')
            .hasMatch(_text(row['destination']))) {
          _invalid();
        }
        final snapshot = _snapshot(row['snapshot']);
        if (row['id'] != '${snapshot.runId}:${row['destination']}') _invalid();
        if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(_text(row['payloadHash']))) {
          _invalid();
        }
        _integer(row['attempts']);
        if (!{
          'queued',
          'uploading',
          'completed',
          'failed',
          'cancelled',
        }.contains(row['state'])) {
          _invalid();
        }
        _nullableText(row['error'], max: 4096);
        final tabs = _strings(row['completedTabs'], maxCount: 3);
        if (tabs.toSet().length != tabs.length ||
            tabs.any(
              (t) => !{'History', 'All Listings', 'Current Deals'}.contains(t),
            )) {
          _invalid();
        }
        return SyncJob.fromJson(row).id;
      });
      final normalized = jsonEncode({
        ...root,
        'version': version,
        'databaseSchema': 4,
        'runs': [
          for (final row in runs)
            {...row as Map<String, dynamic>, if (legacy) 'configuration': null},
        ],
      });
      if (normalized.length > maxBytes ||
          utf8.encode(normalized).length > maxBytes) {
        throw const FormatException('Backup exceeds the 32 MiB limit.');
      }
      return BackupArchive._(
        normalized,
        created,
        Map.unmodifiable({
          'targets': targets.length,
          'deals': deals.length,
          'runs': runs.length,
          'snapshots': snapshots.length,
          'syncJobs': jobs.length,
        }),
      );
    } on FormatException catch (error) {
      // Parser error messages can embed file contents. Only expose our constants.
      if (error.message == 'Backup exceeds the 32 MiB limit.' ||
          error.message == 'Unsupported Deal Finder backup version.') {
        rethrow;
      }
      throw const FormatException(
        'Invalid or inconsistent Deal Finder backup. No data was replaced.',
      );
    } on Object {
      throw const FormatException(
        'Invalid or inconsistent Deal Finder backup. No data was replaced.',
      );
    }
  }
}

Never _invalid() => throw const FormatException('Invalid backup');
Map<String, dynamic> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      !value.keys.every(keys.contains)) {
    _invalid();
  }
  return value;
}

List<dynamic> _rows(Object? value) {
  if (value is! List || value.length > BackupArchive.maxRows) _invalid();
  return value;
}

Set<String> _unique(List<dynamic> rows, String Function(dynamic) identity) {
  final ids = <String>{};
  for (final row in rows) {
    if (!ids.add(identity(row))) _invalid();
  }
  return ids;
}

String _text(Object? value, {int max = 65536}) {
  if (value is! String || value.length > max || value.contains('\u0000')) {
    _invalid();
  }
  return value;
}

void _nullableText(Object? value, {int max = 65536}) {
  if (value != null) _text(value, max: max);
}

String _id(Object? value, {int max = 200}) {
  final id = _text(value, max: max);
  if (id.trim().isEmpty ||
      id != id.trim() ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(id)) {
    _invalid();
  }
  return id;
}

int _integer(Object? value, {int min = 0, int max = 9007199254740991}) {
  if (value is! int || value < min || value > max) _invalid();
  return value;
}

DateTime _date(Object? value) {
  final date = DateTime.tryParse(_text(value, max: 40));
  if (date == null || !date.isUtc || date.toIso8601String() != value) {
    _invalid();
  }
  return date;
}

List<String> _strings(Object? value, {int maxCount = 1000}) {
  if (value is! List || value.length > maxCount) _invalid();
  return value.map((s) => _text(s)).toList();
}

Target _target(Object? raw) {
  final j = _object(raw, {
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
    'notes',
    'revision',
  });
  _id(j['id']);
  if (_text(j['name']).trim() != j['name']) _invalid();
  _text(j['category']);
  _text(j['notes']);
  _integer(j['revision']);
  _integer(j['dealPrice'], min: 1);
  if (j['retailPrice'] != null) _integer(j['retailPrice'], min: 1);
  _strings(j['downsizingKeywords']);
  _strings(j['freebieKeywords']);
  return Target.fromJson(j);
}

Listing _listing(Object? raw) {
  final j = _object(raw, {
    'id',
    'title',
    'price',
    'description',
    'condition',
    'link',
    'seller',
    'category',
    'thumbnailUrl',
    'sellerRating',
    'sellerRatingCount',
    'likeCount',
    'location',
    'listedAt',
    'eligibleTargetNames',
  });
  _id(j['id']);
  for (final key in [
    'title',
    'description',
    'condition',
    'link',
    'seller',
    'category',
  ]) {
    _text(j[key]);
  }
  for (final key in ['thumbnailUrl', 'location', 'listedAt']) {
    _nullableText(j[key]);
  }
  // Stored marketplace timestamps may be relative labels; preserve them verbatim.
  if (j['price'] != null) _integer(j['price']);
  for (final key in ['sellerRatingCount', 'likeCount']) {
    if (j[key] != null) _integer(j[key]);
  }
  final rating = j['sellerRating'];
  if (rating != null &&
      (rating is! num || !rating.isFinite || rating < 0 || rating > 5)) {
    _invalid();
  }
  if (j['eligibleTargetNames'] != null) _strings(j['eligibleTargetNames']);
  return Listing.fromJson(j);
}

Deal _deal(Object? raw) {
  final j = _object(raw, {
    'listing',
    'target',
    'price',
    'provenance',
    'finalCondition',
    'issues',
    'freebies',
    'isBundle',
    'priceEvidence',
    'isFavorite',
    'isDismissed',
    'firstSeen',
    'lastSeen',
  });
  _listing(j['listing']);
  _target(j['target']);
  _integer(j['price'], min: 1);
  _text(j['finalCondition']);
  _strings(j['issues']);
  _strings(j['freebies']);
  _nullableText(j['priceEvidence']);
  if (_date(j['lastSeen']).isBefore(_date(j['firstSeen']))) _invalid();
  final provenance = j['provenance'];
  if (provenance is! Map || provenance['source'] != 'gemini') {
    // Audit-only lexical matches must never enter the normal library by restore.
    _invalid();
  }
  _object(provenance, {'source', 'confidence', 'specsMatched'});
  _integer(provenance['confidence'], min: 80, max: 100);
  if (provenance['specsMatched'] != true) _invalid();
  if (j['isBundle'] == true &&
      ((j['target'] as Map)['allowBundle'] != true ||
          (j['priceEvidence'] as String? ?? '').trim().isEmpty ||
          (j['freebies'] as List).isNotEmpty)) {
    _invalid();
  }
  return Deal.fromJson(j);
}

RunSnapshot _snapshot(Object? raw) {
  final j = _object(raw, {
    'runId',
    'createdAt',
    'deals',
    'listings',
    'targets',
  });
  _id(j['runId']);
  _date(j['createdAt']);
  _unique(_rows(j['deals']), (r) => _deal(r).id);
  _unique(_rows(j['listings']), (r) => _listing(r).id);
  _unique(_rows(j['targets']), (r) => _target(r).id);
  return RunSnapshot.fromJson(j);
}

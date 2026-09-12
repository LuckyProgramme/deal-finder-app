import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';

import '../../application/pipeline/cancellation.dart';
import '../../application/pipeline/pipeline_ports.dart';
export '../../application/pipeline/pipeline_ports.dart'
    show Auditor, AuditBatch;
import '../network/bounded_dio.dart';
import '../../domain/models/audit.dart';
import '../../domain/models/run_configuration.dart';
import '../../domain/matching/candidate_filter.dart';
import '../../domain/matching/text_cleaner.dart';

final class GeminiService implements Auditor {
  GeminiService(
    this.client, {
    required this.key,
    required this.model,
    required this.prompt,
    this.chunkSize = 20,
  });
  final Dio client;
  final String key, model, prompt;
  final int chunkSize;
  @override
  AuditConfiguration get configuration => AuditConfiguration(
    model: model,
    endpointClass: 'generateContent',
    chunkSize: chunkSize,
    promptSha256: sha256.convert(utf8.encode(prompt)).toString(),
    schemaSha256: sha256.convert(utf8.encode(jsonEncode(schema))).toString(),
  );
  static final schema = <String, Object?>{
    'type': 'object',
    'required': ['audits'],
    'properties': {
      'audits': {
        'type': 'array',
        'items': {
          'type': 'object',
          'required': [
            'id',
            'matched_item',
            'confidence',
            'specs_matched',
            'issues',
            'freebies',
            'downgrade_condition',
            'is_accessory',
            'is_bundle',
            'individual_price',
            'separately_available',
            'price_evidence',
          ],
          'properties': {
            'id': {'type': 'string'},
            'matched_item': {
              'type': ['string', 'null'],
            },
            'confidence': {'type': 'integer', 'minimum': 0, 'maximum': 100},
            'specs_matched': {'type': 'boolean'},
            'issues': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'freebies': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'downgrade_condition': {'type': 'boolean'},
            'is_accessory': {'type': 'boolean'},
            'is_bundle': {'type': 'boolean'},
            'individual_price': {
              'type': ['number', 'null'],
            },
            'separately_available': {'type': 'boolean'},
            'price_evidence': {
              'type': ['string', 'null'],
            },
          },
        },
      },
    },
  };
  String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  @override
  Future<AuditBatch> audit(
    List<CandidateMatch> candidates,
    Cancellation c,
    FutureOr<void> Function(AuditProgress) progress,
  ) async {
    if (chunkSize < 1) throw ArgumentError('Chunk size must be positive');
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(model)) {
      throw ArgumentError('Invalid Gemini model');
    }
    final ids = candidates.map((c) => c.listing.id).toSet().toList();
    final result = <Audit>[],
        failed = <String>{},
        diagnostics = <Map<String, Object?>>[];
    for (var offset = 0; offset < ids.length; offset += chunkSize) {
      c.check();
      final chunkIds = ids.skip(offset).take(chunkSize).toSet();
      await progress(
        AuditingChunkStarted(
          offset ~/ chunkSize,
          (ids.length / chunkSize).ceil(),
          offset,
          ids.length,
        ),
      );
      final chunk = candidates
          .where((c) => chunkIds.contains(c.listing.id))
          .toList();
      final allowed = <String, Set<String>>{
        for (final id in chunkIds)
          id: chunk
              .where((c) => c.listing.id == id)
              .map((c) => c.target.name)
              .toSet(),
      };
      final targets = {for (final c in chunk) c.target.id: c.target}.values;
      final targetJson = [
        for (final t in targets)
          {
            'item_name': sanitizeText(redactPii(t.name)),
            'deal_price': double.parse(t.dealPrice.decimal),
            'target_type': t.type.name == 'game' ? 'Game' : 'Hardware',
            'allow_bundle_check': t.allowBundle,
          },
      ];
      final listingsXml = [
        for (final id in chunkIds)
          (() {
            final l = chunk.firstWhere((c) => c.listing.id == id).listing;
            return '<listing_untrusted_data id="${_xml(sanitizeText(l.id))}">\n<title>${_xml(sanitizeText(redactPii(l.title)))}</title>\n<price>${l.price?.decimal ?? '0.00'}</price>\n<description>${_xml(cleanDescription(l.description))}</description>\n</listing_untrusted_data>';
          })(),
      ].join('\n');
      final text = prompt
          .replaceAll('{target_items_json}', jsonEncode(targetJson))
          .replaceAll(
            '{allowed_targets_json}',
            jsonEncode(allowed.map((k, v) => MapEntry(k, v.toList()))),
          )
          .replaceAll('{candidate_listings_xml}', listingsXml);
      var attempts = 0;
      int? httpStatus;
      try {
        Object? payload;
        for (;;) {
          c.check();
          attempts++;
          httpStatus = null;
          try {
            final response = await boundedDioText(
              client,
              'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
              c,
              method: 'POST',
              onResponseStatus: (status) => httpStatus = status,
              allowedHosts: {'generativelanguage.googleapis.com'},
              headers: {'x-goog-api-key': key},
              data: {
                'contents': [
                  {
                    'role': 'user',
                    'parts': [
                      {'text': text},
                    ],
                  },
                ],
                'generationConfig': {
                  'responseFormat': {
                    'text': {'mimeType': 'APPLICATION_JSON', 'schema': schema},
                  },
                },
              },
            );
            final decoded = jsonDecode(response);
            final outputs = decoded is Map ? decoded['candidates'] : null;
            if (outputs is! List || outputs.isEmpty) {
              throw const FormatException('No Gemini candidate');
            }
            final parts = outputs.first['content']['parts'] as List;
            payload = jsonDecode(
              parts.whereType<Map>().map((p) => p['text'] ?? '').join().trim(),
            );
            break;
          } on DioException catch (e) {
            final status = e.response?.statusCode;
            httpStatus = status;
            if (attempts >= 2 ||
                (status != null && status < 500 && status != 429)) {
              rethrow;
            }
            await c.delay(Duration(seconds: attempts * 2));
          }
        }
        c.check();
        final validated = validateAudits(payload, allowed);
        result.addAll(validated.audits);
        failed.addAll(validated.missingIds);
        diagnostics.add({
          'chunk': offset ~/ chunkSize,
          'attempts': attempts,
          'missing': validated.missingIds.toList(),
          'unknown': validated.unknownIds.toList(),
          'errors': validated.errors,
        });
      } on RunCancelled {
        rethrow;
      } catch (e) {
        failed.addAll(chunkIds);
        // Never serialize an HTTP exception: it may contain headers or prompt text.
        diagnostics.add({
          'chunk': offset ~/ chunkSize,
          'attempts': attempts,
          'failedIds': chunkIds.toList(),
          'error': e is DioException
              ? 'Gemini HTTP ${e.response?.statusCode ?? 'network failure'}'
              : 'Invalid Gemini response',
        });
      }
      diagnostics.last.addAll({
        'model': model,
        'endpointClass': 'generateContent',
        'httpStatus': httpStatus,
      });
      await progress(
        AuditingChunkCompleted(
          offset ~/ chunkSize,
          (ids.length / chunkSize).ceil(),
          offset + chunkIds.length,
          ids.length,
          diagnostics.last,
        ),
      );
    }
    return AuditBatch(result, failed, diagnostics);
  }
}

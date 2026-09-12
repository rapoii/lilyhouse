import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../database/db_helper.dart';
import '../database/tables.dart';

class SyncResult {
  final bool isSuccess;
  final int syncedCount;
  final String? errorMessage;
  final List<String> processedIds;
  final List<Map<String, dynamic>> errors;

  const SyncResult({
    required this.isSuccess,
    required this.syncedCount,
    this.errorMessage,
    this.processedIds = const [],
    this.errors = const [],
  });
}

class RestoreResult {
  final bool isSuccess;
  final int totalCount;
  final Map<String, int> tableCounts;
  final String? errorMessage;

  const RestoreResult({
    required this.isSuccess,
    this.totalCount = 0,
    this.tableCounts = const {},
    this.errorMessage,
  });
}

class SyncService {
  final String endpointUrl;
  final DatabaseHelper dbHelper;
  final http.Client _client;

  SyncService({
    required this.endpointUrl,
    DatabaseHelper? dbHelper,
    http.Client? httpClient,
  })  : dbHelper = dbHelper ?? DatabaseHelper.instance,
        _client = httpClient ?? http.Client();

  Future<http.Response> _postWithRedirect(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final initialResponse = await _client.post(uri, headers: headers, body: body);
    if ((initialResponse.statusCode == 301 ||
            initialResponse.statusCode == 302 ||
            initialResponse.statusCode == 303 ||
            initialResponse.statusCode == 307 ||
            initialResponse.statusCode == 308) &&
        initialResponse.headers.containsKey('location')) {
      final redirectUrl = initialResponse.headers['location']!;
      return await _client.get(Uri.parse(redirectUrl));
    }
    return initialResponse;
  }

  /// Reads pending items in sync_queue, posts them in batch to Google Apps Script,
  /// and removes successfully processed records from the local sync queue.
  /// If [uploadLocalMedia] is true, checks for local image paths in payload and
  /// automatically uploads them to Google Drive via uploadMedia before sync.
  Future<SyncResult> syncPending({bool uploadLocalMedia = true}) async {
    try {
      await dbHelper.enqueueAllUnsyncedRecords();
      final pendingItems = await dbHelper.getPendingSyncItems();
      if (pendingItems.isEmpty) {
        return const SyncResult(
          isSuccess: true,
          syncedCount: 0,
        );
      }

      if (endpointUrl.isEmpty) {
        return const SyncResult(
          isSuccess: false,
          syncedCount: 0,
          errorMessage: 'URL endpoint sinkronisasi belum diatur.',
        );
      }

      final itemsPayload = <Map<String, dynamic>>[];
      for (final item in pendingItems) {
        var payloadStr = item['payload'] as String? ?? '{}';
        if (uploadLocalMedia) {
          try {
            final payloadMap = jsonDecode(payloadStr) as Map<String, dynamic>;
            bool modified = false;
            final photoFields = [
              'cover_photo',
              'photo_url',
              'proof_photo_url',
              'ktp_photo_url',
              'selfie_ktp_url',
            ];
            for (final field in photoFields) {
              final val = payloadMap[field];
              if (val is String &&
                  val.isNotEmpty &&
                  !val.startsWith('http://') &&
                  !val.startsWith('https://')) {
                final cleanPath =
                    val.startsWith('file://') ? val.replaceFirst('file://', '') : val;
                final file = File(cleanPath);
                if (file.existsSync()) {
                  try {
                    final bytes = await file.readAsBytes();
                    final base64Data = base64Encode(bytes);
                    final tableName = item['table_name'] as String;
                    final recordId = item['record_id'] as String;
                    final fileName = '${tableName}_${recordId}_$field.jpg';
                    final driveUrl = await uploadMedia(
                      fileName: fileName,
                      base64Data: base64Data,
                    );
                    if (driveUrl != null && driveUrl.isNotEmpty) {
                      payloadMap[field] = driveUrl;
                      modified = true;
                      try {
                        final db = await dbHelper.database;
                        await db.update(
                          tableName,
                          {field: driveUrl},
                          where: 'id = ?',
                          whereArgs: [recordId],
                        );
                      } catch (_) {}
                    }
                  } catch (_) {
                    // Continue even if one media fails to upload
                  }
                }
              }
            }

            if (modified) {
              payloadStr = jsonEncode(payloadMap);
              try {
                final db = await dbHelper.database;
                await db.update(
                  AppTables.syncQueue,
                  {'payload': payloadStr},
                  where: 'id = ?',
                  whereArgs: [item['id']],
                );
              } catch (_) {}
            }
          } catch (_) {}
        }

        itemsPayload.add({
          'id': item['id'],
          'table_name': item['table_name'],
          'record_id': item['record_id'],
          'action': item['action'],
          'payload': payloadStr,
        });
      }

      final requestBody = jsonEncode({
        'action': 'sync_batch',
        'items': itemsPayload,
      });

      final response = await _postWithRedirect(
        Uri.parse(endpointUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      if (response.statusCode != 200) {
        return SyncResult(
          isSuccess: false,
          syncedCount: 0,
          errorMessage: 'Server merespons dengan HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final status = responseData['status'] as String?;
      final processedRaw = responseData['processed_ids'] as List<dynamic>? ?? [];
      final processedIds = processedRaw.map((e) => e.toString()).toList();

      final errorsRaw = responseData['errors'] as List<dynamic>? ?? [];
      final errors = errorsRaw
          .whereType<Map<String, dynamic>>()
          .toList();

      // Clean up successfully synced records from queue
      for (final id in processedIds) {
        await dbHelper.removeSyncItem(id);
      }

      final isSuccess = status == 'success' && errors.isEmpty;
      String? errorMessage;
      if (!isSuccess) {
        if (errors.isNotEmpty) {
          errorMessage = errors.map((e) => e['error']?.toString() ?? 'Kesalahan item tidak diketahui').join('; ');
        } else {
          errorMessage = responseData['message']?.toString() ?? 'Sinkronisasi berakhir dengan status: $status';
        }
      }

      return SyncResult(
        isSuccess: isSuccess,
        syncedCount: processedIds.length,
        errorMessage: errorMessage,
        processedIds: processedIds,
        errors: errors,
      );
    } catch (e) {
      return SyncResult(
        isSuccess: false,
        syncedCount: 0,
        errorMessage: e.toString(),
      );
    }
  }

  /// Pulls all cloud tables (GAS fetch_all) and merges them into local SQLite.
  /// Skips overwriting records that are currently pending in sync_queue.
  Future<SyncResult> pullFromCloud() async {
    try {
      if (endpointUrl.isEmpty) {
        return const SyncResult(
          isSuccess: false,
          syncedCount: 0,
          errorMessage: 'URL endpoint sinkronisasi belum diatur.',
        );
      }

      final uri = Uri.parse(endpointUrl).replace(queryParameters: {'action': 'fetch_all'});
      final response = await _client.get(uri);

      if (response.statusCode != 200) {
        return SyncResult(
          isSuccess: false,
          syncedCount: 0,
          errorMessage: 'Server merespons dengan HTTP ${response.statusCode}',
        );
      }

      final Map<String, dynamic> responseData =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (responseData['status'] != 'success') {
        return SyncResult(
          isSuccess: false,
          syncedCount: 0,
          errorMessage: responseData['message']?.toString() ?? 'Gagal mengambil data cloud',
        );
      }

      final rawData = responseData['data'];
      if (rawData is! Map) {
        return const SyncResult(
          isSuccess: false,
          syncedCount: 0,
          errorMessage: 'Format data cloud tidak valid',
        );
      }

      final cloudData = <String, dynamic>{};
      rawData.forEach((k, v) => cloudData[k.toString()] = v);

      final counts = await dbHelper.mergeFromCloud(cloudData);
      final totalMerged = counts.values.fold<int>(0, (sum, c) => sum + c);

      return SyncResult(
        isSuccess: true,
        syncedCount: totalMerged,
      );
    } catch (e) {
      return SyncResult(
        isSuccess: false,
        syncedCount: 0,
        errorMessage: e.toString(),
      );
    }
  }

  /// Full 2-Way Sync:
  /// 1. Push: Uploads pending local offline changes to Google Sheets/Drive.
  /// 2. Pull: Downloads latest data from Google Sheets and merges into local SQLite.
  Future<SyncResult> syncTwoWay({bool uploadLocalMedia = true}) async {
    // 1. Push
    final pushResult = await syncPending(uploadLocalMedia: uploadLocalMedia);
    if (!pushResult.isSuccess &&
        pushResult.errorMessage != null &&
        !pushResult.errorMessage!.contains('belum diatur')) {
      return pushResult;
    }

    // 2. Pull
    final pullResult = await pullFromCloud();
    if (!pullResult.isSuccess) {
      return pullResult;
    }

    final totalEffect = pushResult.syncedCount + pullResult.syncedCount;
    return SyncResult(
      isSuccess: true,
      syncedCount: totalEffect,
    );
  }

  /// Downloads all cloud tables (GAS fetch_all) and replaces local tables.
  /// Returns per-table restored counts. Overwrites local rows — intended for
  /// fresh installs after uninstall. Sync queue is cleared on success.
  Future<RestoreResult> restoreFromCloud() async {
    try {
      if (endpointUrl.isEmpty) {
        return const RestoreResult(
          isSuccess: false,
          errorMessage: 'URL endpoint sinkronisasi belum diatur.',
        );
      }

      final uri = Uri.parse(endpointUrl).replace(queryParameters: {'action': 'fetch_all'});
      final response = await _client.get(uri);

      if (response.statusCode != 200) {
        return RestoreResult(
          isSuccess: false,
          errorMessage: 'Server merespons dengan HTTP ${response.statusCode}',
        );
      }

      final Map<String, dynamic> responseData =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (responseData['status'] != 'success') {
        return RestoreResult(
          isSuccess: false,
          errorMessage: responseData['message']?.toString() ?? 'Gagal mengambil data cloud',
        );
      }

      final rawData = responseData['data'];
      if (rawData is! Map) {
        return const RestoreResult(
          isSuccess: false,
          errorMessage: 'Format data cloud tidak valid',
        );
      }

      final cloudData = <String, dynamic>{};
      rawData.forEach((k, v) => cloudData[k.toString()] = v);

      final counts = await dbHelper.restoreAll(cloudData);
      final total = counts.values.fold<int>(0, (sum, c) => sum + c);
      return RestoreResult(
        isSuccess: true,
        totalCount: total,
        tableCounts: counts,
      );
    } catch (e) {
      return RestoreResult(
        isSuccess: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Uploads media file to Google Apps Script / Google Drive
  Future<String?> uploadMedia({
    required String fileName,
    required String base64Data,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      if (endpointUrl.isEmpty) {
        throw Exception('URL endpoint sinkronisasi belum diatur.');
      }

      final requestBody = jsonEncode({
        'action': 'upload_media',
        'file_name': fileName,
        'base64_data': base64Data,
        'mime_type': mimeType,
      });

      final response = await _postWithRedirect(
        Uri.parse(endpointUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      if (response.statusCode != 200) {
        throw Exception('Kesalahan HTTP ${response.statusCode}: ${response.body}');
      }

      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] == 'success') {
        return (data['file_url'] ?? data['url']) as String?;
      } else {
        throw Exception(data['message'] ?? 'Unggah gagal');
      }
    } catch (e) {
      rethrow;
    }
  }
}

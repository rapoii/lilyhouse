import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/db_helper.dart';

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

  /// Reads pending items in sync_queue, posts them in batch to Google Apps Script,
  /// and removes successfully processed records from the local sync queue.
  Future<SyncResult> syncPending() async {
    try {
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
          errorMessage: 'Sync endpoint URL is not configured.',
        );
      }

      final itemsPayload = pendingItems.map((item) {
        return {
          'id': item['id'],
          'table_name': item['table_name'],
          'record_id': item['record_id'],
          'action': item['action'],
          'payload': item['payload'],
        };
      }).toList();

      final requestBody = jsonEncode({
        'action': 'sync_batch',
        'items': itemsPayload,
      });

      final response = await _client.post(
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
          errorMessage: 'Server responded with HTTP ${response.statusCode}: ${response.body}',
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
          errorMessage = errors.map((e) => e['error']?.toString() ?? 'Unknown item error').join('; ');
        } else {
          errorMessage = responseData['message']?.toString() ?? 'Sync ended with status: $status';
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

  /// Uploads media file to Google Apps Script / Google Drive
  Future<String?> uploadMedia({
    required String fileName,
    required String base64Data,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      if (endpointUrl.isEmpty) {
        throw Exception('Sync endpoint URL is not configured.');
      }

      final requestBody = jsonEncode({
        'action': 'upload_media',
        'file_name': fileName,
        'base64_data': base64Data,
        'mime_type': mimeType,
      });

      final response = await _client.post(
        Uri.parse(endpointUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}: ${response.body}');
      }

      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] == 'success') {
        return data['url'] as String?;
      } else {
        throw Exception(data['message'] ?? 'Upload failed');
      }
    } catch (e) {
      rethrow;
    }
  }
}

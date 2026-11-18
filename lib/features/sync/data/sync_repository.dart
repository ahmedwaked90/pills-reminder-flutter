import 'package:dio/dio.dart';
import 'package:pills_reminder/core/network/api_client.dart';

class SyncResult {
  final DateTime serverTime;
  final List<String> applied;
  final List<Map<String, dynamic>> rejected;
  final List<Map<String, dynamic>> changes;

  const SyncResult({
    required this.serverTime,
    required this.applied,
    required this.rejected,
    required this.changes,
  });
}

class SyncRepository {
  final ApiClient _api;
  SyncRepository(this._api);

  Future<SyncResult> sync({
    DateTime? since,
    required List<Map<String, dynamic>> changes,
  }) async {
    final resp = await _api.dio.post(
      '/sync',
      data: {
        'since': since?.toUtc().toIso8601String(),
        'changes': changes,
      },
    );
    if (resp.statusCode != 200 || resp.data is! Map) {
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        type: DioExceptionType.badResponse,
        error: 'Sync failed (${resp.statusCode})',
      );
    }
    final data = Map<String, dynamic>.from(resp.data as Map);
    return SyncResult(
      serverTime: DateTime.parse(data['server_time'] as String),
      applied: (data['applied'] as List? ?? const []).cast<String>(),
      rejected: (data['rejected'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      changes: (data['changes'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}

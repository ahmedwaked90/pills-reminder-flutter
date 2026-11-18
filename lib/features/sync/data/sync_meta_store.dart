import 'package:hive_ce_flutter/hive_flutter.dart';

/// Sidecar box storing sync metadata keyed by the local MedicationModel
/// int `id`. Keeps MedicationModel's Hive schema untouched so existing
/// user data needs no migration.
///
/// Stored shape (plain Map, no adapter):
///   {
///     'uuid':       String,
///     'updatedAt':  int (millisSinceEpoch, UTC),
///     'deleted':    bool,
///   }
///
/// Also holds a few global keys:
///   'lastSyncAt' -> ISO-8601 string
///   'syncEnabled' -> bool
class SyncMetaStore {
  static const String boxName = 'medication_sync_meta';

  final Box _box;

  SyncMetaStore(this._box);

  static Future<SyncMetaStore> open() async {
    final box = await Hive.openBox(boxName);
    return SyncMetaStore(box);
  }

  Map<String, dynamic>? read(int medicationId) {
    final v = _box.get(medicationId);
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  Future<void> write(
    int medicationId, {
    required String uuid,
    required DateTime updatedAt,
    bool deleted = false,
  }) {
    return _box.put(medicationId, {
      'uuid': uuid,
      'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
      'deleted': deleted,
    });
  }

  Future<void> markDeleted(int medicationId) async {
    final existing = read(medicationId);
    if (existing == null) return;
    await _box.put(medicationId, {
      ...existing,
      'updatedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
      'deleted': true,
    });
  }

  Future<void> remove(int medicationId) => _box.delete(medicationId);

  /// Reverse lookup: local id for a given remote uuid, or null.
  int? idForUuid(String uuid) {
    for (final key in _box.keys) {
      final v = _box.get(key);
      if (v is Map && v['uuid'] == uuid) return key as int;
    }
    return null;
  }

  Iterable<int> medicationIds() =>
      _box.keys.whereType<int>();

  DateTime? get lastSyncAt {
    final raw = _box.get('lastSyncAt');
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Future<void> setLastSyncAt(DateTime at) =>
      _box.put('lastSyncAt', at.toUtc().toIso8601String());

  bool get syncEnabled => (_box.get('syncEnabled') as bool?) ?? false;
  Future<void> setSyncEnabled(bool v) => _box.put('syncEnabled', v);

  Future<void> clearAll() async {
    for (final key in _box.keys.toList()) {
      await _box.delete(key);
    }
  }
}

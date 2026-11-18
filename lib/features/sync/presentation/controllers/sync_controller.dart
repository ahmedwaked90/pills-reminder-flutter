import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import 'package:pills_reminder/features/auth/presentation/controllers/auth_controller.dart';
import 'package:pills_reminder/features/medications/data/models/medication_model.dart';
import 'package:pills_reminder/features/medications/presentation/controllers/medications_controller.dart';
import 'package:pills_reminder/features/sync/data/medication_mapper.dart';
import 'package:pills_reminder/features/sync/data/sync_meta_store.dart';
import 'package:pills_reminder/features/sync/data/sync_repository.dart';

class SyncController extends GetxController {
  SyncController({
    required SyncRepository repository,
    required SyncMetaStore metaStore,
  })  : _repo = repository,
        _meta = metaStore;

  final SyncRepository _repo;
  final SyncMetaStore _meta;
  final _uuid = const Uuid();

  final RxBool isSyncing = false.obs;
  final RxnString lastError = RxnString();
  final Rxn<DateTime> lastSyncAt = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();
    lastSyncAt.value = _meta.lastSyncAt;
  }

  /// Called right after Google sign-in succeeds. If the user already has
  /// local medications and no sync has ever run, asks whether to upload
  /// them or discard them.
  Future<void> onSignedIn() async {
    final medsController = Get.find<MedicationController>();
    final locals = medsController.medications;
    final firstEverSync = _meta.lastSyncAt == null;
    final hasLocalRows = locals.isNotEmpty;

    if (firstEverSync && hasLocalRows) {
      final choice = await _showFirstLoginDialog(locals.length);
      switch (choice) {
        case _FirstLoginChoice.cancel:
          return;
        case _FirstLoginChoice.discard:
          await _discardAllLocal(medsController);
          break;
        case _FirstLoginChoice.upload:
          // Nothing extra — regular sync below will push them up.
          break;
      }
    }

    await _meta.setSyncEnabled(true);
    await syncNow();
  }

  Future<void> syncNow() async {
    if (!Get.isRegistered<AuthController>()) return;
    final auth = Get.find<AuthController>();
    if (!auth.isSignedIn) return;
    if (isSyncing.value) return;

    isSyncing.value = true;
    lastError.value = null;

    try {
      final medsController = Get.find<MedicationController>();
      final locals = medsController.medications;

      final changes = <Map<String, dynamic>>[];
      final uuidByLocalId = <int, String>{};

      for (final entity in locals) {
        final full = await medsController.getMedication(entity.id);
        final existingMeta = _meta.read(full.id);
        final uuid = (existingMeta?['uuid'] as String?) ?? _uuid.v4();
        final updatedAt = existingMeta == null
            ? DateTime.now().toUtc()
            : DateTime.fromMillisecondsSinceEpoch(
                existingMeta['updatedAt'] as int, isUtc: true);
        uuidByLocalId[full.id] = uuid;

        if (existingMeta == null) {
          await _meta.write(full.id, uuid: uuid, updatedAt: updatedAt);
        }

        changes.add(MedicationMapper.toRemote(
          full,
          clientUuid: uuid,
          clientUpdatedAt: updatedAt,
        ));
      }

      // Also push tombstones for rows the user deleted locally.
      for (final medId in _meta.medicationIds()) {
        final rec = _meta.read(medId);
        if (rec == null) continue;
        final isTombstone = (rec['deleted'] as bool?) ?? false;
        if (!isTombstone) continue;
        changes.add({
          'client_uuid': rec['uuid'],
          'deleted': true,
          'client_updated_at': DateTime.fromMillisecondsSinceEpoch(
                  rec['updatedAt'] as int, isUtc: true)
              .toIso8601String(),
        });
      }

      final result = await _repo.sync(
        since: _meta.lastSyncAt,
        changes: changes,
      );

      await _applyServerChanges(result.changes, medsController);
      await _meta.setLastSyncAt(result.serverTime);
      lastSyncAt.value = result.serverTime;
    } catch (e) {
      lastError.value = e.toString();
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> _applyServerChanges(
    List<Map<String, dynamic>> serverChanges,
    MedicationController medsController,
  ) async {
    for (final row in serverChanges) {
      final uuid = row['client_uuid'] as String?;
      if (uuid == null) continue;
      final deleted = (row['deleted'] as bool?) ?? false;
      final existingLocalId = _meta.idForUuid(uuid);

      if (deleted) {
        if (existingLocalId != null) {
          await medsController.deleteMedication(existingLocalId);
          await _meta.remove(existingLocalId);
        }
        continue;
      }

      final localId = existingLocalId ?? _allocateLocalId(medsController);
      final model = MedicationMapper.fromRemote(row, localId: localId);
      final updatedAt = DateTime.tryParse(
            row['client_updated_at'] as String? ?? '',
          )?.toUtc() ??
          DateTime.now().toUtc();

      if (existingLocalId == null) {
        await medsController.addMedication(model);
      } else {
        await medsController.updateMedication(model);
      }
      await _meta.write(localId, uuid: uuid, updatedAt: updatedAt);
    }
  }

  int _allocateLocalId(MedicationController medsController) {
    final existing = medsController.medications.map((m) => m.id).toList()
      ..sort();
    final highest = existing.isEmpty ? 0 : existing.last;
    final metaMax = _meta.medicationIds().isEmpty
        ? 0
        : _meta.medicationIds().reduce((a, b) => a > b ? a : b);
    final start = (highest > metaMax ? highest : metaMax) + 1;
    return start;
  }

  Future<void> _discardAllLocal(MedicationController c) async {
    final ids = c.medications.map((m) => m.id).toList();
    for (final id in ids) {
      await c.deleteMedication(id);
    }
    await _meta.clearAll();
  }

  Future<_FirstLoginChoice?> _showFirstLoginDialog(int count) {
    return Get.dialog<_FirstLoginChoice>(
      AlertDialog(
        title: Text('firstLoginTitle'.tr),
        content: Text('firstLoginBody'.trParams({'n': '$count'})),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: _FirstLoginChoice.cancel),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: _FirstLoginChoice.discard),
            child: Text('firstLoginDiscard'.tr),
          ),
          FilledButton(
            onPressed: () => Get.back(result: _FirstLoginChoice.upload),
            child: Text('firstLoginUpload'.tr),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Should be called by the medications controller after a local
  /// add/update, so the sync meta is kept current and the next sync
  /// pushes the change.
  Future<void> markLocalWrite(MedicationModel med) async {
    final existing = _meta.read(med.id);
    final uuid = (existing?['uuid'] as String?) ?? _uuid.v4();
    await _meta.write(
      med.id,
      uuid: uuid,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Should be called just before a local hard-delete, so the next sync
  /// propagates the tombstone up to the server.
  Future<void> markLocalDelete(int id) => _meta.markDeleted(id);
}

enum _FirstLoginChoice { cancel, discard, upload }

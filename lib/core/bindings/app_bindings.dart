import 'package:get/get.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:pills_reminder/core/network/api_client.dart';
import 'package:pills_reminder/features/auth/data/auth_repository.dart';
import 'package:pills_reminder/features/auth/data/secure_token_storage.dart';
import 'package:pills_reminder/features/auth/presentation/controllers/auth_controller.dart';
import 'package:pills_reminder/features/medications/data/datasources/medication_local_data_source_impl.dart';
import 'package:pills_reminder/features/medications/data/models/medication_model.dart';
import 'package:pills_reminder/features/medications/data/repositories/medications_repo_impl.dart';
import 'package:pills_reminder/features/medications/presentation/controllers/medications_controller.dart';
import 'package:pills_reminder/features/notifications/data/repositories/notification_repo_impl.dart';
import 'package:pills_reminder/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:pills_reminder/features/sync/data/sync_meta_store.dart';
import 'package:pills_reminder/features/sync/data/sync_repository.dart';
import 'package:pills_reminder/features/sync/presentation/controllers/sync_controller.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    final Box<MedicationModel> box = Hive.box('medications');
    final localDataSource = MedicationLocalDataSourceImpl(box);
    Get.put<MedicationController>(
      MedicationController(
        MedicationsRepoImpl(localDataSource: localDataSource),
      ),
    );
    Get.put<NotificationsController>(
      NotificationsController(NotificationRepoImpl()),
    );

    // ---- Phase 2 — Laravel backend sync ----
    final tokenStorage = SecureTokenStorage();
    Get.put<SecureTokenStorage>(tokenStorage);
    final apiClient = ApiClient(tokenStorage);
    Get.put<ApiClient>(apiClient);
    final authRepo = AuthRepository(
      apiClient: apiClient,
      tokenStorage: tokenStorage,
    );
    Get.put<AuthRepository>(authRepo);
    Get.put<AuthController>(
      AuthController(authRepo, Hive.box('Settings')),
    );

    final syncMeta = SyncMetaStore(Hive.box(SyncMetaStore.boxName));
    Get.put<SyncMetaStore>(syncMeta);
    Get.put<SyncRepository>(SyncRepository(apiClient));
    Get.put<SyncController>(
      SyncController(
        repository: Get.find<SyncRepository>(),
        metaStore: syncMeta,
      ),
    );
  }
}

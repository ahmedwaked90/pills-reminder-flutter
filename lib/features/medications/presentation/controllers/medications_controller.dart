import 'package:get/get.dart';
import 'package:pills_reminder/features/medications/data/models/medication_model.dart';
import 'package:pills_reminder/features/medications/domain/entities/medication.dart';
import 'package:pills_reminder/features/medications/domain/repositories/medications_repo.dart';
import 'package:pills_reminder/features/sync/presentation/controllers/sync_controller.dart';

class MedicationController extends GetxController {
  final MedicationsRepo medicationsRepo;
  MedicationController(this.medicationsRepo);
  RxList<Medication> medications = <Medication>[].obs;
  final isReady = false.obs;

  @override
  void onInit() async {
    super.onInit();
    resetPillsProgress();
    getAllMedications();
    isReady.value = true;
  }

  void resetPillsProgress() async {
    medicationsRepo.resetProgress();
  }

  void getAllMedications() async {
    final data = await medicationsRepo.getAllMedications();
    medications.assignAll(data);
  }

  Future<MedicationModel> getMedication(int id) async {
    final data = await medicationsRepo.getMedication(id);
    return data;
  }

  Future<void> addMedication(MedicationModel med) async {
    await medicationsRepo.addMedication(med);
    await _notifySync((s) => s.markLocalWrite(med));
    getAllMedications();
  }

  Future<void> updateMedication(MedicationModel med) async {
    await medicationsRepo.updateMedication(med);
    await _notifySync((s) => s.markLocalWrite(med));
    getAllMedications();
  }

  Future<void> deleteMedication(int id) async {
    await _notifySync((s) => s.markLocalDelete(id));
    await medicationsRepo.deleteMedication(id);
    getAllMedications();
  }

  Future<void> _notifySync(Future<void> Function(SyncController) f) async {
    if (!Get.isRegistered<SyncController>()) return;
    try {
      await f(Get.find<SyncController>());
    } catch (_) {
      // Sync bookkeeping is best-effort; never block user writes.
    }
  }
}

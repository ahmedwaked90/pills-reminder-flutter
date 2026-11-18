import 'package:get/get.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:pills_reminder/features/auth/data/auth_repository.dart';
import 'package:pills_reminder/features/auth/domain/entities/auth_user.dart';

class AuthController extends GetxController {
  AuthController(this._repo, this._settingsBox);

  final AuthRepository _repo;
  final Box _settingsBox;

  final Rxn<AuthUser> user = Rxn<AuthUser>();
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  bool get isSignedIn => user.value != null;

  @override
  void onInit() {
    super.onInit();
    _restoreUser();
    _refreshFromServer();
  }

  void _restoreUser() {
    final cached = _settingsBox.get('authUser');
    if (cached is Map) {
      try {
        user.value = AuthUser.fromJson(Map<String, dynamic>.from(cached));
      } catch (_) {}
    }
  }

  Future<void> _refreshFromServer() async {
    final fresh = await _repo.fetchMe();
    if (fresh != null) {
      user.value = fresh;
      await _settingsBox.put('authUser', fresh.toJson());
    }
  }

  Future<bool> signInWithGoogle() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final u = await _repo.signInWithGoogle();
      user.value = u;
      await _settingsBox.put('authUser', u.toJson());
      return true;
    } on AuthException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    isLoading.value = true;
    try {
      await _repo.signOut();
    } finally {
      user.value = null;
      await _settingsBox.delete('authUser');
      isLoading.value = false;
    }
  }
}

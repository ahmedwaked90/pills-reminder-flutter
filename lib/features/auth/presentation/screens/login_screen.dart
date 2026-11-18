import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pills_reminder/features/auth/presentation/controllers/auth_controller.dart';
import 'package:pills_reminder/features/medications/presentation/screens/main_screen/main_screen.dart';
import 'package:pills_reminder/features/sync/presentation/controllers/sync_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.allowOfflineMode = true});

  final bool allowOfflineMode;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medication_outlined,
                      size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'appName'.tr,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'signInSubtitle'.tr,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  Obx(() {
                    final msg = auth.errorMessage.value;
                    if (msg == null || msg.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        msg,
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }),
                  Obx(
                    () => SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.login),
                        onPressed: auth.isLoading.value
                            ? null
                            : () => _onSignIn(context),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: auth.isLoading.value
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : Text('signInWithGoogle'.tr),
                        ),
                      ),
                    ),
                  ),
                  if (allowOfflineMode) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Get.offAll(() => const MainScreen()),
                      child: Text('continueOffline'.tr),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSignIn(BuildContext context) async {
    final auth = Get.find<AuthController>();
    final ok = await auth.signInWithGoogle();
    if (!ok) return;
    // Hand off to sync — it decides whether to prompt about local meds.
    if (Get.isRegistered<SyncController>()) {
      await Get.find<SyncController>().onSignedIn();
    }
    Get.offAll(() => const MainScreen());
  }
}

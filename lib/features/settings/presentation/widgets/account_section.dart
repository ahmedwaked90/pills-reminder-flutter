import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pills_reminder/features/auth/presentation/controllers/auth_controller.dart';
import 'package:pills_reminder/features/auth/presentation/screens/login_screen.dart';
import 'package:pills_reminder/features/sync/presentation/controllers/sync_controller.dart';

String _two(int n) => n.toString().padLeft(2, '0');
String _formatDate(DateTime d) =>
    '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final sync = Get.find<SyncController>();
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final user = auth.user.value;
          if (user == null) {
            return Row(
              children: [
                Icon(Icons.cloud_off_outlined, color: theme.hintColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('accountTitle'.tr, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('accountSignedOut'.tr,
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => Get.to(
                    () => const LoginScreen(allowOfflineMode: false),
                  ),
                  child: Text('signIn'.tr),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: (user.avatarUrl != null)
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: (user.avatarUrl == null)
                        ? Text(user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : '?')
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: theme.textTheme.titleMedium),
                        if (user.email != null)
                          Text(user.email!, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Obx(() {
                final at = sync.lastSyncAt.value;
                final text = at == null
                    ? 'lastSyncNever'.tr
                    : 'lastSyncAt'.trParams({'when': _formatDate(at.toLocal())});
                return Text(text, style: theme.textTheme.bodySmall);
              }),
              const SizedBox(height: 8),
              Obx(() {
                final err = sync.lastError.value;
                if (err == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    err,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                );
              }),
              Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => OutlinedButton.icon(
                        onPressed: sync.isSyncing.value
                            ? null
                            : () => sync.syncNow(),
                        icon: sync.isSyncing.value
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.sync),
                        label: Text('syncNow'.tr),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => auth.signOut(),
                      icon: const Icon(Icons.logout),
                      label: Text('signOut'.tr),
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}

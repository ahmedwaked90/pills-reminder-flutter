import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:pills_reminder/core/bindings/app_bindings.dart';
import 'package:pills_reminder/core/styles/strings.dart';
import 'package:pills_reminder/features/onboarding/presentation/screens/onboarding_page.dart';
import 'package:pills_reminder/features/settings/presentation/controllers/settings_controller.dart';
import 'package:pills_reminder/features/medications/presentation/screens/main_screen/main_screen.dart';
import 'package:pills_reminder/features/sync/presentation/controllers/sync_controller.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        Get.isRegistered<SyncController>()) {
      // Best-effort sync on resume; SyncController no-ops if signed-out
      // or already syncing.
      Get.find<SyncController>().syncNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<SettingsController>();
    return Obx(
      () => GetMaterialApp(
        translations: AppTranslations(),
        locale: themeController.locale.value,
        initialBinding: AppBindings(),
        debugShowCheckedModeBanner: false,
        title: 'appName'.tr,
        theme: themeController.lightTheme.value,
        darkTheme: themeController.darkTheme.value,
        themeMode: themeController.themeMode.value,
        home: Hive.box('Settings').get('onboarded') == '1'
            ? const MainScreen()
            : OnboardingPage(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/constants/app_constants.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import '../features/security/presentation/app_lock_wrapper.dart';

export 'theme/theme_provider.dart' show themeModeProvider;

/// Root widget for TutorMate.
class TutorMateApp extends ConsumerWidget {
  const TutorMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(_routerProvider);

    return AppLockWrapper(
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}

/// Provides the GoRouter instance (created once and reused).
final _routerProvider = Provider<GoRouter>((ref) {
  return buildRouter();
});

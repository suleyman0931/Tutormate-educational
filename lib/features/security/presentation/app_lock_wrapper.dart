import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/security_service.dart';
import 'lock_screen.dart';

/// Wraps the entire app and shows the [LockScreen] when [appLockedProvider]
/// is true. Also handles auto-lock via app lifecycle events.
class AppLockWrapper extends ConsumerStatefulWidget {
  const AppLockWrapper({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends ConsumerState<AppLockWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockOnStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// On app start, lock if PIN is enabled and auto-lock has elapsed.
  Future<void> _checkLockOnStart() async {
    final svc = ref.read(securityServiceProvider);
    final shouldLock = await svc.shouldAutoLock();
    if (shouldLock && mounted) {
      ref.read(appLockedProvider.notifier).state = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check if auto-lock elapsed while backgrounded.
      _checkLockOnResume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Record activity timestamp so we can compare on resume.
      ref.read(securityServiceProvider).recordActivity();
    }
  }

  Future<void> _checkLockOnResume() async {
    final svc = ref.read(securityServiceProvider);
    final shouldLock = await svc.shouldAutoLock();
    if (shouldLock && mounted) {
      ref.read(appLockedProvider.notifier).state = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appLockedProvider);
    if (locked) return const LockScreen();
    return widget.child;
  }
}

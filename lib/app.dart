import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_controller.dart';
import 'app_shell.dart';
import 'core/db/app_database.dart';
import 'core/services/backup_service.dart';
import 'core/services/screen_protection_service.dart';
import 'core/services/security_service.dart';
import 'core/services/theme_preferences_service.dart';
import 'core/services/user_profile_controller_access.dart';
import 'features/onboarding_screen.dart';
import 'features/recovery/recovery_screen.dart';
import 'features/settings/lock_gate.dart';
import 'shared/app_theme.dart';
import 'shared/saku_brand.dart';

class ArusApp extends StatefulWidget {
  const ArusApp({
    super.key,
    required this.controller,
    required this.database,
    required this.security,
  });
  final AppController controller;
  final AppDatabase database;
  final SecurityService security;

  @override
  State<ArusApp> createState() => _ArusAppState();
}

class _ArusAppState extends State<ArusApp> with WidgetsBindingObserver {
  final ThemePreferencesService _themePreferences = ThemePreferencesService.instance;
  final ScreenProtectionService _screenProtection = ScreenProtectionService.instance;
  bool? _onboardingDone;
  bool _onboardingJustCompleted = false;
  bool _privacyShielded = false;
  bool _launchSplashDone = false;
  late bool _lastInitializing;
  late bool _lastFatalRecovery;

  @override
  void initState() {
    super.initState();
    _captureRootControllerState();
    widget.controller.addListener(_controllerChanged);
    _themePreferences.addListener(_appearanceChanged);
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void didUpdateWidget(covariant ArusApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_controllerChanged);
    _captureRootControllerState();
    widget.controller.addListener(_controllerChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_controllerChanged);
    _themePreferences.removeListener(_appearanceChanged);
    super.dispose();
  }

  void _appearanceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_privacyShielded && mounted) {
        setState(() => _privacyShielded = false);
      }
      widget.controller.processAppResume();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // This lifecycle shield is intentionally independent from the optional
      // Android screenshot flag. App-switcher snapshots stay protected even
      // when the user explicitly allows screenshots while SAKU is active.
      if (!_privacyShielded && mounted) {
        setState(() {
          _privacyShielded = true;
          _onboardingJustCompleted = false;
        });
      } else {
        _onboardingJustCompleted = false;
      }
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _checkpointRecoveryOnBackground();
    }
  }

  void _checkpointRecoveryOnBackground() {
    if (widget.controller.initializing || widget.controller.errorMessage != null) {
      return;
    }
    unawaited(
      BackupService(widget.database)
          .createLocalRecoveryGeneration(
            minimumInterval: const Duration(minutes: 30),
          )
          .catchError((_) {}),
    );
  }

  void _captureRootControllerState() {
    _lastInitializing = widget.controller.initializing;
    _lastFatalRecovery =
        widget.controller.errorMessage != null &&
        widget.controller.dashboardData == null;
  }

  void _controllerChanged() {
    final initializing = widget.controller.initializing;
    final fatalRecovery =
        widget.controller.errorMessage != null &&
        widget.controller.dashboardData == null;
    if (initializing == _lastInitializing &&
        fatalRecovery == _lastFatalRecovery) {
      return;
    }
    _lastInitializing = initializing;
    _lastFatalRecovery = fatalRecovery;
    if (mounted) setState(() {});
  }

  Future<void> _boot() async {
    final startedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    _onboardingDone = prefs.getBool('onboarding_done_v1') ?? false;
    await _themePreferences.load();
    await _screenProtection.loadAndApply();
    if (mounted) setState(() {});
    await widget.controller.initialize();
    if (widget.controller.errorMessage == null) {
      unawaited(
        BackupService(widget.database)
            .createLocalRecoveryGeneration()
            .catchError((_) {}),
      );
    }

    // The branded splash is a cold-launch transition, not a route. It is
    // intentionally never replayed on background/resume while this process
    // stays alive. Keep a small minimum display time so a fast device does not
    // flash the logo too quickly, but never add extra delay to a slow boot.
    const minimumSplash = Duration(milliseconds: 900);
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < minimumSplash) {
      await Future<void>.delayed(minimumSplash - elapsed);
    }
    if (mounted) setState(() => _launchSplashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: SakuBrand.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(_themePreferences.themeId),
      darkTheme: AppTheme.dark(_themePreferences.themeId),
      themeMode: _themePreferences.themeMode,
      // Security wraps the Navigator itself. A dialog, modal bottom sheet, or
      // pushed route must never sit above the lock/privacy layers after SAKU
      // leaves the foreground. The launch splash is static/non-sensitive and
      // is the only deliberate pre-lock surface.
      builder: (context, child) => _launchSplashDone
          ? _buildSecurityEnvelope(child)
          : const SakuLaunchSplash(),
      home: _buildHome(),
    );
  }

  Widget _buildSecurityEnvelope(Widget? routedChild) {
    final lockedNavigator = _buildRootLock(
      routedChild ?? const SizedBox.shrink(),
    );
    return _buildPrivacyProtectedHome(lockedNavigator);
  }

  Widget _buildRootLock(Widget child) {
    return LockGate(
      key: ValueKey('root-lock-${_onboardingDone == true}'),
      security: widget.security,
      startUnlocked: _onboardingJustCompleted,
      child: child,
    );
  }

  Widget _buildPrivacyProtectedHome(Widget protectedNavigator) {
    return Stack(
      fit: StackFit.expand,
      children: [
        protectedNavigator,
        if (_privacyShielded)
          const ColoredBox(
            color: SakuBrand.noturno,
            child: Semantics(
              container: true,
              label: 'SAKU disembunyikan saat aplikasi tidak aktif',
              child: Center(
                child: Icon(
                  Icons.lock_outline,
                  color: Colors.white70,
                  size: 36,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHome() {
    if (_onboardingDone == null || widget.controller.initializing) {
      return const Scaffold(
        body: Center(
          child: Semantics(
            label: 'Memuat SAKU',
            liveRegion: true,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (_onboardingDone == false) {
      return OnboardingScreen(
        security: widget.security,
        profile: widget.controller.userProfileService,
        onDone: () => setState(() {
          _onboardingJustCompleted = true;
          _onboardingDone = true;
        }),
      );
    }
    if (widget.controller.errorMessage != null &&
        widget.controller.dashboardData == null) {
      return RecoveryScreen(
        controller: widget.controller,
        database: widget.database,
        errorMessage: widget.controller.errorMessage!,
      );
    }
    return AppShell(
      controller: widget.controller,
      database: widget.database,
      security: widget.security,
    );
  }
}

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
import 'shared/saku_splash.dart';

class ArusApp extends StatefulWidget {
  const ArusApp({super.key, required this.controller, required this.database, required this.security});
  final AppController controller;
  final AppDatabase database;
  final SecurityService security;

  @override
  State<ArusApp> createState() => _ArusAppState();
}

class _ArusAppState extends State<ArusApp> with WidgetsBindingObserver {
  static const _minimumColdStartSplash = Duration(milliseconds: 1200);
  final ThemePreferencesService _themePreferences = ThemePreferencesService.instance;
  final ScreenProtectionService _screenProtection = ScreenProtectionService.instance;
  bool? _onboardingDone;
  bool _onboardingJustCompleted = false;
  bool _privacyShielded = false;
  bool _minimumSplashElapsed = false;
  late final DateTime _bootStartedAt;
  late bool _lastInitializing;
  late bool _lastFatalRecovery;

  bool get _isBooting => !_minimumSplashElapsed || _onboardingDone == null || widget.controller.initializing;

  @override
  void initState() {
    super.initState();
    _bootStartedAt = DateTime.now();
    _captureRootControllerState();
    widget.controller.addListener(_controllerChanged);
    _themePreferences.addListener(_appearanceChanged);
    _screenProtection.addListener(_screenProtectionChanged);
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
    _screenProtection.removeListener(_screenProtectionChanged);
    super.dispose();
  }

  void _appearanceChanged() { if (mounted) setState(() {}); }

  void _screenProtectionChanged() {
    // Privacy-cover state follows the user's reachable Privasi layar setting.
    // Turning it OFF must also remove any stale app-switcher shield immediately.
    if (!_screenProtection.enabled && _privacyShielded) {
      if (mounted) setState(() => _privacyShielded = false);
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_privacyShielded && mounted) setState(() => _privacyShielded = false);
      // Authentication remains independent: controller classifies genuine
      // device lock through the native keyguard bridge; Recent Apps/pickers
      // alone therefore do not create a new auth requirement.
      widget.controller.processAppResume();
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.hidden || state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Vivo regression gate: Recent Apps is privacy-covered only when the
      // user enabled Privasi layar. OFF intentionally leaves the normal task
      // preview visible. This visual state never itself locks the session.
      if (_screenProtection.enabled && !_privacyShielded && mounted) {
        setState(() { _privacyShielded = true; _onboardingJustCompleted = false; });
      } else {
        _onboardingJustCompleted = false;
      }
    }

    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) _checkpointRecoveryOnBackground();
  }

  void _checkpointRecoveryOnBackground() {
    if (widget.controller.initializing || widget.controller.errorMessage != null) return;
    unawaited(BackupService(widget.database).createLocalRecoveryGeneration(minimumInterval: const Duration(minutes: 30)).catchError((_) {}));
  }

  void _captureRootControllerState() {
    _lastInitializing = widget.controller.initializing;
    _lastFatalRecovery = widget.controller.errorMessage != null && widget.controller.dashboardData == null;
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
    final prefs = await SharedPreferences.getInstance();
    _onboardingDone = prefs.getBool('onboarding_done_v1') ?? false;
    await _themePreferences.load();
    await _screenProtection.loadAndApply();
    if (mounted) setState(() {});
    await widget.controller.initialize();
    if (widget.controller.errorMessage == null) unawaited(BackupService(widget.database).createLocalRecoveryGeneration().catchError((_) {}));
    final remaining = _minimumColdStartSplash - DateTime.now().difference(_bootStartedAt);
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (mounted) setState(() => _minimumSplashElapsed = true);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: SakuBrand.appName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(_themePreferences.themeId),
    darkTheme: AppTheme.dark(_themePreferences.themeId),
    themeMode: _themePreferences.themeMode,
    builder: (context, child) => _buildSecurityEnvelope(child),
    home: _buildHome(),
  );

  Widget _buildSecurityEnvelope(Widget? routedChild) {
    final child = routedChild ?? const SizedBox.shrink();
    if (_isBooting) return _buildPrivacyProtectedHome(child);
    return _buildPrivacyProtectedHome(_buildRootLock(child));
  }

  Widget _buildRootLock(Widget child) => LockGate(key: ValueKey('root-lock-${_onboardingDone == true}'), security: widget.security, startUnlocked: _onboardingJustCompleted, child: child);

  Widget _buildPrivacyProtectedHome(Widget protectedNavigator) => Stack(
    fit: StackFit.expand,
    children: [
      protectedNavigator,
      if (_privacyShielded && _screenProtection.enabled)
        ColoredBox(
          color: SakuBrand.noturno,
          child: Semantics(
            container: true,
            label: 'SAKU disembunyikan saat aplikasi tidak aktif',
            child: const Center(child: Icon(Icons.lock_outline, color: Colors.white70, size: 36)),
          ),
        ),
    ],
  );

  Widget _buildHome() {
    if (_isBooting) return const SakuSplashScreen();
    if (_onboardingDone == false) {
      return OnboardingScreen(profile: widget.controller.userProfileService, onDone: () => setState(() { _onboardingJustCompleted = true; _onboardingDone = true; }));
    }
    if (widget.controller.errorMessage != null && widget.controller.dashboardData == null) {
      return RecoveryScreen(controller: widget.controller, database: widget.database, errorMessage: widget.controller.errorMessage!);
    }
    return AppShell(controller: widget.controller, database: widget.database, security: widget.security);
  }
}

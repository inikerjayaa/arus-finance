import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_controller.dart';
import 'app_shell.dart';
import 'core/db/app_database.dart';
import 'core/services/backup_service.dart';
import 'core/services/security_service.dart';
import 'features/onboarding_screen.dart';
import 'features/recovery/recovery_screen.dart';
import 'features/settings/lock_gate.dart';
import 'shared/app_theme.dart';

class ArusApp extends StatefulWidget {
  const ArusApp({super.key, required this.controller, required this.database, required this.security});
  final AppController controller;
  final AppDatabase database;
  final SecurityService security;

  @override
  State<ArusApp> createState() => _ArusAppState();
}

class _ArusAppState extends State<ArusApp> with WidgetsBindingObserver {
  bool? _onboardingDone;
  bool _privacyShielded = false;
  late bool _lastInitializing;
  late bool _lastFatalRecovery;

  @override
  void initState() {
    super.initState();
    _captureRootControllerState();
    widget.controller.addListener(_controllerChanged);
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
    super.dispose();
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
      // Obscure financial UI before the OS can capture an app-switcher snapshot.
      // Android also receives FLAG_SECURE from the native hardener.
      if (!_privacyShielded && mounted) {
        setState(() => _privacyShielded = true);
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
        widget.controller.errorMessage != null && widget.controller.dashboardData == null;
  }

  void _controllerChanged() {
    final initializing = widget.controller.initializing;
    final fatalRecovery =
        widget.controller.errorMessage != null && widget.controller.dashboardData == null;
    if (initializing == _lastInitializing && fatalRecovery == _lastFatalRecovery) {
      // AppScope/InheritedNotifier owns normal in-app state propagation. Avoid
      // rebuilding MaterialApp/Navigator for search, pagination, busy, notices,
      // dashboard values, or other routine controller notifications.
      return;
    }
    _lastInitializing = initializing;
    _lastFatalRecovery = fatalRecovery;
    if (mounted) setState(() {});
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingDone = prefs.getBool('onboarding_done_v1') ?? false;
    if (mounted) setState(() {});
    await widget.controller.initialize();
    if (widget.controller.errorMessage == null) {
      unawaited(
        BackupService(widget.database)
            .createLocalRecoveryGeneration()
            .catchError((_) {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arus Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: _buildPrivacyProtectedHome(),
    );
  }

  Widget _buildPrivacyProtectedHome() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildHome(),
        if (_privacyShielded)
          ColoredBox(
            color: Color(0xFF101114),
            child: Semantics(
              container: true,
              label: 'Arus disembunyikan saat aplikasi tidak aktif',
              child: Center(
                child: Icon(Icons.lock_outline, color: Colors.white70, size: 36),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHome() {
    if (_onboardingDone == null || widget.controller.initializing) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: 'Memuat Arus Finance',
            liveRegion: true,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (_onboardingDone == false) {
      return OnboardingScreen(onDone: () => setState(() => _onboardingDone = true));
    }
    if (widget.controller.errorMessage != null && widget.controller.dashboardData == null) {
      return LockGate(
        security: widget.security,
        child: RecoveryScreen(
          controller: widget.controller,
          database: widget.database,
          errorMessage: widget.controller.errorMessage!,
        ),
      );
    }
    return LockGate(
      security: widget.security,
      child: AppShell(controller: widget.controller, database: widget.database, security: widget.security),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/security_service.dart';
import 'pin_recovery_panel.dart';

class LockGate extends StatefulWidget {
  const LockGate({
    super.key,
    required this.security,
    required this.child,
    this.startUnlocked = false,
  });

  final SecurityService security;
  final Widget child;
  final bool startUnlocked;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _checking = true;
  bool _locked = false;
  bool _hasPin = false;
  bool _foreground = true;
  bool _biometricInFlight = false;
  bool _biometricAutoSuppressed = false;
  bool _biometricSuccessPendingResume = false;
  bool _biometricAvailable = false;
  bool _recovering = false;
  int _lifecycleGeneration = 0;
  final _pin = TextEditingController();
  String? _error;
  String? _biometricError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pin.dispose();
    super.dispose();
  }

  Future<void> _checkInitial() async {
    final hasPin = await widget.security.hasPin();
    final biometricAvailable =
        hasPin && await widget.security.canUseBiometrics();
    final biometricEnabled =
        biometricAvailable && await widget.security.biometricEnabled();
    if (!mounted) return;
    final shouldStartLocked = hasPin && !widget.startUnlocked;
    setState(() {
      _hasPin = hasPin;
      _biometricAvailable = biometricAvailable;
      _locked = shouldStartLocked;
      _checking = false;
    });
    if (biometricEnabled && shouldStartLocked && _foreground) {
      await _tryBiometric();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleGeneration++;
    if (state == AppLifecycleState.resumed) {
      _foreground = true;

      // Some Android OEMs complete BiometricPrompt successfully while Flutter
      // still reports `inactive`, just before the matching `resumed` event.
      // Keep the lock surface in place while inactive, then consume that
      // already-authenticated result on the immediate resume instead of
      // discarding it and making fingerprint appear broken.
      if (_biometricSuccessPendingResume && _hasPin && mounted) {
        _biometricSuccessPendingResume = false;
        _biometricAutoSuppressed = false;
        setState(() {
          _locked = false;
          _recovering = false;
          _error = null;
          _biometricError = null;
          _pin.clear();
        });
        return;
      }
      _biometricSuccessPendingResume = false;

      if (_hasPin && !_locked && mounted) {
        setState(() {
          _locked = true;
          _recovering = false;
          _error = null;
          _biometricError = null;
          _pin.clear();
        });
      }
      if (_biometricInFlight) return;
      unawaited(_refreshPinStateOnResume(_lifecycleGeneration));
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.detached) {
        // A successful biometric result may bridge only the transient
        // system-overlay `inactive` state. Never carry it across a real
        // background/hidden transition.
        _biometricSuccessPendingResume = false;
      }
      if (!_biometricInFlight &&
          (state == AppLifecycleState.paused ||
              state == AppLifecycleState.hidden ||
              state == AppLifecycleState.detached)) {
        _biometricAutoSuppressed = false;
      }
      if ((_hasPin && !_locked) || _recovering) {
        if (mounted) {
          setState(() {
            _locked = _hasPin;
            _recovering = false;
            _error = null;
            _biometricError = null;
            _pin.clear();
          });
        }
      }
    }
  }

  Future<void> _refreshPinStateOnResume(int generation) async {
    final hasPin = await widget.security.hasPin();
    final biometricAvailable =
        hasPin && await widget.security.canUseBiometrics();
    final biometricEnabled =
        biometricAvailable && await widget.security.biometricEnabled();
    if (!mounted || !_foreground || generation != _lifecycleGeneration) return;
    setState(() {
      _hasPin = hasPin;
      _biometricAvailable = biometricAvailable;
      _locked = hasPin;
      _recovering = false;
      if (!hasPin) {
        _error = null;
        _biometricError = null;
      }
    });
    if (biometricEnabled && !_biometricAutoSuppressed) {
      if (!mounted || !_foreground || generation != _lifecycleGeneration) {
        return;
      }
      await _tryBiometric();
    }
  }

  Future<void> _tryBiometric({bool manual = false}) async {
    if (_biometricInFlight || !_foreground || !_hasPin) return;
    if (manual) {
      _biometricAutoSuppressed = false;
      _biometricSuccessPendingResume = false;
      if (mounted && _biometricError != null) {
        setState(() => _biometricError = null);
      }
    }
    _biometricInFlight = true;
    try {
      final ok = await widget.security.authenticateBiometric();
      if (!mounted || !_hasPin) return;
      if (!ok) {
        _biometricSuccessPendingResume = false;
        _biometricAutoSuppressed = true;
        if (_foreground) {
          setState(() {
            _locked = true;
            _biometricError = widget.security.lastBiometricError;
          });
        }
        return;
      }
      if (!_foreground) {
        // BiometricPrompt can report success a few milliseconds before Flutter
        // receives `resumed` on some Android OEMs. Stay locked until resume,
        // but do not throw away the successful OS authentication.
        _biometricSuccessPendingResume = true;
        _biometricAutoSuppressed = true;
        return;
      }
      _biometricSuccessPendingResume = false;
      setState(() {
        _locked = false;
        _recovering = false;
        _error = null;
        _biometricError = null;
        _pin.clear();
      });
    } finally {
      _biometricInFlight = false;
    }
  }

  Future<void> _unlockPin() async {
    if (!_foreground) return;
    final ok = await widget.security.verifyPin(_pin.text);
    final lockUntil = ok ? null : await widget.security.pinLockedUntil();
    if (!mounted || !_foreground) return;
    setState(() {
      _locked = !ok;
      if (ok) {
        _recovering = false;
        _error = null;
        _biometricError = null;
        _pin.clear();
      } else if (lockUntil != null) {
        final seconds =
            lockUntil.difference(DateTime.now().toUtc()).inSeconds + 1;
        _error =
            'Terlalu banyak percobaan. Coba lagi sekitar $seconds detik.';
      } else {
        _error = 'PIN tidak cocok.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_checking)
          _buildSecuritySurface(
            context,
            const ColoredBox(
              color: Color(0xFF101114),
              child: Center(
                child: Semantics(
                  label: 'Memeriksa keamanan SAKU',
                  liveRegion: true,
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          )
        else if (_locked)
          _buildSecuritySurface(
            context,
            _recovering
                ? PinRecoveryPanel(
                    security: widget.security,
                    onRecovered: _finishRecovery,
                    onCancel: () => setState(() => _recovering = false),
                  )
                : _buildLockedOverlay(context),
          ),
      ],
    );
  }

  Widget _buildSecuritySurface(BuildContext context, Widget child) {
    // LockGate intentionally sits above the app's root Navigator so dialogs,
    // sheets, and pushed routes cannot escape the lock. The lock surface owns
    // a tiny private Navigator/Overlay so PIN text input still has a valid
    // selection/focus overlay without borrowing the sensitive Navigator below.
    return Positioned.fill(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Theme.of(context),
        home: PopScope<void>(
          canPop: false,
          child: child,
        ),
      ),
    );
  }

  Widget _buildLockedOverlay(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'SAKU terkunci',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masukkan PIN untuk membuka data keuangan.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('lock_pin_input'),
                    controller: _pin,
                    autofocus: true,
                    obscureText: true,
                    enableInteractiveSelection: false,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _unlockPin(),
                  ),
                  if (_error != null)
                    Semantics(
                      liveRegion: true,
                      label: _error!,
                      child: const SizedBox.shrink(),
                    ),
                  if (_biometricError != null) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _biometricError!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _unlockPin,
                    child: const Text('Buka'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _recovering = true;
                      _error = null;
                      _biometricError = null;
                      _pin.clear();
                    }),
                    child: const Text('Lupa PIN?'),
                  ),
                  if (_biometricAvailable) ...[
                    const SizedBox(height: 2),
                    TextButton.icon(
                      onPressed: () => _tryBiometric(manual: true),
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Gunakan biometrik'),
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

  void _finishRecovery() {
    if (!mounted || !_foreground) return;
    setState(() {
      _hasPin = true;
      _locked = false;
      _recovering = false;
      _error = null;
      _biometricError = null;
      _pin.clear();
    });
  }
}

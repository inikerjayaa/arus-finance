from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
read=lambda r:(ROOT/r).read_text()
app=read('lib/app.dart')
hardener=read('tool/native_hardening.py')
service=read('lib/core/services/screen_protection_service.dart')
settings=read('lib/features/settings/settings_screen.dart')
privacy=read('lib/features/settings/privacy_settings_screen.dart')
docs=read('docs/PRIVACY_SHIELD_UAT_V23.md')
checks={
 'Flutter privacy shield state exists':'_privacyShielded = false' in app,
 'shield activates on inactive':'state == AppLifecycleState.inactive' in app,
 'shield activates on hidden':'state == AppLifecycleState.hidden' in app,
 'shield activates on paused':'state == AppLifecycleState.paused' in app,
 'shield clears on resumed':'setState(() => _privacyShielded = false)' in app,
 'protected home overlays sensitive UI':'_buildPrivacyProtectedHome()' in app and 'if (_privacyShielded)' in app,
 'shield is opaque':'color: Color(0xFF101114)' in app,
 'shield has assistive label':'Arus disembunyikan saat aplikasi tidak aktif' in app,
 'app switcher shield is documented independent':'intentionally independent' in app,
 'Android hardener imports WindowManager':'android.view.WindowManager' in hardener,
 'Android starts secure before Dart':'window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)' in hardener,
 'Android runtime bridge channel':'arus.finance/screen_protection' in hardener,
 'Android runtime bridge can enable':'"setEnabled"' in hardener and 'addFlags' in hardener,
 'Android runtime bridge can disable':'clearFlags(WindowManager.LayoutParams.FLAG_SECURE)' in hardener,
 'Android runtime bridge reports support':'"isSupported"' in hardener,
 'Android Kotlin engine override retained':'override fun configureFlutterEngine(flutterEngine: FlutterEngine)' in hardener,
 'Android Java engine override retained':'public void configureFlutterEngine(FlutterEngine flutterEngine)' in hardener,
 'screen preference defaults secure':'bool _enabled = true' in service,
 'screen preference is local':'screen_protection_enabled_v1' in service and 'SharedPreferences' in service,
 'boot applies screen preference':'_screenProtection.loadAndApply()' in app,
 'settings exposes privacy screen':"title: const Text('Privasi layar')" in settings,
 'disable path requires warning':'Izinkan screenshot?' in privacy and 'Matikan perlindungan' in privacy,
 'unsupported platform is truthful':'Arus tidak akan mengklaim perlindungan yang tidak dapat diverifikasi.' in privacy,
 'V23 UAT covers app switcher':'App Switcher Snapshot' in docs,
 'V23 UAT covers screenshot':'Android Screenshot / Screen Share' in docs,
 'V23 UAT covers biometric inactive transition':'Biometric / System Overlay Transition' in docs,
}
failed=[k for k,v in checks.items() if not v]
if failed:
 print('FAIL: V23 privacy-shield contract')
 for k in failed: print(' -',k)
 sys.exit(1)
print(f'PASS: V23 privacy-shield + runtime screenshot-toggle contract ({len(checks)} checks)')

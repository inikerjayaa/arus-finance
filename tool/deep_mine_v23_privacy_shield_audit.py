from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
read=lambda r:(ROOT/r).read_text()
app=read('lib/app.dart')
hardener=read('tool/native_hardening.py')
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
 'Android hardener imports WindowManager':'android.view.WindowManager' in hardener,
 'Android hardener applies FLAG_SECURE':'WindowManager.LayoutParams.FLAG_SECURE' in hardener,
 'Android Kotlin secure override retained':'override fun onCreate(savedInstanceState: Bundle?)' in hardener,
 'Android Java secure override retained':'protected void onCreate(Bundle savedInstanceState)' in hardener,
 'V23 UAT covers app switcher':'App Switcher Snapshot' in docs,
 'V23 UAT covers screenshot':'Android Screenshot / Screen Share' in docs,
 'V23 UAT covers biometric inactive transition':'Biometric / System Overlay Transition' in docs,
}
failed=[k for k,v in checks.items() if not v]
if failed:
 print('FAIL: V23 privacy-shield contract')
 for k in failed: print(' -',k)
 sys.exit(1)
print(f'PASS: V23 privacy-shield contract ({len(checks)} checks)')

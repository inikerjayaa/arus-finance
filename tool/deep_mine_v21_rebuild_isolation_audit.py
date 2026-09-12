from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
read=lambda r:(ROOT/r).read_text()
app=read('lib/app.dart')
shell=read('lib/app_shell.dart')
docs=read('docs/REBUILD_LIFECYCLE_UAT_V21.md')
checks={
 'root no longer rebuilds on every controller notification':'widget.controller.addListener(_refresh)' not in app,
 'root uses selective controller listener':'widget.controller.addListener(_controllerChanged)' in app,
 'root selection tracks initializing':'_lastInitializing' in app and 'widget.controller.initializing' in app,
 'root selection tracks fatal recovery only':'_lastFatalRecovery' in app and 'dashboardData == null' in app,
 'routine controller notifications return without root setState':'AppScope/InheritedNotifier owns normal in-app state propagation' in app,
 'controller replacement listener is safely rewired':'didUpdateWidget' in app and 'oldWidget.controller.removeListener(_controllerChanged)' in app,
 'root listener removed on dispose':'widget.controller.removeListener(_controllerChanged)' in app,
 'shell directly listens to controller':'AnimatedBuilder(' in shell and 'animation: controller' in shell,
 'shell busy state remains reactive':'if (controller.busy)' in shell,
 'shell error state remains reactive':'controller.errorMessage != null' in shell,
 'shell notice state remains reactive':'controller.noticeMessage != null' in shell,
 'shell navigation selection remains reactive':'selectedIndex: controller.navigationIndex' in shell,
 'V21 UAT covers pagination/search without root rebuild':'Search / Pagination Rebuild Boundary' in docs,
 'V21 UAT covers fatal recovery transition':'Fatal Recovery Transition' in docs,
 'V21 UAT covers listener replacement/dispose':'Listener Lifecycle' in docs,
}
failed=[k for k,v in checks.items() if not v]
if failed:
 print('FAIL: V21 rebuild/lifecycle isolation contract')
 for k in failed: print(' -',k)
 sys.exit(1)
print(f'PASS: V21 rebuild/lifecycle isolation contract ({len(checks)} checks)')

"""Static privacy/safety audit for local notification implementation."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
src=(ROOT/'lib/core/services/local_notification_service.dart').read_text()
pub=(ROOT/'pubspec.yaml').read_text()
hard=(ROOT/'tool/native_hardening.py').read_text()

checks={
  'local_notifications_dependency':'flutter_local_notifications: ^22.3.0' in pub,
  'timezone_dependency':'timezone: ^0.11.1' in pub,
  'timezone_identifier':'.identifier' in src,
  'inexact_schedule':'AndroidScheduleMode.inexactAllowWhileIdle' in src,
  'no_exact_alarm_permission':'SCHEDULE_EXACT_ALARM' not in hard and 'USE_EXACT_ALARM' not in hard,
  'privacy_default':"prefs.getBool(_detailsKey) ?? false" in src,
  'stable_ids':'int _stableId(String payload)' in src,
  'per_item_hash':'sha256.convert(utf8.encode(signatureSource)).toString()' in src,
  'persist_hash_only':"for (final reminder in desired) '${reminder.id}': reminder.signature" in src,
  'differential_cancel':'await _plugin.cancel(id: id);' in src,
  'no_cancel_all_pending':'cancelAllPendingNotifications' not in src,
  'legacy_cleanup':'_cleanLegacyIdsOnce' in src,
  'boot_receivers':'ScheduledNotificationBootReceiver' in hard and 'ScheduledNotificationReceiver' in hard,
  'post_notifications_permission':'android.permission.POST_NOTIFICATIONS' in hard,
  'boot_permission':'android.permission.RECEIVE_BOOT_COMPLETED' in hard,
  'desugaring':'isCoreLibraryDesugaringEnabled = true' in hard,
}
bad=[k for k,v in checks.items() if not v]
if bad:
    raise SystemExit('FAIL notification contract: '+', '.join(bad))
print('PASS: differential local notification privacy/native contract')

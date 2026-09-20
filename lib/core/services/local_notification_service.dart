import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../shared/money.dart';

class LocalNotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _enabledKey = 'arus_local_reminders_enabled_v1';
  static const _detailsKey = 'arus_notification_details_enabled_v1';
  static const _stateKey = 'arus_notification_managed_state_v2';
  static const _legacyCleanedKey = 'arus_notification_legacy_ids_cleaned_v1';
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      throw StateError('Zona waktu perangkat tidak dapat dibaca untuk menjadwalkan pengingat lokal: $e');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: darwin, macOS: darwin);
    await _plugin.initialize(settings: settings);
    await _cleanLegacyIdsOnce();
    _initialized = true;
  }

  Future<bool> enabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<bool> showDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_detailsKey) ?? false;
  }

  Future<bool> setEnabled(bool value) async {
    await initialize();
    if (value) {
      var granted = true;
      if (Platform.isAndroid) {
        granted = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? true;
      } else if (Platform.isIOS) {
        granted = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true, badge: false) ?? false;
      }
      if (!granted) return false;
    } else {
      await _cancelManagedReminders();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    return true;
  }

  Future<void> setShowDetails(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_detailsKey, value);
  }

  Future<void> syncSchedules({required List<BillModel> bills, required List<RecurringRuleModel> recurring}) async {
    if (!await enabled()) return;
    await initialize();
    final details = await showDetails();
    final desired = _buildDesiredReminders(bills, recurring, details);
    final prefs = await SharedPreferences.getInstance();
    final previous = _readState(prefs);
    final desiredState = <String, String>{for (final reminder in desired) '${reminder.id}': reminder.signature};
    for (final idText in previous.keys) {
      if (desiredState.containsKey(idText)) continue;
      final id = int.tryParse(idText);
      if (id != null) await _plugin.cancel(id: id);
    }
    for (final reminder in desired) {
      if (previous['${reminder.id}'] == reminder.signature) continue;
      await _schedule(reminder);
    }
    await prefs.setString(_stateKey, jsonEncode(desiredState));
  }

  List<_ReminderSpec> _buildDesiredReminders(List<BillModel> bills, List<RecurringRuleModel> recurring, bool details) {
    final now = tz.TZDateTime.now(tz.local);
    final raw = <_ReminderDraft>[];
    final billList = bills.where((b) => b.status != BillStatus.paid && b.status != BillStatus.skipped).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    for (final bill in billList) {
      if (raw.length >= 32) break;
      var scheduled = tz.TZDateTime(tz.local, bill.dueDate.year, bill.dueDate.month, bill.dueDate.day, 9).subtract(const Duration(days: 1));
      if (!scheduled.isAfter(now)) scheduled = tz.TZDateTime(tz.local, bill.dueDate.year, bill.dueDate.month, bill.dueDate.day, 8);
      if (!scheduled.isAfter(now)) continue;
      raw.add(_ReminderDraft(payload: 'bill:${bill.id}', title: 'Tagihan mendekati jatuh tempo', body: details ? '${bill.name} • ${Money.format(bill.expectedAmountMinor, currency: bill.currency)}' : 'Buka SAKU untuk melihat detail tagihan.', when: scheduled));
    }
    final recurringList = recurring.where((r) => r.active).toList()..sort((a, b) => a.nextRun.compareTo(b.nextRun));
    for (final rule in recurringList) {
      if (raw.length >= 48) break;
      final scheduled = tz.TZDateTime(tz.local, rule.nextRun.year, rule.nextRun.month, rule.nextRun.day, 8);
      if (!scheduled.isAfter(now)) continue;
      raw.add(_ReminderDraft(payload: 'recurring:${rule.id}', title: 'Transaksi berulang', body: details ? '${rule.name} • ${Money.format(rule.amountMinor, currency: rule.currency)}' : 'Buka SAKU untuk meninjau transaksi berulang.', when: scheduled));
    }
    final used = <int>{};
    return raw.map((draft) {
      var id = _stableId(draft.payload);
      while (!used.add(id)) id = id >= 2000000000 ? 10000 : id + 1;
      final signatureSource = [draft.payload, draft.title, draft.body, draft.when.toUtc().toIso8601String()].join('|');
      return _ReminderSpec(id: id, title: draft.title, body: draft.body, when: draft.when, payload: draft.payload, signature: sha256.convert(utf8.encode(signatureSource)).toString());
    }).toList(growable: false);
  }

  int _stableId(String payload) {
    final bytes = sha256.convert(utf8.encode(payload)).bytes;
    final raw = ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) & 0x7fffffff;
    return 10000 + (raw % 1999990000);
  }

  Map<String, String> _readState(SharedPreferences prefs) {
    final raw = prefs.getString(_stateKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return decoded.map((key, value) => MapEntry('$key', '$value'));
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _cancelManagedReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final state = _readState(prefs);
    for (final idText in state.keys) {
      final id = int.tryParse(idText);
      if (id != null) await _plugin.cancel(id: id);
    }
    await prefs.remove(_stateKey);
  }

  Future<void> _cleanLegacyIdsOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_legacyCleanedKey) ?? false) return;
    for (var id = 1000; id <= 1047; id++) await _plugin.cancel(id: id);
    await prefs.setBool(_legacyCleanedKey, true);
  }

  Future<void> _schedule(_ReminderSpec reminder) {
    return _plugin.zonedSchedule(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      scheduledDate: reminder.when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'arus_reminders',
          'Pengingat SAKU',
          channelDescription: 'Pengingat lokal tagihan dan transaksi berulang.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: reminder.payload,
    );
  }
}

class _ReminderDraft {
  const _ReminderDraft({required this.payload, required this.title, required this.body, required this.when});
  final String payload;
  final String title;
  final String body;
  final tz.TZDateTime when;
}

class _ReminderSpec extends _ReminderDraft {
  const _ReminderSpec({required this.id, required super.payload, required super.title, required super.body, required super.when, required this.signature});
  final int id;
  final String signature;
}

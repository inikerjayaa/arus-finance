import 'package:flutter/material.dart';

import 'app.dart';
import 'app_controller.dart';
import 'core/db/app_database.dart';
import 'core/services/security_service.dart';
import 'core/services/local_notification_service.dart';
import 'data/local_finance_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  final repository = LocalFinanceRepository(database);
  final notifications = LocalNotificationService();
  final controller = AppController(repository, notifications: notifications);
  final security = SecurityService();
  runApp(ArusApp(controller: controller, database: database, security: security));
}

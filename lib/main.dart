import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'app_controller.dart';
import 'core/db/app_database.dart';
import 'core/services/category_composition_controller_access.dart';
import 'core/services/category_composition_service.dart';
import 'core/services/category_maintenance_controller_access.dart';
import 'core/services/category_maintenance_service.dart';
import 'core/services/local_insight_controller_access.dart';
import 'core/services/local_insight_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/security_service.dart';
import 'core/services/visual_identity_controller_access.dart';
import 'core/services/visual_identity_store.dart';
import 'data/local_finance_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final database = AppDatabase();
  final repository = LocalFinanceRepository(database);
  final notifications = LocalNotificationService();
  final controller = AppController(repository, notifications: notifications);
  controller.visualIdentityStore = VisualIdentityStore(database);
  controller.categoryCompositionService = CategoryCompositionService(database);
  controller.categoryMaintenanceService = CategoryMaintenanceService(database);
  controller.localInsightService = LocalInsightService(database);
  final security = SecurityService();
  runApp(
    ArusApp(
      controller: controller,
      database: database,
      security: security,
    ),
  );
}

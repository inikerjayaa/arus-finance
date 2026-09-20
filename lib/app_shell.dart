import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'core/db/app_database.dart';
import 'core/services/backup_service.dart';
import 'core/services/csv_export_service.dart';
import 'core/services/csv_import_service.dart';
import 'core/services/security_service.dart';
import 'features/accounts/accounts_screen.dart';
import 'features/home/home_screen.dart';
import 'features/insights/insights_screen.dart';
import 'features/planning/planning_screen.dart';
import 'features/quick_add/quick_add_sheet.dart';
import 'features/settings/settings_screen.dart';
import 'features/transactions/transactions_screen.dart';
import 'shared/app_scope.dart';
import 'shared/saku_brand.dart';
import 'shared/saku_splash.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.controller,
    required this.database,
    required this.security,
  });

  final AppController controller;
  final AppDatabase database;
  final SecurityService security;

  @override
  Widget build(BuildContext context) {
    final pages = <int, Widget>{
      0: const HomeScreen(),
      1: const TransactionsScreen(),
      3: const PlanningScreen(),
      4: const InsightsScreen(),
    };

    return AppScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            titleSpacing: 20,
            title: Semantics(
              label: 'SAKU',
              header: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SakuBrandMark(size: 30),
                  SizedBox(width: 9),
                  Text(
                    'SAKU',
                    style: TextStyle(
                      fontFamily: SakuBrand.fontFamily,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            centerTitle: false,
            actions: [
              IconButton(
                tooltip: 'Akun',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppScope(
                      controller: controller,
                      child: const AccountsScreen(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.account_balance_outlined),
              ),
              IconButton(
                tooltip: 'Pengaturan',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppScope(
                      controller: controller,
                      child: SettingsScreen(
                        security: security,
                        backup: BackupService(database),
                        csv: CsvExportService(controller.repository),
                        csvImport: CsvImportService(controller.repository),
                        notifications: controller.notifications,
                      ),
                    ),
                  ),
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Stack(
            children: [
              IndexedStack(
                index: switch (controller.navigationIndex) {
                  0 => 0,
                  1 => 1,
                  3 => 2,
                  4 => 3,
                  _ => 0,
                },
                children: [pages[0]!, pages[1]!, pages[3]!, pages[4]!],
              ),
              if (controller.busy)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (controller.errorMessage != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 8,
                  child: Semantics(
                    liveRegion: true,
                    label: 'Kesalahan: ${controller.errorMessage!}',
                    child: Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        title: Text(
                          controller.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Tutup pesan kesalahan',
                          onPressed: controller.clearError,
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ),
                  ),
                ),
              if (controller.errorMessage == null &&
                  controller.noticeMessage != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 8,
                  child: Semantics(
                    liveRegion: true,
                    label: 'Informasi: ${controller.noticeMessage!}',
                    child: Material(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                        title: Text(
                          controller.noticeMessage!,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Muat ulang tampilan',
                              onPressed: controller.busy
                                  ? null
                                  : controller.retryPresentationRefresh,
                              icon: const Icon(Icons.refresh),
                            ),
                            IconButton(
                              tooltip: 'Tutup informasi',
                              onPressed: controller.clearNotice,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: controller.navigationIndex,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            onDestinationSelected: (index) async {
              if (index == 2) {
                await QuickAddSheet.show(context, controller);
                return;
              }
              controller.setNavigation(index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Beranda',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Transaksi',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: 'Tambah',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note_rounded),
                label: 'Rencana',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'Insight',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/user_entity.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/auth/auth.dart';
import 'package:pricelet_app/src/features/customers/customers_page.dart';
import 'package:pricelet_app/src/features/dashboard/dashboard_page.dart';
import 'package:pricelet_app/src/features/pos/pos_page.dart';
import 'package:pricelet_app/src/features/price_check/price_check_page.dart';
import 'package:pricelet_app/src/features/products/product_list_page.dart';
import 'package:pricelet_app/src/features/reports/reports_page.dart';
import 'package:pricelet_app/src/features/sales/sales_history_page.dart';
import 'package:pricelet_app/src/features/settings/app_settings.dart';
import 'package:pricelet_app/src/features/settings/settings_page.dart';

enum AppSection {
  dashboard('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded, adminOnly: true),
  register('Register', Icons.point_of_sale_outlined, Icons.point_of_sale_rounded),
  products('Products', Icons.inventory_2_outlined, Icons.inventory_2_rounded, adminOnly: true),
  sales('Sales', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  customers('Customers', Icons.people_outline_rounded, Icons.people_rounded),
  reports('Reports', Icons.insights_outlined, Icons.insights_rounded, adminOnly: true),
  priceCheck('Price check', Icons.qr_code_scanner_outlined, Icons.qr_code_scanner_rounded),
  settings('Settings', Icons.settings_outlined, Icons.settings_rounded, adminOnly: true);

  const AppSection(this.label, this.icon, this.selectedIcon, {this.adminOnly = false});

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool adminOnly;

  static AppSection homeFor(UserEntity user) => user.isAdmin ? dashboard : register;
}

final sectionProvider = StateProvider<AppSection>((ref) => AppSection.register);

final visibleSectionsProvider = Provider<List<AppSection>>((ref) {
  final isAdmin = ref.watch(isAdminProvider);
  return AppSection.values.where((s) => isAdmin || !s.adminOnly).toList();
});

/// Shows the page for the selected section.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var section = ref.watch(sectionProvider);
    if (!ref.watch(visibleSectionsProvider).contains(section)) section = AppSection.register;

    switch (section) {
      case AppSection.dashboard:
        return const DashboardPage();
      case AppSection.register:
        return const PosPage();
      case AppSection.products:
        return const ProductListPage();
      case AppSection.sales:
        return const SalesHistoryPage();
      case AppSection.customers:
        return const CustomersPage();
      case AppSection.reports:
        return const ReportsPage();
      case AppSection.priceCheck:
        return const PriceCheckPage();
      case AppSection.settings:
        return const SettingsPage();
    }
  }
}

/// Scaffold for top-level pages: navigation rail on wide screens, drawer on
/// narrow ones.
class ShellScaffold extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  const ShellScaffold({
    super.key,
    required this.title,
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final scaffold = Scaffold(
      appBar: AppBar(title: Text(title), actions: [...?actions, const SizedBox(width: 8)]),
      drawer: wide ? null : const _NavDrawer(),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
    if (!wide) return scaffold;
    return Material(
      color: AppColors.background,
      child: Row(
        children: [
          const _NavRail(),
          Expanded(child: scaffold),
        ],
      ),
    );
  }
}

void _lock(WidgetRef ref) => ref.read(currentUserProvider.notifier).state = null;

class _NavRail extends ConsumerWidget {
  const _NavRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(visibleSectionsProvider);
    final current = ref.watch(sectionProvider);
    final user = ref.watch(currentUserProvider);
    final extended = MediaQuery.sizeOf(context).width >= 1280;
    final index = sections.indexOf(current);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.navy, Color(0xFF1C2740)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: NavigationRail(
        extended: extended,
        minExtendedWidth: 220,
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.white.withOpacity(0.14),
        selectedIndex: index < 0 ? null : index,
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: const IconThemeData(color: Colors.white60),
        selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
        labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
        onDestinationSelected: (i) => ref.read(sectionProvider.notifier).state = sections[i],
        leading: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
            child: Icon(Icons.storefront_rounded, color: AppColors.primary),
          ),
        ),
        trailing: Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (user != null)
                    Tooltip(message: '${user.name} (${UserRole.label(user.role)})', child: InitialAvatar(name: user.name, radius: 18)),
                  const SizedBox(height: 8),
                  IconButton(
                    tooltip: 'Lock register',
                    onPressed: () => _lock(ref),
                    icon: const Icon(Icons.lock_outline_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
        destinations: [
          for (final s in sections)
            NavigationRailDestination(icon: Icon(s.icon), selectedIcon: Icon(s.selectedIcon), label: Text(s.label)),
        ],
      ),
    );
  }
}

class _NavDrawer extends ConsumerWidget {
  const _NavDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(visibleSectionsProvider);
    final current = ref.watch(sectionProvider);
    final user = ref.watch(currentUserProvider);
    final storeName = ref.watch(settingsProvider).storeName;

    return Drawer(
      width: 290,
      backgroundColor: AppColors.navy,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.storefront_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(storeName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (user != null)
                          Text('${user.name} · ${UserRole.label(user.role)}', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final s in sections)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        selected: s == current,
                        selectedTileColor: Colors.white.withOpacity(0.12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Icon(s == current ? s.selectedIcon : s.icon, color: Colors.white),
                        title: Text(s.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(context);
                          ref.read(sectionProvider.notifier).state = s;
                        },
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded, color: Colors.white70),
              title: const Text('Lock register', style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                _lock(ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

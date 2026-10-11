import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/user_entity.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/features/auth/auth.dart';
import 'package:pricelet_app/src/features/auth/login_page.dart';
import 'package:pricelet_app/src/features/shell/app_shell.dart';

class PriceletApp extends ConsumerWidget {
  const PriceletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Land each user on their home section when they sign in.
    ref.listen<UserEntity?>(currentUserProvider, (previous, next) {
      if (next != null && previous?.id != next.id) {
        ref.read(sectionProvider.notifier).state = AppSection.homeFor(next);
      }
    });
    final signedIn = ref.watch(currentUserProvider) != null;

    return MaterialApp(
      title: 'Pricelet POS',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: signedIn ? const AppShell() : const LoginPage(),
    );
  }
}

/// Shown when the database cannot be opened at startup.
class StartupErrorApp extends StatelessWidget {
  final Object error;

  const StartupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_rounded, size: 48, color: AppColors.danger),
                const SizedBox(height: 12),
                const Text('Pricelet could not open its database', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SelectableText('$error', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

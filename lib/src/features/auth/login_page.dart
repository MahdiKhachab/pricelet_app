import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/user_entity.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/auth/auth.dart';
import 'package:pricelet_app/src/features/settings/app_settings.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const _maxPinLength = 8;

  UserEntity? _selected;
  String _pin = '';
  String? _error;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _select(UserEntity user) {
    setState(() {
      _selected = user;
      _pin = '';
      _error = null;
    });
    _focusNode.requestFocus();
  }

  void _press(String digit) {
    if (_pin.length >= _maxPinLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submit() {
    final user = _selected;
    if (user == null || _pin.isEmpty) return;
    if (verifyPin(user, _pin)) {
      ref.read(currentUserProvider.notifier).state = user;
    } else {
      setState(() {
        _pin = '';
        _error = 'Incorrect PIN';
      });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final char = event.character;
    if (char != null && RegExp(r'^\d$').hasMatch(char)) {
      _press(char);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final storeName = ref.watch(settingsProvider).storeName;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.navy, AppColors.navyLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Focus(
                  focusNode: _focusNode,
                  autofocus: true,
                  onKeyEvent: _onKey,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: usersAsync.when(
                        loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(usersProvider)),
                        data: (users) {
                          final active = users.where((u) => u.active).toList();
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircleAvatar(
                                radius: 30,
                                backgroundColor: AppColors.primarySoft,
                                child: Icon(Icons.storefront_rounded, color: AppColors.primary, size: 32),
                              ),
                              const SizedBox(height: 12),
                              Text(storeName, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                              const SizedBox(height: 4),
                              Text(
                                _selected == null ? 'Who is signing in?' : 'Enter PIN for ${_selected!.name}',
                                style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                              ),
                              const SizedBox(height: 20),
                              if (_selected == null)
                                _UserList(users: active, onSelect: _select)
                              else
                                // Pad buttons must not steal focus from the
                                // keyboard listener above.
                                ExcludeFocus(
                                  child: _PinPad(
                                    pinLength: _pin.length,
                                    error: _error,
                                    onDigit: _press,
                                    onBackspace: _backspace,
                                    onSubmit: _submit,
                                    onBack: () => setState(() => _selected = null),
                                  ),
                                ),
                              if (_showDefaultPinHint(active)) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'First launch: the Admin PIN is $defaultAdminPin. Change it in Settings → Staff.',
                                  style: textTheme.bodySmall?.copyWith(color: AppColors.warning),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _showDefaultPinHint(List<UserEntity> users) =>
      users.any((u) => u.isAdmin && verifyPin(u, defaultAdminPin));
}

class _UserList extends StatelessWidget {
  final List<UserEntity> users;
  final ValueChanged<UserEntity> onSelect;

  const _UserList({required this.users, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final user in users)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE6EAF2)),
              ),
              leading: InitialAvatar(name: user.name),
              title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(UserRole.label(user.role)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onSelect(user),
            ),
          ),
      ],
    );
  }
}

class _PinPad extends StatelessWidget {
  final int pinLength;
  final String? error;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _PinPad({
    required this.pinLength,
    required this.error,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            width: 76,
            height: 60,
            child: OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(padding: EdgeInsets.zero), child: child),
          ),
        );
    Widget digit(String d) => key(Text(d, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)), () => onDigit(d));

    return Column(
      children: [
        SizedBox(
          height: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < (pinLength < 4 ? 4 : pinLength); i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < pinLength ? AppColors.primary : const Color(0xFFE0E5EE),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 24,
          child: error == null ? null : Text(error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) digit(d)]),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            key(const Icon(Icons.backspace_outlined), onBackspace),
            digit('0'),
            Padding(
              padding: const EdgeInsets.all(6),
              child: SizedBox(
                width: 76,
                height: 60,
                child: FilledButton(onPressed: onSubmit, style: FilledButton.styleFrom(padding: EdgeInsets.zero), child: const Icon(Icons.arrow_forward_rounded)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded), label: const Text('Switch user')),
      ],
    );
  }
}

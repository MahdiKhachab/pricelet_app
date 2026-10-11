import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/user_entity.dart';
import 'package:pricelet_app/src/core/providers.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/auth/auth.dart';
import 'package:pricelet_app/src/features/settings/settings_page.dart';

/// Manage staff accounts (managers and cashiers) and their PINs.
class StaffSection extends ConsumerWidget {
  const StaffSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    final me = ref.watch(currentUserProvider);

    return SectionCard(
      title: 'Staff',
      trailing: FilledButton.tonalIcon(
        onPressed: () => showDialog(context: context, builder: (_) => const _UserDialog()),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add staff'),
      ),
      child: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e),
        data: (users) => Column(
          children: [
            for (final u in users)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: InitialAvatar(name: u.name),
                title: Text(u.id == me?.id ? '${u.name} (you)' : u.name, style: TextStyle(fontWeight: FontWeight.w700, color: u.active ? null : AppColors.subtle)),
                subtitle: Text(UserRole.label(u.role) + (u.active ? '' : ' · disabled')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (u.isAdmin && verifyPin(u, defaultAdminPin)) const StatusChip(label: 'Default PIN', color: AppColors.warning),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                onTap: () => showDialog(context: context, builder: (_) => _UserDialog(user: u)),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserDialog extends ConsumerStatefulWidget {
  final UserEntity? user;

  const _UserDialog({this.user});

  @override
  ConsumerState<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends ConsumerState<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name ?? '');
  final _pin = TextEditingController();
  late String _role = widget.user?.role ?? UserRole.cashier;
  late bool _active = widget.user?.active ?? true;

  bool get _isNew => widget.user == null;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final dao = ref.read(databaseProvider).userDao;
    final users = await dao.findAllUsers();
    final existing = widget.user;

    // Never leave the store without an active manager.
    final otherActiveAdmins = users.where((u) => u.isAdmin && u.active && u.id != existing?.id).length;
    if (existing != null && existing.isAdmin && (!_active || _role != UserRole.admin) && otherActiveAdmins == 0) {
      if (mounted) showMessage(context, 'At least one active manager is required', error: true);
      return;
    }

    final pin = _pin.text.trim();
    if (existing == null) {
      await dao.insertUser(newUser(name: _name.text.trim(), role: _role, pin: pin));
    } else {
      var updated = existing.copyWith(name: _name.text.trim(), role: _role, active: _active);
      if (pin.isNotEmpty) {
        final salt = newSalt();
        updated = updated.copyWith(pinSalt: salt, pinHash: hashPin(pin, salt));
      }
      await dao.updateUser(updated);
      // Keep the session in sync when editing yourself.
      if (ref.read(currentUserProvider)?.id == updated.id) {
        ref.read(currentUserProvider.notifier).state = updated;
      }
    }
    ref.invalidate(usersProvider);
    if (mounted) {
      Navigator.pop(context);
      showMessage(context, _isNew ? 'Staff member added' : 'Staff member updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'Add staff member' : 'Edit ${widget.user!.name}'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(controller: _name, autofocus: _isNew, decoration: const InputDecoration(labelText: 'Name *'), validator: requiredValidator),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: UserRole.cashier, label: Text('Cashier'), icon: Icon(Icons.point_of_sale_rounded)),
                  ButtonSegment(value: UserRole.admin, label: Text('Manager'), icon: Icon(Icons.admin_panel_settings_rounded)),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 6),
              Text(
                _role == UserRole.admin
                    ? 'Full access: products, reports, refunds and settings.'
                    : 'Register, sales history, customers and price check.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: pinInputFormatters,
                decoration: InputDecoration(labelText: _isNew ? 'PIN (4-8 digits) *' : 'New PIN (leave empty to keep)'),
                validator: (v) {
                  final pin = v?.trim() ?? '';
                  if (pin.isEmpty && !_isNew) return null;
                  if (pin.length < 4) return 'Use at least 4 digits';
                  return null;
                },
              ),
              if (!_isNew)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: const Text('Can sign in'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/settings/app_settings.dart';
import 'package:pricelet_app/src/features/settings/staff_section.dart';
import 'package:pricelet_app/src/features/shell/app_shell.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late AppSettings _initial;
  late final TextEditingController _storeName;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _footer;
  late final TextEditingController _symbol;
  late final TextEditingController _secondarySymbol;
  late final TextEditingController _rate;
  late final TextEditingController _tax;
  late int _decimals;
  late int _secondaryDecimals;
  late bool _secondaryEnabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initial = ref.read(settingsProvider);
    final s = _initial;
    String n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
    _storeName = TextEditingController(text: s.storeName);
    _address = TextEditingController(text: s.storeAddress);
    _phone = TextEditingController(text: s.storePhone);
    _footer = TextEditingController(text: s.receiptFooter);
    _symbol = TextEditingController(text: s.currencySymbol);
    _secondarySymbol = TextEditingController(text: s.secondarySymbol);
    _rate = TextEditingController(text: n(s.exchangeRate));
    _tax = TextEditingController(text: n(s.taxRate));
    _decimals = s.currencyDecimals;
    _secondaryDecimals = s.secondaryDecimals;
    _secondaryEnabled = s.secondaryEnabled;
  }

  @override
  void dispose() {
    for (final c in [_storeName, _address, _phone, _footer, _symbol, _secondarySymbol, _rate, _tax]) {
      c.dispose();
    }
    super.dispose();
  }

  AppSettings get _draft => _initial.copyWith(
        storeName: _storeName.text.trim(),
        storeAddress: _address.text.trim(),
        storePhone: _phone.text.trim(),
        receiptFooter: _footer.text.trim(),
        currencySymbol: _symbol.text.trim(),
        currencyDecimals: _decimals,
        secondaryEnabled: _secondaryEnabled,
        secondarySymbol: _secondarySymbol.text.trim(),
        secondaryDecimals: _secondaryDecimals,
        exchangeRate: parseDecimal(_rate.text) ?? _initial.exchangeRate,
        taxRate: parseDecimal(_tax.text) ?? 0,
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final draft = _draft;
      await ref.read(settingsProvider.notifier).save(draft);
      _initial = draft;
      if (mounted) showMessage(context, 'Settings saved');
    } catch (e) {
      if (mounted) showMessage(context, 'Could not save settings: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = Money(_draft);
    void refresh(String _) => setState(() {});

    final store = SectionCard(
      title: 'Store',
      child: Column(
        children: [
          TextFormField(controller: _storeName, decoration: const InputDecoration(labelText: 'Store name *'), validator: requiredValidator),
          const SizedBox(height: 12),
          TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 12),
          TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 12),
          TextFormField(controller: _footer, maxLines: 2, decoration: const InputDecoration(labelText: 'Receipt footer')),
        ],
      ),
    );

    final currency = SectionCard(
      title: 'Currency & tax',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _symbol,
                  onChanged: refresh,
                  decoration: const InputDecoration(labelText: 'Currency symbol *', helperText: 'Prices are entered in this currency'),
                  validator: requiredValidator,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _decimalsField('Decimals', _decimals, (v) => setState(() => _decimals = v))),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tax,
            onChanged: refresh,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: decimalInputFormatters,
            decoration: const InputDecoration(labelText: 'Tax rate', suffixText: '%', helperText: 'Added on top of prices at checkout. 0 to disable.'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _secondaryEnabled,
            onChanged: (v) => setState(() => _secondaryEnabled = v),
            title: const Text('Show second currency'),
            subtitle: const Text('Display totals and accept cash in a second currency, e.g. L.L'),
          ),
          if (_secondaryEnabled) ...[
            Row(
              children: [
                Expanded(child: TextFormField(controller: _secondarySymbol, onChanged: refresh, decoration: const InputDecoration(labelText: 'Symbol'), validator: requiredValidator)),
                const SizedBox(width: 12),
                Expanded(child: _decimalsField('Decimals', _secondaryDecimals, (v) => setState(() => _secondaryDecimals = v))),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rate,
              onChanged: refresh,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: decimalInputFormatters,
              decoration: InputDecoration(labelText: 'Exchange rate', prefixText: '1 ${_symbol.text} = ', suffixText: _secondarySymbol.text),
              validator: (v) => (parseDecimal(v ?? '') ?? 0) <= 0 ? 'Enter a rate above 0' : null,
            ),
          ],
          const SizedBox(height: 12),
          Text('Preview: ${preview.both(1234.5)}', style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );

    return ShellScaffold(
      title: 'Settings',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(builder: (context, c) {
                      if (c.maxWidth < 760) return Column(children: [store, const SizedBox(height: 16), currency]);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Expanded(child: store), const SizedBox(width: 16), Expanded(child: currency)],
                      );
                    }),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save settings'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const StaffSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decimalsField(String label, int value, ValueChanged<int> onChanged) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [for (final d in [0, 1, 2, 3]) DropdownMenuItem(value: d, child: Text('$d'))],
      onChanged: (v) => onChanged(v ?? value),
    );
  }
}

/// Digits-only formatter shared by PIN fields.
final pinInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(8),
];

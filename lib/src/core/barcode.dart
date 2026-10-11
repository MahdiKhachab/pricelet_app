import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

/// The camera scanner plugin only exists on Android and iOS. On desktop, USB
/// barcode scanners type into the focused text field instead.
bool get cameraScanSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Scans a barcode with the camera, or asks for it to be typed/scanned into a
/// dialog when no camera scanner is available. Returns null when cancelled.
Future<String?> scanBarcode(BuildContext context) async {
  if (cameraScanSupported) {
    try {
      final code = await FlutterBarcodeScanner.scanBarcode('#4C6FFF', 'Cancel', true, ScanMode.BARCODE);
      return code == '-1' || code.trim().isEmpty ? null : code.trim();
    } catch (_) {
      // Fall through to manual entry if the camera is unavailable.
    }
  }
  if (!context.mounted) return null;
  return showDialog<String>(context: context, builder: (_) => const _BarcodeEntryDialog());
}

class _BarcodeEntryDialog extends StatefulWidget {
  const _BarcodeEntryDialog();

  @override
  State<_BarcodeEntryDialog> createState() => _BarcodeEntryDialogState();
}

class _BarcodeEntryDialogState extends State<_BarcodeEntryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    Navigator.pop(context, code.isEmpty ? null : code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scan or enter barcode'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Barcode', prefixIcon: Icon(Icons.qr_code_rounded)),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerSheet extends StatefulWidget {
  const BarcodeScannerSheet({super.key});

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  bool _hasResult = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 16),
              const Text(
                'Scan barcode / QR',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                if (_hasResult) return;
                if (capture.barcodes.isEmpty) return;
                final barcode = capture.barcodes.first;
                final value = barcode?.rawValue;
                if (value == null || value.trim().isEmpty) return;
                setState(() => _hasResult = true);
                Navigator.of(context).pop(value.trim());
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Point the camera at a QR or barcode.'),
          ),
        ],
      ),
    );
  }
}

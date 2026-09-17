import 'package:flutter/material.dart';

class CameraScanPlaceholder extends StatelessWidget {
  final VoidCallback onSimulateScan;

  const CameraScanPlaceholder({super.key, required this.onSimulateScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Scan Barcode or Receipt (ML Kit coming soon)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onSimulateScan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Simulate Scan'),
          )
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class RedemptionDialog extends StatefulWidget {
  const RedemptionDialog({required this.onSubmit, super.key});

  final ValueChanged<String> onSubmit;

  @override
  State<RedemptionDialog> createState() => _RedemptionDialogState();
}

class _RedemptionDialogState extends State<RedemptionDialog> {
  String _deliveryMethod = 'Ship to me';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request redemption'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose how Orion should hand over the matching inventory unit.',
          ),
          const SizedBox(height: 12),
          for (final method in ['Ship to me', 'Arrange warehouse pickup'])
            RadioListTile<String>(
              value: method,
              groupValue: _deliveryMethod,
              contentPadding: EdgeInsets.zero,
              title: Text(method, style: const TextStyle(fontSize: 13)),
              onChanged: (value) => setState(() => _deliveryMethod = value!),
            ),
          const Text(
            'A secure hash of your delivery address is submitted on-chain to mint your Orion Redemption Ticket.',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onSubmit(_deliveryMethod);
          },
          child: const Text('Submit request'),
        ),
      ],
    );
  }
}

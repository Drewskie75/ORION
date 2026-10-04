import 'package:flutter/material.dart';

import '../../../core/theme/orion_theme.dart';
import '../models/owned_claim.dart';

class ClaimActionsSheet extends StatelessWidget {
  const ClaimActionsSheet({
    required this.claim,
    required this.onSell,
    required this.onRedeem,
    super.key,
  });

  final OwnedClaim claim;
  final VoidCallback onSell;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final canAct = claim.status == 'Held';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              claim.listing.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            Text(
              '${claim.listing.identifier} · ${claim.status}',
              style: const TextStyle(color: OrionColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _detailRow('Backing inventory', claim.listing.specification),
            _detailRow('Custody', 'Orion · mock record'),
            const SizedBox(height: 14),
            if (canAct) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSell,
                  icon: const Icon(Icons.sell_outlined),
                  label: const Text('List on secondary market'),
                  style: FilledButton.styleFrom(
                    backgroundColor: OrionColors.crimson,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRedeem,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Redeem physical asset'),
                ),
              ),
            ] else
              Text(
                'This claim is ${claim.status.toLowerCase()}; further actions are unavailable in the preview.',
                style: const TextStyle(color: OrionColors.muted, fontSize: 12),
              ),
            const SizedBox(height: 10),
            const Text(
              'Redemption and listing interact directly with Orion Protocol (Devnet Program: 9yX2d3V9...).',
              style: TextStyle(color: OrionColors.muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: OrionColors.muted, fontSize: 12),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

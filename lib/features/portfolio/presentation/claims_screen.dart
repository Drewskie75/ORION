import 'package:flutter/material.dart';

import '../../../core/theme/orion_theme.dart';
import '../../../shared/widgets/claim_card.dart';
import '../models/owned_claim.dart';

class ClaimsScreen extends StatelessWidget {
  const ClaimsScreen({
    required this.claims,
    required this.onClaimSelected,
    super.key,
  });

  final List<OwnedClaim> claims;
  final ValueChanged<int> onClaimSelected;

  @override
  Widget build(BuildContext context) {
    final active = claims.where((claim) => claim.status != 'Redeemed').toList();
    final total = active.fold<double>(
      0,
      (sum, claim) => sum + (double.tryParse(claim.listing.price) ?? 0),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text('Your claims', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 7),
        const Text(
          'Digital receipts for inventory held in Orion custody.',
          style: TextStyle(color: OrionColors.muted),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: OrionColors.darkRed,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MOCK PORTFOLIO VALUE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '${active.length} active claims · values are illustrative',
                style: const TextStyle(
                  color: OrionColors.lightRed,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Inventory-backed claims',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${claims.length} total',
              style: const TextStyle(color: OrionColors.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < claims.length; index++) ...[
          ClaimCard(claim: claims[index], onTap: () => onClaimSelected(index)),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        const Text(
          'Claim records shown here are local preview data. On-chain ownership is not being checked.',
          style: TextStyle(color: OrionColors.muted, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }
}

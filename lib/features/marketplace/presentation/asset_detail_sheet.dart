import 'package:flutter/material.dart';

import '../../../core/theme/orion_theme.dart';
import '../../../shared/widgets/asset_artwork.dart';
import '../models/asset_listing.dart';

class AssetDetailSheet extends StatelessWidget {
  const AssetDetailSheet({
    required this.listing,
    required this.onReviewPurchase,
    super.key,
  });

  final AssetListing listing;
  final VoidCallback onReviewPurchase;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: OrionColors.oxblood,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: AssetArtwork(listing: listing),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  listing.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '\$${listing.price}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: OrionColors.oxblood,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            listing.specification,
            style: const TextStyle(color: OrionColors.muted),
          ),
          const SizedBox(height: 16),
          _detailRow('Condition', listing.grade),
          _detailRow('Tracked identifier', listing.identifier),
          _detailRow('Custody status', 'Held by Orion · mock data'),
          _detailRow('Verified supply', '1 active claim'),
          _detailRow('Evidence bundle', 'Inspection · custody log · photos'),
          _detailRow('Verifier', 'Orion Operations · approved'),
          _detailRow('Reference movement', listing.change),
          const SizedBox(height: 12),
          const Text(
            'Inventory, verification, and pricing shown here are sample data. A claim is not automatic legal title.',
            style: TextStyle(
              color: OrionColors.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onReviewPurchase,
              style: FilledButton.styleFrom(
                backgroundColor: OrionColors.crimson,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Review purchase'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _detailRow(String label, String value) => Padding(
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

import 'package:flutter/material.dart';

import '../../core/theme/orion_theme.dart';
import '../../features/portfolio/models/owned_claim.dart';

class ClaimCard extends StatelessWidget {
  const ClaimCard({required this.claim, required this.onTap, super.key});

  final OwnedClaim claim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = claim.status == 'Held';
    return Material(
      color: OrionColors.surface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: OrionColors.paleRed,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  claim.listing.icon,
                  size: 28,
                  color: OrionColors.oxblood,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      claim.listing.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${claim.listing.identifier} · ${claim.listing.specification}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OrionColors.muted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          isActive
                              ? Icons.verified_user_outlined
                              : Icons.timelapse_outlined,
                          size: 13,
                          color: OrionColors.oxblood,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          claim.status,
                          style: const TextStyle(
                            color: OrionColors.oxblood,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${claim.listing.price}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Icon(
                    Icons.chevron_right,
                    size: 17,
                    color: OrionColors.muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

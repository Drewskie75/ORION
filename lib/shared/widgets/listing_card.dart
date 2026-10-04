import 'package:flutter/material.dart';

import '../../core/theme/orion_theme.dart';
import '../../features/marketplace/models/asset_listing.dart';
import 'asset_artwork.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({
    required this.listing,
    required this.onTap,
    required this.animation,
    super.key,
  });

  final AssetListing listing;
  final VoidCallback onTap;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: animation.drive(
          Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero),
        ),
        child: Material(
          color: OrionColors.surface,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 118,
                  width: double.infinity,
                  child: AssetArtwork(listing: listing),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              listing.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.verified,
                            color: OrionColors.oxblood,
                            size: 14,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        listing.specification,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: OrionColors.muted,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 11),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              '\$${listing.price}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            listing.change,
                            style: const TextStyle(
                              color: OrionColors.crimson,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 13,
                            color: OrionColors.oxblood,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${listing.grade} · custody record',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: OrionColors.oxblood,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

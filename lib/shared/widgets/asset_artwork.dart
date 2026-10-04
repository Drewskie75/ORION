import 'package:flutter/material.dart';

import '../../core/theme/orion_theme.dart';
import '../../features/marketplace/models/asset_listing.dart';

class AssetArtwork extends StatelessWidget {
  const AssetArtwork({required this.listing, super.key});

  final AssetListing listing;

  @override
  Widget build(BuildContext context) {
    if (listing.imageAsset != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            listing.imageAsset!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  OrionColors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [OrionColors.surface, OrionColors.oxblood],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(listing.icon, size: 48, color: OrionColors.oxblood),
    );
  }
}

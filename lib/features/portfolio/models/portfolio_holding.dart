import 'package:flutter/material.dart';
import '../../marketplace/models/asset_listing.dart';

class PortfolioHolding {
  const PortfolioHolding({
    required this.name,
    required this.unitPrice,
    required this.amount,
    required this.change,
    required this.totalValue,
    required this.isPositive,
    this.iconBgColor,
    this.icon,
    this.imageAsset,
    this.listing,
  });

  final String name;
  final String unitPrice;
  final String amount;
  final String change;
  final String totalValue;
  final bool isPositive;
  final Color? iconBgColor;
  final IconData? icon;
  final String? imageAsset;
  final AssetListing? listing;
}

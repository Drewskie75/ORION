import 'package:flutter/material.dart';

class AssetListing {
  const AssetListing({
    this.assetId = 1,
    required this.name,
    required this.category,
    required this.grade,
    required this.price,
    required this.change,
    required this.identifier,
    required this.specification,
    required this.icon,
    this.imageAsset,
    this.sparklinePoints,
    this.iconBgColor,
    this.marketCap,
    this.volume24h,
    this.totalSupply,
    this.liquidity,
  });

  final int assetId;
  final String name;
  final String category;
  final String grade;
  final String price;
  final String change;
  final String identifier;
  final String specification;
  final IconData icon;
  final String? imageAsset;
  final List<double>? sparklinePoints;
  final Color? iconBgColor;
  final String? marketCap;
  final String? volume24h;
  final String? totalSupply;
  final String? liquidity;

  factory AssetListing.fromJson(Map<String, dynamic> json) {
    IconData icon;
    Color iconBgColor;
    final cat = (json['category'] as String?)?.toLowerCase() ?? '';
    if (cat.contains('gpu')) {
      icon = Icons.memory_rounded;
      iconBgColor = const Color(0xFF2E461A);
    } else if (cat.contains('gold')) {
      icon = Icons.layers_rounded;
      iconBgColor = const Color(0xFF6B450E);
    } else if (cat.contains('car')) {
      icon = Icons.electric_car_rounded;
      iconBgColor = const Color(0xFF5E1313);
    } else if (cat.contains('ram')) {
      icon = Icons.developer_board_rounded;
      iconBgColor = const Color(0xFF1E3A8A);
    } else {
      icon = Icons.phone_iphone_rounded;
      iconBgColor = const Color(0xFF222226);
    }

    List<double>? sparkline;
    if (json['sparklinePoints'] is List) {
      sparkline = (json['sparklinePoints'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    final rawPrice = json['price_usd']?.toString() ?? json['price']?.toString() ?? '0.00';
    final parsedPrice = double.tryParse(rawPrice);
    final formattedPrice = parsedPrice != null ? parsedPrice.toStringAsFixed(2) : rawPrice;

    final changeVal = json['change']?.toString() ??
        (json['change_24h_pct'] != null ? '${json['change_24h_pct']}%' : '+0.00%');

    return AssetListing(
      assetId: int.tryParse(json['asset_id']?.toString() ?? '1') ?? 1,
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
      price: formattedPrice,
      change: changeVal,
      identifier: json['identifier']?.toString() ?? '',
      specification: json['specification']?.toString() ?? '',
      icon: icon,
      imageAsset: json['image_asset']?.toString(),
      sparklinePoints: sparkline,
      iconBgColor: iconBgColor,
      marketCap: json['marketCap']?.toString(),
      volume24h: json['volume_24h_usd'] != null ? '\$${json['volume_24h_usd']}' : null,
      totalSupply: json['total_supply']?.toString(),
      liquidity: json['liquidity_usd'] != null ? '\$${json['liquidity_usd']}' : null,
    );
  }
}

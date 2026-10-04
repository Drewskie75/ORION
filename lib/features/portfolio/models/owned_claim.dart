import '../../marketplace/models/asset_listing.dart';

class OwnedClaim {
  const OwnedClaim({
    required this.listing,
    this.status = 'Held',
    this.id,
    this.amount = 1.0,
    this.acquiredPriceUsd,
    this.txHash,
  });

  final AssetListing listing;
  final String status;
  final int? id;
  final double amount;
  final String? acquiredPriceUsd;
  final String? txHash;

  factory OwnedClaim.fromJson(Map<String, dynamic> json) {
    return OwnedClaim(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'Held',
      amount: double.tryParse(json['amount']?.toString() ?? '1.0') ?? 1.0,
      acquiredPriceUsd: json['acquired_price_usd']?.toString(),
      txHash: json['tx_hash']?.toString(),
      listing: AssetListing.fromJson(json),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/orion_theme.dart';
import '../../marketplace/models/asset_listing.dart';
import '../../marketplace/presentation/purchase_confirmation_dialog.dart';

class TradeScreen extends StatefulWidget {
  const TradeScreen({
    super.key,
    required this.listings,
    required this.walletConnected,
    this.connectedAddress,
    this.onConnectWallet,
    this.onTradeSuccess,
  });

  final List<AssetListing> listings;
  final bool walletConnected;
  final String? connectedAddress;
  final VoidCallback? onConnectWallet;
  final VoidCallback? onTradeSuccess;

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  static const double _solPriceUsd = 150.0;

  bool _isBuy = true;
  String _payAsset = 'USDC';
  String _receiveAsset = '';
  final TextEditingController _payController = TextEditingController(
    text: '185.50',
  );
  final TextEditingController _receiveController = TextEditingController(
    text: '0.25',
  );

  final List<String> _cryptoAssets = ['USDC', 'SOL', 'USDT'];
  List<String> get _rwaAssets =>
      widget.listings.map((asset) => asset.name).toList();

  AssetListing get _selectedListing => widget.listings.firstWhere(
    (asset) => asset.name == (_isBuy ? _receiveAsset : _payAsset),
    orElse: () => widget.listings.first,
  );

  double get _selectedPriceUsd =>
      double.tryParse(_selectedListing.price.replaceAll(',', '')) ?? 0;

  String get _exchangeRate {
    if (_selectedPriceUsd <= 0) return 'Unavailable';
    final paymentUsd = _payAsset == 'SOL' ? _solPriceUsd : 1.0;
    final unitsPerPayment = paymentUsd / (_selectedPriceUsd * 1.025);
    final solReference = _payAsset == 'SOL' ? ' (~\$150)' : '';
    return '1 $_payAsset$solReference ≈ ${unitsPerPayment.toStringAsFixed(6)} ${_selectedListing.name}';
  }

  @override
  void initState() {
    super.initState();
    if (widget.listings.isNotEmpty) {
      _receiveAsset = widget.listings.first.name;
    }
    _updateEstimatedUnits();
  }

  @override
  void dispose() {
    _payController.dispose();
    _receiveController.dispose();
    super.dispose();
  }

  void _switchDirections() {
    setState(() {
      final temp = _payAsset;
      _payAsset = _receiveAsset;
      _receiveAsset = temp;

      final tempVal = _payController.text;
      _payController.text = _receiveController.text;
      _receiveController.text = tempVal;
    });
  }

  void _updateEstimatedUnits() {
    if (!_isBuy || widget.listings.isEmpty) return;
    final payAmount = double.tryParse(_payController.text) ?? 0;
    final paymentUsd = payAmount * (_payAsset == 'SOL' ? _solPriceUsd : 1.0);
    final estimatedUnits = _selectedPriceUsd > 0
        ? paymentUsd / (_selectedPriceUsd * 1.025)
        : 0.0;
    _receiveController.text = estimatedUnits.toStringAsFixed(6);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrionColors.black,
      appBar: AppBar(
        backgroundColor: OrionColors.black,
        elevation: 0,
        title: const Text(
          'Trade RWA',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: OrionColors.darkRed,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OrionColors.oxblood, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00D084),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Devnet',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Buy / Sell Selector
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF161619),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isBuy = true),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _isBuy ? OrionColors.buttonGradient : null,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Buy RWA',
                        style: TextStyle(
                          color: _isBuy ? Colors.white : Colors.white60,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isBuy = false),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: !_isBuy ? OrionColors.buttonGradient : null,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Sell RWA',
                        style: TextStyle(
                          color: !_isBuy ? Colors.white : Colors.white60,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Pay Card
          _buildTradeCard(
            label: _isBuy ? 'You Pay' : 'You Sell',
            controller: _payController,
            selectedAsset: _payAsset,
            availableAssets: _isBuy ? _cryptoAssets : _rwaAssets,
            onAssetChanged: (newAsset) {
              setState(() {
                _payAsset = newAsset;
                if (newAsset == 'SOL' &&
                    (_payController.text == '185.50' ||
                        (double.tryParse(_payController.text) ?? 0) > 10)) {
                  _payController.text = '0.01';
                } else if (newAsset == 'USDC' &&
                    _payController.text == '0.01') {
                  _payController.text = '185.50';
                }
                _updateEstimatedUnits();
              });
            },
            balance: _payAsset == 'SOL' ? '12.45 SOL' : '0.00 USDC',
            onValueChanged: (_) => _updateEstimatedUnits(),
          ),

          // Direction Switcher
          Center(
            child: GestureDetector(
              onTap: _switchDirections,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: OrionColors.darkRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: OrionColors.oxblood, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: OrionColors.red.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.swap_vert_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),

          // Receive Card
          _buildTradeCard(
            label: _isBuy ? 'You Receive (Estimated)' : 'You Receive',
            controller: _receiveController,
            selectedAsset: _receiveAsset,
            availableAssets: _isBuy ? _rwaAssets : _cryptoAssets,
            onAssetChanged: (newAsset) => setState(() {
              _receiveAsset = newAsset;
              _updateEstimatedUnits();
            }),
            balance: '0.00 Units',
            readOnly: _isBuy,
          ),

          const SizedBox(height: 20),

          // Trade Breakdown Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF140707),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: OrionColors.oxblood.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Exchange Rate', _exchangeRate),
                const SizedBox(height: 8),
                _buildSummaryRow('Slippage Tolerance', '0.5% (Dynamic)'),
                const SizedBox(height: 8),
                _buildSummaryRow('Network Fee', '~0.00005 SOL (Devnet)'),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  'Settlement',
                  'Solana Orion Protocol (Devnet)',
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Execute Button
          Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: OrionColors.buttonGradient,
              borderRadius: BorderRadius.circular(27),
              boxShadow: [
                BoxShadow(
                  color: OrionColors.red.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(27),
                onTap: () {
                  if (!widget.walletConnected ||
                      widget.connectedAddress == null) {
                    widget.onConnectWallet?.call();
                    return;
                  }

                  final selectedListing = _selectedListing;
                  final baseUsdPrice = _selectedPriceUsd;

                  final currency = (_isBuy ? _payAsset : _receiveAsset)
                      .toUpperCase();
                  final payAmount =
                      double.tryParse(_payController.text) ??
                      (currency == 'SOL' ? 0.01 : 100.0);
                  final rawAmount =
                      double.tryParse(_receiveController.text) ?? 0.25;
                  final units = rawAmount > 0 ? rawAmount : 0.25;
                  final buyerWallet = widget.connectedAddress!;

                  // Show Orion Confirmation Alert Dialog with dynamic currency (SOL / USDC)
                  PurchaseConfirmationDialog.show(
                    context: context,
                    assetId: selectedListing.assetId,
                    assetName: selectedListing.name,
                    unitPriceUsdc: baseUsdPrice,
                    units: units,
                    currency: currency,
                    customPaymentTotal: payAmount,
                    buyerWallet: buyerWallet,
                    walletName: widget.connectedAddress != null
                        ? 'Connected Wallet'
                        : 'Solana Devnet Wallet',
                    onPurchaseComplete: (txHash) {
                      widget.onTradeSuccess?.call();
                    },
                  );
                },
                child: Center(
                  child: Text(
                    widget.walletConnected
                        ? 'Confirm ${_isBuy ? "Purchase" : "Sale"}'
                        : 'Connect Wallet to Trade',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeCard({
    required String label,
    required TextEditingController controller,
    required String selectedAsset,
    required List<String> availableAssets,
    required ValueChanged<String> onAssetChanged,
    required String balance,
    ValueChanged<String>? onValueChanged,
    bool readOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161619),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Text(
                  'Bal: $balance',
                  textAlign: TextAlign.end,
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Value Input
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: readOnly,
                  onChanged: onValueChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),

              // Asset Selector Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: OrionColors.darkRed,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: OrionColors.oxblood, width: 1),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: availableAssets.contains(selectedAsset)
                        ? selectedAsset
                        : availableAssets.first,
                    dropdownColor: OrionColors.darkRed,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    items: availableAssets.map((asset) {
                      return DropdownMenuItem<String>(
                        value: asset,
                        child: Text(
                          asset,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) onAssetChanged(val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 4,
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.end,
            softWrap: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

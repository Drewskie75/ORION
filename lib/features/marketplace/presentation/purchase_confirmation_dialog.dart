import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/orion_config.dart';
import '../../../core/services/orion_api_service.dart';
import '../../../core/theme/orion_theme.dart';
import '../../auth/services/solana_wallet_service.dart';

/// Luxury Web3 Confirmation AlertDialog using the official ORION_COLOR palette:
/// - Pitch Black (#0D0D0D)
/// - Dark Burgundy (#260101)
/// - Oxblood (#590202)
/// - Crimson (#A60303)
/// - Vibrant Red (#F20505)
class PurchaseConfirmationDialog extends StatefulWidget {
  const PurchaseConfirmationDialog({
    required this.assetId,
    required this.assetName,
    required this.unitPriceUsdc,
    required this.units,
    required this.buyerWallet,
    this.walletName,
    this.currency = 'USDC',
    this.customPaymentTotal,
    this.onPurchaseComplete,
    super.key,
  });

  final int assetId;
  final String assetName;
  final double unitPriceUsdc;
  final double units;
  final String buyerWallet;
  final String? walletName;
  final String currency;
  final double? customPaymentTotal;
  final void Function(String txHash)? onPurchaseComplete;

  static Future<void> show({
    required BuildContext context,
    required int assetId,
    required String assetName,
    required double unitPriceUsdc,
    required double units,
    required String buyerWallet,
    String? walletName,
    String currency = 'USDC',
    double? customPaymentTotal,
    void Function(String txHash)? onPurchaseComplete,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PurchaseConfirmationDialog(
        assetId: assetId,
        assetName: assetName,
        unitPriceUsdc: unitPriceUsdc,
        units: units,
        buyerWallet: buyerWallet,
        walletName: walletName,
        currency: currency,
        customPaymentTotal: customPaymentTotal,
        onPurchaseComplete: onPurchaseComplete,
      ),
    );
  }

  @override
  State<PurchaseConfirmationDialog> createState() =>
      _PurchaseConfirmationDialogState();
}

class _PurchaseConfirmationDialogState
    extends State<PurchaseConfirmationDialog> {
  bool _isProcessing = false;
  bool _isSuccess = false;
  String? _errorMessage;
  String _statusText = 'Preparing transaction...';
  String _txHash = '';

  String get _shortWallet {
    final w = widget.buyerWallet;
    if (w.length <= 10) return w;
    return '${w.substring(0, 4)}...${w.substring(w.length - 4)}';
  }

  bool get _isSol => widget.currency.toUpperCase() == 'SOL';

  double get _subtotal {
    if (widget.customPaymentTotal != null) {
      return widget.customPaymentTotal! / 1.025;
    }
    if (_isSol) {
      return (widget.unitPriceUsdc / 150.0) * widget.units;
    }
    return widget.unitPriceUsdc * widget.units;
  }

  double get _fee => _subtotal * 0.025;

  double get _total {
    if (widget.customPaymentTotal != null) {
      return widget.customPaymentTotal!;
    }
    return _subtotal + _fee;
  }

  Future<void> _executePurchase() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _statusText = 'Opening connected wallet...';
    });

    try {
      final isAndroid =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

      String? txHash;
      if (isAndroid) {
        txHash = await SolanaWalletService.requestWalletTransactionApproval(
          buyerWallet: widget.buyerWallet,
          currency: widget.currency,
          paymentAmount: _total,
          onStatus: (status) {
            if (mounted) setState(() => _statusText = status);
          },
        );

        if (txHash == null || txHash.isEmpty) {
          throw Exception(
            'Payment was cancelled in wallet. No assets were transferred.',
          );
        }
      }

      if (!mounted) return;
      setState(
        () => _statusText = 'Settling fractional RWA on Solana Devnet...',
      );

      final result = await OrionApiService.executePurchase(
        buyer: widget.buyerWallet,
        assetId: widget.assetId,
        amount: widget.units,
        txHash: txHash,
      );

      final hash = result['txHash']?.toString() ?? txHash ?? '';
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _txHash = hash;
      });

      widget.onPurchaseComplete?.call(hash);
    } catch (e) {
      if (!mounted) return;
      debugPrint(
        '[PurchaseConfirmationDialog] Purchase cancelled or failed: $e',
      );
      final raw = e.toString().replaceFirst('Exception: ', '');
      final isCancelled =
          raw.toLowerCase().contains('cancel') ||
          raw.toLowerCase().contains('decline') ||
          raw.toLowerCase().contains('reject') ||
          raw.toLowerCase().contains('timed out');
      setState(() {
        _isProcessing = false;
        _errorMessage = isCancelled
            ? 'Payment was cancelled in wallet. No funds were debited and no assets were transferred.'
            : raw;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: OrionColors.black,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: OrionColors.oxblood, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: OrionColors.crimson.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: _isSuccess ? _buildSuccessView() : _buildConfirmationView(),
      ),
    );
  }

  Widget _buildConfirmationView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with Icon & Title
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: OrionColors.darkRed,
                shape: BoxShape.circle,
                border: Border.all(color: OrionColors.oxblood),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Image.asset(
                  'assets/images/orion_icon.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Confirm Purchase',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Solana Devnet · Fractional RWA',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: OrionColors.darkRed,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: OrionColors.crimson.withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                'Devnet',
                style: TextStyle(
                  color: OrionColors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Order Summary Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OrionColors.darkRed,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OrionColors.oxblood),
          ),
          child: Column(
            children: [
              _detailRow('Asset', widget.assetName, isBold: true),
              const SizedBox(height: 6),
              _detailRow(
                'Dynamic Quantity',
                '${widget.units} Share${widget.units == 1.0 ? '' : 's'}',
                isBold: true,
              ),
              const SizedBox(height: 6),
              _detailRow(
                'Unit Price',
                _isSol
                    ? '${(widget.unitPriceUsdc / 150.0).toStringAsFixed(4)} SOL'
                    : '\$${widget.unitPriceUsdc.toStringAsFixed(2)} USDC',
              ),
              const SizedBox(height: 6),
              _detailRow(
                'Subtotal',
                _isSol
                    ? '${_subtotal.toStringAsFixed(4)} SOL'
                    : '\$${_subtotal.toStringAsFixed(2)} USDC',
              ),
              const SizedBox(height: 6),
              _detailRow(
                'Protocol Fee (2.5%)',
                _isSol
                    ? '${_fee.toStringAsFixed(4)} SOL'
                    : '\$${_fee.toStringAsFixed(2)} USDC',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: OrionColors.oxblood, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isSol ? 'Total SOL Due' : 'Total USDC Due',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _isSol
                        ? '${_total.toStringAsFixed(4)} SOL'
                        : '\$${_total.toStringAsFixed(2)} USDC',
                    style: const TextStyle(
                      color: OrionColors.red,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Wallet info snippet
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF140707),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white60,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                widget.walletName ?? 'Connected Wallet',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              Text(
                _shortWallet,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        if (_isProcessing) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: OrionColors.darkRed,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OrionColors.oxblood),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: OrionColors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E0909),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OrionColors.red.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: OrionColors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 22),

        // Action Buttons: Cancel vs Confirm & Authorize
        Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: _isProcessing ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: OrionColors.oxblood),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: FilledButton(
                onPressed: _isProcessing ? null : _executePurchase,
                style: FilledButton.styleFrom(
                  backgroundColor: OrionColors.crimson,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Authorizing...'),
                        ],
                      )
                    : Text(
                        'Confirm & Pay (${_isSol ? "SOL" : "USDC"})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glowing Green/Crimson Checkmark
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: OrionColors.darkRed,
            shape: BoxShape.circle,
            border: Border.all(color: OrionColors.red, width: 2),
            boxShadow: [
              BoxShadow(
                color: OrionColors.red.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF14F195),
            size: 34,
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Purchase Confirmed!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.units} share${widget.units == 1.0 ? '' : 's'} of ${widget.assetName} settled onto Solana Devnet.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 18),

        // Transaction Hash Card
        if (_txHash.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OrionColors.darkRed,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OrionColors.oxblood),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: OrionColors.muted,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'TX: ${_txHash.length > 22 ? "${_txHash.substring(0, 10)}...${_txHash.substring(_txHash.length - 8)}" : _txHash}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _txHash));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transaction signature copied'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              launchUrl(
                Uri.parse(OrionConfig.getExplorerTxUrl(_txHash)),
                mode: LaunchMode.externalApplication,
              );
            },
            icon: const Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: OrionColors.red,
            ),
            label: const Text(
              'View on Solana Explorer',
              style: TextStyle(
                color: OrionColors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],

        const SizedBox(height: 18),

        // Done button
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: OrionColors.crimson,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Done · View in Portfolio',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

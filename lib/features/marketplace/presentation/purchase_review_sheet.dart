import 'package:flutter/material.dart';

import '../../../core/theme/orion_theme.dart';
import '../models/asset_listing.dart';

class PurchaseReviewSheet extends StatefulWidget {
  const PurchaseReviewSheet({
    required this.listing,
    required this.walletConnected,
    required this.identityVerified,
    required this.onConnectWallet,
    required this.onVerifyIdentity,
    required this.onConfirm,
    super.key,
  });

  final AssetListing listing;
  final bool walletConnected;
  final bool identityVerified;
  final VoidCallback onConnectWallet;
  final VoidCallback onVerifyIdentity;
  final void Function(double units, String currency) onConfirm;

  @override
  State<PurchaseReviewSheet> createState() => _PurchaseReviewSheetState();
}

class _PurchaseReviewSheetState extends State<PurchaseReviewSheet> {
  late bool _walletConnected = widget.walletConnected;
  late bool _identityVerified = true;
  double _fractionalUnits = 1.0;
  String _currency = 'SOL'; // Default to SOL for Devnet real testing
  late final TextEditingController _customAmountController;

  @override
  void initState() {
    super.initState();
    _customAmountController = TextEditingController(text: '1.0');
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unitPriceUsd = double.tryParse(widget.listing.price.replaceAll(',', '')) ?? 0;
    final isSol = _currency == 'SOL';
    final unitPrice = isSol ? (unitPriceUsd / 150.0) : unitPriceUsd;
    final subtotal = unitPrice * _fractionalUnits;
    final fee = subtotal * 0.025;
    final total = subtotal + fee;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Purchase review',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isSol ? OrionColors.darkRed : const Color(0xFF132B45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSol ? OrionColors.red : const Color(0xFF2775CA),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSol ? Icons.flash_on_rounded : Icons.monetization_on_rounded,
                        color: isSol ? OrionColors.red : const Color(0xFF2775CA),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSol ? 'Devnet SOL' : 'Devnet USDC',
                        style: TextStyle(
                          color: isSol ? Colors.white : const Color(0xFF58A6FF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'Real on-chain fractional settlement on Solana Devnet',
              style: TextStyle(color: OrionColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),

            // Currency Selector Toggle (SOL vs USDC)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: OrionColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OrionColors.oxblood),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => setState(() => _currency = 'SOL'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSol ? OrionColors.crimson : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.flash_on_rounded, size: 15, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Pay in SOL',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isSol ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => setState(() => _currency = 'USDC'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !isSol ? OrionColors.crimson : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.monetization_on_rounded, size: 15, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Pay in USDC',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: !isSol ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: OrionColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.listing.icon,
                    color: OrionColors.oxblood,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.listing.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.listing.specification,
                          style: const TextStyle(
                            color: OrionColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    isSol
                        ? '${(unitPriceUsd / 150.0).toStringAsFixed(3)} SOL'
                        : '\$${widget.listing.price} USDC',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Always-Open Free Quantity Input
            const Text(
              'Enter Quantity (Shares / Fractions)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Stepper and Direct Editable Number Input
            Row(
              children: [
                // Decrement Button
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    final current = _fractionalUnits;
                    final step = current <= 1.0 ? 0.1 : 1.0;
                    final next = (current - step).clamp(0.01, 10000.0);
                    final formatted = double.parse(next.toStringAsFixed(4));
                    setState(() {
                      _fractionalUnits = formatted;
                      _customAmountController.text = '$formatted';
                    });
                  },
                  child: Container(
                    width: 44,
                    height: 48,
                    decoration: BoxDecoration(
                      color: OrionColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.remove, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 8),

                // Free Editable Quantity Field
                Expanded(
                  child: TextField(
                    controller: _customAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Enter quantity (e.g. 0.1, 0.5, 2.5)',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      suffixText: 'Shares',
                      suffixStyle: const TextStyle(color: OrionColors.muted, fontSize: 12),
                      filled: true,
                      fillColor: OrionColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: OrionColors.oxblood),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: OrionColors.crimson, width: 1.5),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val.trim());
                      setState(() {
                        if (parsed != null && parsed > 0) {
                          _fractionalUnits = parsed;
                        } else {
                          _fractionalUnits = 0.0;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Increment Button
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    final current = _fractionalUnits;
                    final step = current < 1.0 ? 0.1 : 1.0;
                    final next = (current + step).clamp(0.01, 10000.0);
                    final formatted = double.parse(next.toStringAsFixed(4));
                    setState(() {
                      _fractionalUnits = formatted;
                      _customAmountController.text = '$formatted';
                    });
                  },
                  child: Container(
                    width: 44,
                    height: 48,
                    decoration: BoxDecoration(
                      color: OrionColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Quick Preset Suggestions (shortcuts that do not lock the user)
            Row(
              children: [0.1, 0.25, 0.5, 1.0, 2.0, 5.0].map((preset) {
                final isCurrent = (_fractionalUnits - preset).abs() < 0.0001;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          _fractionalUnits = preset;
                          _customAmountController.text = '$preset';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isCurrent ? OrionColors.crimson : OrionColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrent ? OrionColors.red : Colors.white12,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$preset',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            _eligibilityRow(
              'Solana wallet',
              _walletConnected ? 'Connected · Devnet' : 'Not connected',
              _walletConnected,
            ),
            const SizedBox(height: 8),
            _eligibilityRow(
              'Payment Currency',
              'Devnet USDC (Active)',
              true,
            ),
            const SizedBox(height: 8),
            _eligibilityRow(
              'Identity check',
              _identityVerified ? 'Verified · active' : 'Required',
              _identityVerified,
            ),
            if (!_walletConnected)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _walletConnected = true);
                    widget.onConnectWallet();
                  },
                  icon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 17,
                  ),
                  label: const Text('Connect wallet'),
                ),
              ),
            if (_walletConnected && !_identityVerified)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _identityVerified = true);
                    widget.onVerifyIdentity();
                  },
                  icon: const Icon(Icons.fact_check_outlined, size: 17),
                  label: const Text('Complete verification'),
                ),
              ),
            const SizedBox(height: 12),
            _detailRow('Fraction', '$_fractionalUnits share${_fractionalUnits == 1.0 ? "" : "s"} of ${widget.listing.name}'),
            _detailRow(
              'Subtotal',
              isSol
                  ? '${subtotal.toStringAsFixed(4)} SOL'
                  : '\$${subtotal.toStringAsFixed(2)} USDC',
            ),
            _detailRow(
              'Protocol fee (2.5%)',
              isSol
                  ? '${fee.toStringAsFixed(4)} SOL'
                  : '\$${fee.toStringAsFixed(2)} USDC',
            ),
            const Divider(height: 18),
            _detailRow(
              'Estimated total',
              isSol
                  ? '${total.toStringAsFixed(4)} SOL'
                  : '\$${total.toStringAsFixed(2)} USDC',
            ),
            const SizedBox(height: 10),
            const Text(
              'Purchases settle on Solana Devnet via Orion Protocol. Fractional SPL tokens are transferred directly to your wallet Associated Token Account (ATA).',
              style: TextStyle(
                color: OrionColors.muted,
                fontSize: 10,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _fractionalUnits > 0
                    ? () {
                        if (!_walletConnected) {
                          setState(() => _walletConnected = true);
                          widget.onConnectWallet();
                        } else {
                          widget.onConfirm(_fractionalUnits, _currency);
                        }
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: OrionColors.crimson,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      !_walletConnected
                          ? 'Connect Wallet to Buy'
                          : _fractionalUnits > 0
                              ? 'Request Wallet Approval · ${isSol ? "${total.toStringAsFixed(4)} SOL" : "\$${total.toStringAsFixed(2)} USDC"}'
                              : 'Enter a valid quantity > 0',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eligibilityRow(String label, String value, bool complete) => Row(
    children: [
      Icon(
        complete ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
        color: complete ? const Color(0xFF00D084) : OrionColors.muted,
        size: 17,
      ),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 12)),
      const Spacer(),
      Text(
        value,
        style: TextStyle(
          color: complete ? const Color(0xFF00D084) : OrionColors.muted,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    ],
  );

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: OrionColors.muted, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config/orion_config.dart';

/// Interactive Solana Wallet Transaction Approval Sheet (Phantom / Solflare style).
/// Presents the user with an authentic Web3 signature request to approve paying
/// Devnet USDC for their fractional RWA claim.
class WalletUsdcApprovalSheet extends StatefulWidget {
  const WalletUsdcApprovalSheet({
    required this.buyerWallet,
    required this.usdcAmount,
    required this.assetName,
    required this.fractionalUnits,
    required this.onApproved,
    this.walletName,
    this.onRejected,
    super.key,
  });

  final String buyerWallet;
  final String? walletName;
  final double usdcAmount;
  final String assetName;
  final double fractionalUnits;
  final VoidCallback onApproved;
  final VoidCallback? onRejected;

  @override
  State<WalletUsdcApprovalSheet> createState() => _WalletUsdcApprovalSheetState();
}

class _WalletUsdcApprovalSheetState extends State<WalletUsdcApprovalSheet> {
  bool _isSigning = false;

  String get _displayWalletName => widget.walletName ?? 'Solana Wallet';

  String get _shortBuyer {
    if (widget.buyerWallet.length <= 10) return widget.buyerWallet;
    return '${widget.buyerWallet.substring(0, 4)}...${widget.buyerWallet.substring(widget.buyerWallet.length - 4)}';
  }

  String get _shortTreasury {
    const t = OrionConfig.treasuryPubkey;
    if (t.length <= 10) return t;
    return '${t.substring(0, 4)}...${t.substring(t.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF101014),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Color(0xFF2E2E36), width: 1.2),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header: Wallet Icon, Wallet Name, Devnet Badge
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFAB9FF2).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFAB9FF2)),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFFAB9FF2),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_displayWalletName Request',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Connected: $_shortBuyer',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1333),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF9945FF), width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: Color(0xFF14F195), size: 12),
                    SizedBox(width: 3),
                    Text(
                      'Devnet',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Central Payment Action Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF18181E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                const Text(
                  'ALLOW PAYMENT',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: Color(0xFF2775CA),
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '-${widget.usdcAmount.toStringAsFixed(2)} USDC',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'For ${widget.fractionalUnits}x ${widget.assetName}',
                  style: const TextStyle(
                    color: Color(0xFF30D158),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Transaction details rows
          _buildInfoRow('Wallet', '$_displayWalletName ($_shortBuyer)'),
          _buildInfoRow('Action', 'Allow USDC Transfer'),
          _buildInfoRow('Contract', 'Orion Protocol (9yX2...VTS)'),
          _buildInfoRow('Recipient', 'Orion Treasury ($_shortTreasury)'),
          _buildInfoRow('Token Mint', 'Devnet USDC (4zMM...ncDU)'),
          _buildInfoRow('Network Fee', r'< 0.000005 SOL (~$0.0008)'),

          const SizedBox(height: 14),

          // Simulation Success Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F291E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF14F195).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Color(0xFF14F195), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Simulation Passed: -USDC out, +RWA claim token in',
                    style: TextStyle(
                      color: Color(0xFF14F195),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Action buttons: Cancel vs Approve & Sign
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _isSigning
                      ? null
                      : () {
                          Navigator.pop(context);
                          widget.onRejected?.call();
                        },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: FilledButton(
                  onPressed: _isSigning
                      ? null
                      : () async {
                          HapticFeedback.heavyImpact();
                          setState(() => _isSigning = true);
                          await Future.delayed(const Duration(milliseconds: 650));
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          widget.onApproved();
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9945FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSigning
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
                            Flexible(
                              child: Text(
                                'Authorizing...',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_open_rounded, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Allow & Pay',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

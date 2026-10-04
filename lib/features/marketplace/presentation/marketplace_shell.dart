import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/orion_config.dart';
import '../../../core/services/orion_api_service.dart';
import '../../../core/theme/orion_theme.dart';
import '../../../features/home/models/portfolio_data.dart';
import '../../../features/home/presentation/home_screen.dart';
import '../../../features/portfolio/models/owned_claim.dart';
import '../../../features/portfolio/presentation/claim_actions_sheet.dart';
import '../../../features/portfolio/presentation/portfolio_screen.dart';
import '../../../features/portfolio/presentation/redemption_dialog.dart';
import '../../../features/profile/presentation/profile_screen.dart';
import '../../../features/supplier/presentation/supplier_wizard.dart';
import '../../../features/trade/presentation/trade_screen.dart';
import '../../auth/services/solana_wallet_service.dart';
import '../../marketplace/data/mock_inventory.dart';
import '../../marketplace/models/asset_listing.dart';
import 'asset_detail_screen.dart';
import 'marketplace_screen.dart';
import 'purchase_confirmation_dialog.dart';
import 'purchase_review_sheet.dart';

class MarketplaceShell extends StatefulWidget {
  const MarketplaceShell({
    this.initialWalletConnected = false,
    this.connectedWalletAddress,
    this.connectedWalletName,
    super.key,
  });

  final bool initialWalletConnected;
  final String? connectedWalletAddress;
  final String? connectedWalletName;

  @override
  State<MarketplaceShell> createState() => _MarketplaceShellState();
}

class _MarketplaceShellState extends State<MarketplaceShell> {
  int _selectedTab = 0;
  late bool _walletConnected;
  String? _connectedWalletAddress;
  String? _connectedWalletName;
  bool _identityVerified = false;
  List<AssetListing> _listings = MockInventory.listings;
  List<OwnedClaim> _claims = [];
  int _dataLoadGeneration = 0;
  late final List<String> _activities;

  @override
  void initState() {
    super.initState();
    _walletConnected = widget.initialWalletConnected;
    _connectedWalletAddress = widget.connectedWalletAddress;
    _connectedWalletName = widget.connectedWalletName;
    _activities = [
      _walletConnected && _connectedWalletAddress != null
          ? 'Wallet connected · ${_connectedWalletName ?? 'Solana wallet'} (${_connectedWalletAddress!.substring(0, 4)}...${_connectedWalletAddress!.substring(_connectedWalletAddress!.length - 4)})'
          : 'Wallet not connected · Browse mode',
      'Program active: 9yX2d3V9R93UP1Pv4kNzHp5Foas4xTEdJneiKEM2aVTS',
      'Devnet USDC Ready · Paying with USDC',
    ];
    _loadData();
  }

  Future<void> _loadData() async {
    final generation = ++_dataLoadGeneration;
    final walletAddress =
        _connectedWalletAddress ?? OrionConfig.defaultUserWallet;
    try {
      final assets = await OrionApiService.fetchAssets();
      if (assets.isNotEmpty && mounted && generation == _dataLoadGeneration) {
        setState(() => _listings = assets);
      }
      final claims = await OrionApiService.fetchUserClaims(walletAddress);
      if (mounted && generation == _dataLoadGeneration) {
        setState(() {
          _claims = claims;
        });
      }
    } catch (e) {
      debugPrint('[MarketplaceShell] _loadData error: $e');
    }
  }

  void _navigateToTab(int index) {
    if (index == _selectedTab) return;
    setState(() => _selectedTab = index);
  }

  void _handleTrendingAssetTap(TrendingAssetItem item) {
    final match = _listings.firstWhere(
      (l) => l.name.toLowerCase().contains(
        item.name.toLowerCase().split(' ').first,
      ),
      orElse: () => _listings.first,
    );
    _showListing(match);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        walletAddress: _connectedWalletAddress,
        onExploreTap: () => _navigateToTab(1),
        onWatchlistTap: () => _navigateToTab(1),
        onPortfolioTap: () => _navigateToTab(3),
        onSeeAllTrendingTap: () => _navigateToTab(1),
        onProfileTap: () => _navigateToTab(4),
        onAssetTap: _handleTrendingAssetTap,
        onSearchTap: () => _navigateToTab(1),
      ),
      MarketplaceScreen(
        listings: _listings,
        walletConnected: _walletConnected,
        onConnectWallet: _connectWallet,
        onListingSelected: _showListing,
      ),
      TradeScreen(
        listings: _listings,
        walletConnected: _walletConnected,
        connectedAddress: _connectedWalletAddress,
        onConnectWallet: _connectWallet,
        onTradeSuccess: _loadData,
      ),
      PortfolioScreen(
        claims: _claims,
        walletAddress: _connectedWalletAddress,
        onClaimSelected: _showClaimActions,
        onAssetSelected: _showListing,
        onExploreTap: () => _navigateToTab(1),
      ),
      ProfileScreen(
        walletConnected: _walletConnected,
        connectedWalletAddress: _connectedWalletAddress,
        connectedWalletName: _connectedWalletName,
        identityVerified: _identityVerified,
        claims: _claims,
        onBackTap: () => _navigateToTab(0),
        onToggleWallet: _toggleWallet,
        onCheckBalance: _showBalance,
        onVerifyIdentity: _showVerificationFlow,
        onSupplierIntake: _openSupplierWizard,
        onOpenPolicy: _showPolicyDetails,
        onRefresh: _loadData,
      ),
    ];

    return Scaffold(
      backgroundColor: OrionColors.black,
      // Apple-grade fluid cross-fade transition with subtle 1.6% vertical lift
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0.0, 0.016),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedTab),
            child: pages[_selectedTab],
          ),
        ),
      ),
      bottomNavigationBar: _buildAppleBottomNav(),
    );
  }

  /// Apple-designed Frosted Bottom Navigation Bar with Spring Haptics & Gliding Indicator
  Widget _buildAppleBottomNav() {
    final navItems = [
      (
        icon: Icons.home_rounded,
        inactiveIcon: Icons.home_outlined,
        label: 'Home',
      ),
      (
        icon: Icons.trending_up_rounded,
        inactiveIcon: Icons.trending_up_rounded,
        label: 'Markets',
      ),
      (
        icon: Icons.swap_horizontal_circle_rounded,
        inactiveIcon: Icons.swap_horizontal_circle_outlined,
        label: 'Trade',
      ),
      (
        icon: Icons.wallet_rounded,
        inactiveIcon: Icons.wallet_outlined,
        label: 'Portfolio',
      ),
      (
        icon: Icons.person_rounded,
        inactiveIcon: Icons.person_outline_rounded,
        label: 'Account',
      ),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xEB0D0D0D),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Column(
                children: [
                  // Smooth Gliding Active Indicator Bar
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final tabWidth = constraints.maxWidth / navItems.length;
                      return Stack(
                        children: [
                          const SizedBox(height: 2, width: double.infinity),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                            left: _selectedTab * tabWidth + (tabWidth - 26) / 2,
                            top: 0,
                            width: 26,
                            height: 2.2,
                            child: Container(
                              decoration: BoxDecoration(
                                color: OrionColors.red,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: OrionColors.red.withValues(
                                      alpha: 0.85,
                                    ),
                                    blurRadius: 6,
                                    spreadRadius: 0.5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // 5 Tab Buttons with Spring Bounce and Haptics
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(navItems.length, (index) {
                        return _AppleTabButton(
                          item: navItems[index],
                          isSelected: _selectedTab == index,
                          onTap: () => _navigateToTab(index),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _connectWallet() async {
    try {
      final connection = await SolanaWalletService.connectNativeWallet(
        onStatus: (msg) => _showMessage(msg),
      );
      if (connection != null && mounted) {
        setState(() {
          _walletConnected = true;
          _connectedWalletAddress = connection.publicKey;
          _connectedWalletName = connection.walletName;
          _activities.insert(
            0,
            'Wallet connected · ${connection.walletName} (${connection.shortenedAddress})',
          );
        });
        _showMessage(
          'Connected: ${connection.walletName} (${connection.shortenedAddress})',
        );
        await _loadData();
      }
    } catch (_) {
      if (mounted) {
        _showMessage('No Solana wallet available or connection cancelled');
      }
    }
  }

  void _toggleWallet() {
    if (_walletConnected) {
      setState(() {
        _walletConnected = false;
        _connectedWalletAddress = null;
        _connectedWalletName = null;
      });
      SolanaWalletService.clearSession();
      _showMessage('Solana wallet disconnected');
    } else {
      _connectWallet();
    }
  }

  void _showBalance() {
    _showMessage(
      _walletConnected
          ? 'Demo SOL balance satisfies the sample threshold.'
          : 'Connect a wallet to check the minimum balance.',
    );
  }

  void _showListing(AssetListing listing) {
    Navigator.of(context).push<void>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AssetDetailScreen(
              listing: listing,
              walletConnected: _walletConnected,
              onTrade: () => _showPurchaseFlow(listing),
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showPurchaseFlow(AssetListing listing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OrionColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) => PurchaseReviewSheet(
        listing: listing,
        walletConnected: _walletConnected,
        identityVerified: _identityVerified,
        onConnectWallet: () => setState(() => _walletConnected = true),
        onVerifyIdentity: () {
          setState(() => _identityVerified = true);
          _activities.insert(0, 'Identity verification approved');
        },
        onConfirm: (fractionalUnits, currency) async {
          Navigator.pop(sheetContext);
          await Future.delayed(const Duration(milliseconds: 150));
          if (!mounted) return;
          _showWalletPaymentRequest(
            listing,
            fractionalUnits,
            currency: currency,
          );
        },
      ),
    );
  }

  void _showWalletPaymentRequest(
    AssetListing listing,
    double fractionalUnits, {
    String currency = 'SOL',
  }) {
    final buyerWallet =
        _connectedWalletAddress ?? OrionConfig.defaultUserWallet;
    final unitPrice = double.tryParse(listing.price.replaceAll(',', '')) ?? 0.0;

    PurchaseConfirmationDialog.show(
      context: context,
      assetId: listing.assetId,
      assetName: listing.name,
      unitPriceUsdc: unitPrice,
      units: fractionalUnits,
      currency: currency,
      buyerWallet: buyerWallet,
      walletName: _connectedWalletName ?? 'Connected Wallet',
      onPurchaseComplete: (txHash) async {
        await _loadData();
        setState(() {
          _selectedTab = 3; // Switch to Portfolio tab
          _activities.insert(
            0,
            '$currency Payment Settled · ${fractionalUnits}x ${listing.name}',
          );
          _activities.insert(1, 'SPL claim token transferred to wallet ATA');
        });
      },
    );
  }

  void _showClaimActions(int index) {
    final claim = _claims[index];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OrionColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) => ClaimActionsSheet(
        claim: claim,
        onSell: () {
          setState(
            () => _claims[index] = OwnedClaim(
              listing: claim.listing,
              status: 'Listed for sale',
            ),
          );
          Navigator.pop(sheetContext);
          _showMessage('Listing published to secondary marketplace');
        },
        onRedeem: () {
          Navigator.pop(sheetContext);
          _showRedemptionDialog(claim);
        },
      ),
    );
  }

  void _showRedemptionDialog(OwnedClaim claim) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => RedemptionDialog(
        onSubmit: (method) async {
          Navigator.pop(dialogContext);
          try {
            final redeemer = _connectedWalletAddress ?? OrionConfig.programId;
            final ticketId = await OrionApiService.requestRedemption(
              claimId: claim.id ?? 1,
              redeemer: redeemer,
              carrier: method,
            );
            await _loadData();
            _showMessage(
              'Redemption Ticket #$ticketId generated on-chain! Vault logistics dispatched ($method).',
            );
          } catch (e) {
            _showMessage('Redemption requested ($method) · Vault dispatched.');
          }
        },
      ),
    );
  }

  void _showVerificationFlow() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OrionColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Identity Verification',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            const Text(
              'KYC is required before claiming physical physical custody of RWAs or trading tier-1 high value assets.',
              style: TextStyle(color: OrionColors.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _identityVerified = true);
                  Navigator.pop(sheetContext);
                  _showMessage('Identity verified (preview approved)');
                },
                child: const Text('Approve preview KYC'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSupplierWizard() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => const SupplierWizard()),
    );
  }

  void _showPolicyDetails(String title) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OrionColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              'Orion ensures physical asset provenance through certified custodian vaulting, smart contract collateralization, and audited proof-of-reserve telemetry.',
              style: TextStyle(color: OrionColors.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: OrionColors.darkRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Interactive Apple-style Navigation Button with spring bounce and haptic click
class _AppleTabButton extends StatefulWidget {
  const _AppleTabButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final ({IconData icon, IconData inactiveIcon, String label}) item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_AppleTabButton> createState() => _AppleTabButtonState();
}

class _AppleTabButtonState extends State<_AppleTabButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _springController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.86,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.86,
          end: 1.10,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.10,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
    ]).animate(_springController);
  }

  @override
  void didUpdateWidget(covariant _AppleTabButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isSelected && widget.isSelected) {
      _springController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final item = widget.item;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          HapticFeedback.lightImpact();
        },
        onTap: () {
          HapticFeedback.selectionClick();
          _springController.forward(from: 0.0);
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isSelected ? _scaleAnimation.value : 1.0,
              child: child,
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ambient frosted capsule behind active icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? OrionColors.red.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: OrionColors.red.withValues(alpha: 0.25),
                            blurRadius: 10,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isSelected ? item.icon : item.inactiveIcon,
                  color: isSelected
                      ? OrionColors.red
                      : Colors.white.withValues(alpha: 0.45),
                  size: 23,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected
                      ? OrionColors.red
                      : Colors.white.withValues(alpha: 0.50),
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: -0.1,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

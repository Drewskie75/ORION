import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orion_marketplace/main.dart';
import 'package:orion_marketplace/features/marketplace/data/mock_inventory.dart';
import 'package:orion_marketplace/features/trade/presentation/trade_screen.dart';

void main() {
  testWidgets(
    'Landing screen displays reference text and connect wallet button',
    (tester) async {
      await tester.pumpWidget(const OrionApp());
      await tester.pump();

      // Verify reference landing text from the user image
      expect(find.text('Real World Assets\nNow in Your Hands'), findsOneWidget);
      expect(
        find.text(
          'Trade tokenized real assets like phones, GPUs, RAM and more. Built on blockchain. Powered by you.',
        ),
        findsOneWidget,
      );
      expect(find.text('Connect Wallet'), findsOneWidget);
      expect(find.text('Explore Marketplace as Guest'), findsOneWidget);
      expect(find.text('ORION'), findsOneWidget);
    },
  );

  testWidgets('Guest entry navigates directly to homepage', (tester) async {
    await tester.pumpWidget(const OrionApp());
    await tester.pump();

    await tester.tap(find.text('Explore Marketplace as Guest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Good Morning,'), findsOneWidget);
    expect(find.text('Trader'), findsOneWidget);
    expect(find.text('Total Portfolio Value'), findsOneWidget);
    expect(find.text('Trending Assets'), findsOneWidget);
  });

  testWidgets('Trade estimates units from SOL and selected asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TradeScreen(
          listings: MockInventory.listings,
          walletConnected: false,
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SOL').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '0.01');

    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      '0.001490',
    );

    await tester.tap(find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tesla Model S').last);
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      '0.000021',
    );
  });

  testWidgets('Trade summary wraps on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: TradeScreen(
          listings: MockInventory.listings,
          walletConnected: false,
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Settlement'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Clicking any asset opens default buy UI matching reference design',
    (tester) async {
      await tester.pumpWidget(const OrionApp());
      await tester.pump();

      // Navigate to homepage as guest
      await tester.tap(find.text('Explore Marketplace as Guest'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Tap the Markets tab
      await tester.tap(find.text('Markets'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Tap NVIDIA GPU
      await tester.tap(find.text('NVIDIA GPU'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Asset Detail UI matches reference image
      expect(find.text('NVIDIA GPU'), findsOneWidget);
      expect(find.text('RWA'), findsOneWidget);
      expect(find.text('Tokenized'), findsOneWidget);
      expect(find.text('\$742.18'), findsOneWidget);
      expect(find.text('+3.76% (24h)'), findsOneWidget);
      expect(find.text('1D'), findsOneWidget);
      expect(find.text('1W'), findsOneWidget);
      expect(find.text('1M'), findsOneWidget);
      expect(find.text('3M'), findsOneWidget);
      expect(find.text('1Y'), findsOneWidget);
      expect(find.text('ALL'), findsOneWidget);

      // Scroll down to reveal metrics and bottom button
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Market Cap'), findsOneWidget);
      expect(find.text('\$7.2M'), findsOneWidget);
      expect(find.text('Volume (24h)'), findsOneWidget);
      expect(find.text('\$2.9M'), findsOneWidget);
      expect(find.text('Total Supply'), findsOneWidget);
      expect(find.text('10,000'), findsOneWidget);
      expect(find.text('Liquidity'), findsOneWidget);
      expect(find.text('\$9.8M'), findsOneWidget);
      expect(find.text('Trade'), findsOneWidget);
    },
  );

  testWidgets('Portfolio tab displays exact reference UI and holdings', (
    tester,
  ) async {
    await tester.pumpWidget(const OrionApp());
    await tester.pump();

    // Navigate to homepage as guest
    await tester.tap(find.text('Explore Marketplace as Guest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Tap Portfolio tab in bottom nav
    await tester.tap(find.text('Portfolio').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Header
    expect(find.text('Portfolio'), findsOneWidget);

    // Verify Total Value Card
    expect(find.text('Total Value'), findsOneWidget);
    expect(find.text('\$ 24,582.16'), findsOneWidget);
    expect(find.text('+2.48% (24h)'), findsOneWidget);

    // Verify Timeframe pills
    expect(find.text('1D'), findsOneWidget);
    expect(find.text('1W'), findsOneWidget);
    expect(find.text('1M'), findsOneWidget);
    expect(find.text('3M'), findsOneWidget);
    expect(find.text('1Y'), findsOneWidget);
    expect(find.text('ALL'), findsOneWidget);

    // Verify Your Holdings section
    expect(find.text('Your Holdings'), findsOneWidget);

    // Verify 4 Holdings from reference screenshot
    expect(find.text('iPhone 15 Pro'), findsOneWidget);
    expect(find.text('\$982.28'), findsOneWidget);
    expect(find.text('0.5098'), findsOneWidget);
    expect(find.text('+4.21%'), findsOneWidget);
    expect(find.text('\$500.12'), findsOneWidget);

    expect(find.text('NVIDIA GPU'), findsOneWidget);
    expect(find.text('\$1,994.00'), findsOneWidget);
    expect(find.text('2.148'), findsOneWidget);
    expect(find.text('+3.76%'), findsOneWidget);
    expect(find.text('\$1,594.32'), findsOneWidget);

    expect(find.text('Gold (RWA)'), findsOneWidget);
    expect(find.text('\$4,591.02'), findsOneWidget);
    expect(find.text('0.432'), findsOneWidget);
    expect(find.text('+1.32%'), findsOneWidget);
    expect(find.text('\$837.06'), findsOneWidget);

    expect(find.text('Tesla Model S'), findsOneWidget);
    expect(find.text('\$5,684.00'), findsOneWidget);
    expect(find.text('0.083'), findsOneWidget);
    expect(find.text('+2.19%'), findsOneWidget);
    expect(find.text('\$5,684.60'), findsOneWidget);

    // Tap NVIDIA GPU holding to verify it opens the default buy UI
    await tester.tap(find.text('NVIDIA GPU'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Asset Detail / Buy UI is opened
    expect(find.text('RWA'), findsOneWidget);
    expect(find.text('Tokenized'), findsOneWidget);
    expect(find.text('Trade'), findsOneWidget);
  });

  testWidgets(
    'Account tab displays exact reference UI, actions and menu items',
    (tester) async {
      await tester.pumpWidget(const OrionApp());
      await tester.pump();

      // Navigate to homepage as guest
      await tester.tap(find.text('Explore Marketplace as Guest'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Tap Account tab in bottom nav
      await tester.tap(find.text('Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Header Trader and address
      expect(find.text('Trader'), findsOneWidget);
      expect(find.text('0x3f2...7a9b'), findsOneWidget);

      // Verify Total Portfolio Value Card
      expect(find.text('Total Portfolio Value'), findsOneWidget);
      expect(find.text('\$ 24,582.16'), findsOneWidget);
      expect(find.text('+2.48% (24h)'), findsOneWidget);

      // Verify 3 Action Buttons
      expect(find.text('Deposit'), findsOneWidget);
      expect(find.text('Withdraw'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Verify Account Menu Items
      expect(find.text('Transaction History'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Help & Support'), findsOneWidget);
    },
  );
}

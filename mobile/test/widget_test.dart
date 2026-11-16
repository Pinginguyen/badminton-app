import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:club_squad_app/core/widgets/mobile_frame.dart';
import 'package:club_squad_app/features/home/screens/home_dashboard_screen.dart';

void main() {
  testWidgets('mobile frame caps its width on a desktop-sized viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MobileFrame(
          child: ColoredBox(
            key: ValueKey('frame-content'),
            color: Colors.black,
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('frame-content'))).width, 460);
  });

  testWidgets('Quick Match fits a narrow phone viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: HomeDashboardScreen()),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Admin can add players and generate a doubles match',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: HomeDashboardScreen()),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(
        find.byType(TextField).first,
        'Nam, Tuấn, Hoàng, Minh',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('Nam'), findsOneWidget);
      expect(find.text('Tuấn'), findsOneWidget);
      expect(find.text('Hoàng'), findsOneWidget);
      expect(find.text('Minh'), findsOneWidget);

      final scheduleButton = find.text('XẾP CẶP ĐẤU');
      await tester.ensureVisible(scheduleButton);
      await tester.tap(scheduleButton);
      await tester.pump();

      expect(find.text('Vòng 1'), findsOneWidget);
      expect(find.text('SÂN 1'), findsOneWidget);
      expect(find.text('ĐỘI A'), findsOneWidget);
      expect(find.text('ĐỘI B'), findsOneWidget);
    },
  );

  testWidgets('roster, matches, and scores restore after reopening the hub', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: HomeDashboardScreen()),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byType(TextField).first,
      'Nam, Tuấn, Hoàng, Minh',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.ensureVisible(find.text('XẾP CẶP ĐẤU'));
    await tester.tap(find.text('XẾP CẶP ĐẤU'));
    await tester.pump(const Duration(milliseconds: 650));

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    await tester.pumpWidget(
      const MaterialApp(home: HomeDashboardScreen()),
    );
    await tester.pump(const Duration(milliseconds: 650));

    expect(find.text('Nam'), findsOneWidget);
    expect(find.text('Tuấn'), findsOneWidget);
    expect(find.text('Hoàng'), findsOneWidget);
    expect(find.text('Minh'), findsOneWidget);
    expect(find.text('Vòng 1'), findsOneWidget);
    expect(find.text('SÂN 1'), findsOneWidget);
  });

  testWidgets('admin can drag a player to another slot to swap the lineup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: HomeDashboardScreen()),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byType(TextField).first,
      'Nam, Tuấn, Hoàng, Minh',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 650));
    Future<void> setSkill(String playerName, String level) async {
      final playerCard = find.ancestor(
        of: find.text(playerName),
        matching: find.byType(Card),
      );
      final choice = find.descendant(
        of: playerCard,
        matching: find.text(level),
      );
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump(const Duration(milliseconds: 450));
    }

    await setSkill('Nam', 'Yếu · 1★');
    await setSkill('Hoàng', 'Khá · 3★');
    await setSkill('Minh', 'Cứng · 4★');
    await tester.ensureVisible(find.text('XẾP CẶP ĐẤU'));
    await tester.tap(find.text('XẾP CẶP ĐẤU'));
    await tester.pump(const Duration(milliseconds: 650));

    final source = find.byKey(const ValueKey('player-slot-0-0-0'));
    final target = find.byKey(const ValueKey('player-slot-0-1-0'));
    await tester.ensureVisible(source);
    String playerAt(Finder slot) => tester
        .widget<Text>(find.descendant(of: slot, matching: find.byType(Text)))
        .data!;

    String teamDelta() =>
        tester.widget<Text>(find.textContaining('CHÊNH ')).data!;

    final sourceName = playerAt(source);
    final targetName = playerAt(target);
    expect(teamDelta(), 'CHÊNH 0');
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(kLongPressTimeout);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 650));

    expect(playerAt(source), targetName);
    expect(playerAt(target), sourceName);
    expect(teamDelta(), 'CHÊNH 800');
  });
}

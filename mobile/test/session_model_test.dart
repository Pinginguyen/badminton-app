import 'package:flutter_test/flutter_test.dart';

import 'package:club_squad_app/features/session/models/session_model.dart';

void main() {
  test('bill preserves exact VND shares instead of rounding to thousands', () {
    final startsAt = DateTime(2026, 11, 15);
    final session = SessionModel(
      id: 'session-test',
      title: 'Test',
      startsAt: startsAt,
      endsAt: startsAt.add(const Duration(hours: 2)),
      courtCount: 1,
      courtRentalTotalVnd: 101,
      shuttleUnitPriceVnd: 10,
      shuttlesUsed: 1,
      participants: const [
        SessionMember(
          id: 'p1',
          displayName: 'Nam',
          skillLevel: 2,
          eloRating: 1000,
          attendanceWeight: 0.5,
        ),
        SessionMember(
          id: 'p2',
          displayName: 'Tuấn',
          skillLevel: 2,
          eloRating: 1000,
        ),
      ],
    );

    final firstBill = session.billFor(session.participants[0]);
    final secondBill = session.billFor(session.participants[1]);

    expect(firstBill.courtShareVnd, 34);
    expect(secondBill.courtShareVnd, 67);
    expect(firstBill.totalAmountVnd, 39);
    expect(secondBill.totalAmountVnd, 72);
    expect(
      firstBill.totalAmountVnd + secondBill.totalAmountVnd,
      101 + 10,
    );
    expect(
      firstBill.totalAmountVnd,
      firstBill.courtShareVnd +
          firstBill.shuttleShareVnd +
          firstBill.lateFeeVnd,
    );
    expect(
      secondBill.totalAmountVnd,
      secondBill.courtShareVnd +
          secondBill.shuttleShareVnd +
          secondBill.lateFeeVnd,
    );
  });
}

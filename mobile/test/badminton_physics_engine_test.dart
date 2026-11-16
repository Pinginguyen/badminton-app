import 'package:flutter_test/flutter_test.dart';

import 'package:club_squad_app/features/scoreboard/badminton_physics_engine.dart';

void main() {
  const engine = BadmintonPhysicsEngine();

  test('recovers peak exit speed above a drag-reduced average', () {
    final peak = engine.peakExitVelocityMps(
      observedAverageVelocityMps: 60,
      flightDurationSeconds: 1.2,
    );

    expect(peak, greaterThan(60));
    expect(
      engine.instantaneousVelocityMps(
        peakExitVelocityMps: peak,
        elapsedSeconds: 1.2,
      ),
      lessThan(peak),
    );
  });

  test('converts the corrected peak speed to kilometers per hour', () {
    final peakKmh = engine.peakExitVelocityKmh(
      observedAverageVelocityKmh: 180,
      flightDurationSeconds: 0.8,
    );
    expect(peakKmh, greaterThan(180));
    expect(peakKmh, closeTo(
      engine.peakExitVelocityMps(
        observedAverageVelocityMps: 50,
        flightDurationSeconds: 0.8,
      ) *
          3.6,
      1e-10,
    ));
  });

  test('rejects a non-positive flight duration', () {
    expect(
      () => engine.peakExitVelocityMps(
        observedAverageVelocityMps: 20,
        flightDurationSeconds: 0,
      ),
      throwsArgumentError,
    );
  });
}

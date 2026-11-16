import 'dart:math' as math;

/// Estimates shuttlecock launch speed from a measured speed after drag loss.
class BadmintonPhysicsEngine {
  const BadmintonPhysicsEngine({
    this.dragDecayCoefficientPerSecond = 0.0021,
  }) : assert(dragDecayCoefficientPerSecond >= 0);

  /// The requested `k = 0.0021` is used as a first-order decay rate in s^-1:
  /// `dv/dt = -k*v`, whose solution is `v(t) = v0*exp(-k*t)`.
  final double dragDecayCoefficientPerSecond;

  /// Inverts the time-average of the exponential speed curve to estimate
  /// peak exit speed at racket contact, rather than reporting the average.
  ///
  /// For duration `t`, average speed is
  /// `vAvg = v0 * (1 - exp(-k*t)) / (k*t)`. Therefore the launch estimate is
  /// `v0 = vAvg * (k*t) / (1 - exp(-k*t))`.
  double peakExitVelocityMps({
    required double observedAverageVelocityMps,
    required double flightDurationSeconds,
  }) {
    if (!observedAverageVelocityMps.isFinite ||
        observedAverageVelocityMps < 0) {
      throw ArgumentError.value(
        observedAverageVelocityMps,
        'observedAverageVelocityMps',
        'Must be a finite non-negative speed.',
      );
    }
    if (!flightDurationSeconds.isFinite || flightDurationSeconds <= 0) {
      throw ArgumentError.value(
        flightDurationSeconds,
        'flightDurationSeconds',
        'Must be a finite positive duration.',
      );
    }

    final decay = dragDecayCoefficientPerSecond * flightDurationSeconds;
    if (decay == 0) return observedAverageVelocityMps;
    if (decay.abs() < 1e-5) {
      return observedAverageVelocityMps *
          (1 + decay / 2 + decay * decay / 12);
    }
    return observedAverageVelocityMps * decay / (1 - math.exp(-decay));
  }

  double peakExitVelocityKmh({
    required double observedAverageVelocityKmh,
    required double flightDurationSeconds,
  }) {
    final peakMps = peakExitVelocityMps(
      observedAverageVelocityMps: observedAverageVelocityKmh / 3.6,
      flightDurationSeconds: flightDurationSeconds,
    );
    return peakMps * 3.6;
  }

  double instantaneousVelocityMps({
    required double peakExitVelocityMps,
    required double elapsedSeconds,
  }) {
    if (!peakExitVelocityMps.isFinite || peakExitVelocityMps < 0) {
      throw ArgumentError.value(peakExitVelocityMps, 'peakExitVelocityMps');
    }
    if (!elapsedSeconds.isFinite || elapsedSeconds < 0) {
      throw ArgumentError.value(elapsedSeconds, 'elapsedSeconds');
    }
    return peakExitVelocityMps *
        math.exp(-dragDecayCoefficientPerSecond * elapsedSeconds);
  }
}

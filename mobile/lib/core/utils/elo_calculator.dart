import 'dart:math' as math;

/// Calculates new Elo values in the order A1, A2, B1, B2.
///
/// [pointMargin] is the aggregate winning margin across completed sets. A
/// bounded margin multiplier gives decisive wins a modest bonus without
/// allowing a large score to dominate the rating change.
List<int> calculateDoublesElo({
  required List<int> teamAElos,
  required List<int> teamBElos,
  required bool teamAWon,
  int pointMargin = 0,
}) {
  if (teamAElos.length != 2 || teamBElos.length != 2) {
    throw ArgumentError('Doubles Elo requires exactly two ratings per team.');
  }
  if (teamAElos.any((elo) => elo < 0) || teamBElos.any((elo) => elo < 0)) {
    throw ArgumentError('Elo ratings cannot be negative.');
  }
  if (pointMargin < 0) {
    throw ArgumentError.value(pointMargin, 'pointMargin', 'Cannot be negative.');
  }

  final teamARating =
      teamAElos.fold<double>(0, (total, elo) => total + elo) / 2;
  final teamBRating =
      teamBElos.fold<double>(0, (total, elo) => total + elo) / 2;
  final expectedA =
      1 / (1 + math.pow(10, (teamBRating - teamARating) / 400));
  final actualA = teamAWon ? 1.0 : 0.0;
  final marginMultiplier = 1 + pointMargin.clamp(0, 30) / 100;
  final delta = (32 * marginMultiplier * (actualA - expectedA)).round();

  return List.unmodifiable([
    ...teamAElos.map((elo) => math.max(0, elo + delta).toInt()),
    ...teamBElos.map((elo) => math.max(0, elo - delta).toInt()),
  ]);
}

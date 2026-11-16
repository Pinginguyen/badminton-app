import 'package:flutter_test/flutter_test.dart';

import 'package:club_squad_app/core/engine/matchmaking_engine.dart';

void main() {
  const engine = BadmintonMatchmakingEngine();

  test('selects a player who sat out before players who just played', () {
    final now = DateTime.utc(2026, 11, 15, 20);
    final players = [
      for (var index = 0; index < 4; index++)
        MatchPlayer(
          id: 'p$index',
          skillLevel: 2,
          eloRating: 1000,
          lastPlayedAt: now,
          matchesPlayed: 1,
        ),
      const MatchPlayer(
        id: 'resting',
        skillLevel: 2,
        eloRating: 1000,
        matchesPlayed: 0,
      ),
    ];

    final match = engine.suggestMatch(
      availablePlayers: players,
      recentMatches: const [],
      now: now,
    );

    expect(match, isNotNull);
    final result = match!;
    expect(result.players.map((player) => player.id), contains('resting'));
    expect(
      result.players.where((player) => player.matchesPlayed == 0),
      hasLength(1),
    );
  });

  test('keeps a proven winning duo together against a higher-Elo team', () {
    const players = [
      MatchPlayer(id: 'a', skillLevel: 2, eloRating: 1000),
      MatchPlayer(id: 'b', skillLevel: 2, eloRating: 1000),
      MatchPlayer(id: 'c', skillLevel: 2, eloRating: 1500),
      MatchPlayer(id: 'd', skillLevel: 2, eloRating: 1500),
    ];
    final history = [
      for (var index = 1; index <= 5; index++)
        RecentMatch(
          matchNumber: index,
          teamAPlayerIds: const ['a', 'b'],
          teamBPlayerIds: const ['c', 'd'],
          teamAWon: index <= 4,
        ),
    ];

    final match = engine.suggestMatch(
      availablePlayers: players,
      recentMatches: history,
    );

    expect(match, isNotNull);
    final result = match!;
    final hotDuoTeam = result.teamA.any((player) => player.id == 'a')
        ? result.teamA
        : result.teamB;
    final opponentTeam =
        identical(hotDuoTeam, result.teamA) ? result.teamB : result.teamA;
    expect(hotDuoTeam.map((player) => player.id), containsAll(['a', 'b']));
    expect(
      opponentTeam.fold<int>(0, (total, player) => total + player.eloRating),
      greaterThan(
        hotDuoTeam.fold<int>(0, (total, player) => total + player.eloRating),
      ),
    );
  });

  test('does not classify a duo at exactly 75 percent as proven chemistry', () {
    const players = [
      MatchPlayer(id: 'a', skillLevel: 2, eloRating: 1000),
      MatchPlayer(id: 'b', skillLevel: 2, eloRating: 1000),
      MatchPlayer(id: 'c', skillLevel: 2, eloRating: 1500),
      MatchPlayer(id: 'd', skillLevel: 2, eloRating: 1500),
    ];
    final history = [
      for (var index = 1; index <= 4; index++)
        RecentMatch(
          matchNumber: index,
          teamAPlayerIds: const ['a', 'b'],
          teamBPlayerIds: const ['c', 'd'],
          teamAWon: index <= 3,
        ),
    ];

    final match = engine.suggestMatch(
      availablePlayers: players,
      recentMatches: history,
    );

    expect(match, isNotNull);
    final result = match!;
    expect(
      result.teamA.map((player) => player.id).toSet().containsAll(['a', 'b']) ||
          result.teamB.map((player) => player.id).toSet().containsAll(['a', 'b']),
      isFalse,
    );
  });
}

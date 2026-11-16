/// Deterministic doubles matchmaking with fatigue, partner chemistry, and
/// opponent Elo challenge scoring.
class MatchPlayer {
  const MatchPlayer({
    required this.id,
    required this.skillLevel,
    required this.eloRating,
    this.lastPlayedAt,
    this.matchesPlayed = 0,
    this.setsPlayed = 0,
    this.setsSatOut = 0,
  })  : assert(id != ''),
        assert(skillLevel >= 1 && skillLevel <= 4),
        assert(eloRating >= 0),
      assert(matchesPlayed >= 0),
      assert(setsPlayed >= 0),
      assert(setsSatOut >= 0);

  final String id;
  final int skillLevel;
  final int eloRating;
  final DateTime? lastPlayedAt;
  final int matchesPlayed;
  final int setsPlayed;
  final int setsSatOut;

  int get combinedSkill => skillLevel * 400 + eloRating;

  /// Each played match adds one fatigue point; sitting a round keeps the
  /// player's score below that of everyone who just played.
  int get fatiguePenalty => matchesPlayed;
}

class RecentMatch {
  const RecentMatch({
    required this.matchNumber,
    required this.teamAPlayerIds,
    required this.teamBPlayerIds,
    this.teamAWon,
    this.setsPlayed = 0,
  })  : assert(teamAPlayerIds.length == 2),
      assert(teamBPlayerIds.length == 2),
      assert(setsPlayed >= 0);

  final int matchNumber;
  final List<String> teamAPlayerIds;
  final List<String> teamBPlayerIds;

  /// Null while the match is unfinished or when restoring legacy history.
  final bool? teamAWon;
  final int setsPlayed;
}

class MatchSuggestion {
  const MatchSuggestion({
    required this.teamA,
    required this.teamB,
    required this.teamSkillDelta,
    required this.repeatedPairCount,
    this.sessionId,
    this.courtNumber,
    this.isAdminOverride = false,
  });

  final List<MatchPlayer> teamA;
  final List<MatchPlayer> teamB;
  final int teamSkillDelta;
  final int repeatedPairCount;
  final String? sessionId;
  final int? courtNumber;
  final bool isAdminOverride;

  List<MatchPlayer> get players => List.unmodifiable([...teamA, ...teamB]);
}

class BadmintonMatchmakingEngine {
  const BadmintonMatchmakingEngine();

  static const int _chemistryMinimumMatches = 4;
  static const double _chemistryWinRateThreshold = 0.75;

  int countRecentPairRepeats({
    required List<MatchPlayer> teamA,
    required List<MatchPlayer> teamB,
    required List<RecentMatch> recentMatches,
  }) {
    if (teamA.length != 2 || teamB.length != 2) {
      throw ArgumentError('A doubles match must contain two players per team.');
    }
    _validatePlayers([...teamA, ...teamB]);
    final rankedHistory = [...recentMatches]
      ..sort((a, b) => b.matchNumber.compareTo(a.matchNumber));
    final history = rankedHistory.take(3).toList(growable: false);
    return _RepeatedPairs.fromHistory(history).countFor(teamA, teamB);
  }

  /// Returns a 2-v-2 match, or null when fewer than four unique players exist.
  ///
  /// Fatigue is compared before every other criterion, so lower-fatigue
  /// players take precedence over players who just played. A proven winning
  /// duo is kept together and, when possible, challenged by a higher-Elo team.
  MatchSuggestion? suggestMatch({
    required List<MatchPlayer> availablePlayers,
    required List<RecentMatch> recentMatches,
    DateTime? now,
    String? sessionId,
    int? courtNumber,
  }) {
    _validatePlayers(availablePlayers);
    _validateCourtNumber(courtNumber);
    if (availablePlayers.length < 4) return null;

    final referenceTime = (now ?? DateTime.now()).toUtc();
    final rankedHistory = [...recentMatches]
      ..sort((a, b) => b.matchNumber.compareTo(a.matchNumber));
    final repeatHistory = rankedHistory.take(3).toList(growable: false);
    final repeatedPairs = _RepeatedPairs.fromHistory(repeatHistory);
    final chemistry = _DuoChemistry.fromHistory(recentMatches);
    _Candidate? best;

    for (var i = 0; i < availablePlayers.length - 3; i++) {
      for (var j = i + 1; j < availablePlayers.length - 2; j++) {
        for (var k = j + 1; k < availablePlayers.length - 1; k++) {
          for (var l = k + 1; l < availablePlayers.length; l++) {
            final quartet = [
              availablePlayers[i],
              availablePlayers[j],
              availablePlayers[k],
              availablePlayers[l],
            ];
            for (final teams in _teamSplits(quartet)) {
              final candidate = _Candidate(
                teamA: teams.$1,
                teamB: teams.$2,
                fatigueRank: _fatigueRank(quartet),
                setsPlayedRank: _setsPlayedRank(quartet),
                setsSatOutRank: _setsSatOutRank(quartet),
                restRank: _restRank(quartet, referenceTime),
                repeatedPairCount:
                    repeatedPairs.countFor(teams.$1, teams.$2),
                repeatedPartnerCount:
                  repeatedPairs.partnerCountFor(teams.$1, teams.$2),
                chemistryScore: chemistry.scoreFor(teams.$1, teams.$2),
              );
              if (best == null || candidate.compareTo(best) < 0) {
                best = candidate;
              }
            }
          }
        }
      }
    }

    final winner = best!;
    return MatchSuggestion(
      teamA: List.unmodifiable(winner.teamA),
      teamB: List.unmodifiable(winner.teamB),
      teamSkillDelta: _teamSkillDelta(winner.teamA, winner.teamB),
      repeatedPairCount: winner.repeatedPairCount,
      sessionId: sessionId,
      courtNumber: courtNumber,
    );
  }

  /// Preserves a lineup selected manually by the Admin.
  MatchSuggestion createAdminOverride({
    required List<MatchPlayer> teamA,
    required List<MatchPlayer> teamB,
    String? sessionId,
    int? courtNumber,
  }) {
    if (teamA.length != 2 || teamB.length != 2) {
      throw ArgumentError('An admin override must contain two players per team.');
    }
    _validateCourtNumber(courtNumber);
    _validatePlayers([...teamA, ...teamB]);
    return MatchSuggestion(
      teamA: List.unmodifiable(teamA),
      teamB: List.unmodifiable(teamB),
      teamSkillDelta: _teamSkillDelta(teamA, teamB),
      repeatedPairCount: 0,
      sessionId: sessionId,
      courtNumber: courtNumber,
      isAdminOverride: true,
    );
  }

  static void _validatePlayers(List<MatchPlayer> players) {
    if (players.map((player) => player.id).toSet().length != players.length) {
      throw ArgumentError('Player IDs must be unique.');
    }
    if (players.any(
      (player) =>
          player.id.trim().isEmpty ||
          player.skillLevel < 1 ||
          player.skillLevel > 4 ||
          player.eloRating < 0 ||
          player.matchesPlayed < 0 ||
          player.setsPlayed < 0 ||
          player.setsSatOut < 0,
    )) {
      throw ArgumentError('Player ratings and fatigue values are invalid.');
    }
  }

  static void _validateCourtNumber(int? courtNumber) {
    if (courtNumber != null && (courtNumber < 1 || courtNumber > 3)) {
      throw ArgumentError.value(
        courtNumber,
        'courtNumber',
        'Must be from 1 to 3.',
      );
    }
  }

  static List<int> _fatigueRank(List<MatchPlayer> quartet) {
    final values = quartet.map((player) => player.fatiguePenalty).toList()
      ..sort();
    return values;
  }

  static List<int> _setsPlayedRank(List<MatchPlayer> quartet) {
    final values = quartet.map((player) => player.setsPlayed).toList()
      ..sort();
    return values;
  }

  static List<int> _setsSatOutRank(List<MatchPlayer> quartet) {
    final values = quartet
        .map((player) => player.setsSatOut)
        .toList()
      ..sort((first, second) => second.compareTo(first));
    return values;
  }

  static List<double> _restRank(List<MatchPlayer> quartet, DateTime now) {
    final rests = quartet.map((player) {
      final lastPlayed = player.lastPlayedAt;
      if (lastPlayed == null) return double.infinity;
      final seconds = now.difference(lastPlayed.toUtc()).inSeconds;
      return seconds < 0 ? 0.0 : seconds.toDouble();
    }).toList()
      ..sort((a, b) => b.compareTo(a));
    return rests;
  }

  static int _teamSkillDelta(
    List<MatchPlayer> teamA,
    List<MatchPlayer> teamB,
  ) {
    final ratingA =
        teamA.fold<int>(0, (total, player) => total + player.combinedSkill);
    final ratingB =
        teamB.fold<int>(0, (total, player) => total + player.combinedSkill);
    return (ratingA - ratingB).abs();
  }

  static List<(List<MatchPlayer>, List<MatchPlayer>)> _teamSplits(
    List<MatchPlayer> quartet,
  ) {
    return [
      ([quartet[0], quartet[1]], [quartet[2], quartet[3]]),
      ([quartet[0], quartet[2]], [quartet[1], quartet[3]]),
      ([quartet[0], quartet[3]], [quartet[1], quartet[2]]),
    ];
  }

  static String _pairKey(String first, String second) =>
      first.compareTo(second) <= 0 ? '$first\u0000$second' : '$second\u0000$first';
}

class _DuoStats {
  int wins = 0;
  int matches = 0;

  double get winRate => matches == 0 ? 0 : wins / matches;
  bool get isProvenWinningDuo =>
      matches >= BadmintonMatchmakingEngine._chemistryMinimumMatches &&
      winRate > BadmintonMatchmakingEngine._chemistryWinRateThreshold;
}

class _DuoChemistry {
  _DuoChemistry(this._stats);

  final Map<String, _DuoStats> _stats;

  factory _DuoChemistry.fromHistory(List<RecentMatch> matches) {
    final stats = <String, _DuoStats>{};
    for (final match in matches) {
      final teamAWon = match.teamAWon;
      if (teamAWon == null) continue;

      void recordDuo(List<String> teamPlayerIds, bool won) {
        final key = BadmintonMatchmakingEngine._pairKey(
          teamPlayerIds[0],
          teamPlayerIds[1],
        );
        final duo = stats.putIfAbsent(key, _DuoStats.new);
        duo.matches++;
        if (won) duo.wins++;
      }

      recordDuo(match.teamAPlayerIds, teamAWon);
      recordDuo(match.teamBPlayerIds, !teamAWon);
    }
    return _DuoChemistry(stats);
  }

  _ChemistryScore scoreFor(
    List<MatchPlayer> teamA,
    List<MatchPlayer> teamB,
  ) {
    final teamAIds = {for (final player in teamA) player.id};
    final teamBIds = {for (final player in teamB) player.id};
    var provenPairs = 0;
    var challengedPairs = 0;
    var challengeGap = 0;

    for (final entry in _stats.entries) {
      final duoIds = entry.key.split('\u0000');
      if (!entry.value.isProvenWinningDuo ||
          duoIds.length != 2 ||
          !(_sameTeam(teamAIds, duoIds) || _sameTeam(teamBIds, duoIds))) {
        continue;
      }
      provenPairs++;
      final isInA = teamAIds.contains(duoIds.first);
      final winnersTeam = isInA ? teamA : teamB;
      final opponents = isInA ? teamB : teamA;
      final duoElo = winnersTeam
          .where((player) => duoIds.contains(player.id))
          .fold<int>(0, (sum, player) => sum + player.eloRating);
      final opponentElo =
          opponents.fold<int>(0, (sum, player) => sum + player.eloRating);
      if (opponentElo > duoElo) {
        challengedPairs++;
        challengeGap += opponentElo - duoElo;
      }
    }
    return _ChemistryScore(
      provenPairs: provenPairs,
      challengedPairs: challengedPairs,
      challengeGap: challengeGap,
    );
  }

  static bool _sameTeam(Set<String> teamIds, List<String> duoIds) =>
      teamIds.contains(duoIds[0]) && teamIds.contains(duoIds[1]);
}

class _ChemistryScore {
  const _ChemistryScore({
    required this.provenPairs,
    required this.challengedPairs,
    required this.challengeGap,
  });

  final int provenPairs;
  final int challengedPairs;
  final int challengeGap;
}

class _RepeatedPairs {
  const _RepeatedPairs(this.partners, this.opponents);

  final Set<String> partners;
  final Set<String> opponents;

  factory _RepeatedPairs.fromHistory(List<RecentMatch> history) {
    final partners = <String>{};
    final opponents = <String>{};
    for (final match in history) {
      partners.add(
        BadmintonMatchmakingEngine._pairKey(
          match.teamAPlayerIds[0],
          match.teamAPlayerIds[1],
        ),
      );
      partners.add(
        BadmintonMatchmakingEngine._pairKey(
          match.teamBPlayerIds[0],
          match.teamBPlayerIds[1],
        ),
      );
      for (final playerA in match.teamAPlayerIds) {
        for (final playerB in match.teamBPlayerIds) {
          opponents.add(BadmintonMatchmakingEngine._pairKey(playerA, playerB));
        }
      }
    }
    return _RepeatedPairs(partners, opponents);
  }

  int countFor(List<MatchPlayer> teamA, List<MatchPlayer> teamB) {
    var count = 0;
    if (partners.contains(
      BadmintonMatchmakingEngine._pairKey(teamA[0].id, teamA[1].id),
    )) {
      count++;
    }
    if (partners.contains(
      BadmintonMatchmakingEngine._pairKey(teamB[0].id, teamB[1].id),
    )) {
      count++;
    }
    for (final playerA in teamA) {
      for (final playerB in teamB) {
        if (opponents.contains(
          BadmintonMatchmakingEngine._pairKey(playerA.id, playerB.id),
        )) {
          count++;
        }
      }
    }
    return count;
  }

  int partnerCountFor(List<MatchPlayer> teamA, List<MatchPlayer> teamB) {
    return [teamA, teamB]
        .where(
          (team) => partners.contains(
            BadmintonMatchmakingEngine._pairKey(team[0].id, team[1].id),
          ),
        )
        .length;
  }
}

class _Candidate implements Comparable<_Candidate> {
  const _Candidate({
    required this.teamA,
    required this.teamB,
    required this.fatigueRank,
    required this.setsPlayedRank,
    required this.setsSatOutRank,
    required this.restRank,
    required this.repeatedPairCount,
    required this.repeatedPartnerCount,
    required this.chemistryScore,
  });

  final List<MatchPlayer> teamA;
  final List<MatchPlayer> teamB;
  final List<int> fatigueRank;
  final List<int> setsPlayedRank;
  final List<int> setsSatOutRank;
  final List<double> restRank;
  final int repeatedPairCount;
  final int repeatedPartnerCount;
  final _ChemistryScore chemistryScore;

  @override
  int compareTo(_Candidate other) {
    for (var index = 0; index < setsPlayedRank.length; index++) {
      final setComparison =
          setsPlayedRank[index].compareTo(other.setsPlayedRank[index]);
      if (setComparison != 0) return setComparison;
    }
    for (var index = 0; index < setsSatOutRank.length; index++) {
      final restComparison =
          other.setsSatOutRank[index].compareTo(setsSatOutRank[index]);
      if (restComparison != 0) return restComparison;
    }
    for (var index = 0; index < fatigueRank.length; index++) {
      final fatigueComparison =
          fatigueRank[index].compareTo(other.fatigueRank[index]);
      if (fatigueComparison != 0) return fatigueComparison;
    }
    for (var index = 0; index < restRank.length; index++) {
      final restComparison = other.restRank[index].compareTo(restRank[index]);
      if (restComparison != 0) return restComparison;
    }

    final chemistryComparison =
        other.chemistryScore.provenPairs.compareTo(chemistryScore.provenPairs);
    if (chemistryComparison != 0) return chemistryComparison;
    final challengeComparison = other.chemistryScore.challengedPairs
        .compareTo(chemistryScore.challengedPairs);
    if (challengeComparison != 0) return challengeComparison;
    final gapComparison = chemistryScore.challengeGap
        .compareTo(other.chemistryScore.challengeGap);
    if (gapComparison != 0) return gapComparison;

    final partnerRepeatComparison =
        repeatedPartnerCount.compareTo(other.repeatedPartnerCount);
    if (partnerRepeatComparison != 0) return partnerRepeatComparison;
    final repeatComparison =
        repeatedPairCount.compareTo(other.repeatedPairCount);
    if (repeatComparison != 0) return repeatComparison;
    final skillComparison =
        _teamSkillDelta(teamA, teamB)
            .compareTo(_teamSkillDelta(other.teamA, other.teamB));
    if (skillComparison != 0) return skillComparison;

    final thisIds = [...teamA, ...teamB].map((player) => player.id).join('|');
    final otherIds =
        [...other.teamA, ...other.teamB].map((player) => player.id).join('|');
    return thisIds.compareTo(otherIds);
  }

  static int _teamSkillDelta(
    List<MatchPlayer> teamA,
    List<MatchPlayer> teamB,
  ) {
    final ratingA =
        teamA.fold<int>(0, (sum, player) => sum + player.combinedSkill);
    final ratingB =
        teamB.fold<int>(0, (sum, player) => sum + player.combinedSkill);
    return (ratingA - ratingB).abs();
  }
}

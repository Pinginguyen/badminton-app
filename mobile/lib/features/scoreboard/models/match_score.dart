enum ServingTeam { teamA, teamB }

class MatchSetScore {
  const MatchSetScore({this.teamA = 0, this.teamB = 0})
      : assert(teamA >= 0),
        assert(teamB >= 0);

  final int teamA;
  final int teamB;

  ServingTeam? get winner {
    if ((teamA >= 21 && teamA - teamB >= 2) || teamA == 30) {
      return ServingTeam.teamA;
    }
    if ((teamB >= 21 && teamB - teamA >= 2) || teamB == 30) {
      return ServingTeam.teamB;
    }
    return null;
  }
}

/// Immutable scoreboard state for one doubles match.
class MatchScore {
  MatchScore({
    required List<String> teamAPlayerNames,
    required List<String> teamBPlayerNames,
    required List<MatchSetScore> sets,
    this.servingTeam = ServingTeam.teamA,
  })  : teamAPlayerNames = _validateNames(teamAPlayerNames, 'teamAPlayerNames'),
        teamBPlayerNames = _validateNames(teamBPlayerNames, 'teamBPlayerNames'),
        sets = _validateSets(sets);

  factory MatchScore.initial({
    required List<String> teamAPlayerNames,
    required List<String> teamBPlayerNames,
    ServingTeam servingTeam = ServingTeam.teamA,
  }) {
    return MatchScore(
      teamAPlayerNames: teamAPlayerNames,
      teamBPlayerNames: teamBPlayerNames,
      sets: List.generate(3, (_) => const MatchSetScore()),
      servingTeam: servingTeam,
    );
  }

  factory MatchScore.fromJson(Map<String, Object?> json) {
    final teamAPlayerNames =
        _readNames(json['teamAPlayerNames'], 'teamAPlayerNames');
    final teamBPlayerNames =
        _readNames(json['teamBPlayerNames'], 'teamBPlayerNames');
    if (teamAPlayerNames.length != 2 || teamBPlayerNames.length != 2) {
      throw const FormatException('A saved doubles score must have four players.');
    }

    final rawSets = json['sets'];
    if (rawSets is! List || rawSets.length != 3) {
      throw const FormatException('A saved match must contain three set scores.');
    }

    final sets = <MatchSetScore>[];
    for (final rawSet in rawSets) {
      if (rawSet is! Map ||
          rawSet['teamA'] is! int ||
          rawSet['teamB'] is! int ||
          (rawSet['teamA'] as int) < 0 ||
          (rawSet['teamB'] as int) < 0) {
        throw const FormatException('A saved set score is invalid.');
      }
      sets.add(
        MatchSetScore(
          teamA: rawSet['teamA'] as int,
          teamB: rawSet['teamB'] as int,
        ),
      );
    }

    final servingTeam = switch (json['servingTeam']) {
      'teamA' => ServingTeam.teamA,
      'teamB' => ServingTeam.teamB,
      _ => throw const FormatException('The saved serving team is invalid.'),
    };

    return MatchScore(
      teamAPlayerNames: teamAPlayerNames,
      teamBPlayerNames: teamBPlayerNames,
      sets: sets,
      servingTeam: servingTeam,
    );
  }

  final List<String> teamAPlayerNames;
  final List<String> teamBPlayerNames;
  final List<MatchSetScore> sets;
  final ServingTeam servingTeam;

  int get teamASetsWon =>
      sets.where((set) => set.winner == ServingTeam.teamA).length;

  int get teamBSetsWon =>
      sets.where((set) => set.winner == ServingTeam.teamB).length;

  bool get isMatchComplete => teamASetsWon >= 2 || teamBSetsWon >= 2;

  /// Index of the set receiving the next point, or null once the match ends.
  int? get activeSetIndex {
    if (isMatchComplete) return null;
    for (var index = 0; index < sets.length; index++) {
      if (sets[index].winner == null) return index;
    }
    return null;
  }

  /// Returns an updated score. The team winning a rally serves the next rally.
  MatchScore addPoint(ServingTeam scoringTeam) {
    final index = activeSetIndex;
    if (index == null) {
      throw StateError('Cannot add a point after the match is complete.');
    }

    final updatedSets = List<MatchSetScore>.of(sets);
    final current = updatedSets[index];
    updatedSets[index] = scoringTeam == ServingTeam.teamA
        ? MatchSetScore(teamA: current.teamA + 1, teamB: current.teamB)
        : MatchSetScore(teamA: current.teamA, teamB: current.teamB + 1);

    return MatchScore(
      teamAPlayerNames: teamAPlayerNames,
      teamBPlayerNames: teamBPlayerNames,
      sets: updatedSets,
      servingTeam: scoringTeam,
    );
  }

  MatchScore copyWithPlayerNames({
    required List<String> teamAPlayerNames,
    required List<String> teamBPlayerNames,
  }) {
    return MatchScore(
      teamAPlayerNames: teamAPlayerNames,
      teamBPlayerNames: teamBPlayerNames,
      sets: sets,
      servingTeam: servingTeam,
    );
  }

  Map<String, Object?> toJson() => {
        'teamAPlayerNames': teamAPlayerNames,
        'teamBPlayerNames': teamBPlayerNames,
        'sets': [
          for (final set in sets) {'teamA': set.teamA, 'teamB': set.teamB},
        ],
        'servingTeam': servingTeam.name,
      };

  static List<String> _readNames(Object? value, String field) {
    if (value is! List || value.any((name) => name is! String)) {
      throw FormatException('Saved $field must be a list of names.');
    }
    final names = value.cast<String>();
    if (names.any((name) => name.trim().isEmpty)) {
      throw FormatException('Saved $field contains an empty name.');
    }
    return names;
  }

  static List<String> _validateNames(List<String> names, String field) {
    if (names.length != 2 || names.any((name) => name.trim().isEmpty)) {
      throw ArgumentError.value(names, field, 'Provide two player names.');
    }
    return List.unmodifiable(names.map((name) => name.trim()));
  }

  static List<MatchSetScore> _validateSets(List<MatchSetScore> sets) {
    if (sets.length != 3) {
      throw ArgumentError.value(sets, 'sets', 'A match must have three set slots.');
    }
    return List.unmodifiable(sets);
  }
}

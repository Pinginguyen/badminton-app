class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.displayName,
    required this.nickname,
    required this.skillLevel,
    required this.eloRating,
    this.isAdmin = false,
    this.avatarUrl,
    this.funTitles = const [],
  })  : assert(id != ''),
        assert(displayName != ''),
        assert(skillLevel >= 1 && skillLevel <= 4),
        assert(eloRating >= 0);

  final String id;
  final String displayName;
  final String nickname;
  final int skillLevel;
  final int eloRating;
  final bool isAdmin;
  final String? avatarUrl;
  final List<String> funTitles;
}

class PlayedMatch {
  PlayedMatch({
    required this.id,
    required this.playedAt,
    required List<String> teamAPlayerIds,
    required List<String> teamBPlayerIds,
    required this.teamAWon,
    required this.scoreLabel,
  })  : teamAPlayerIds = List.unmodifiable(teamAPlayerIds),
        teamBPlayerIds = List.unmodifiable(teamBPlayerIds) {
    final allPlayers = [...this.teamAPlayerIds, ...this.teamBPlayerIds];
    if (this.teamAPlayerIds.length != 2 ||
        this.teamBPlayerIds.length != 2 ||
        allPlayers.toSet().length != 4) {
      throw ArgumentError('A doubles match must contain four unique players.');
    }
    if (id.trim().isEmpty || scoreLabel.trim().isEmpty) {
      throw ArgumentError('Match id and score are required.');
    }
  }

  final String id;
  final DateTime playedAt;
  final List<String> teamAPlayerIds;
  final List<String> teamBPlayerIds;
  final bool teamAWon;
  final String scoreLabel;

  bool areOpponents(String firstPlayerId, String secondPlayerId) {
    return (teamAPlayerIds.contains(firstPlayerId) &&
            teamBPlayerIds.contains(secondPlayerId)) ||
        (teamAPlayerIds.contains(secondPlayerId) &&
            teamBPlayerIds.contains(firstPlayerId));
  }

  bool didPlayerWin(String playerId) {
    if (teamAPlayerIds.contains(playerId)) return teamAWon;
    if (teamBPlayerIds.contains(playerId)) return !teamAWon;
    throw ArgumentError.value(
      playerId,
      'playerId',
      'Player was not in this match.',
    );
  }
}

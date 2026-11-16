import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _TournamentFormat { roundRobin, knockout }

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  static const _storageKey = 'badminton_squad.mini_tournament.v1';
  final _teamsController = TextEditingController();
  _TournamentFormat _format = _TournamentFormat.roundRobin;
  List<_TournamentMatch> _matches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _teamsController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(_storageKey);
      if (encoded != null) {
        final value = jsonDecode(encoded);
        if (value is Map && mounted) {
          setState(() {
            _format = _TournamentFormat.values.byName(value['format'] as String);
            _teamsController.text = (value['teams'] as List).cast<String>().join('\n');
            _matches = (value['matches'] as List)
                .map((match) => _TournamentMatch.fromJson(match as Map))
                .toList();
          });
        }
      }
    } catch (_) {
      if (mounted) _showMessage('Giải đấu đã lưu bị lỗi định dạng.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generate() async {
    final teams = _teamsController.text
        .split(RegExp(r'[,;\n]'))
        .map((team) => team.trim())
        .where((team) => team.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (teams.length < 4) {
      _showMessage('Nhập ít nhất 4 cặp đấu khác nhau.');
      return;
    }

    setState(() {
      _matches = _format == _TournamentFormat.roundRobin
          ? _roundRobinMatches(teams)
          : _knockoutMatches(teams);
    });
    await _save(teams);
  }

  List<_TournamentMatch> _roundRobinMatches(List<String> teams) {
    final rotation = List<String?>.of(teams);
    if (rotation.length.isOdd) rotation.add(null);
    final roundCount = rotation.length - 1;
    final matches = <_TournamentMatch>[];
    for (var round = 0; round < roundCount; round++) {
      for (var index = 0; index < rotation.length ~/ 2; index++) {
        final first = rotation[index];
        final second = rotation[rotation.length - 1 - index];
        if (first == null || second == null) continue;
        matches.add(
          _TournamentMatch(
            roundNumber: round + 1,
            matchNumber: index + 1,
            roundLabel: 'Vòng ${round + 1}',
            teamA: first,
            teamB: second,
          ),
        );
      }
      final tail = rotation.sublist(1);
      rotation
        ..clear()
        ..add(teams.first)
        ..add(tail.last)
        ..addAll(tail.take(tail.length - 1));
    }
    return matches;
  }

  List<_TournamentMatch> _knockoutMatches(List<String> teams) {
    var bracketSize = 1;
    while (bracketSize < teams.length) {
      bracketSize *= 2;
    }
    final rounds = <List<_TournamentMatch>>[];
    final byeCount = bracketSize - teams.length;
    final firstRoundTeams = <String>[];
    var teamIndex = 0;
    for (var index = 0; index < byeCount; index++) {
      firstRoundTeams
        ..add(teams[teamIndex++])
        ..add('BYE');
    }
    while (teamIndex < teams.length) {
      firstRoundTeams
        ..add(teams[teamIndex++])
        ..add(teams[teamIndex++]);
    }
    final firstRoundCount = bracketSize ~/ 2;
    rounds.add([
      for (var index = 0; index < firstRoundCount; index++)
        _TournamentMatch(
          roundNumber: 1,
          matchNumber: index + 1,
          roundLabel: _roundName(firstRoundCount),
          teamA: firstRoundTeams[index * 2],
          teamB: firstRoundTeams[index * 2 + 1],
            winner: firstRoundTeams[index * 2] == 'BYE' &&
                firstRoundTeams[index * 2 + 1] == 'BYE'
              ? null
              : firstRoundTeams[index * 2] == 'BYE'
                ? firstRoundTeams[index * 2 + 1]
                : firstRoundTeams[index * 2 + 1] == 'BYE'
                  ? firstRoundTeams[index * 2]
                  : null,
        ),
    ]);
    var matchCount = firstRoundCount;
    var roundNumber = 2;
    while (matchCount > 1) {
      matchCount ~/= 2;
      rounds.add([
        for (var index = 0; index < matchCount; index++)
          _TournamentMatch(
            roundNumber: roundNumber,
            matchNumber: index + 1,
            roundLabel: _roundName(matchCount),
            teamA: 'TBD',
            teamB: 'TBD',
          ),
      ]);
      roundNumber++;
    }
    final allMatches = rounds.expand((round) => round).toList();
    for (final match in rounds.first) {
      if (match.winner != null) _advanceWinner(allMatches, match);
    }
    return allMatches;
  }

  String _roundName(int matchCount) => switch (matchCount) {
        1 => 'Chung kết',
        2 => 'Bán kết',
        4 => 'Tứ kết',
        _ => 'Vòng $matchCount trận',
      };

  Future<void> _chooseWinner(_TournamentMatch match) async {
    if (match.teamA == 'TBD' ||
        match.teamB == 'TBD' ||
        match.teamA == 'BYE' ||
        match.teamB == 'BYE') {
      return;
    }
    final winner = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text('${match.roundLabel} · Chọn đội thắng'),
            ),
            for (final team in [match.teamA, match.teamB])
              ListTile(
                minHeight: 56,
                title: Text(team),
                trailing: const Icon(Icons.emoji_events_outlined),
                onTap: () => Navigator.of(context).pop(team),
              ),
          ],
        ),
      ),
    );
    if (!mounted || winner == null) return;
    setState(() {
      match.winner = winner;
      if (_format == _TournamentFormat.knockout) {
        _advanceWinner(_matches, match);
      }
    });
    final teams = _teamsController.text
        .split(RegExp(r'[,;\n]'))
        .map((team) => team.trim())
        .where((team) => team.isNotEmpty)
        .toList(growable: false);
    await _save(teams);
  }

  void _advanceWinner(List<_TournamentMatch> matches, _TournamentMatch match) {
    final nextRound = match.roundNumber + 1;
    final nextMatchNumber = (match.matchNumber + 1) ~/ 2;
    final nextMatch = matches.cast<_TournamentMatch?>().firstWhere(
          (candidate) =>
              candidate?.roundNumber == nextRound &&
              candidate?.matchNumber == nextMatchNumber,
          orElse: () => null,
        );
    if (nextMatch == null || match.winner == null) return;
    if (match.matchNumber.isOdd) {
      nextMatch.teamA = match.winner!;
    } else {
      nextMatch.teamB = match.winner!;
    }
  }

  Future<void> _save(List<String> teams) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _storageKey,
        jsonEncode({
          'format': _format.name,
          'teams': teams,
          'matches': _matches.map((match) => match.toJson()).toList(),
        }),
      );
    } catch (_) {
      if (mounted) _showMessage('Không thể lưu giải đấu trên thiết bị.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Giải đấu mini')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _teamsController,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Các cặp đấu',
              hintText: 'Mỗi dòng một cặp\nNam & Tuấn\nHoàng & Minh',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<_TournamentFormat>(
            segments: const [
              ButtonSegment(
                value: _TournamentFormat.roundRobin,
                label: Text('Vòng tròn'),
              ),
              ButtonSegment(
                value: _TournamentFormat.knockout,
                label: Text('Loại trực tiếp'),
              ),
            ],
            selected: {_format},
            onSelectionChanged: (selection) =>
                setState(() => _format = selection.first),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('TẠO LỊCH GIẢI'),
            ),
          ),
          const SizedBox(height: 18),
          for (final match in _matches)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _chooseWinner(match),
                leading: CircleAvatar(
                  backgroundColor: match.winner == null
                      ? Colors.white12
                      : const Color(0xFFCCFF00).withOpacity(0.18),
                  child: Text('${match.roundNumber}.${match.matchNumber}'),
                ),
                title: Text(match.roundLabel),
                subtitle: Text('${match.teamA}  vs  ${match.teamB}'),
                trailing: match.winner == null
                    ? const Icon(Icons.chevron_right)
                    : const Icon(Icons.emoji_events, color: Color(0xFFCCFF00)),
              ),
            ),
        ],
      ),
    );
  }
}

class _TournamentMatch {
  _TournamentMatch({
    required this.roundNumber,
    required this.matchNumber,
    required this.roundLabel,
    required this.teamA,
    required this.teamB,
    this.winner,
  });

  final int roundNumber;
  final int matchNumber;
  final String roundLabel;
  String teamA;
  String teamB;
  String? winner;

  Map<String, Object?> toJson() => {
        'roundNumber': roundNumber,
        'matchNumber': matchNumber,
        'roundLabel': roundLabel,
        'teamA': teamA,
        'teamB': teamB,
        'winner': winner,
      };

  factory _TournamentMatch.fromJson(Map json) => _TournamentMatch(
        roundNumber: json['roundNumber'] as int,
        matchNumber: json['matchNumber'] as int,
        roundLabel: json['roundLabel'] as String,
        teamA: json['teamA'] as String,
        teamB: json['teamB'] as String,
        winner: json['winner'] as String?,
      );
}
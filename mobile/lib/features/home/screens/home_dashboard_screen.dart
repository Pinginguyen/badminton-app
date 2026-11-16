import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/engine/emvco_vietqr.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/bouncy_pressable.dart';
import '../../../core/ui/glass_container.dart';
import '../../../services/matchmaking_service.dart';
import '../../../services/vietqr_service.dart';
import '../../scoreboard/models/match_score.dart';
import '../../scoreboard/screens/camera_scoreboard_screen.dart';
import '../../session/models/session_model.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({
    super.key,
    this.bankAccount,
    this.isAdmin = true,
    this.matchmakingService = const MatchmakingService(),
  });

  final VietQrBankAccount? bankAccount;
  final bool isAdmin;
  final MatchmakingService matchmakingService;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final _storage = LocalStorageService();
  final _nameController = TextEditingController();
  final _courtCostController = TextEditingController();
  final _shuttlePriceController = TextEditingController();
  final _shuttleCountController = TextEditingController();
  final List<_HubPlayer> _players = [];
  final List<RecentMatch> _recentMatches = [];
  final List<MatchSuggestion> _matches = [];
  final List<MatchScore> _matchScores = [];
  String _sessionId =
      'session-${DateTime.now().microsecondsSinceEpoch}';

  SessionModel? _billingSession;
  int _courtCount = 1;
  int _roundNumber = 0;
  int _roundRecentStartIndex = 0;
  int _nextPlayerId = 0;
  bool _isLoading = true;
  bool _storageErrorShown = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreState());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _courtCostController.dispose();
    _shuttlePriceController.dispose();
    _shuttleCountController.dispose();
    super.dispose();
  }

  void _addPlayers(String value) {
    final names = value
        .split(RegExp(r'[,;\n]'))
        .map((name) => name.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((name) => name.isNotEmpty);
    final knownNames =
        _players.map((player) => _normalizeName(player.name)).toSet();
    final added = <_HubPlayer>[];
    for (final name in names) {
      if (!knownNames.add(_normalizeName(name))) continue;
      added.add(_HubPlayer(id: 'p${++_nextPlayerId}', name: name));
    }

    _nameController.clear();
    if (added.isEmpty) {
      if (value.trim().isNotEmpty) _showMessage('Tên này đã có trong danh sách.');
      return;
    }

    setState(() {
      _players.addAll(added);
      _matches.clear();
      _billingSession = null;
    });
    _queuePersistence();
  }

  static String _normalizeName(String name) => name.trim().toLowerCase();

  void _removePlayer(String id) {
    setState(() {
      _players.removeWhere((player) => player.id == id);
      _matches.clear();
      _billingSession = null;
    });
    _queuePersistence();
  }

  void _updatePlayer(String id, void Function(_HubPlayer player) update) {
    setState(() {
      update(_findPlayer(id));
      _matches.clear();
      _billingSession = null;
    });
    _queuePersistence();
  }

  _HubPlayer _findPlayer(String id) =>
      _players.firstWhere((player) => player.id == id);

  void _setCourtCount(int count) {
    setState(() {
      _courtCount = count;
      _matches.clear();
      _billingSession = null;
    });
    _queuePersistence();
  }

  void _scheduleMatches() {
    if (!widget.isAdmin) return;
    if (_players.length < 4) {
      _showMessage('Cần ít nhất 4 người chơi để xếp một trận đôi.');
      return;
    }

    final available = _players.map((player) => player.toMatchPlayer()).toList();
    final history = List<RecentMatch>.unmodifiable(_recentMatches);
    final nextMatches = <MatchSuggestion>[];
    final nextScores = <MatchScore>[];
    final playedAt = DateTime.now();

    for (var court = 1; court <= _courtCount; court++) {
      final match = widget.matchmakingService.suggestMatch(
        availablePlayers: available,
        recentMatches: history,
        now: playedAt,
        sessionId: _sessionId,
        courtNumber: court,
      );
      if (match == null) break;
      nextMatches.add(match);
      nextScores.add(_scoreForMatch(match));
      final selectedIds = match.players.map((player) => player.id).toSet();
      available.removeWhere((player) => selectedIds.contains(player.id));
    }

    if (nextMatches.isEmpty) {
      _showMessage('Chưa thể xếp trận từ danh sách hiện tại.');
      return;
    }

    final recentStartIndex = _recentMatches.length;
    setState(() {
      _roundNumber++;
      _roundRecentStartIndex = recentStartIndex;
      _matches
        ..clear()
        ..addAll(nextMatches);
      _matchScores
        ..clear()
        ..addAll(nextScores);
      for (final match in nextMatches) {
        final teamAIds = match.teamA.map((player) => player.id).toList();
        final teamBIds = match.teamB.map((player) => player.id).toList();
        for (final id in [...teamAIds, ...teamBIds]) {
          final player = _findPlayer(id);
          player.lastPlayedAt = playedAt;
          player.matchesPlayed++;
        }
        _recentMatches.add(
          RecentMatch(
            matchNumber: _recentMatches.length + 1,
            teamAPlayerIds: teamAIds,
            teamBPlayerIds: teamBIds,
          ),
        );
      }
    });
    unawaited(HapticFeedback.mediumImpact());
    _queuePersistence();
  }

  MatchScore _scoreForMatch(MatchSuggestion match) {
    final names = {for (final player in _players) player.id: player.name};
    return MatchScore.initial(
      teamAPlayerNames:
          match.teamA.map((player) => names[player.id] ?? player.id).toList(),
      teamBPlayerNames:
          match.teamB.map((player) => names[player.id] ?? player.id).toList(),
    );
  }

  void _openCamera(int matchIndex) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CameraScoreboardScreen(
          initialScore: _matchScores[matchIndex],
          onScoreChanged: (score) => _onMatchScoreChanged(matchIndex, score),
        ),
      ),
    );
  }

  void _onMatchScoreChanged(int matchIndex, MatchScore score) {
    if (!mounted || matchIndex < 0 || matchIndex >= _matchScores.length) return;
    setState(() {
      _matchScores[matchIndex] = score;
      final historyIndex = _roundRecentStartIndex + matchIndex;
      if (historyIndex >= 0 && historyIndex < _recentMatches.length) {
        final recent = _recentMatches[historyIndex];
        final teamAWon = score.isMatchComplete
            ? score.teamASetsWon > score.teamBSetsWon
            : null;
        if (recent.teamAWon != teamAWon) {
          _recentMatches[historyIndex] = RecentMatch(
            matchNumber: recent.matchNumber,
            teamAPlayerIds: recent.teamAPlayerIds,
            teamBPlayerIds: recent.teamBPlayerIds,
            teamAWon: teamAWon,
          );
        }
      }
    });
    _queuePersistence();
  }

  void _calculateBills() {
    if (_players.isEmpty) {
      _showMessage('Thêm thành viên trước khi tính tiền.');
      return;
    }
    setState(() => _billingSession = _createBillingSession());
    _queuePersistence();
  }

  void _refreshBillingSession() {
    if (_billingSession != null) {
      setState(() => _billingSession = _createBillingSession());
    }
    _queuePersistence();
  }

  void _swapPlayers(_PlayerPosition source, _PlayerPosition target) {
    if (!widget.isAdmin ||
        source == target ||
        source.matchIndex < 0 ||
        target.matchIndex < 0 ||
        source.matchIndex >= _matches.length ||
        target.matchIndex >= _matches.length) {
      return;
    }

    final teams = _matches
        .map(
          (match) => [
            List<MatchPlayer>.of(match.teamA),
            List<MatchPlayer>.of(match.teamB),
          ],
        )
        .toList();
    final sourceTeam = teams[source.matchIndex][source.teamIndex];
    final targetTeam = teams[target.matchIndex][target.teamIndex];
    if (source.playerIndex >= sourceTeam.length ||
        target.playerIndex >= targetTeam.length) {
      return;
    }

    final sourcePlayer = sourceTeam[source.playerIndex];
    sourceTeam[source.playerIndex] = targetTeam[target.playerIndex];
    targetTeam[target.playerIndex] = sourcePlayer;

    final affectedIndices = {source.matchIndex, target.matchIndex};
    final updatedMatches = List<MatchSuggestion>.of(_matches);
    final updatedScores = List<MatchScore>.of(_matchScores);
    final updatedHistory = List<RecentMatch>.of(_recentMatches);
    final playerNames = {for (final player in _players) player.id: player.name};
    final priorHistory =
        _recentMatches.take(_roundRecentStartIndex).toList(growable: false);

    for (final matchIndex in affectedIndices) {
      final match = _matches[matchIndex];
      final teamA = teams[matchIndex][0];
      final teamB = teams[matchIndex][1];
      final adminMatch = widget.matchmakingService.createAdminOverride(
        teamA: teamA,
        teamB: teamB,
        sessionId: match.sessionId,
        courtNumber: match.courtNumber,
      );
      final repeatedPairCount =
          widget.matchmakingService.countRecentPairRepeats(
        teamA: teamA,
        teamB: teamB,
        recentMatches: priorHistory,
      );
      updatedMatches[matchIndex] = MatchSuggestion(
        teamA: adminMatch.teamA,
        teamB: adminMatch.teamB,
        teamSkillDelta: adminMatch.teamSkillDelta,
        repeatedPairCount: repeatedPairCount,
        sessionId: adminMatch.sessionId,
        courtNumber: adminMatch.courtNumber,
        isAdminOverride: true,
      );

      final currentScore = _matchScores[matchIndex];
      updatedScores[matchIndex] = currentScore.copyWithPlayerNames(
        teamAPlayerNames:
            teamA.map((player) => playerNames[player.id] ?? player.id).toList(),
        teamBPlayerNames:
            teamB.map((player) => playerNames[player.id] ?? player.id).toList(),
      );
      final historyIndex = _roundRecentStartIndex + matchIndex;
      if (historyIndex < 0 || historyIndex >= updatedHistory.length) {
        _showMessage('Không thể đồng bộ lịch sử trận sau khi đổi người.');
        return;
      }
      updatedHistory[historyIndex] = RecentMatch(
        matchNumber: updatedHistory[historyIndex].matchNumber,
        teamAPlayerIds: teamA.map((player) => player.id).toList(),
        teamBPlayerIds: teamB.map((player) => player.id).toList(),
      );
    }

    setState(() {
      _matches
        ..clear()
        ..addAll(updatedMatches);
      _matchScores
        ..clear()
        ..addAll(updatedScores);
      _recentMatches
        ..clear()
        ..addAll(updatedHistory);
    });
    unawaited(HapticFeedback.mediumImpact());
    _queuePersistence();
  }

  void _queuePersistence() {
    if (!mounted || _isLoading || _loadError != null) return;
    unawaited(_saveSnapshot(_createSnapshot()));
  }

  Future<void> _saveSnapshot(Map<String, Object?> snapshot) async {
    try {
      await _storage.saveSnapshot(snapshot);
      _storageErrorShown = false;
    } on PlatformException catch (error, stackTrace) {
      _reportPersistenceFailure(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _reportPersistenceFailure(error, stackTrace);
    } on StateError catch (error, stackTrace) {
      _reportPersistenceFailure(error, stackTrace);
    }
  }

  void _reportPersistenceFailure(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'local session storage',
        context: ErrorDescription('while saving the current badminton session'),
      ),
    );
    if (!mounted || _storageErrorShown) return;
    _storageErrorShown = true;
    _showMessage('Không thể tự lưu buổi đánh. Hãy kiểm tra bộ nhớ thiết bị.');
  }

  Future<void> _restoreState({bool retry = false}) async {
    if (retry && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final snapshot = await _storage.loadSnapshot();
      if (snapshot != null) _applySnapshot(snapshot);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = null;
      });
    } on FormatException catch (error, stackTrace) {
      _showRestoreError(error, stackTrace);
    } on ArgumentError catch (error, stackTrace) {
      _showRestoreError(error, stackTrace);
    } on PlatformException catch (error, stackTrace) {
      _showRestoreError(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _showRestoreError(error, stackTrace);
    } on StateError catch (error, stackTrace) {
      _showRestoreError(error, stackTrace);
    }
  }

  void _showRestoreError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'local session storage',
        context: ErrorDescription('while restoring the saved badminton session'),
      ),
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _loadError =
          'Không thể khôi phục buổi đánh đã lưu. Có thể thử lại hoặc xóa dữ liệu lỗi.';
    });
  }

  void _applySnapshot(Map<String, Object?> snapshot) {
    if (_requiredInt(snapshot, 'version') != 1) {
      throw const FormatException('Unsupported badminton session snapshot version.');
    }

    final sessionId = _requiredString(snapshot, 'sessionId');
    if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(sessionId)) {
      throw const FormatException('The saved session ID is invalid.');
    }
    final courtCount = _requiredInt(snapshot, 'courtCount');
    if (courtCount < 1 || courtCount > 2) {
      throw const FormatException('The saved court count is invalid.');
    }

    final players = _requiredList(snapshot, 'players')
        .map(_HubPlayer.fromJson)
        .toList(growable: false);
    final playerIds = players.map((player) => player.id).toSet();
    final playerNames =
        players.map((player) => _normalizeName(player.name)).toSet();
    if (playerIds.length != players.length || playerNames.length != players.length) {
      throw const FormatException('The saved roster contains duplicate players.');
    }
    final highestPlayerId = players.fold<int>(0, (highest, player) {
      final match = RegExp(r'^p(\d+)$').firstMatch(player.id);
      final value = match == null ? 0 : int.parse(match.group(1)!);
      return value > highest ? value : highest;
    });

    final recentMatches = _requiredList(snapshot, 'recentMatches')
        .map(_recentMatchFromJson)
        .toList(growable: false);
    final matches = _requiredList(snapshot, 'matches')
        .map(_matchSuggestionFromJson)
        .toList(growable: false);
    final scores = _requiredList(snapshot, 'scores')
        .map((value) => MatchScore.fromJson(_requiredObjectMap(value, 'score')))
        .toList(growable: false);
    if (matches.length != scores.length || matches.length > courtCount) {
      throw const FormatException('Saved matches and scores do not line up.');
    }

    final scheduledPlayerIds = <String>{};
    final namesById = {for (final player in players) player.id: player.name};
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      for (final player in match.players) {
        if (!playerIds.contains(player.id) || !scheduledPlayerIds.add(player.id)) {
          throw const FormatException('A saved match contains an unknown or duplicate player.');
        }
      }
      final score = scores[index];
      final expectedTeamA =
          match.teamA.map((player) => namesById[player.id]!).toList();
      final expectedTeamB =
          match.teamB.map((player) => namesById[player.id]!).toList();
      if (!_sameNames(score.teamAPlayerNames, expectedTeamA) ||
          !_sameNames(score.teamBPlayerNames, expectedTeamB)) {
        throw const FormatException('Saved score names do not match the roster.');
      }
    }

    final roundNumber = _requiredInt(snapshot, 'roundNumber');
    final recentStartIndex = _requiredInt(snapshot, 'roundRecentStartIndex');
    if (roundNumber < 0 ||
        recentStartIndex < 0 ||
        recentStartIndex > recentMatches.length ||
        (matches.isNotEmpty &&
            recentStartIndex + matches.length != recentMatches.length)) {
      throw const FormatException('The saved round history is inconsistent.');
    }
    final nextPlayerId = _requiredInt(snapshot, 'nextPlayerId');
    if (nextPlayerId < highestPlayerId) {
      throw const FormatException('The saved player ID counter is invalid.');
    }
    final billing = _requiredObjectMap(snapshot['billing'], 'billing');
    final courtCost = _requiredString(billing, 'courtCost');
    final shuttlePrice = _requiredString(billing, 'shuttlePrice');
    final shuttleCount = _requiredString(billing, 'shuttleCount');
    for (final value in [courtCost, shuttlePrice, shuttleCount]) {
      if (!RegExp(r'^\d*$').hasMatch(value)) {
        throw const FormatException('Saved billing input contains invalid characters.');
      }
    }

    _sessionId = sessionId;
    _courtCount = courtCount;
    _roundNumber = roundNumber;
    _roundRecentStartIndex = recentStartIndex;
    _nextPlayerId = nextPlayerId;
    _players
      ..clear()
      ..addAll(players);
    _recentMatches
      ..clear()
      ..addAll(recentMatches);
    _matches
      ..clear()
      ..addAll(matches);
    _matchScores
      ..clear()
      ..addAll(scores);
    _courtCostController.text = courtCost;
    _shuttlePriceController.text = shuttlePrice;
    _shuttleCountController.text = shuttleCount;
    _billingSession = _requiredBool(snapshot, 'billingCalculated') &&
            _players.isNotEmpty
        ? _createBillingSession()
        : null;
  }

  Map<String, Object?> _createSnapshot() => {
        'version': 1,
        'sessionId': _sessionId,
        'courtCount': _courtCount,
        'roundNumber': _roundNumber,
        'roundRecentStartIndex': _roundRecentStartIndex,
        'nextPlayerId': _nextPlayerId,
        'players': _players.map((player) => player.toJson()).toList(),
        'recentMatches':
            _recentMatches.map(_recentMatchToJson).toList(growable: false),
        'matches': _matches.map(_matchSuggestionToJson).toList(growable: false),
        'scores': _matchScores.map((score) => score.toJson()).toList(),
        'billing': {
          'courtCost': _courtCostController.text,
          'shuttlePrice': _shuttlePriceController.text,
          'shuttleCount': _shuttleCountController.text,
        },
        'billingCalculated': _billingSession != null,
      };

  Future<void> _discardSavedState() async {
    try {
      await _storage.clearSnapshot();
      if (!mounted) return;
      _nameController.clear();
      _courtCostController.clear();
      _shuttlePriceController.clear();
      _shuttleCountController.clear();
      _players.clear();
      _recentMatches.clear();
      _matches.clear();
      _matchScores.clear();
      setState(() {
        _sessionId = 'session-${DateTime.now().microsecondsSinceEpoch}';
        _courtCount = 1;
        _roundNumber = 0;
        _roundRecentStartIndex = 0;
        _nextPlayerId = 0;
        _billingSession = null;
        _loadError = null;
      });
    } on PlatformException catch (error, stackTrace) {
      _showRestoreError(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _showRestoreError(error, stackTrace);
    } on StateError catch (error, stackTrace) {
      _showRestoreError(error, stackTrace);
    }
  }

  SessionModel _createBillingSession() {
    final now = DateTime.now();
    return SessionModel(
      id: _sessionId,
      title: 'Buổi đánh',
      startsAt: now,
      endsAt: now.add(const Duration(hours: 2)),
      courtCount: _courtCount,
      courtRentalTotalVnd: int.tryParse(_courtCostController.text) ?? 0,
      shuttleUnitPriceVnd: int.tryParse(_shuttlePriceController.text) ?? 0,
      shuttlesUsed: int.tryParse(_shuttleCountController.text) ?? 0,
      participants: _players
          .map(
            (player) => SessionMember(
              id: player.id,
              displayName: player.name,
              skillLevel: player.skillLevel,
              eloRating: player.eloRating,
              lastPlayedAt: player.lastPlayedAt,
              attendanceWeight: player.lateOrLeavingEarly ? 0.5 : 1,
            ),
          )
          .toList(growable: false),
    );
  }

  void _openQr(SessionModel session, SessionMember member, SessionBill bill) {
    final bankAccount = widget.bankAccount;
    if (bankAccount == null) {
      _showMessage('Cấu hình tài khoản ngân hàng để tạo VietQR.');
      return;
    }

    try {
      final memo = 'CLB_${session.id}_${member.id}';
      final payload = EmvcoVietQr.buildPayload(
        bankBin: bankAccount.bankBin,
        accountNumber: bankAccount.accountNumber,
        amount: bill.totalAmountVnd,
        memo: memo,
      );
      showDialog<void>(
        context: context,
        builder: (_) => _PaymentQrDialog(
          member: member,
          bill: bill,
          bankAccount: bankAccount,
          payload: payload,
          memo: memo,
        ),
      );
    } on ArgumentError catch (error) {
      _showMessage('Không thể tạo VietQR: ${error.message}');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.courtNavy,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) return _buildLoadError(_loadError!);

    final session = _billingSession;
    final bills = session == null
        ? const <SessionBill>[]
        : session.participants
            .map((member) => session.billFor(member))
            .toList(growable: false);
    final totalDue =
        bills.fold<int>(0, (total, bill) => total + bill.totalAmountVnd);

    return Scaffold(
      backgroundColor: AppTheme.courtNavy,
      appBar: _buildAppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _HubIntro(playerCount: _players.length),
            const SizedBox(height: 22),
            _buildPlayerSection(),
            const SizedBox(height: 22),
            _buildCourtSection(),
            _buildMatchSection(),
            const SizedBox(height: 22),
            _buildBillingSection(session, bills, totalDue),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError(String message) {
    return Scaffold(
      backgroundColor: AppTheme.courtNavy,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_rounded, size: 42, color: Colors.orangeAccent),
                const SizedBox(height: 12),
                const Text(
                  'Không thể khôi phục dữ liệu',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => unawaited(_restoreState(retry: true)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _discardSavedState,
                  child: const Text('Xóa dữ liệu lỗi và bắt đầu mới'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COURT SIDE',
            style: TextStyle(
              color: AppTheme.neonGreen,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          Text(
            'BADMINTON HUB',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      actions: [
        _AdminBadge(isAdmin: widget.isAdmin),
        const SizedBox(width: 14),
      ],
    );
  }

  Widget _buildPlayerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(
          index: '01',
          title: 'Nhập quân siêu tốc',
          subtitle: 'Nhập tên hoặc dán danh sách, ngăn cách bằng dấu phẩy',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                enabled: widget.isAdmin,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: _addPlayers,
                decoration: const InputDecoration(
                  hintText: 'Nam, Tuấn, Hoàng, Minh...',
                  prefixIcon: Icon(Icons.person_add_alt_1),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed:
                  widget.isAdmin ? () => _addPlayers(_nameController.text) : null,
              child: const Text('Thêm'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_players.isEmpty)
          const _EmptyPlayers()
        else
          for (var index = 0; index < _players.length; index++)
            _buildPlayerTile(index),
      ],
    );
  }

  Widget _buildPlayerTile(int index) {
    final player = _players[index];
    final delay = Duration(milliseconds: index.clamp(0, 8).toInt() * 42);
    return _PlayerTile(
      player: player,
      isAdmin: widget.isAdmin,
      onSkillChanged: (level) => _updatePlayer(
        player.id,
        (current) => current.skillLevel = level,
      ),
      onLateChanged: (value) => _updatePlayer(
        player.id,
        (current) => current.lateOrLeavingEarly = value,
      ),
      onRemove: () => _removePlayer(player.id),
    )
        .animate(key: ValueKey('roster-${player.id}'))
        .fadeIn(duration: 320.ms, delay: delay)
        .slideY(
          begin: 0.14,
          end: 0,
          duration: 360.ms,
          delay: delay,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildCourtSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(
          index: '02',
          title: 'Chia sân thi đấu',
          subtitle: 'Chia đội cân bằng, không trùng người giữa các sân',
        ),
        const SizedBox(height: 11),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('1 Sân')),
            ButtonSegment(value: 2, label: Text('2 Sân')),
          ],
          selected: {_courtCount},
          onSelectionChanged: widget.isAdmin
              ? (selection) => _setCourtCount(selection.first)
              : null,
        ),
        const SizedBox(height: 11),
        BouncyPressable(
          onPressed: widget.isAdmin ? _scheduleMatches : null,
          enabled: widget.isAdmin,
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isAdmin
                    ? [AppTheme.neonGreen, AppTheme.limeYellow]
                    : [Colors.white24, Colors.white12],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: widget.isAdmin
                  ? [
                      BoxShadow(
                        color: AppTheme.neonGreen.withOpacity(0.18),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt, color: AppTheme.courtNavy),
                SizedBox(width: 8),
                Text(
                  'XẾP CẶP ĐẤU',
                  style: TextStyle(
                    color: AppTheme.courtNavy,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchSection() {
    if (_matches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        _SectionTitle(
          index: 'LIVE',
          title: 'Vòng $_roundNumber',
          subtitle: '${_matches.length} trận đã được xếp',
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < _matches.length; index++)
          _MatchCard(
            matchIndex: index,
            match: _matches[index],
            score: _matchScores[index],
            isAdmin: widget.isAdmin,
            onOpenCamera: () => _openCamera(index),
            onSwap: _swapPlayers,
            playerNames: {
              for (final player in _players) player.id: player.name,
            },
          )
              .animate(key: ValueKey('match-$_roundNumber-$index'))
              .fadeIn(duration: 320.ms)
              .flipH(
                begin: 0.72,
                end: 0,
                duration: 560.ms,
                curve: Curves.easeOutBack,
              ),
        _RestingPlayers(
          players: _players
              .where(
                (player) => !_matches
                    .expand((match) => match.players)
                    .any((matched) => matched.id == player.id),
              )
              .map((player) => player.name)
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildBillingSection(
    SessionModel? session,
    List<SessionBill> bills,
    int totalDue,
  ) {
    final moneyInputs = [
      _MoneyField(
        controller: _courtCostController,
        label: 'Tiền sân (₫)',
        onChanged: _refreshBillingSession,
      ),
      _MoneyField(
        controller: _shuttlePriceController,
        label: 'Giá / quả (₫)',
        onChanged: _refreshBillingSession,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(
          index: '03',
          title: 'Thanh toán & VietQR',
          subtitle: 'Tính chi phí minh bạch cho từng thành viên',
        ),
        const SizedBox(height: 11),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 390) {
              return Column(
                children: [
                  moneyInputs[0],
                  const SizedBox(height: 9),
                  moneyInputs[1],
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: moneyInputs[0]),
                const SizedBox(width: 9),
                Expanded(child: moneyInputs[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 9),
        _MoneyField(
          controller: _shuttleCountController,
          label: 'Số quả cầu đã đánh',
          onChanged: _refreshBillingSession,
        ),
        const SizedBox(height: 5),
        Text(
          'Tiền cầu = giá mỗi quả × số quả đã đánh.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white54,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: widget.isAdmin
              ? _withNeonShimmer(
                  BouncyPressable(
                    onPressed: _calculateBills,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.neonGreen, AppTheme.limeYellow],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payments_outlined,
                              color: AppTheme.courtNavy),
                          SizedBox(width: 8),
                          Text(
                            'TÍNH TIỀN NGAY',
                            style: TextStyle(
                              color: AppTheme.courtNavy,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  key: const ValueKey('billing-shimmer'),
                )
              : BouncyPressable(
                  onPressed: null,
                  enabled: false,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('TÍNH TIỀN NGAY'),
                  ),
                ),
          ),
        ),
        if (session != null) ...[
          const SizedBox(height: 13),
          _TotalDueCard(totalVnd: totalDue),
          for (var index = 0; index < session.participants.length; index++)
            _BillTile(
              member: session.participants[index],
              bill: bills[index],
              canOpenQr: widget.bankAccount != null &&
                  bills[index].totalAmountVnd > 0,
              onOpenQr: () => _openQr(
                session,
                session.participants[index],
                bills[index],
              ),
            ),
        ],
        if (widget.bankAccount == null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Cần cấu hình VIETQR_BANK_BIN, VIETQR_ACCOUNT_NUMBER và '
              'VIETQR_ACCOUNT_NAME để bật mã QR.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orangeAccent,
                  ),
            ),
          ),
      ],
    );
  }
}

class _HubPlayer {
  _HubPlayer({required this.id, required this.name});

  final String id;
  final String name;
  int skillLevel = 2;
  int eloRating = 1000;
  int matchesPlayed = 0;
  bool lateOrLeavingEarly = false;
  DateTime? lastPlayedAt;

  MatchPlayer toMatchPlayer() => MatchPlayer(
        id: id,
        skillLevel: skillLevel,
        eloRating: eloRating,
        lastPlayedAt: lastPlayedAt,
        matchesPlayed: matchesPlayed,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'skillLevel': skillLevel,
        'eloRating': eloRating,
        'matchesPlayed': matchesPlayed,
        'lateOrLeavingEarly': lateOrLeavingEarly,
        'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      };

  factory _HubPlayer.fromJson(Object? value) {
    final json = _requiredObjectMap(value, 'player');
    final id = _requiredString(json, 'id');
    final name = _requiredString(json, 'name').trim();
    final skillLevel = _requiredInt(json, 'skillLevel');
    final eloRatingValue = json['eloRating'];
    final eloRating =
        eloRatingValue == null ? 1000 : _requiredInt(json, 'eloRating');
    final matchesPlayedValue = json['matchesPlayed'];
    final matchesPlayed =
        matchesPlayedValue == null ? 0 : _requiredInt(json, 'matchesPlayed');
    final lastPlayedAtValue = json['lastPlayedAt'];
    final lastPlayedAt = switch (lastPlayedAtValue) {
      null => null,
      String value => DateTime.tryParse(value),
      _ => throw const FormatException('A saved player date is invalid.'),
    };
    if (id.isEmpty ||
        name.isEmpty ||
        skillLevel < 1 ||
        skillLevel > 4 ||
        eloRating < 0 ||
        matchesPlayed < 0 ||
        (lastPlayedAtValue is String && lastPlayedAt == null)) {
      throw const FormatException('A saved player is invalid.');
    }

    return _HubPlayer(id: id, name: name)
      ..skillLevel = skillLevel
      ..eloRating = eloRating
      ..matchesPlayed = matchesPlayed
      ..lateOrLeavingEarly = _requiredBool(json, 'lateOrLeavingEarly')
      ..lastPlayedAt = lastPlayedAt;
  }
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.neonGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        isAdmin ? 'ADMIN' : 'MEMBER',
        style: const TextStyle(
          color: AppTheme.neonGreen,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _HubIntro extends StatelessWidget {
  const _HubIntro({required this.playerCount});

  final int playerCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3024), AppTheme.raisedNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.neonGreen.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.neonGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.sports_tennis, color: AppTheme.neonGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SẴN SÀNG RA SÂN?',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$playerCount người chơi trong buổi này',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                ),
              ],
            ),
          ),
          const Icon(Icons.bolt, color: AppTheme.limeYellow),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  final String index;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.neonGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            index,
            style: const TextStyle(
              color: AppTheme.neonGreen,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyPlayers extends StatelessWidget {
  const _EmptyPlayers();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: const Row(
        children: [
          Icon(Icons.groups_outlined, color: Colors.white54),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Thêm người chơi để bắt đầu chia sân.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.player,
    required this.isAdmin,
    required this.onSkillChanged,
    required this.onLateChanged,
    required this.onRemove,
  });

  final _HubPlayer player;
  final bool isAdmin;
  final ValueChanged<int> onSkillChanged;
  final ValueChanged<bool> onLateChanged;
  final VoidCallback onRemove;

  static const _levels = [
    (1, 'Yếu'),
    (2, 'TB'),
    (3, 'Khá'),
    (4, 'Cứng'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.raisedNavy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: AppTheme.neonGreen.withOpacity(0.12),
                  child: Text(
                    String.fromCharCode(player.name.runes.first).toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.neonGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: isAdmin ? onRemove : null,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Xóa người chơi',
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            Wrap(
              spacing: 5,
              runSpacing: 0,
              children: [
                for (final level in _levels)
                  ChoiceChip(
                    label: Text('${level.$2} · ${level.$1}★'),
                    selected: player.skillLevel == level.$1,
                    onSelected: !isAdmin || player.skillLevel == level.$1
                        ? null
                        : (_) => onSkillChanged(level.$1),
                    visualDensity: VisualDensity.compact,
                    labelStyle: const TextStyle(fontSize: 10),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.white54),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Đi trễ · 0,5 phần sân',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
                Switch.adaptive(
                  value: player.lateOrLeavingEarly,
                  onChanged: isAdmin ? onLateChanged : null,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.matchIndex,
    required this.match,
    required this.score,
    required this.isAdmin,
    required this.playerNames,
    required this.onOpenCamera,
    required this.onSwap,
  });

  final int matchIndex;
  final MatchSuggestion match;
  final MatchScore score;
  final bool isAdmin;
  final Map<String, String> playerNames;
  final VoidCallback onOpenCamera;
  final void Function(_PlayerPosition, _PlayerPosition) onSwap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(13),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.grid_view_rounded,
                  color: AppTheme.limeYellow,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Text(
                  'SÂN ${match.courtNumber ?? 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
                const Spacer(),
                Text(
                  'CHÊNH ${match.teamSkillDelta}',
                  style: const TextStyle(
                    color: AppTheme.neonGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            _TeamLine(
              matchIndex: matchIndex,
              teamIndex: 0,
              label: 'ĐỘI A',
              color: AppTheme.neonGreen,
              players: match.teamA,
              playerNames: playerNames,
              isAdmin: isAdmin && !score.isMatchComplete,
              onSwap: onSwap,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'VS',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _TeamLine(
              matchIndex: matchIndex,
              teamIndex: 1,
              label: 'ĐỘI B',
              color: AppTheme.limeYellow,
              players: match.teamB,
              playerNames: playerNames,
              isAdmin: isAdmin && !score.isMatchComplete,
              onSwap: onSwap,
            ),
            const SizedBox(height: 8),
            Text(
              'HIỆP ĐẤU  ${score.sets.map((set) => '${set.teamA}:${set.teamB}').join('   ')}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white60,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenCamera,
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('MỞ CAMERA SCOREBOARD'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({
    required this.matchIndex,
    required this.teamIndex,
    required this.label,
    required this.color,
    required this.players,
    required this.playerNames,
    required this.isAdmin,
    required this.onSwap,
  });

  final int matchIndex;
  final int teamIndex;
  final String label;
  final Color color;
  final List<MatchPlayer> players;
  final Map<String, String> playerNames;
  final bool isAdmin;
  final void Function(_PlayerPosition, _PlayerPosition) onSwap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 50,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              for (var playerIndex = 0;
                  playerIndex < players.length;
                  playerIndex++)
                _PlayerDropZone(
                  position: _PlayerPosition(
                    matchIndex: matchIndex,
                    teamIndex: teamIndex,
                    playerIndex: playerIndex,
                  ),
                  name: playerNames[players[playerIndex].id] ??
                      players[playerIndex].id,
                  isAdmin: isAdmin,
                  onSwap: onSwap,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerDropZone extends StatelessWidget {
  const _PlayerDropZone({
    required this.position,
    required this.name,
    required this.isAdmin,
    required this.onSwap,
  });

  final _PlayerPosition position;
  final String name;
  final bool isAdmin;
  final void Function(_PlayerPosition, _PlayerPosition) onSwap;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_PlayerPosition>(
      key: ValueKey(
        'player-slot-${position.matchIndex}-${position.teamIndex}-${position.playerIndex}',
      ),
      onWillAcceptWithDetails: isAdmin
          ? (details) => details.data != position
          : null,
      onAcceptWithDetails: isAdmin
          ? (details) => onSwap(details.data, position)
          : null,
      builder: (context, candidates, rejected) {
        final highlighted = candidates.isNotEmpty;
        final pill = _PlayerPill(
          name: name,
          highlighted: highlighted,
          draggable: isAdmin,
        );
        if (!isAdmin) return pill;

        return LongPressDraggable<_PlayerPosition>(
          data: position,
          maxSimultaneousDrags: 1,
          feedback: Material(
            color: Colors.transparent,
            child: _PlayerPill(name: name, dragging: true),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: pill),
          child: pill,
        );
      },
    );
  }
}

class _PlayerPill extends StatelessWidget {
  const _PlayerPill({
    required this.name,
    this.highlighted = false,
    this.dragging = false,
    this.draggable = false,
  });

  final String name;
  final bool highlighted;
  final bool dragging;
  final bool draggable;

  @override
  Widget build(BuildContext context) {
    final borderColor = highlighted ? AppTheme.limeYellow : Colors.white12;
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? AppTheme.limeYellow.withOpacity(0.14) : Colors.white10,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: borderColor,
          width: highlighted || dragging ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dragging || highlighted || draggable) ...[
            Icon(
              dragging
                  ? Icons.open_with_rounded
                  : highlighted
                      ? Icons.swap_horiz_rounded
                      : Icons.drag_indicator,
              size: 13,
              color: AppTheme.limeYellow,
            ),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerPosition {
  const _PlayerPosition({
    required this.matchIndex,
    required this.teamIndex,
    required this.playerIndex,
  });

  final int matchIndex;
  final int teamIndex;
  final int playerIndex;

  @override
  bool operator ==(Object other) =>
      other is _PlayerPosition &&
      other.matchIndex == matchIndex &&
      other.teamIndex == teamIndex &&
      other.playerIndex == playerIndex;

  @override
  int get hashCode => Object.hash(matchIndex, teamIndex, playerIndex);
}

class _RestingPlayers extends StatelessWidget {
  const _RestingPlayers({required this.players});

  final List<String> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hotel_outlined, size: 16, color: Colors.white54),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Nghỉ vòng này: ${players.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.edit_note, size: 19),
        isDense: true,
      ),
    );
  }
}

class _TotalDueCard extends StatelessWidget {
  const _TotalDueCard({required this.totalVnd});

  final int totalVnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.neonGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.neonGreen.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'TỔNG CẦN THU',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Text(
            formatVnd(totalVnd),
            style: const TextStyle(
              color: AppTheme.neonGreen,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({
    required this.member,
    required this.bill,
    required this.canOpenQr,
    required this.onOpenQr,
  });

  final SessionMember member;
  final SessionBill bill;
  final bool canOpenQr;
  final VoidCallback onOpenQr;

  @override
  Widget build(BuildContext context) {
    final qrButton = BouncyPressable(
      onPressed: canOpenQr ? onOpenQr : null,
      enabled: canOpenQr,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canOpenQr
                ? AppTheme.neonGreen.withOpacity(0.55)
                : Colors.white12,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2, size: 17, color: AppTheme.neonGreen),
            SizedBox(width: 5),
            Text('VietQR', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: AppTheme.raisedNavy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${member.arrivedLate ? 'Sân 0,5 phần' : 'Sân đủ phần'}'
                    ' · Cầu ${formatVnd(bill.shuttleShareVnd)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white60,
                        ),
                  ),
                  Text(
                    formatVnd(bill.totalAmountVnd),
                    style: const TextStyle(
                      color: AppTheme.limeYellow,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            canOpenQr
                ? _withNeonShimmer(
                    qrButton,
                    key: ValueKey('qr-shimmer-${member.id}'),
                  )
                : qrButton,
          ],
        ),
      ),
    );
  }
}

class _PaymentQrDialog extends StatelessWidget {
  const _PaymentQrDialog({
    required this.member,
    required this.bill,
    required this.bankAccount,
    required this.payload,
    required this.memo,
  });

  final SessionMember member;
  final SessionBill bill;
  final VietQrBankAccount bankAccount;
  final String payload;
  final String memo;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final qrSize = screenWidth < 360
        ? 160.0
        : screenWidth < 420
            ? 190.0
            : 230.0;

    return AlertDialog(
      title: Text('VietQR · ${member.displayName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatVnd(bill.totalAmountVnd),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.neonGreen,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            _QrBillLine(label: 'Tiền sân', amountVnd: bill.courtShareVnd),
            _QrBillLine(label: 'Tiền cầu', amountVnd: bill.shuttleShareVnd),
            _QrBillLine(label: 'Phụ phí', amountVnd: bill.lateFeeVnd),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(
                data: payload,
                size: qrSize,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                semanticsLabel: 'Mã VietQR của ${member.displayName}',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${bankAccount.accountName}\n${bankAccount.accountNumber}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 5),
            SelectableText(
              'Nội dung: $memo',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _copyAccountNumber(context),
          icon: const Icon(Icons.copy),
          label: const Text('Copy số tài khoản'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  Future<void> _copyAccountNumber(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: bankAccount.accountNumber));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Đã copy số tài khoản.')),
        );
    } on PlatformException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể copy số tài khoản.')),
      );
    }
  }
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('Saved "$key" must be an integer.');
  return value;
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Saved "$key" must be text.');
  return value;
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Saved "$key" must be a boolean.');
  return value;
}

List<Object?> _requiredList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('Saved "$key" must be a list.');
  return List<Object?>.of(value);
}

Map<String, Object?> _requiredObjectMap(Object? value, String field) {
  if (value is! Map) throw FormatException('Saved $field must be an object.');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('Saved $field contains a non-text key.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<String> _requiredStringList(Map<String, Object?> json, String key) {
  final values = _requiredList(json, key);
  if (values.any((value) => value is! String || value.isEmpty)) {
    throw FormatException('Saved "$key" must contain non-empty text values.');
  }
  return values.cast<String>();
}

DateTime? _optionalDateTime(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('Saved "$key" must be a date.');
  final date = DateTime.tryParse(value);
  if (date == null) throw FormatException('Saved "$key" is not a valid date.');
  return date;
}

Map<String, Object?> _matchPlayerToJson(MatchPlayer player) => {
      'id': player.id,
      'skillLevel': player.skillLevel,
      'eloRating': player.eloRating,
      'lastPlayedAt': player.lastPlayedAt?.toIso8601String(),
      'matchesPlayed': player.matchesPlayed,
    };

MatchPlayer _matchPlayerFromJson(Object? value) {
  final json = _requiredObjectMap(value, 'match player');
  final id = _requiredString(json, 'id');
  final skillLevel = _requiredInt(json, 'skillLevel');
  final eloRating = _requiredInt(json, 'eloRating');
  final matchesPlayedValue = json['matchesPlayed'];
  final matchesPlayed =
      matchesPlayedValue == null ? 0 : _requiredInt(json, 'matchesPlayed');
  if (id.isEmpty ||
      skillLevel < 1 ||
      skillLevel > 4 ||
      eloRating < 0 ||
      matchesPlayed < 0) {
    throw const FormatException('A saved match player is invalid.');
  }
  return MatchPlayer(
    id: id,
    skillLevel: skillLevel,
    eloRating: eloRating,
    lastPlayedAt: _optionalDateTime(json, 'lastPlayedAt'),
    matchesPlayed: matchesPlayed,
  );
}

Map<String, Object?> _matchSuggestionToJson(MatchSuggestion match) => {
      'teamA': match.teamA.map(_matchPlayerToJson).toList(growable: false),
      'teamB': match.teamB.map(_matchPlayerToJson).toList(growable: false),
      'teamSkillDelta': match.teamSkillDelta,
      'repeatedPairCount': match.repeatedPairCount,
      'sessionId': match.sessionId,
      'courtNumber': match.courtNumber,
      'isAdminOverride': match.isAdminOverride,
    };

MatchSuggestion _matchSuggestionFromJson(Object? value) {
  final json = _requiredObjectMap(value, 'match');
  final teamA = _requiredList(json, 'teamA')
      .map(_matchPlayerFromJson)
      .toList(growable: false);
  final teamB = _requiredList(json, 'teamB')
      .map(_matchPlayerFromJson)
      .toList(growable: false);
  final teamSkillDelta = _requiredInt(json, 'teamSkillDelta');
  final repeatedPairCount = _requiredInt(json, 'repeatedPairCount');
  final sessionId = json['sessionId'];
  final courtNumber = json['courtNumber'];
  if (teamA.length != 2 ||
      teamB.length != 2 ||
      teamSkillDelta < 0 ||
      repeatedPairCount < 0 ||
      (sessionId != null && sessionId is! String) ||
      (courtNumber != null && courtNumber is! int) ||
      (courtNumber is int && (courtNumber < 1 || courtNumber > 2))) {
    throw const FormatException('A saved doubles match is invalid.');
  }
  return MatchSuggestion(
    teamA: List.unmodifiable(teamA),
    teamB: List.unmodifiable(teamB),
    teamSkillDelta: teamSkillDelta,
    repeatedPairCount: repeatedPairCount,
    sessionId: sessionId as String?,
    courtNumber: courtNumber as int?,
    isAdminOverride: _requiredBool(json, 'isAdminOverride'),
  );
}

Map<String, Object?> _recentMatchToJson(RecentMatch match) => {
      'matchNumber': match.matchNumber,
      'teamAPlayerIds': match.teamAPlayerIds,
      'teamBPlayerIds': match.teamBPlayerIds,
      'teamAWon': match.teamAWon,
    };

RecentMatch _recentMatchFromJson(Object? value) {
  final json = _requiredObjectMap(value, 'recent match');
  final matchNumber = _requiredInt(json, 'matchNumber');
  final teamAPlayerIds = _requiredStringList(json, 'teamAPlayerIds');
  final teamBPlayerIds = _requiredStringList(json, 'teamBPlayerIds');
  final teamAWon = json['teamAWon'];
  if (matchNumber < 1 ||
      teamAPlayerIds.length != 2 ||
      teamBPlayerIds.length != 2 ||
      {...teamAPlayerIds, ...teamBPlayerIds}.length != 4 ||
      (teamAWon != null && teamAWon is! bool)) {
    throw const FormatException('A saved match history entry is invalid.');
  }
  return RecentMatch(
    matchNumber: matchNumber,
    teamAPlayerIds: List.unmodifiable(teamAPlayerIds),
    teamBPlayerIds: List.unmodifiable(teamBPlayerIds),
    teamAWon: teamAWon as bool?,
  );
}

bool _sameNames(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

Widget _withNeonShimmer(Widget child, {required Key key}) {
  return RepaintBoundary(
    child: child
        .animate(
          key: key,
          onPlay: (controller) => controller.repeat(),
        )
        .shimmer(
          duration: 1800.ms,
          color: Colors.white.withOpacity(0.35),
        ),
  );
}

class _QrBillLine extends StatelessWidget {
  const _QrBillLine({required this.label, required this.amountVnd});

  final String label;
  final int amountVnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(formatVnd(amountVnd)),
        ],
      ),
    );
  }
}

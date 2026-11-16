import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/elo_calculator.dart';
import '../../../core/storage/session_detail_storage.dart';
import '../../../core/storage/vietqr_settings_store.dart';
import '../../../services/matchmaking_service.dart';
import '../../../services/vietqr_service.dart';
import '../../scoreboard/models/match_score.dart';
import '../../scoreboard/screens/camera_scoreboard_screen.dart';
import '../models/session_model.dart';
import '../widgets/vietqr_dialog.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.session,
    this.bankAccount,
    this.isAdmin = false,
    this.matchmakingService = const MatchmakingService(),
    this.vietQrService = const VietQrService(),
  });

  final SessionModel session;
  final VietQrBankAccount? bankAccount;
  final bool isAdmin;
  final MatchmakingService matchmakingService;
  final VietQrService vietQrService;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late SessionModel _session;
  late final TextEditingController _courtCostController;
  late final TextEditingController _shuttleCountController;
  final _detailStorage = SessionDetailStorage();
  final Set<String> _finishedMatchKeys = {};
  final Map<String, MatchScore> _matchScores = {};
  Future<void> _writeTail = Future<void>.value();
  VietQrBankAccount? _bankAccount;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _bankAccount = widget.bankAccount;
    unawaited(_restorePaymentSettings());
    _courtCostController = TextEditingController(
      text: '${_session.courtRentalTotalVnd}',
    );
    _shuttleCountController = TextEditingController(
      text: '${_session.shuttlesUsed}',
    );
    unawaited(_restoreLocalState());
  }

  Future<void> _restorePaymentSettings() async {
    try {
      final saved = await VietQrSettingsStore().load();
      if (mounted && saved != null) setState(() => _bankAccount = saved);
    } catch (_) {
      if (mounted) _showMessage('Không thể đọc cài đặt VietQR đã lưu.');
    }
  }

  @override
  void dispose() {
    _courtCostController.dispose();
    _shuttleCountController.dispose();
    super.dispose();
  }

  void _updateSession(SessionModel updated) {
    setState(() => _session = updated);
    unawaited(_persistLocalState());
  }

  Future<void> _restoreLocalState() async {
    try {
      final snapshot = await _detailStorage.load(_session.id);
      if (snapshot == null || snapshot['version'] != 1) return;
      final savedMembers = {
        for (final raw in _readList(snapshot, 'participants'))
          _readString(_readMap(raw, 'participant'), 'id'):
              _readMap(raw, 'participant'),
      };
      final participants = _session.participants.map((member) {
        final saved = savedMembers[member.id];
        if (saved == null) return member;
        return member.copyWith(
          eloRating: _readInt(saved, 'eloRating'),
          attendanceWeight: _readDouble(saved, 'attendanceWeight'),
          lateFeeVnd: _readInt(saved, 'lateFeeVnd'),
          paymentStatus: SessionPaymentStatus.values.byName(
            _readString(saved, 'paymentStatus'),
          ),
          hasReportedTransfer: _readBool(saved, 'hasReportedTransfer'),
        );
      }).toList(growable: false);
      final membersById = {for (final member in participants) member.id: member};
      final recentMatches = _readList(snapshot, 'recentMatches').map((raw) {
        final json = _readMap(raw, 'recent match');
        return RecentMatch(
          matchNumber: _readInt(json, 'matchNumber'),
          teamAPlayerIds: _readStringList(json, 'teamAPlayerIds'),
          teamBPlayerIds: _readStringList(json, 'teamBPlayerIds'),
          teamAWon: _readNullableBool(json, 'teamAWon'),
        );
      }).toList(growable: false);
      final scheduledMatches = _readList(snapshot, 'scheduledMatches').map((raw) {
        final json = _readMap(raw, 'scheduled match');
        final teamA = _readStringList(json, 'teamAIds')
            .map((id) => membersById[id]?.matchPlayer ?? _missingMember(id))
            .toList(growable: false);
        final teamB = _readStringList(json, 'teamBIds')
            .map((id) => membersById[id]?.matchPlayer ?? _missingMember(id))
            .toList(growable: false);
        return ScheduledSessionMatch(
          roundNumber: _readInt(json, 'roundNumber'),
          suggestion: MatchSuggestion(
            teamA: teamA,
            teamB: teamB,
            teamSkillDelta: _readInt(json, 'teamSkillDelta'),
            repeatedPairCount: _readInt(json, 'repeatedPairCount'),
            sessionId: _readNullableString(json, 'matchSessionId'),
            courtNumber: _readNullableInt(json, 'courtNumber'),
            isAdminOverride: _readBool(json, 'isAdminOverride'),
          ),
        );
      }).toList(growable: false);
      final scores = _readMap(snapshot['scores'], 'scores');
      final restoredScores = <String, MatchScore>{
        for (final entry in scores.entries)
          entry.key: MatchScore.fromJson(_readMap(entry.value, 'score')),
      };
      final finishedKeys = _readStringList(snapshot, 'finishedMatchKeys');
      if (!mounted) return;
      setState(() {
        _session = _session.copyWith(
          courtRentalTotalVnd: _readInt(snapshot, 'courtRentalTotalVnd'),
          shuttlesUsed: _readInt(snapshot, 'shuttlesUsed'),
          participants: participants,
          recentMatches: recentMatches,
          scheduledMatches: scheduledMatches,
        );
        _courtCostController.text = '${_session.courtRentalTotalVnd}';
        _shuttleCountController.text = '${_session.shuttlesUsed}';
        _matchScores
          ..clear()
          ..addAll(restoredScores);
        _finishedMatchKeys
          ..clear()
          ..addAll(finishedKeys);
      });
    } catch (error) {
      if (mounted) _showMessage('Không thể khôi phục dữ liệu phiên: $error');
    }
  }

  Future<void> _persistLocalState() {
    final snapshot = <String, Object?>{
      'version': 1,
      'participants': [
        for (final member in _session.participants)
          {
            'id': member.id,
            'eloRating': member.eloRating,
            'attendanceWeight': member.attendanceWeight,
            'lateFeeVnd': member.lateFeeVnd,
            'paymentStatus': member.paymentStatus.name,
            'hasReportedTransfer': member.hasReportedTransfer,
          },
      ],
      'recentMatches': [
        for (final match in _session.recentMatches)
          {
            'matchNumber': match.matchNumber,
            'teamAPlayerIds': match.teamAPlayerIds,
            'teamBPlayerIds': match.teamBPlayerIds,
            'teamAWon': match.teamAWon,
          },
      ],
      'scheduledMatches': [
        for (final match in _session.scheduledMatches)
          {
            'roundNumber': match.roundNumber,
            'teamAIds': match.suggestion.teamA.map((player) => player.id).toList(),
            'teamBIds': match.suggestion.teamB.map((player) => player.id).toList(),
            'teamSkillDelta': match.suggestion.teamSkillDelta,
            'repeatedPairCount': match.suggestion.repeatedPairCount,
            'matchSessionId': match.suggestion.sessionId,
            'courtNumber': match.suggestion.courtNumber,
            'isAdminOverride': match.suggestion.isAdminOverride,
          },
      ],
      'scores': {
        for (final entry in _matchScores.entries) entry.key: entry.value.toJson(),
      },
      'finishedMatchKeys': _finishedMatchKeys.toList(),
      'courtRentalTotalVnd': _session.courtRentalTotalVnd,
      'shuttlesUsed': _session.shuttlesUsed,
    };
    final operation = _writeTail.then(
      (_) => _detailStorage.save(_session.id, snapshot),
    );
    _writeTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace _) {
        if (mounted) _showMessage('Không thể tự lưu phiên: $error');
      },
    );
  }

  void _updateMember(String memberId, SessionMember Function(SessionMember) update) {
    final participants = _session.participants
        .map((member) => member.id == memberId ? update(member) : member)
        .toList(growable: false);
    _updateSession(_session.copyWith(participants: participants));
  }

  void _updateCourtCost(String value) {
    final amount = int.tryParse(value) ?? 0;
    _updateSession(_session.copyWith(courtRentalTotalVnd: amount));
  }

  void _updateShuttleCount(String value) {
    final count = int.tryParse(value) ?? 0;
    _updateSession(_session.copyWith(shuttlesUsed: count));
  }

  Future<void> _openCamera(ScheduledSessionMatch scheduledMatch) async {
    final suggestion = scheduledMatch.suggestion;
    final matchKey = _matchKey(scheduledMatch);
    final score = await Navigator.of(context).push<MatchScore>(
      MaterialPageRoute<MatchScore>(
        builder: (_) => CameraScoreboardScreen(
          initialScore: _matchScores[matchKey] ??
              MatchScore.initial(
                teamAPlayerNames: _playerNames(suggestion.teamA),
                teamBPlayerNames: _playerNames(suggestion.teamB),
              ),
          onScoreChanged: (updatedScore) {
            _matchScores[matchKey] = updatedScore;
            unawaited(_persistLocalState());
          },
        ),
      ),
    );
    if (!mounted || score == null) return;
    _matchScores[matchKey] = score;
    await _persistLocalState();
    if (score.isMatchComplete) {
      await _confirmMatchCompletion(scheduledMatch, score);
    }
  }

  String _matchKey(ScheduledSessionMatch match) =>
      '${match.roundNumber}-${match.suggestion.courtNumber ?? 0}';

  Future<void> _confirmMatchCompletion(
    ScheduledSessionMatch scheduledMatch,
    MatchScore score,
  ) async {
    if (!widget.isAdmin) return;
    if (_finishedMatchKeys.contains(_matchKey(scheduledMatch))) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận kết thúc trận?'),
        content: Text(
          'Đôi A ${score.teamASetsWon} - ${score.teamBSetsWon} Đôi B. '
          'Kết quả và Elo sẽ được lưu trên thiết bị.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Kiểm tra lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Chốt kết quả'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final signedMargin = score.sets.fold<int>(
      0,
      (total, set) => total + set.teamA - set.teamB,
    );
    await _applyMatchResult(
      scheduledMatch,
      _MatchResult(
        teamAWon: score.teamASetsWon > score.teamBSetsWon,
        pointMargin: signedMargin.abs(),
      ),
    );
  }

  void _generateMatches() {
    if (!widget.isAdmin) return;
    final available = _session.participants
        .map((member) => member.matchPlayer)
        .toList(growable: true);
    if (available.length < 4) {
      _showMessage('Cần ít nhất 4 thành viên để tự động chia cặp.');
      return;
    }

    final generated = <ScheduledSessionMatch>[];
    for (var court = 1; court <= _session.courtCount; court++) {
      final suggestion = widget.matchmakingService.suggestMatch(
        availablePlayers: available,
        recentMatches: _session.recentMatches,
        sessionId: _session.id,
        courtNumber: court,
      );
      if (suggestion == null) break;
      generated.add(
        ScheduledSessionMatch(roundNumber: 1, suggestion: suggestion),
      );
      final selectedIds = suggestion.players.map((player) => player.id).toSet();
      available.removeWhere((player) => selectedIds.contains(player.id));
    }

    if (generated.isEmpty) {
      _showMessage('Không thể tạo trận đấu từ danh sách thành viên hiện tại.');
      return;
    }
    _updateSession(_session.copyWith(scheduledMatches: generated));
  }

  List<String> _playerNames(List<MatchPlayer> players) {
    return players
        .map(
          (player) => _session.participants
              .firstWhere((member) => member.id == player.id)
              .displayName,
        )
        .toList(growable: false);
  }

  Future<void> _finishMatch(ScheduledSessionMatch scheduledMatch) async {
    if (!widget.isAdmin) return;
    final suggestion = scheduledMatch.suggestion;
    final matchKey =
        '${scheduledMatch.roundNumber}-${suggestion.courtNumber ?? 0}';
    if (_finishedMatchKeys.contains(matchKey)) {
      _showMessage('Trận đấu này đã được chốt Elo.');
      return;
    }

    final result = await showDialog<_MatchResult>(
      context: context,
      builder: (_) => const _MatchResultDialog(),
    );
    if (!mounted || result == null) return;

    await _applyMatchResult(scheduledMatch, result);
  }

  Future<void> _applyMatchResult(
    ScheduledSessionMatch scheduledMatch,
    _MatchResult result,
  ) async {
    final suggestion = scheduledMatch.suggestion;
    final matchKey = _matchKey(scheduledMatch);
    if (_finishedMatchKeys.contains(matchKey)) {
      _showMessage('Trận đấu này đã được chốt Elo.');
      return;
    }
    final teamA = suggestion.teamA
        .map(
          (player) => _session.participants
              .firstWhere((member) => member.id == player.id),
        )
        .toList(growable: false);
    final teamB = suggestion.teamB
        .map(
          (player) => _session.participants
              .firstWhere((member) => member.id == player.id),
        )
        .toList(growable: false);
    final updatedElos = calculateDoublesElo(
      teamAElos: teamA.map((member) => member.eloRating).toList(),
      teamBElos: teamB.map((member) => member.eloRating).toList(),
      teamAWon: result.teamAWon,
      pointMargin: result.pointMargin,
    );
    final changes = <({String name, int delta})>[
      for (var index = 0; index < 2; index++)
        (
          name: teamA[index].displayName,
          delta: updatedElos[index] - teamA[index].eloRating,
        ),
      for (var index = 0; index < 2; index++)
        (
          name: teamB[index].displayName,
          delta: updatedElos[index + 2] - teamB[index].eloRating,
        ),
    ];
    final updatedParticipants = _session.participants.map((member) {
      final teamAIndex = teamA.indexWhere((player) => player.id == member.id);
      if (teamAIndex >= 0) {
        return member.copyWith(eloRating: updatedElos[teamAIndex]);
      }
      final teamBIndex = teamB.indexWhere((player) => player.id == member.id);
      if (teamBIndex >= 0) {
        return member.copyWith(eloRating: updatedElos[teamBIndex + 2]);
      }
      return member;
    }).toList(growable: false);
    final nextMatchNumber = _session.recentMatches.fold<int>(
          0,
          (highest, match) =>
              match.matchNumber > highest ? match.matchNumber : highest,
        ) +
        1;
    final updatedHistory = [
      ..._session.recentMatches,
      RecentMatch(
        matchNumber: nextMatchNumber,
        teamAPlayerIds: suggestion.teamA.map((player) => player.id).toList(),
        teamBPlayerIds: suggestion.teamB.map((player) => player.id).toList(),
        teamAWon: result.teamAWon,
      ),
    ];

    setState(() {
      _finishedMatchKeys.add(matchKey);
      _session = _session.copyWith(
        participants: updatedParticipants,
        recentMatches: updatedHistory,
      );
    });
    await _persistLocalState();

    final highestIncrease =
        changes.map((change) => change.delta).reduce((a, b) => a > b ? a : b);
    final honorees = changes
        .where((change) => change.delta == highestIncrease)
        .map((change) => change.name)
        .join(' & ');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.emoji_events, color: Color(0xFFC6FF00), size: 40),
        title: const Text('Vinh danh trận đấu'),
        content: Text(
          '$honorees tăng nhiều Elo nhất: +$highestIncrease điểm.\n'
          '${result.teamAWon ? 'Đôi A' : 'Đôi B'} giành chiến thắng.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPaymentDialog(SessionMember member) async {
    try {
      final bill = _session.billFor(member);
      final bankAccount = _bankAccount;
      if (bankAccount == null) {
        _showMessage('Chưa cấu hình tài khoản nhận VietQR.');
        return;
      }
      final paymentCode = widget.vietQrService.createPaymentCode(
        bankAccount: bankAccount,
        amountVnd: bill.totalAmountVnd,
        sessionId: _session.id,
        memberId: member.id,
      );
      await showDialog<void>(
        context: context,
        builder: (context) => VietQrDialog(
          member: member,
          bill: bill,
          bankAccount: bankAccount,
          paymentCode: paymentCode,
          onPaymentReported: () {
            _updateMember(
              member.id,
              (current) => current.copyWith(
                hasReportedTransfer: true,
                paymentStatus: SessionPaymentStatus.pending,
              ),
            );
          },
        ),
      );
    } on ArgumentError catch (error) {
      _showMessage('Không thể tạo hóa đơn/VietQR: ${error.message}');
    }
  }

  void _approvePayment(SessionMember member) {
    if (!widget.isAdmin || !member.hasReportedTransfer) return;
    _updateMember(
      member.id,
      (current) => current.copyWith(
        paymentStatus: SessionPaymentStatus.approved,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_session.title),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.sports_tennis), text: 'Sắp cặp & Thi đấu'),
              Tab(icon: Icon(Icons.account_balance_wallet), text: 'Thu tiền & Quỹ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMatchesTab(),
            _buildBillingTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SessionSummary(session: _session),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: widget.isAdmin ? _generateMatches : null,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Tự động chia cặp'),
        ),
        if (!widget.isAdmin)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Chỉ Admin mới có thể tạo hoặc thay đổi cặp đấu.'),
          ),
        const SizedBox(height: 12),
        if (_session.scheduledMatches.isEmpty)
          const _EmptyState(
            icon: Icons.groups_2_outlined,
            message: 'Chưa có trận đấu. Hãy tạo cặp đấu tự động.',
          )
        else
          for (final match in _session.scheduledMatches)
            _MatchCard(
              scheduledMatch: match,
              teamAPlayerNames: _playerNames(match.suggestion.teamA),
              teamBPlayerNames: _playerNames(match.suggestion.teamB),
              isAdmin: widget.isAdmin,
              isCompleted: _finishedMatchKeys.contains(
                '${match.roundNumber}-${match.suggestion.courtNumber ?? 0}',
              ),
              onOpenCamera: () => _openCamera(match),
              onFinishMatch: () => _finishMatch(match),
            ),
      ],
    );
  }

  Widget _buildBillingTab() {
    final members = _session.participants;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SessionSummary(session: _session),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final courtCost = _CostInput(
              label: 'Tổng tiền sân (₫)',
              controller: _courtCostController,
              enabled: widget.isAdmin,
              onChanged: _updateCourtCost,
            );
            final shuttleCount = _CostInput(
              label: 'Số quả cầu đã đánh',
              controller: _shuttleCountController,
              enabled: widget.isAdmin,
              onChanged: _updateShuttleCount,
            );
            if (constraints.maxWidth < 390) {
              return Column(
                children: [
                  courtCost,
                  const SizedBox(height: 10),
                  shuttleCount,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: courtCost),
                const SizedBox(width: 12),
                Expanded(child: shuttleCount),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Đơn giá cầu: ${formatVnd(_session.shuttleUnitPriceVnd)} / quả · '
          'Tổng cầu: ${formatVnd(_session.shuttlesUsed * _session.shuttleUnitPriceVnd)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_bankAccount == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'VietQR chưa bật: hãy cấu hình tài khoản nhận tiền.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 14),
        Text(
          'Thành viên tham gia (${members.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (members.isEmpty)
          const _EmptyState(
            icon: Icons.person_off_outlined,
            message: 'Chưa có thành viên tham gia buổi đánh.',
          )
        else
          for (final member in members)
            _MemberBillingCard(
              key: ValueKey(member.id),
              member: member,
              bill: _session.billFor(member),
              isAdmin: widget.isAdmin,
              canShowQr: _bankAccount != null,
              onLateChanged: (isLate) => _updateMember(
                member.id,
                (current) =>
                    current.copyWith(attendanceWeight: isLate ? 0.5 : 1.0),
              ),
              onLateFeeChanged: (amount) => _updateMember(
                member.id,
                (current) => current.copyWith(lateFeeVnd: amount),
              ),
              onShowQr: () => _openPaymentDialog(member),
              onApprove: () => _approvePayment(member),
            ),
      ],
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.session});

  final SessionModel session;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd/MM/yyyy · HH:mm', 'vi_VN')
        .format(session.startsAt.toLocal());

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.event_available)),
        title: Text(session.title),
        subtitle: Text('$dateLabel · ${session.courtCount} sân'),
      ),
    );
  }
}

class _CostInput extends StatelessWidget {
  const _CostInput({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _MemberBillingCard extends StatelessWidget {
  const _MemberBillingCard({
    super.key,
    required this.member,
    required this.bill,
    required this.isAdmin,
    required this.canShowQr,
    required this.onLateChanged,
    required this.onLateFeeChanged,
    required this.onShowQr,
    required this.onApprove,
  });

  final SessionMember member;
  final SessionBill bill;
  final bool isAdmin;
  final bool canShowQr;
  final ValueChanged<bool> onLateChanged;
  final ValueChanged<int> onLateFeeChanged;
  final VoidCallback onShowQr;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final member = this.member;
    final bill = this.bill;
    final isAdmin = this.isAdmin;
    final statusLabel = switch (member.paymentStatus) {
      SessionPaymentStatus.approved => 'Đã nộp',
      SessionPaymentStatus.rejected => 'Bị từ chối',
      SessionPaymentStatus.pending =>
        member.hasReportedTransfer ? 'Chờ Admin duyệt' : 'Chưa nộp',
    };
    final statusColor = member.paymentStatus == SessionPaymentStatus.approved
        ? Colors.green
        : member.paymentStatus == SessionPaymentStatus.rejected
            ? Theme.of(context).colorScheme.error
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    member.displayName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (member.paymentStatus == SessionPaymentStatus.approved)
                  const Padding(
                    padding: EdgeInsets.only(left: 5),
                    child: Icon(Icons.verified, color: Colors.green, size: 18),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Đến trễ · tính 0.5 tiền sân'),
              value: member.arrivedLate,
              onChanged: isAdmin ? onLateChanged : null,
            ),
            if (isAdmin)
              TextFormField(
                key: ValueKey(member.id),
                initialValue: '${member.lateFeeVnd}',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Phạt trễ (₫)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) =>
                    onLateFeeChanged(int.tryParse(value) ?? 0),
              ),
            const SizedBox(height: 8),
            Text(
              'Sân ${formatVnd(bill.courtShareVnd)}  ·  '
              'Cầu ${formatVnd(bill.shuttleShareVnd)}  ·  '
              'Phạt ${formatVnd(bill.lateFeeVnd)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cần đóng ${formatVnd(bill.totalAmountVnd)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Hiện mã VietQR',
                  onPressed: !canShowQr ||
                          member.paymentStatus ==
                              SessionPaymentStatus.approved ||
                          bill.totalAmountVnd <= 0
                      ? null
                      : onShowQr,
                  icon: const Icon(Icons.qr_code_2),
                ),
                if (isAdmin)
                  IconButton(
                    tooltip: 'Admin duyệt đã nộp',
                    onPressed: member.hasReportedTransfer &&
                            member.paymentStatus != SessionPaymentStatus.approved
                        ? onApprove
                        : null,
                    icon: Icon(
                      Icons.check_circle,
                      color: member.paymentStatus == SessionPaymentStatus.approved
                          ? Colors.green
                          : null,
                    ),
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
    required this.scheduledMatch,
    required this.teamAPlayerNames,
    required this.teamBPlayerNames,
    required this.isAdmin,
    required this.isCompleted,
    required this.onOpenCamera,
    required this.onFinishMatch,
  });

  final ScheduledSessionMatch scheduledMatch;
  final List<String> teamAPlayerNames;
  final List<String> teamBPlayerNames;
  final bool isAdmin;
  final bool isCompleted;
  final VoidCallback onOpenCamera;
  final VoidCallback onFinishMatch;

  @override
  Widget build(BuildContext context) {
    final suggestion = scheduledMatch.suggestion;
    final teamA = teamAPlayerNames.join(' & ');
    final teamB = teamBPlayerNames.join(' & ');

    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_tennis, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Sân ${suggestion.courtNumber ?? '-'} · Vòng ${scheduledMatch.roundNumber}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  'Lệch kỹ năng ${suggestion.teamSkillDelta}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const Divider(height: 20),
            _TeamLine(label: 'ĐÔI A', names: teamA),
            const SizedBox(height: 8),
            _TeamLine(label: 'ĐÔI B', names: teamB),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenCamera,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Bật Camera Bảng điểm'),
                ),
                if (isAdmin)
                  FilledButton.tonalIcon(
                    onPressed: isCompleted ? null : onFinishMatch,
                    icon: Icon(isCompleted ? Icons.verified : Icons.flag),
                    label: Text(
                      isCompleted ? 'Đã chốt Elo' : 'Kết thúc trận đấu',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchResult {
  const _MatchResult({
    required this.teamAWon,
    required this.pointMargin,
  });

  final bool teamAWon;
  final int pointMargin;
}

class _MatchResultDialog extends StatefulWidget {
  const _MatchResultDialog();

  @override
  State<_MatchResultDialog> createState() => _MatchResultDialogState();
}

class _MatchResultDialogState extends State<_MatchResultDialog> {
  late final List<TextEditingController> _teamAControllers =
      List.generate(3, (_) => TextEditingController());
  late final List<TextEditingController> _teamBControllers =
      List.generate(3, (_) => TextEditingController());
  String? _error;

  @override
  void dispose() {
    for (final controller in [..._teamAControllers, ..._teamBControllers]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    var teamASets = 0;
    var teamBSets = 0;
    var teamAPointDifference = 0;
    var matchEnded = false;

    for (var index = 0; index < 3; index++) {
      final teamAText = _teamAControllers[index].text.trim();
      final teamBText = _teamBControllers[index].text.trim();
      if (teamAText.isEmpty && teamBText.isEmpty) {
        if (index < 2 && !matchEnded) {
          setState(() => _error = 'Nhập tỉ số của ít nhất hai hiệp.');
          return;
        }
        continue;
      }
      if (teamAText.isEmpty || teamBText.isEmpty || matchEnded) {
        setState(() => _error = 'Kiểm tra tỉ số các hiệp đã nhập.');
        return;
      }

      final teamAScore = int.tryParse(teamAText);
      final teamBScore = int.tryParse(teamBText);
      if (teamAScore == null ||
          teamBScore == null ||
          teamAScore > 30 ||
          teamBScore > 30 ||
          (teamAScore == 30 && teamBScore == 30)) {
        setState(() => _error = 'Điểm mỗi hiệp phải nằm trong khoảng 0–30.');
        return;
      }

      final setWinner =
          MatchSetScore(teamA: teamAScore, teamB: teamBScore).winner;
      if (setWinner == null) {
        setState(() => _error = 'Tỉ số hiệp chưa có đội thắng theo luật 21/30.');
        return;
      }
      if (setWinner == ServingTeam.teamA) {
        teamASets++;
      } else {
        teamBSets++;
      }
      teamAPointDifference += teamAScore - teamBScore;
      matchEnded = teamASets == 2 || teamBSets == 2;
    }

    if (!matchEnded) {
      setState(() => _error = 'Nhập đủ hiệp để xác định đội thắng trận.');
      return;
    }
    final teamAWon = teamASets == 2;
    final pointMargin =
        (teamAWon ? teamAPointDifference : -teamAPointDifference)
            .clamp(0, 30)
            .toInt();
    Navigator.of(context).pop(
      _MatchResult(
        teamAWon: teamAWon,
        pointMargin: pointMargin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chốt kết quả trận đấu'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nhập điểm từng hiệp để xác định đội thắng và cập nhật Elo.',
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < 3; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 48, child: Text('Hiệp ${index + 1}')),
                    Expanded(
                      child: _SetPointField(
                        controller: _teamAControllers[index],
                        label: 'Đôi A',
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(':'),
                    ),
                    Expanded(
                      child: _SetPointField(
                        controller: _teamBControllers[index],
                        label: 'Đôi B',
                      ),
                    ),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Kết thúc & tính Elo'),
        ),
      ],
    );
  }
}

class _SetPointField extends StatelessWidget {
  const _SetPointField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({required this.label, required this.names});

  final String label;
  final String names;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Expanded(child: Text(names)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

Map<String, Object?> _readMap(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('Saved $field must be an object.');
  }
  return value.cast<String, Object?>();
}

List<Object?> _readList(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! List) throw FormatException('Saved $field must be a list.');
  return value.cast<Object?>();
}

List<String> _readStringList(Map<String, Object?> json, String field) {
  final values = _readList(json, field);
  if (values.any((value) => value is! String)) {
    throw FormatException('Saved $field must contain text values.');
  }
  return values.cast<String>();
}

String _readString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String) throw FormatException('Saved $field must be text.');
  return value;
}

String? _readNullableString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is! String) throw FormatException('Saved $field must be text.');
  return value;
}

int _readInt(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! int) throw FormatException('Saved $field must be an integer.');
  return value;
}

int? _readNullableInt(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is! int) {
    throw FormatException('Saved $field must be an integer.');
  }
  return value;
}

double _readDouble(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! num) throw FormatException('Saved $field must be numeric.');
  return value.toDouble();
}

bool _readBool(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! bool) throw FormatException('Saved $field must be boolean.');
  return value;
}

bool? _readNullableBool(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is! bool) throw FormatException('Saved $field must be boolean.');
  return value;
}

MatchPlayer _missingMember(String id) {
  throw FormatException('Saved match refers to unknown member "$id".');
}

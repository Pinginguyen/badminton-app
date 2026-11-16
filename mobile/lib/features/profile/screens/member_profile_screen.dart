import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/member_profile.dart';

class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({
    super.key,
    required this.member,
    required this.members,
    required this.matches,
  });

  final MemberProfile member;
  final List<MemberProfile> members;
  final List<PlayedMatch> matches;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  String? _selectedOpponentId;

  @override
  void initState() {
    super.initState();
    final opponents = widget.members
        .where((member) => member.id != widget.member.id)
        .toList()
      ..sort(
        (first, second) => _headToHeadMatches(second.id)
            .length
            .compareTo(_headToHeadMatches(first.id).length),
      );
    _selectedOpponentId = opponents.isEmpty ? null : opponents.first.id;
  }

  List<PlayedMatch> _headToHeadMatches(String opponentId) {
    return widget.matches
        .where((match) => match.areOpponents(widget.member.id, opponentId))
        .toList(growable: false);
  }

  MemberProfile? _findMember(String? memberId) {
    for (final member in widget.members) {
      if (member.id == memberId) return member;
    }
    return null;
  }

  int _rankOf(MemberProfile member) {
    final rankedMembers = [...widget.members]
      ..sort((first, second) => second.eloRating.compareTo(first.eloRating));
    final index =
        rankedMembers.indexWhere((candidate) => candidate.id == member.id);
    return index < 0 ? rankedMembers.length + 1 : index + 1;
  }

  MemberProfile? _nemesisFor(MemberProfile member) {
    MemberProfile? nemesis;
    var bestWinDifference = 0;
    for (final opponent in widget.members) {
      if (opponent.id == member.id) continue;
      final matches = widget.matches
          .where((match) => match.areOpponents(member.id, opponent.id));
      var wins = 0;
      var losses = 0;
      for (final match in matches) {
        if (match.didPlayerWin(member.id)) {
          wins++;
        } else {
          losses++;
        }
      }
      final winDifference = wins - losses;
      if (wins > 0 && winDifference > bestWinDifference) {
        bestWinDifference = winDifference;
        nemesis = opponent;
      }
    }
    return nemesis;
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final memberMatches = widget.matches
        .where(
          (match) =>
              match.teamAPlayerIds.contains(member.id) ||
              match.teamBPlayerIds.contains(member.id),
        )
        .toList(growable: false);
    final wins =
        memberMatches.where((match) => match.didPlayerWin(member.id)).length;
    final winRate =
        memberMatches.isEmpty ? 0 : (wins * 100 / memberMatches.length).round();
    final opponent = _findMember(_selectedOpponentId);
    final rivalryMatches = opponent == null
        ? const <PlayedMatch>[]
        : _headToHeadMatches(opponent.id);
    final rivalryWins =
        rivalryMatches.where((match) => match.didPlayerWin(member.id)).length;
    final rivalryLosses = rivalryMatches.length - rivalryWins;
    final rivalryWinRate = rivalryMatches.isEmpty
        ? 0
        : (rivalryWins * 100 / rivalryMatches.length).round();
    final nemesis = _nemesisFor(member);
    final titles = [
      ...member.funTitles,
      if (nemesis != null) 'Khắc tinh của ${nemesis.displayName}',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ vận động viên'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          _ProfileHero(
            member: member,
            rank: _rankOf(member),
            wins: wins,
            winRate: winRate,
            playedMatches: memberMatches.length,
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            title: 'Duyên nợ cá nhân',
            subtitle: 'Đối chiếu thành tích khi đứng hai bên lưới',
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedOpponentId,
                    decoration: const InputDecoration(
                      labelText: 'Chọn đối thủ',
                      prefixIcon: Icon(Icons.person_search),
                    ),
                    items: widget.members
                        .where((candidate) => candidate.id != member.id)
                        .map(
                          (candidate) => DropdownMenuItem(
                            value: candidate.id,
                            child: Text(
                              '${candidate.displayName} · ELO ${candidate.eloRating}',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) =>
                        setState(() => _selectedOpponentId = value),
                  ),
                  const SizedBox(height: 18),
                  if (opponent == null)
                    const Text('Chưa có thành viên khác để so sánh.')
                  else ...[
                    Text(
                      '${member.displayName}  VS  ${opponent.displayName}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _RivalryScore(
                            label: 'BẠN THẮNG',
                            value: rivalryWins,
                            color: AppTheme.neonGreen,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('—'),
                        ),
                        Expanded(
                          child: _RivalryScore(
                            label: 'BẠN THUA',
                            value: rivalryLosses,
                            color: const Color(0xFFFF8B5E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(child: Text('Tỷ lệ áp đảo')),
                        Text(
                          rivalryMatches.isEmpty
                              ? 'Chưa có kèo'
                              : '$rivalryWinRate%',
                          style: const TextStyle(
                            color: AppTheme.limeYellow,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: rivalryWinRate / 100,
                        minHeight: 8,
                        color: AppTheme.neonGreen,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${rivalryMatches.length} trận đối đầu trực tiếp',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            title: 'Danh hiệu nội bộ',
            subtitle: 'Thống kê vui từ những trận đã lưu',
          ),
          const SizedBox(height: 10),
          if (titles.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Danh hiệu đang chờ bạn tạo thêm chuyện để kể trên sân.',
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final title in titles)
                  _TitleBadge(
                    label: title,
                    icon: title.startsWith('Khắc tinh')
                        ? Icons.local_fire_department
                        : title == 'Vua gánh tạ'
                            ? Icons.fitness_center
                            : Icons.celebration,
                  ),
              ],
            ),
          const SizedBox(height: 22),
          _SectionTitle(
            title: 'Lịch sử đối đầu',
            subtitle: opponent == null
                ? 'Chọn một đối thủ để xem kết quả'
                : '${member.displayName} và ${opponent.displayName} đứng ở hai phía đối diện',
          ),
          const SizedBox(height: 10),
          if (opponent == null || rivalryMatches.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Hai bạn chưa có trận đối đầu nào được ghi nhận.'),
              ),
            )
          else
            for (final match in rivalryMatches.reversed.take(8))
              _HistoryTile(
                match: match,
                member: member,
                opponent: opponent,
              ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.member,
    required this.rank,
    required this.wins,
    required this.winRate,
    required this.playedMatches,
  });

  final MemberProfile member;
  final int rank;
  final int wins;
  final int winRate;
  final int playedMatches;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2A31), Color(0xFF121A22)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.neonGreen.withOpacity(0.32)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _MemberAvatar(member: member, radius: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '“${member.nickname}”',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      member.isAdmin
                          ? 'ADMIN · CẤP ĐỘ ${member.skillLevel}'
                          : 'MEMBER · CẤP ĐỘ ${member.skillLevel}',
                      style: const TextStyle(
                        color: AppTheme.limeYellow,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _ProfileMetric(
                value: '#$rank',
                label: 'RANK',
                icon: Icons.emoji_events,
              ),
              _ProfileMetric(
                value: '${member.eloRating}',
                label: 'ELO',
                icon: Icons.bolt,
              ),
              _ProfileMetric(
                value: '$winRate%',
                label: 'TỶ LỆ THẮNG',
                icon: Icons.trending_up,
              ),
              _ProfileMetric(
                value: '$playedMatches',
                label: 'TRẬN ĐẤU',
                icon: Icons.sports_tennis,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$wins trận thắng trong $playedMatches trận',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member, required this.radius});

  final MemberProfile member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = member.displayName.trim().isEmpty
        ? '?'
        : member.displayName.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.neonGreen,
      foregroundImage:
          member.avatarUrl == null ? null : NetworkImage(member.avatarUrl!),
      child: member.avatarUrl == null
          ? Text(
              initials,
              style: TextStyle(
                color: AppTheme.courtNavy,
                fontSize: radius * 0.7,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 15, color: AppTheme.limeYellow),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white60,
              ),
        ),
      ],
    );
  }
}

class _RivalryScore extends StatelessWidget {
  const _RivalryScore({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _TitleBadge extends StatelessWidget {
  const _TitleBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: AppTheme.courtNavy),
      label: Text(label),
      backgroundColor: AppTheme.limeYellow,
      labelStyle: const TextStyle(
        color: AppTheme.courtNavy,
        fontWeight: FontWeight.w800,
      ),
      side: BorderSide.none,
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.match,
    required this.member,
    required this.opponent,
  });

  final PlayedMatch match;
  final MemberProfile member;
  final MemberProfile opponent;

  @override
  Widget build(BuildContext context) {
    final didWin = match.didPlayerWin(member.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: didWin
              ? AppTheme.neonGreen.withOpacity(0.16)
              : const Color(0xFFFF8B5E).withOpacity(0.16),
          child: Icon(
            didWin ? Icons.emoji_events : Icons.sports_tennis,
            color: didWin ? AppTheme.neonGreen : const Color(0xFFFF8B5E),
          ),
        ),
        title: Text(
          didWin ? 'Thắng · ${match.scoreLabel}' : 'Thua · ${match.scoreLabel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy', 'vi_VN').format(match.playedAt)}'
          ' · Đối đầu trực tiếp với ${opponent.displayName}',
        ),
        trailing: Text(
          didWin ? 'W' : 'L',
          style: TextStyle(
            color: didWin ? AppTheme.neonGreen : const Color(0xFFFF8B5E),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

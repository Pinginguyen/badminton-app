import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/ui/animated_score_digit.dart';
import '../models/match_score.dart';

/// Broadcast-style, translucent scoreboard designed to sit over camera video.
class ScoreboardOverlay extends StatelessWidget {
  const ScoreboardOverlay({super.key, required this.score});

  final MatchScore score;

  @override
  Widget build(BuildContext context) {
    final activeSet = score.activeSetIndex;
    final displayedSet = activeSet ??
        score.sets.lastIndexWhere((set) => set.winner != null);
    final current = score.sets[displayedSet];

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE6101724),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MatchHeader(
                  servingTeam: score.servingTeam,
                  activeSetIndex: activeSet,
                  isComplete: score.isMatchComplete,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _TeamNames(
                        names: score.teamAPlayerNames,
                        teamLabel: 'DOUBLES A',
                        isServing: score.servingTeam == ServingTeam.teamA,
                        accent: const Color(0xFF42D6C5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LivePoints(
                      points: current.teamA,
                      color: const Color(0xFF42D6C5),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 9),
                      child: Text(
                        ':',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    _LivePoints(
                      points: current.teamB,
                      color: const Color(0xFFFFC857),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TeamNames(
                        names: score.teamBPlayerNames,
                        teamLabel: 'DOUBLES B',
                        isServing: score.servingTeam == ServingTeam.teamB,
                        accent: const Color(0xFFFFC857),
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SetScores(score: score),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchHeader extends StatelessWidget {
  const _MatchHeader({
    required this.servingTeam,
    required this.activeSetIndex,
    required this.isComplete,
  });

  final ServingTeam servingTeam;
  final int? activeSetIndex;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final servingColor = servingTeam == ServingTeam.teamA
        ? const Color(0xFF42D6C5)
        : const Color(0xFFFFC857);

    return Row(
      children: [
        const Icon(Icons.sports_tennis, color: Color(0xFF42D6C5), size: 18),
        const SizedBox(width: 8),
        const Text(
          'COURT SCORE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const Spacer(),
        if (isComplete)
          const _StatusTag(label: 'FINAL', color: Color(0xFF42D6C5))
        else ...[
          _StatusTag(
            label: 'SET ${(activeSetIndex ?? 0) + 1}',
            color: Colors.white70,
          ),
          const SizedBox(width: 8),
          _StatusTag(
            label: 'SERVE ${servingTeam == ServingTeam.teamA ? 'A' : 'B'}',
            color: servingColor,
          ),
        ],
      ],
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TeamNames extends StatelessWidget {
  const _TeamNames({
    required this.names,
    required this.teamLabel,
    required this.isServing,
    required this.accent,
    this.alignEnd = false,
  });

  final List<String> names;
  final String teamLabel;
  final bool isServing;
  final Color accent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final alignment = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (isServing && !alignEnd) _ServeIndicator(color: accent),
            Text(
              teamLabel,
              style: TextStyle(
                color: accent,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            if (isServing && alignEnd) ...[
              const SizedBox(width: 5),
              _ServeIndicator(color: accent),
            ],
          ],
        ),
        const SizedBox(height: 6),
        for (final name in names)
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _ServeIndicator extends StatelessWidget {
  const _ServeIndicator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _LivePoints extends StatelessWidget {
  const _LivePoints({required this.points, required this.color});

  final int points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedScoreDigit(
      value: points,
      color: color,
      fontSize: 36,
      width: 38,
    );
  }
}

class _SetScores extends StatelessWidget {
  const _SetScores({required this.score});

  final MatchScore score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'SETS',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 10),
        for (var index = 0; index < score.sets.length; index++) ...[
          if (index > 0) const SizedBox(width: 7),
          _SetCell(
            setNumber: index + 1,
            setScore: score.sets[index],
            isCurrent: score.activeSetIndex == index,
          ),
        ],
        const Spacer(),
        Text(
          '${score.teamASetsWon} - ${score.teamBSetsWon}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _SetCell extends StatelessWidget {
  const _SetCell({
    required this.setNumber,
    required this.setScore,
    required this.isCurrent,
  });

  final int setNumber;
  final MatchSetScore setScore;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final foreground = isCurrent ? Colors.white : Colors.white60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.white.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$setNumber  ${setScore.teamA}-${setScore.teamB}',
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

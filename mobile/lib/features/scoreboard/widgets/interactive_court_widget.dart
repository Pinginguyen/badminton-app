import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/match_score.dart';

class InteractiveCourtWidget extends StatelessWidget {
  const InteractiveCourtWidget({super.key, required this.score});

  final MatchScore score;

  @override
  Widget build(BuildContext context) {
    final setIndex = score.activeSetIndex ??
        score.sets.lastIndexWhere((set) => set.winner != null);
    final set = score.sets[setIndex < 0 ? 0 : setIndex];
    final isTeamAServing = score.servingTeam == ServingTeam.teamA;
    final servingPoints = isTeamAServing ? set.teamA : set.teamB;
    final serverIsRight = servingPoints.isEven;
    final serverIndex = isTeamAServing
      ? (serverIsRight ? 1 : 0)
      : (serverIsRight ? 0 : 1);
    final receiverIndex = 1 - serverIndex;

    return AspectRatio(
      aspectRatio: 2.05,
      child: Semantics(
        label: 'Sơ đồ sân đôi, chấm xanh là người giao cầu, chấm cam là người đỡ',
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _BadmintonCourtPainter()),
            Positioned(
              left: 2,
              top: 2,
              child: Text(
                'ĐÔI A',
                style: TextStyle(
                  color: AppTheme.neonGreen.withOpacity(0.9),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: Text(
                'ĐÔI B',
                style: TextStyle(
                  color: AppTheme.sportOrange.withOpacity(0.9),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              width: 98,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < 2; index++) ...[
                    if (index > 0) const SizedBox(height: 8),
                    _CourtPlayer(
                      name: score.teamAPlayerNames[index],
                      isServer: isTeamAServing && index == serverIndex,
                      isReceiver: !isTeamAServing && index == receiverIndex,
                      alignment: CrossAxisAlignment.center,
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              width: 98,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < 2; index++) ...[
                    if (index > 0) const SizedBox(height: 8),
                    _CourtPlayer(
                      name: score.teamBPlayerNames[index],
                      isServer: !isTeamAServing && index == serverIndex,
                      isReceiver: isTeamAServing && index == receiverIndex,
                      alignment: CrossAxisAlignment.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourtPlayer extends StatelessWidget {
  const _CourtPlayer({
    required this.name,
    required this.isServer,
    required this.isReceiver,
    required this.alignment,
  });

  final String name;
  final bool isServer;
  final bool isReceiver;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final color = isServer
        ? AppTheme.neonGreen
        : isReceiver
            ? AppTheme.sportOrange
            : Colors.white70;
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isServer || isReceiver)
          Icon(
            isServer ? Icons.sports_tennis : Icons.south,
            color: color,
            size: 15,
          ),
        Container(
          constraints: const BoxConstraints(maxWidth: 112),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(isServer || isReceiver ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withOpacity(0.65)),
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _BadmintonCourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final court = Rect.fromLTWH(10, 5, size.width - 20, size.height - 10);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final singlesInset = court.height * 0.09;

    canvas.drawRect(court, paint);
    canvas.drawLine(
      Offset(court.left, court.top + singlesInset),
      Offset(court.right, court.top + singlesInset),
      paint,
    );
    canvas.drawLine(
      Offset(court.left, court.bottom - singlesInset),
      Offset(court.right, court.bottom - singlesInset),
      paint,
    );
    canvas.drawLine(
      Offset(court.left + court.width * 0.22, court.top),
      Offset(court.left + court.width * 0.22, court.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(court.left + court.width * 0.36, court.top + singlesInset),
      Offset(court.left + court.width * 0.36, court.bottom - singlesInset),
      paint,
    );
    canvas.drawLine(
      Offset(court.center.dx, court.top),
      Offset(court.center.dx, court.bottom),
      Paint()
        ..color = AppTheme.sportOrange
        ..strokeWidth = 2.2,
    );
    canvas.drawLine(
      Offset(court.left + court.width * 0.64, court.top + singlesInset),
      Offset(court.left + court.width * 0.64, court.bottom - singlesInset),
      paint,
    );
    canvas.drawLine(
      Offset(court.left + court.width * 0.78, court.top),
      Offset(court.left + court.width * 0.78, court.bottom),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BadmintonCourtPainter oldDelegate) => false;
}
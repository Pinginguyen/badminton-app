import 'package:intl/intl.dart';

import '../../../services/matchmaking_service.dart';

enum SessionPaymentStatus { pending, approved, rejected }

class SessionMember {
  const SessionMember({
    required this.id,
    required this.displayName,
    required this.skillLevel,
    required this.eloRating,
    this.lastPlayedAt,
    this.attendanceWeight = 1.0,
    this.lateFeeVnd = 0,
    this.paymentStatus = SessionPaymentStatus.pending,
    this.hasReportedTransfer = false,
  })  : assert(id != ''),
        assert(displayName != ''),
        assert(skillLevel >= 1 && skillLevel <= 4),
        assert(eloRating >= 0),
        assert(attendanceWeight == 0.5 || attendanceWeight == 1.0),
        assert(lateFeeVnd >= 0);

  final String id;
  final String displayName;
  final int skillLevel;
  final int eloRating;
  final DateTime? lastPlayedAt;
  final double attendanceWeight;
  final int lateFeeVnd;
  final SessionPaymentStatus paymentStatus;
  final bool hasReportedTransfer;

  bool get arrivedLate => attendanceWeight == 0.5;

  MatchPlayer get matchPlayer => MatchPlayer(
        id: id,
        skillLevel: skillLevel,
        eloRating: eloRating,
        lastPlayedAt: lastPlayedAt,
      );

  SessionMember copyWith({
    double? attendanceWeight,
    int? eloRating,
    int? lateFeeVnd,
    SessionPaymentStatus? paymentStatus,
    bool? hasReportedTransfer,
  }) {
    return SessionMember(
      id: id,
      displayName: displayName,
      skillLevel: skillLevel,
      eloRating: eloRating ?? this.eloRating,
      lastPlayedAt: lastPlayedAt,
      attendanceWeight: attendanceWeight ?? this.attendanceWeight,
      lateFeeVnd: lateFeeVnd ?? this.lateFeeVnd,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      hasReportedTransfer: hasReportedTransfer ?? this.hasReportedTransfer,
    );
  }
}

class ScheduledSessionMatch {
  const ScheduledSessionMatch({
    required this.roundNumber,
    required this.suggestion,
  }) : assert(roundNumber > 0);

  final int roundNumber;
  final MatchSuggestion suggestion;
}

class SessionBill {
  const SessionBill({
    required this.memberId,
    required this.courtShareVnd,
    required this.shuttleShareVnd,
    required this.lateFeeVnd,
    required this.totalAmountVnd,
  });

  final String memberId;
  final int courtShareVnd;
  final int shuttleShareVnd;
  final int lateFeeVnd;
  final int totalAmountVnd;
}

class SessionModel {
  SessionModel({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.courtCount,
    required this.courtRentalTotalVnd,
    required this.shuttleUnitPriceVnd,
    required this.shuttlesUsed,
    required List<SessionMember> participants,
    List<RecentMatch> recentMatches = const [],
    List<ScheduledSessionMatch> scheduledMatches = const [],
  })  : participants = List.unmodifiable(participants),
        recentMatches = List.unmodifiable(recentMatches),
        scheduledMatches = List.unmodifiable(scheduledMatches) {
    if (id.trim().isEmpty || title.trim().isEmpty) {
      throw ArgumentError('Session id and title are required.');
    }
    if (!endsAt.isAfter(startsAt)) {
      throw ArgumentError('Session end time must be after its start time.');
    }
    if (courtCount < 1 || courtCount > 3) {
      throw ArgumentError.value(courtCount, 'courtCount', 'Must be from 1 to 3.');
    }
    if (courtRentalTotalVnd < 0 ||
        shuttleUnitPriceVnd < 0 ||
        shuttlesUsed < 0) {
      throw ArgumentError('Session costs and shuttle count cannot be negative.');
    }
    if (this.participants.map((member) => member.id).toSet().length !=
        this.participants.length) {
      throw ArgumentError('Participant IDs must be unique.');
    }
    if (this.participants.any(
      (member) =>
          member.displayName.trim().isEmpty ||
          member.skillLevel < 1 ||
          member.skillLevel > 4 ||
          member.eloRating < 0 ||
          (member.attendanceWeight != 0.5 && member.attendanceWeight != 1.0) ||
          member.lateFeeVnd < 0,
    )) {
      throw ArgumentError('Participant details or billing values are invalid.');
    }
  }

  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final int courtCount;
  final int courtRentalTotalVnd;
  final int shuttleUnitPriceVnd;
  final int shuttlesUsed;
  final List<SessionMember> participants;
  final List<RecentMatch> recentMatches;
  final List<ScheduledSessionMatch> scheduledMatches;

  SessionBill billFor(SessionMember member) {
    final memberIndex =
        participants.indexWhere((participant) => participant.id == member.id);
    if (memberIndex < 0) {
      throw ArgumentError.value(member.id, 'member', 'Member is not in this session.');
    }
    final courtShareVnd = _courtShareFor(memberIndex);
    final shuttleShareVnd = _shuttleShareFor(memberIndex);

    return SessionBill(
      memberId: member.id,
      courtShareVnd: courtShareVnd,
      shuttleShareVnd: shuttleShareVnd,
      lateFeeVnd: member.lateFeeVnd,
      totalAmountVnd: courtShareVnd + shuttleShareVnd + member.lateFeeVnd,
    );
  }

  int _courtShareFor(int memberIndex) {
    final weightUnits = participants
        .map((participant) => participant.attendanceWeight == 0.5 ? 1 : 2)
        .toList(growable: false);
    final totalWeightUnits = weightUnits.fold<int>(0, (sum, units) => sum + units);
    final weightedCosts = weightUnits
        .map((units) => courtRentalTotalVnd * units)
        .toList(growable: false);
    final baseShares = weightedCosts
        .map((cost) => cost ~/ totalWeightUnits)
        .toList(growable: false);
    final remainders = weightedCosts
        .map((cost) => cost % totalWeightUnits)
        .toList(growable: false);
    final remainingVnd =
        courtRentalTotalVnd - baseShares.fold<int>(0, (sum, share) => sum + share);
    final priority = List<int>.generate(participants.length, (index) => index)
      ..sort((first, second) {
        final byRemainder = remainders[second].compareTo(remainders[first]);
        return byRemainder != 0 ? byRemainder : first.compareTo(second);
      });
    final getsRemainder = priority.take(remainingVnd).contains(memberIndex);
    return baseShares[memberIndex] + (getsRemainder ? 1 : 0);
  }

  int _shuttleShareFor(int memberIndex) {
    final totalCost = shuttlesUsed * shuttleUnitPriceVnd;
    final baseShare = totalCost ~/ participants.length;
    final remainingVnd = totalCost % participants.length;
    return baseShare + (memberIndex < remainingVnd ? 1 : 0);
  }

  SessionModel copyWith({
    int? courtRentalTotalVnd,
    int? shuttlesUsed,
    List<SessionMember>? participants,
    List<RecentMatch>? recentMatches,
    List<ScheduledSessionMatch>? scheduledMatches,
  }) {
    return SessionModel(
      id: id,
      title: title,
      startsAt: startsAt,
      endsAt: endsAt,
      courtCount: courtCount,
      courtRentalTotalVnd: courtRentalTotalVnd ?? this.courtRentalTotalVnd,
      shuttleUnitPriceVnd: shuttleUnitPriceVnd,
      shuttlesUsed: shuttlesUsed ?? this.shuttlesUsed,
      participants: participants ?? this.participants,
      recentMatches: recentMatches ?? this.recentMatches,
      scheduledMatches: scheduledMatches ?? this.scheduledMatches,
    );
  }
}

String formatVnd(int amount) {
  return NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(amount);
}

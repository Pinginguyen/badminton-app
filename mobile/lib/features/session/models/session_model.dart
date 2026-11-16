import 'package:intl/intl.dart';

import '../../../services/matchmaking_service.dart';

enum SessionPaymentStatus { pending, approved, rejected }
enum BillSplitMode { equal, perSet, attendanceWeighted }

class SessionMember {
  const SessionMember({
    required this.id,
    required this.displayName,
    required this.skillLevel,
    required this.eloRating,
    this.lastPlayedAt,
    this.setsPlayed = 0,
    this.attendanceWeight = 1.0,
    this.lateFeeVnd = 0,
    this.paymentStatus = SessionPaymentStatus.pending,
    this.hasReportedTransfer = false,
  })  : assert(id != ''),
        assert(displayName != ''),
        assert(skillLevel >= 1 && skillLevel <= 4),
        assert(eloRating >= 0),
        assert(setsPlayed >= 0),
        assert(attendanceWeight == 0.5 || attendanceWeight == 1.0),
        assert(lateFeeVnd >= 0);

  final String id;
  final String displayName;
  final int skillLevel;
  final int eloRating;
  final DateTime? lastPlayedAt;
  final int setsPlayed;
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
    int? setsPlayed,
    int? lateFeeVnd,
    SessionPaymentStatus? paymentStatus,
    bool? hasReportedTransfer,
  }) {
    return SessionMember(
      id: id,
      displayName: displayName,
      skillLevel: skillLevel,
      eloRating: eloRating ?? this.eloRating,
      setsPlayed: setsPlayed ?? this.setsPlayed,
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
    required this.extraShareVnd,
    required this.lateFeeVnd,
    required this.totalAmountVnd,
  });

  final String memberId;
  final int courtShareVnd;
  final int shuttleShareVnd;
  final int extraShareVnd;
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
    this.extraCostsVnd = 0,
    this.splitMode = BillSplitMode.attendanceWeighted,
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
      shuttlesUsed < 0 ||
      extraCostsVnd < 0) {
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
          member.setsPlayed < 0 ||
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
  final int extraCostsVnd;
  final BillSplitMode splitMode;
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
    final shuttleWeights = splitMode == BillSplitMode.perSet
        ? _setWeights()
        : List<int>.filled(participants.length, 1);
    final shuttleShareVnd = _shareFor(
      memberIndex,
      shuttlesUsed * shuttleUnitPriceVnd,
      shuttleWeights,
    );
    final extraShareVnd = _shareFor(
      memberIndex,
      extraCostsVnd,
      _courtWeights(),
    );

    return SessionBill(
      memberId: member.id,
      courtShareVnd: courtShareVnd,
      shuttleShareVnd: shuttleShareVnd,
        extraShareVnd: extraShareVnd,
      lateFeeVnd: member.lateFeeVnd,
        totalAmountVnd: courtShareVnd +
          shuttleShareVnd +
          extraShareVnd +
          member.lateFeeVnd,
    );
  }

  int _courtShareFor(int memberIndex) {
    return _shareFor(memberIndex, courtRentalTotalVnd, _courtWeights());
    }

    List<int> _courtWeights() => switch (splitMode) {
      BillSplitMode.equal => List<int>.filled(participants.length, 1),
      BillSplitMode.perSet => _setWeights(),
      BillSplitMode.attendanceWeighted => participants
        .map((participant) => participant.attendanceWeight == 0.5 ? 1 : 2)
        .toList(growable: false),
      };

    List<int> _setWeights() {
    final weights = participants
      .map((participant) => participant.setsPlayed)
      .toList(growable: false);
    return weights.any((weight) => weight > 0)
      ? weights
      : List<int>.filled(participants.length, 1);
    }

    int _shareFor(int memberIndex, int totalCost, List<int> weightUnits) {
    final totalWeightUnits = weightUnits.fold<int>(0, (sum, units) => sum + units);
    final weightedCosts = weightUnits
      .map((units) => totalCost * units)
        .toList(growable: false);
    final baseShares = weightedCosts
        .map((cost) => cost ~/ totalWeightUnits)
        .toList(growable: false);
    final remainders = weightedCosts
        .map((cost) => cost % totalWeightUnits)
        .toList(growable: false);
    final remainingVnd =
        totalCost - baseShares.fold<int>(0, (sum, share) => sum + share);
    final priority = List<int>.generate(participants.length, (index) => index)
      ..sort((first, second) {
        final byRemainder = remainders[second].compareTo(remainders[first]);
        return byRemainder != 0 ? byRemainder : first.compareTo(second);
      });
    final getsRemainder = priority.take(remainingVnd).contains(memberIndex);
    return baseShares[memberIndex] + (getsRemainder ? 1 : 0);
  }

  SessionModel copyWith({
    int? courtRentalTotalVnd,
    int? shuttlesUsed,
    int? extraCostsVnd,
    BillSplitMode? splitMode,
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
      extraCostsVnd: extraCostsVnd ?? this.extraCostsVnd,
      splitMode: splitMode ?? this.splitMode,
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

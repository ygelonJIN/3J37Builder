/// Goal data model for storing badge and animation goals
class GoalData {
  final List<GoalBadge> badges;
  final List<GoalMove> moves;

  const GoalData({
    this.badges = const [],
    this.moves = const [],
  });

  GoalData copyWith({
    List<GoalBadge>? badges,
    List<GoalMove>? moves,
  }) {
    return GoalData(
      badges: badges ?? this.badges,
      moves: moves ?? this.moves,
    );
  }

  int get badgeCount => badges.length;
  int get moveCount => moves.length;
}

/// Represents a badge goal with a target tier
class GoalBadge {
  final int badgeId;
  final String badgeName;
  final String tier; // e.g., 'gold', 'hall_of_fame', 'legend'
  final int targetValue; // The X value in X/Y

  const GoalBadge({
    required this.badgeId,
    required this.badgeName,
    required this.tier,
    required this.targetValue,
  });

  GoalBadge copyWith({
    int? badgeId,
    String? badgeName,
    String? tier,
    int? targetValue,
  }) {
    return GoalBadge(
      badgeId: badgeId ?? this.badgeId,
      badgeName: badgeName ?? this.badgeName,
      tier: tier ?? this.tier,
      targetValue: targetValue ?? this.targetValue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalBadge &&
          runtimeType == other.runtimeType &&
          badgeId == other.badgeId;

  @override
  int get hashCode => badgeId.hashCode;
}

/// Represents a move/animation goal
class GoalMove {
  final String moveId;
  final String moveName;
  final String category; // e.g., 'dribble', 'shot', 'dunk'
  final int targetValue; // The X value in X/Y

  const GoalMove({
    required this.moveId,
    required this.moveName,
    required this.category,
    required this.targetValue,
  });

  GoalMove copyWith({
    String? moveId,
    String? moveName,
    String? category,
    int? targetValue,
  }) {
    return GoalMove(
      moveId: moveId ?? this.moveId,
      moveName: moveName ?? this.moveName,
      category: category ?? this.category,
      targetValue: targetValue ?? this.targetValue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalMove &&
          runtimeType == other.runtimeType &&
          moveId == other.moveId;

  @override
  int get hashCode => moveId.hashCode;
}

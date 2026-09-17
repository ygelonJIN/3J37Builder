/// Goal data model for storing badge, animation, and attribute goals
class GoalData {
  final List<GoalBadge> badges;
  final List<GoalMove> moves;
  final List<GoalAttribute> attributes;

  const GoalData({
    this.badges = const [],
    this.moves = const [],
    this.attributes = const [],
  });

  GoalData copyWith({
    List<GoalBadge>? badges,
    List<GoalMove>? moves,
    List<GoalAttribute>? attributes,
  }) {
    return GoalData(
      badges: badges ?? this.badges,
      moves: moves ?? this.moves,
      attributes: attributes ?? this.attributes,
    );
  }

  int get badgeCount => badges.length;
  int get moveCount => moves.length;
  int get attributeCount => attributes.length;
}

/// Represents a badge goal with a target tier
class GoalBadge {
  final int badgeId;
  final String badgeName;
  final String tier;
  final int targetValue;

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
  final String category;
  final int targetValue;

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

/// Represents an attribute goal with a target value
class GoalAttribute {
  final int attributeIndex;
  final String attributeName;
  final int targetValue;

  const GoalAttribute({
    required this.attributeIndex,
    required this.attributeName,
    required this.targetValue,
  });

  GoalAttribute copyWith({
    int? attributeIndex,
    String? attributeName,
    int? targetValue,
  }) {
    return GoalAttribute(
      attributeIndex: attributeIndex ?? this.attributeIndex,
      attributeName: attributeName ?? this.attributeName,
      targetValue: targetValue ?? this.targetValue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalAttribute &&
          runtimeType == other.runtimeType &&
          attributeIndex == other.attributeIndex;

  @override
  int get hashCode => attributeIndex.hashCode;
}

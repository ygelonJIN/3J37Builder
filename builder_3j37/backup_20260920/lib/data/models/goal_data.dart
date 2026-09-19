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

  /// Get the maximum attribute requirements across all badges and moves
  /// Returns a map of attributeIndex -> maximum required value
  Map<int, int> getAttributeRequirements() {
    final requirements = <int, int>{};
    
    // Collect requirements from badges
    for (final badge in badges) {
      for (final req in badge.attributeRequirements) {
        final current = requirements[req.attributeIndex] ?? 0;
        if (req.minimum > current) {
          requirements[req.attributeIndex] = req.minimum;
        }
      }
    }
    
    // Collect requirements from moves
    for (final move in moves) {
      for (final req in move.attributeRequirements) {
        final current = requirements[req.attributeIndex] ?? 0;
        if (req.minimum > current) {
          requirements[req.attributeIndex] = req.minimum;
        }
      }
    }
    
    return requirements;
  }
}

/// Represents a badge goal with a target tier
class GoalBadge {
  final int badgeId;
  final String badgeName;
  final String tier;
  final int targetValue;
  final List<GoalAttributeRequirement> attributeRequirements;

  const GoalBadge({
    required this.badgeId,
    required this.badgeName,
    required this.tier,
    required this.targetValue,
    this.attributeRequirements = const [],
  });

  GoalBadge copyWith({
    int? badgeId,
    String? badgeName,
    String? tier,
    int? targetValue,
    List<GoalAttributeRequirement>? attributeRequirements,
  }) {
    return GoalBadge(
      badgeId: badgeId ?? this.badgeId,
      badgeName: badgeName ?? this.badgeName,
      tier: tier ?? this.tier,
      targetValue: targetValue ?? this.targetValue,
      attributeRequirements: attributeRequirements ?? this.attributeRequirements,
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
  final List<GoalAttributeRequirement> attributeRequirements;

  const GoalMove({
    required this.moveId,
    required this.moveName,
    required this.category,
    required this.targetValue,
    this.attributeRequirements = const [],
  });

  GoalMove copyWith({
    String? moveId,
    String? moveName,
    String? category,
    int? targetValue,
    List<GoalAttributeRequirement>? attributeRequirements,
  }) {
    return GoalMove(
      moveId: moveId ?? this.moveId,
      moveName: moveName ?? this.moveName,
      category: category ?? this.category,
      targetValue: targetValue ?? this.targetValue,
      attributeRequirements: attributeRequirements ?? this.attributeRequirements,
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

/// Represents an attribute requirement for a badge or move
class GoalAttributeRequirement {
  final int attributeIndex;
  final String attributeName;
  final int minimum;

  const GoalAttributeRequirement({
    required this.attributeIndex,
    required this.attributeName,
    required this.minimum,
  });

  GoalAttributeRequirement copyWith({
    int? attributeIndex,
    String? attributeName,
    int? minimum,
  }) {
    return GoalAttributeRequirement(
      attributeIndex: attributeIndex ?? this.attributeIndex,
      attributeName: attributeName ?? this.attributeName,
      minimum: minimum ?? this.minimum,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalAttributeRequirement &&
          runtimeType == other.runtimeType &&
          attributeIndex == other.attributeIndex;

  @override
  int get hashCode => attributeIndex.hashCode;
}

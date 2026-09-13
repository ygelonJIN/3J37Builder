import 'enums.dart';

/// Badge definition from badges/definitions.json
class BadgeDef {
  final int badgeId;
  final String name;
  final Discipline discipline;
  final int group;
  final int minHeight;
  final int maxHeight;
  final bool allowed;

  const BadgeDef({
    required this.badgeId,
    required this.name,
    required this.discipline,
    required this.group,
    required this.minHeight,
    required this.maxHeight,
    required this.allowed,
  });

  factory BadgeDef.fromJson(Map<String, dynamic> json) {
    final hr = (json['height_inches'] as List).cast<int>();
    return BadgeDef(
      badgeId: json['badge'] as int,
      name: json['name'] as String,
      discipline: DisciplineX.fromCode(_disciplineCodeFromName(json['discipline'] as String)),
      group: json['group'] as int,
      minHeight: hr[0],
      maxHeight: hr[1],
      allowed: json['allowed'] as bool,
    );
  }

  String get displayName {
    return name.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  /// Whether this badge is eligible for a given height
  bool isHeightEligible(int heightInches) =>
      heightInches >= minHeight && heightInches <= maxHeight;

  static int _disciplineCodeFromName(String name) {
    switch (name) {
      case 'finishing': return 1;
      case 'shooting': return 2;
      case 'playmaking': return 3;
      case 'defense': return 4;
      case 'rebounding': return 5;
      case 'physicals': return 6;
      default: return 1;
    }
  }
}

/// Tier requirement for a badge
class BadgeTierRequirement {
  final int badgeId;
  final String badgeName;
  final BadgeTier tier;
  final List<AttributeRequirement> requirements;

  const BadgeTierRequirement({
    required this.badgeId,
    required this.badgeName,
    required this.tier,
    required this.requirements,
  });

  factory BadgeTierRequirement.fromJson(Map<String, dynamic> json) {
    return BadgeTierRequirement(
      badgeId: json['badge'] as int,
      badgeName: json['name'] as String,
      tier: BadgeTierX.fromKey(json['tier'] as String),
      requirements: (json['requirements'] as List)
          .map((r) => AttributeRequirement.fromJson(r))
          .toList(),
    );
  }
}

class AttributeRequirement {
  final int attributeIndex;
  final String name;
  final int minimum;
  final String? operatorToNext; // AND or OR

  const AttributeRequirement({
    required this.attributeIndex,
    required this.name,
    required this.minimum,
    this.operatorToNext,
  });

  factory AttributeRequirement.fromJson(Map<String, dynamic> json) =>
      AttributeRequirement(
        attributeIndex: json['attribute'] as int,
        name: json['name'] as String,
        minimum: json['minimum'] as int,
        operatorToNext: json['operator_to_next'] as String?,
      );
}

/// Token cost for a badge at a tier/height
class BadgeTokenCost {
  final int badgeId;
  final String name;
  final BadgeTier tier;
  final int heightInches;
  final int cost;

  const BadgeTokenCost({
    required this.badgeId,
    required this.name,
    required this.tier,
    required this.heightInches,
    required this.cost,
  });

  factory BadgeTokenCost.fromJson(Map<String, dynamic> json) => BadgeTokenCost(
    badgeId: json['badge'] as int,
    name: json['name'] as String,
    tier: BadgeTierX.fromKey(json['tier'] as String),
    heightInches: json['height_inches'] as int,
    cost: json['cost'] as int,
  );
}

/// Token contribution from one attribute at one rating/height
class TokenContribution {
  final int heightInches;
  final int attributeIndex;
  final String name;
  final int rating;
  final List<int> tokens; // 6 values in discipline_order
  final List<int> slots;

  const TokenContribution({
    required this.heightInches,
    required this.attributeIndex,
    required this.name,
    required this.rating,
    required this.tokens,
    required this.slots,
  });

  factory TokenContribution.fromJson(Map<String, dynamic> json) =>
      TokenContribution(
        heightInches: json['height_inches'] as int,
        attributeIndex: json['attribute'] as int,
        name: json['name'] as String,
        rating: json['rating'] as int,
        tokens: (json['tokens'] as List).cast<int>(),
        slots: (json['slots'] as List).cast<int>(),
      );
}

/// Token contribution key for lookup
class TokenKey {
  final int heightInches;
  final int attributeIndex;
  final int rating;

  const TokenKey(this.heightInches, this.attributeIndex, this.rating);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenKey &&
          heightInches == other.heightInches &&
          attributeIndex == other.attributeIndex &&
          rating == other.rating;

  @override
  int get hashCode => Object.hash(heightInches, attributeIndex, rating);
}

/// Token cost key for lookup
class TokenCostKey {
  final int badgeId;
  final BadgeTier tier;
  final int heightInches;

  const TokenCostKey(this.badgeId, this.tier, this.heightInches);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenCostKey &&
          badgeId == other.badgeId &&
          tier == other.tier &&
          heightInches == other.heightInches;

  @override
  int get hashCode => Object.hash(badgeId, tier, heightInches);
}

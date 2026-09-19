/// Takeover ability from takeovers/requirements.json
class TakeoverAbility {
  final int abilityCode;
  final List<TakeoverRequirement> requirements;

  const TakeoverAbility({required this.abilityCode, required this.requirements});

  factory TakeoverAbility.fromJson(Map<String, dynamic> json) {
    return TakeoverAbility(
      abilityCode: json['ability'] as int,
      requirements: (json['requirements'] as List)
          .map((r) => TakeoverRequirement.fromJson(r))
          .toList(),
    );
  }

  bool get hasRequirements => requirements.isNotEmpty;
}

class TakeoverRequirement {
  final int attributeCode; // unresolved enum
  final int minimum;
  final String? operatorToNext;

  const TakeoverRequirement({
    required this.attributeCode,
    required this.minimum,
    this.operatorToNext,
  });

  factory TakeoverRequirement.fromJson(Map<String, dynamic> json) =>
      TakeoverRequirement(
        attributeCode: json['attribute_code_unresolved'] as int,
        minimum: json['minimum'] as int,
        operatorToNext: json['operator_to_next'] as String?,
      );
}

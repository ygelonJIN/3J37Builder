import 'enums.dart';

/// One of the 21 career attributes
class AttributeDef {
  final int index;
  final String name;
  final Discipline discipline;
  final String colour; // hex from dataset

  const AttributeDef({
    required this.index,
    required this.name,
    required this.discipline,
    required this.colour,
  });

  factory AttributeDef.fromJson(Map<String, dynamic> json) => AttributeDef(
    index: json['index'] as int,
    name: json['name'] as String,
    discipline: _disciplineFromName(json['discipline'] as String),
    colour: json['colour'] as String,
  );

  String get displayName {
    // close_shot -> Close Shot
    return name.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  static Discipline _disciplineFromName(String name) {
    switch (name) {
      case 'finishing': return Discipline.finishing;
      case 'shooting': return Discipline.shooting;
      case 'playmaking': return Discipline.playmaking;
      case 'defense': return Discipline.defense;
      case 'rebounding': return Discipline.rebounding;
      case 'physicals': return Discipline.physicals;
      default: return Discipline.finishing;
    }
  }
}

/// Body configuration
class BodyConfig {
  final Position position;
  final int heightInches;
  final int weightLb;
  final int wingspanInches;

  const BodyConfig({
    required this.position,
    required this.heightInches,
    required this.weightLb,
    required this.wingspanInches,
  });
}

/// Legal body ranges for one position
class LegalBody {
  final Position position;
  final int minHeight;
  final int maxHeight;
  final int defaultHeight;
  final List<BodyRange> bodies;

  const LegalBody({
    required this.position,
    required this.minHeight,
    required this.maxHeight,
    required this.defaultHeight,
    required this.bodies,
  });

  factory LegalBody.fromJson(Map<String, dynamic> json) {
    final posStr = json['position'] as String;
    final heightRange = (json['height_inches'] as List).cast<int>();
    final bodyList = (json['bodies'] as List).map((b) => BodyRange.fromJson(b)).toList();
    return LegalBody(
      position: Position.values.firstWhere((p) => p.label == posStr),
      minHeight: heightRange[0],
      maxHeight: heightRange[1],
      defaultHeight: json['default_height_inches'] as int,
      bodies: bodyList,
    );
  }
}

class BodyRange {
  final int heightInches;
  final int minWeight;
  final int maxWeight;
  final int defaultWeight;
  final int minWingspan;
  final int maxWingspan;
  final int defaultWingspan;

  const BodyRange({
    required this.heightInches,
    required this.minWeight,
    required this.maxWeight,
    required this.defaultWeight,
    required this.minWingspan,
    required this.maxWingspan,
    required this.defaultWingspan,
  });

  factory BodyRange.fromJson(Map<String, dynamic> json) {
    final wt = (json['weight_lb'] as List).cast<int>();
    final ws = (json['wingspan_inches'] as List).cast<int>();
    return BodyRange(
      heightInches: json['height_inches'] as int,
      minWeight: wt[0],
      maxWeight: wt[1],
      defaultWeight: json['default_weight_lb'] as int,
      minWingspan: ws[0],
      maxWingspan: ws[1],
      defaultWingspan: json['default_wingspan_inches'] as int,
    );
  }
}

/// Attribute cap for one attribute on one body
class AttributeCap {
  final int attributeIndex;
  final String name;
  final int cap;

  const AttributeCap({required this.attributeIndex, required this.name, required this.cap});

  factory AttributeCap.fromJson(Map<String, dynamic> json) => AttributeCap(
    attributeIndex: json['attribute'] as int,
    name: json['name'] as String,
    cap: json['cap'] as int,
  );
}

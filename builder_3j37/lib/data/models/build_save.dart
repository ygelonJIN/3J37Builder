import 'dart:convert';
import '../models/enums.dart';

/// A saved player build (MyB archive entry)
class BuildSave {
  final String id;
  String name;
  final Position position;
  final int heightInches;
  final int weightLb;
  final int wingspanInches;
  final List<int> baseRatings;  // 21 attribute values
  final Map<int, int> equippedBadgeTiers;  // badgeId -> tier code (1-5)
  final int overallRating;
  final DateTime createdAt;
  DateTime updatedAt;

  BuildSave({
    required this.id,
    required this.name,
    required this.position,
    required this.heightInches,
    required this.weightLb,
    required this.wingspanInches,
    required this.baseRatings,
    required this.equippedBadgeTiers,
    required this.overallRating,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  // ── Display helpers ──────────────────────────────────────

  String get heightDisplay {
    final feet = heightInches ~/ 12;
    final inc = heightInches % 12;
    return "$feet'$inc\"";
  }

  String get weightDisplay => '$weightLb lbs';

  String get wingspanDisplay {
    final feet = wingspanInches ~/ 12;
    final inc = wingspanInches % 12;
    return "$feet'$inc\"";
  }

  String get positionLabel => position.label;

  /// Subtitle line: "PG | 6'3\" | 185 lbs | 6'5\" | OVR 88"
  String get subtitleLine {
    final hCm = (heightInches * 2.54).round();
    final wKg = (weightLb * 0.453592).round();
    final wsCm = (wingspanInches * 2.54).round();
    final hFeet = heightInches ~/ 12;
    final hInc = heightInches % 12;
    final wsFeet = wingspanInches ~/ 12;
    final wsInc = wingspanInches % 12;
    return positionLabel + '  ' +
      hFeet.toString() + "'" + hInc.toString() + '"/' + hCm.toString() + 'cm  ' +
      weightLb.toString() + ' lbs/' + wKg.toString() + 'kg  ' +
      wsFeet.toString() + "'" + wsInc.toString() + '"/' + wsCm.toString() + 'cm';
  }

  // ── Serialization ────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'position': position.code,
    'heightInches': heightInches,
    'weightLb': weightLb,
    'wingspanInches': wingspanInches,
    'baseRatings': baseRatings,
    'equippedBadgeTiers': equippedBadgeTiers.map((k, v) => MapEntry('$k', v)),
    'overallRating': overallRating,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory BuildSave.fromJson(Map<String, dynamic> json) {
    final badgesRaw = json['equippedBadgeTiers'] as Map<String, dynamic>? ?? {};
    final badges = badgesRaw.map((k, v) => MapEntry(int.parse(k), v as int));
    return BuildSave(
      id: json['id'] as String,
      name: json['name'] as String,
      position: PositionX.fromCode(json['position'] as int),
      heightInches: json['heightInches'] as int,
      weightLb: json['weightLb'] as int,
      wingspanInches: json['wingspanInches'] as int,
      baseRatings: (json['baseRatings'] as List).cast<int>(),
      equippedBadgeTiers: badges,
      overallRating: json['overallRating'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory BuildSave.fromJsonString(String str) =>
      BuildSave.fromJson(jsonDecode(str) as Map<String, dynamic>);
}

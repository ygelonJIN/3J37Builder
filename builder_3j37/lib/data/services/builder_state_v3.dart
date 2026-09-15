import 'package:flutter/foundation.dart';
import '../models/enums.dart';
import '../models/attribute.dart';
import '../models/badge_data.dart';
import '../models/cap_breaker.dart';
import 'dataset_loader.dart';
import 'tuning_parser.dart';
import 'cap_breaker_engine.dart';

class BadgeStatus {
  final BadgeDef badge;
  final BadgeTier? highestTier;
  final BadgeTier? equippedTier;
  final bool heightEligible;

  const BadgeStatus({
    required this.badge,
    this.highestTier,
    this.equippedTier,
    required this.heightEligible,
  });

  bool get isEquipped => equippedTier != null;
  bool get isUnlocked => highestTier != null && heightEligible;
}

/// Represents the state of one attribute including cap breakers
class AttributeState {
  final int baseValue;      // Value set by user (within base cap)
  final int capBreakerGain; // Total gain from cap breakers
  final int baseCap;        // Physical cap before cap breakers
  final List<int> appliedGains; // Individual gains from each cap breaker
  
  const AttributeState({
    required this.baseValue,
    required this.capBreakerGain,
    required this.baseCap,
    required this.appliedGains,
  });
  
  /// Final value including cap breakers
  int get finalValue => baseValue + capBreakerGain;
  
  /// Whether this attribute has cap breakers applied
  bool get hasCapBreakers => capBreakerGain > 0;
  
  /// Available headroom before hitting base cap
  int get headroomBeforeCap => (baseCap - baseValue).clamp(0, 999);
  
  /// Whether more cap breakers can be applied (value < cap)
  bool get canApplyMoreCapBreakers => baseValue < baseCap && appliedGains.length < 5;
}

class BuilderStateV3 extends ChangeNotifier {
  final DatasetLoader _loader = DatasetLoader();
  final CapBreakerEngine _cbEngine = CapBreakerEngine();

  Position _position = Position.pg;
  int _heightInches = 75;
  int _weightLb = 185;
  int _wingspanInches = 75;

  // Base ratings (what user sets, within physical caps)
  List<int> _baseRatings = List.filled(21, 25);
  
  // Final ratings (base + cap breakers)
  List<int> _finalRatings = List.filled(21, 25);
  
  // Cap breaker state - tracks applied gains per attribute
  Map<int, List<int>> _appliedCapBreakers = {};
  
  // Physical caps (from tuning)
  List<int> _physicalCaps = List.filled(21, 99);
  
  // Track which attributes user has manually touched
  List<bool> _userTouched = List.filled(21, false);

  Map<int, BadgeTier?> _equippedBadges = {};

  // Getters
  Position get position => _position;
  int get heightInches => _heightInches;
  int get weightLb => _weightLb;
  int get wingspanInches => _wingspanInches;
  List<int> get ratings => List.unmodifiable(_finalRatings);
  List<int> get baseRatings => List.unmodifiable(_baseRatings);
  List<bool> get userTouched => List.unmodifiable(_userTouched);
  Map<int, BadgeTier?> get equippedBadges => Map.unmodifiable(_equippedBadges);
  List<int> get physicalCaps => List.unmodifiable(_physicalCaps);

  String get heightDisplay {
    final feet = _heightInches ~/ 12;
    final inches = _heightInches % 12;
    return "$feet'$inches\"";
  }

  String get weightDisplay => '$_weightLb lbs';

  String get wingspanDisplay {
    final feet = _wingspanInches ~/ 12;
    final inc = _wingspanInches % 12;
    return "$feet'$inc\"";
  }

  int get overallRating => _loader.getOvr(_position, _heightInches, _finalRatings).round();

  /// Get the state of a specific attribute including cap breakers
  AttributeState getAttributeState(int attrIndex) {
    final appliedGains = _appliedCapBreakers[attrIndex] ?? [];
    final totalGain = appliedGains.fold(0, (sum, g) => sum + g);
    
    return AttributeState(
      baseValue: _baseRatings[attrIndex],
      capBreakerGain: totalGain,
      baseCap: _physicalCaps[attrIndex],
      appliedGains: List.unmodifiable(appliedGains),
    );
  }

  /// Get the next available cap breaker gain for an attribute
  /// Uses chained lookup (each gain based on current rating after previous gains)
  int? getNextCapBreakerGain(int attrIndex) {
    final appliedCount = _appliedCapBreakers[attrIndex]?.length ?? 0;
    if (appliedCount >= 5) return null; // Max 5 cap breakers
    
    // Calculate current rating with applied cap breakers
    final currentRating = _baseRatings[attrIndex] + 
        (_appliedCapBreakers[attrIndex]?.fold(0, (sum, g) => sum + g) ?? 0);
    
    if (currentRating >= 99) return null; // Already at max
    
    // Use near_caps scenario when close to cap, isolated otherwise
    final scenario = CapBreakerEngine.suggestScenario(currentRating, _physicalCaps[attrIndex]);
    
    // Look up gain for current rating and application index
    return _cbEngine.getGain(scenario, attrIndex, currentRating, appliedCount);
  }

  /// Check if a cap breaker can be applied to an attribute
  bool canApplyCapBreaker(int attrIndex) {
    return getNextCapBreakerGain(attrIndex) != null;
  }

  /// Apply a cap breaker to an attribute
  /// Returns true if successful
  bool applyCapBreaker(int attrIndex) {
    final gain = getNextCapBreakerGain(attrIndex);
    if (gain == null) return false;
    
    _appliedCapBreakers.putIfAbsent(attrIndex, () => []);
    _appliedCapBreakers[attrIndex]!.add(gain);
    
    _recalculateFinalRatings();
    notifyListeners();
    return true;
  }

  /// Remove the last cap breaker from an attribute
  bool removeCapBreaker(int attrIndex) {
    final gains = _appliedCapBreakers[attrIndex];
    if (gains == null || gains.isEmpty) return false;
    
    gains.removeLast();
    if (gains.isEmpty) {
      _appliedCapBreakers.remove(attrIndex);
    }
    
    _recalculateFinalRatings();
    notifyListeners();
    return true;
  }

  /// Remove all cap breakers from an attribute
  void removeAllCapBreakers(int attrIndex) {
    _appliedCapBreakers.remove(attrIndex);
    _recalculateFinalRatings();
    notifyListeners();
  }

  /// Clear all cap breakers
  void clearAllCapBreakers() {
    _appliedCapBreakers.clear();
    _recalculateFinalRatings();
    notifyListeners();
  }

  /// Get total cap breakers applied
  int get totalCapBreakersApplied {
    return _appliedCapBreakers.values.fold(0, (sum, gains) => sum + gains.length);
  }

  /// Check if any cap breakers are applied
  bool get hasAnyCapBreakers => _appliedCapBreakers.isNotEmpty;

  void setPosition(Position pos) {
    if (_position == pos) return;
    _position = pos;
    
    final legalBody = _loader.getLegalBody(pos);
    if (legalBody != null) {
      _heightInches = _heightInches.clamp(legalBody.minHeight, legalBody.maxHeight);
    }
    
    final bodyRange = _loader.getBodyRange(pos, _heightInches);
    if (bodyRange != null) {
      _weightLb = _weightLb.clamp(bodyRange.minWeight, bodyRange.maxWeight);
      _wingspanInches = _wingspanInches.clamp(bodyRange.minWingspan, bodyRange.maxWingspan);
    }
    
    _recalcAll();
    notifyListeners();
  }

  void setHeight(int inches) {
    if (_heightInches == inches) return;
    _heightInches = inches;
    
    final bodyRange = _loader.getBodyRange(_position, _heightInches);
    if (bodyRange != null) {
      _weightLb = _weightLb.clamp(bodyRange.minWeight, bodyRange.maxWeight);
      _wingspanInches = _wingspanInches.clamp(bodyRange.minWingspan, bodyRange.maxWingspan);
    }
    
    _recalcAll();
    notifyListeners();
  }

  void setWeight(int lb) {
    if (_weightLb == lb) return;
    _weightLb = lb;
    _recalcAll();
    notifyListeners();
  }

  void setWingspan(int inches) {
    if (_wingspanInches == inches) return;
    _wingspanInches = inches;
    _recalcAll();
    notifyListeners();
  }

  void setRating(int attrIndex, int value) {
    // Clamp to 25 and physical cap (not including cap breakers)
    final newValue = value.clamp(25, _physicalCaps[attrIndex]);
    if (_baseRatings[attrIndex] == newValue) return;

    final oldValue = _baseRatings[attrIndex];
    _baseRatings[attrIndex] = newValue;
    _userTouched[attrIndex] = true;

    if (newValue < oldValue) {
      _propagateDown(attrIndex, newValue);
    }

    _applyConstraintsAndOvrBudget(attrIndex, oldValue);
    _autoDowngradeBadges();
    _recalculateFinalRatings();
    notifyListeners();
  }

  void _propagateDown(int attrIndex, int newValue) {
    final hIdx = _heightInches - 64;
    for (int si = 0; si < 21; si++) {
      final srcName = TuningParser.nativeNames[si];
      final constraints = _loader.tuning.associatedConstraints[srcName]?[hIdx];
      if (constraints == null) continue;
      for (final c in constraints) {
        if (c.targetAttr.isEmpty) continue;
        final ti = TuningParser.nativeNames.indexOf(c.targetAttr);
        if (ti != attrIndex) continue;
        final maxSource = newValue + c.maxDelta;
        if (_baseRatings[si] > maxSource) {
          _baseRatings[si] = maxSource.clamp(25, _physicalCaps[si]);
          _propagateDown(si, _baseRatings[si]);
        }
      }
    }
  }

  void _applyConstraintsAndOvrBudget(int changedIndex, int oldValue) {
    final constrained = _loader.tuning.applyConstraints(_heightInches, _baseRatings);
    for (int i = 0; i < 21; i++) {
      _baseRatings[i] = constrained[i].clamp(25, _physicalCaps[i]);
    }

    // Check overall rating budget using base ratings only
    final tempRatings = List<int>.from(_baseRatings);
    final ovr = _loader.getOvr(_position, _heightInches, tempRatings);
    if (ovr >= 99.0) {
      _baseRatings[changedIndex] = oldValue;
      final revertedConstrained = _loader.tuning.applyConstraints(_heightInches, _baseRatings);
      for (int i = 0; i < 21; i++) {
        _baseRatings[i] = revertedConstrained[i].clamp(25, _physicalCaps[i]);
      }
    }
  }

  void _autoDowngradeBadges() {
    final badgesToDowngrade = <int, BadgeTier?>{};
    
    _equippedBadges.forEach((badgeId, currentTier) {
      if (currentTier == null) return;
      
      final highestTier = _loader.getHighestQualifiedTier(badgeId, _finalRatings);
      final badge = _loader.badgeDefinitions.firstWhere(
        (b) => b.badgeId == badgeId,
        orElse: () => BadgeDef(badgeId: badgeId, name: '', discipline: Discipline.finishing, group: 0, minHeight: 0, maxHeight: 99, allowed: false),
      );
      final meetsHeight = badge.isHeightEligible(_heightInches);
      
      if (highestTier == null || !meetsHeight) {
        badgesToDowngrade[badgeId] = null;
      } else {
        final tierOrder = [BadgeTier.bronze, BadgeTier.silver, BadgeTier.gold, BadgeTier.hallOfFame];
        final currentIndex = tierOrder.indexOf(currentTier);
        final highestIndex = tierOrder.indexOf(highestTier);
        
        if (currentIndex > highestIndex) {
          badgesToDowngrade[badgeId] = highestTier;
        }
      }
    });
    
    badgesToDowngrade.forEach((badgeId, newTier) {
      if (newTier == null) {
        _equippedBadges.remove(badgeId);
      } else {
        _equippedBadges[badgeId] = newTier;
      }
    });
  }

  /// Recalculate final ratings (base + cap breakers)
  void _recalculateFinalRatings() {
    for (int i = 0; i < 21; i++) {
      final base = _baseRatings[i];
      final cbGain = _appliedCapBreakers[i]?.fold(0, (sum, g) => sum + g) ?? 0;
      _finalRatings[i] = (base + cbGain).clamp(25, 99);
    }
  }

  List<int> getAttributeCaps() => _loader.getAttributeCaps(_position, _heightInches, _weightLb, _wingspanInches);
  List<int> getTokenBudget() => _loader.getTokenBudget(_heightInches, _finalRatings);

  List<int> getTokensSpent() {
    final spent = List.filled(6, 0);
    _equippedBadges.forEach((badgeId, tier) {
      if (tier != null) {
        final cost = _loader.getBadgeTokenCost(badgeId, tier, _heightInches);
        final badge = _loader.badgeDefinitions.firstWhere((b) => b.badgeId == badgeId, orElse: () => BadgeDef(badgeId: badgeId, name: '', discipline: Discipline.finishing, group: 0, minHeight: 0, maxHeight: 99, allowed: false));
        spent[badge.discipline.index] += cost;
      }
    });
    return spent;
  }

  List<int> getTokensRemaining() {
    final budget = getTokenBudget(); 
    final spent = getTokensSpent();
    return List.generate(6, (i) => (budget[i] - spent[i]).clamp(0, 999));
  }

  List<BadgeStatus> getBadgeStatuses() {
    return _loader.badgeDefinitions.map((badge) {
      final highestTier = _loader.getHighestQualifiedTier(badge.badgeId, _finalRatings);
      final equipped = _equippedBadges[badge.badgeId];
      return BadgeStatus(
        badge: badge, 
        highestTier: highestTier, 
        equippedTier: equipped, 
        heightEligible: badge.isHeightEligible(_heightInches),
      );
    }).toList();
  }

  bool equipBadge(int badgeId, BadgeTier? tier) {
    if (tier == null) {
      _equippedBadges.remove(badgeId);
      notifyListeners();
      return true;
    }
    
    final cost = _loader.getBadgeTokenCost(badgeId, tier, _heightInches);
    final badge = _loader.badgeDefinitions.firstWhere(
      (b) => b.badgeId == badgeId, 
      orElse: () => BadgeDef(badgeId: badgeId, name: '', discipline: Discipline.finishing, group: 0, minHeight: 0, maxHeight: 99, allowed: false),
    );
    if (getTokensRemaining()[badge.discipline.index] < cost) return false;
    _equippedBadges[badgeId] = tier; 
    notifyListeners(); 
    return true;
  }

  void _recalcAll() {
    _baseRatings = List.filled(21, 25);
    _userTouched = List.filled(21, false);
    _equippedBadges = {};
    _appliedCapBreakers.clear();
    
    // Recalculate physical caps
    _physicalCaps = _loader.getAttributeCaps(_position, _heightInches, _weightLb, _wingspanInches);
    
    final constrained = _loader.tuning.applyConstraints(_heightInches, _baseRatings);
    for (int i = 0; i < 21; i++) {
      _baseRatings[i] = constrained[i].clamp(25, _physicalCaps[i]);
    }
    
    _recalculateFinalRatings();
  }

  /// Save current build state to JSON
  Map<String, dynamic> toJson() {
    return {
      'position': _position.label,
      'heightInches': _heightInches,
      'weightLb': _weightLb,
      'wingspanInches': _wingspanInches,
      'baseRatings': _baseRatings,
      'capBreakers': _appliedCapBreakers.map((k, v) => MapEntry(k.toString(), v)),
      'equippedBadges': _equippedBadges.map((k, v) => MapEntry(k.toString(), v?.key)),
    };
  }

  /// Load build state from JSON
  void fromJson(Map<String, dynamic> json) {
    _position = Position.values.firstWhere(
      (p) => p.label == json['position'],
      orElse: () => Position.pg,
    );
    _heightInches = json['heightInches'] as int? ?? 75;
    _weightLb = json['weightLb'] as int? ?? 185;
    _wingspanInches = json['wingspanInches'] as int? ?? 75;
    
    final baseList = json['baseRatings'] as List?;
    if (baseList != null && baseList.length == 21) {
      _baseRatings = baseList.map((e) => e as int).toList();
    }
    
    final cbJson = json['capBreakers'] as Map<String, dynamic>?;
    if (cbJson != null) {
      _appliedCapBreakers = {};
      cbJson.forEach((key, value) {
        final attrIndex = int.tryParse(key);
        if (attrIndex != null && value is List) {
          _appliedCapBreakers[attrIndex] = value.map((e) => e as int).toList();
        }
      });
    }
    
    final badgesJson = json['equippedBadges'] as Map<String, dynamic>?;
    if (badgesJson != null) {
      _equippedBadges = {};
      badgesJson.forEach((key, value) {
        final badgeId = int.tryParse(key);
        if (badgeId != null && value != null) {
          _equippedBadges[badgeId] = BadgeTierX.fromKey(value as String);
        }
      });
    }
    
    _physicalCaps = _loader.getAttributeCaps(_position, _heightInches, _weightLb, _wingspanInches);
    _recalculateFinalRatings();
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import '../models/enums.dart';
import '../models/attribute.dart';
import '../models/badge_data.dart';
import '../models/cap_breaker.dart';
import '../models/goal_data.dart';
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

  // Lock state (manual only - never auto-locks)
  final Set<int> _lockedAttributes = {};

  // Goal state
  final Map<int, int> _goalRatings = {};
  final Set<int> _goalActive = {};
  final Map<int, int> _goalConstrainedFloors = {}; // attrIndex -> minimum floor imposed by Goal constraints
  final Set<int> _goalFromBadgesMoves = {}; // attrIndex -> attributes goal-locked by badge/move requirements

  // Goal data for badges and moves
  GoalData _goalData = const GoalData();

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
  GoalData get goalData => _goalData;
  DatasetLoader get loader => _loader;

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

  int get overallRating => _loader.getOvr(_position, _heightInches, _baseRatings).round();

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
    final appliedGains = _appliedCapBreakers[attrIndex];
    final currentRating = _baseRatings[attrIndex] + 
        (appliedGains != null ? appliedGains.fold<int>(0, (sum, g) => sum + g) : 0);
    
    if (currentRating >= _physicalCaps[attrIndex]) return null; // Already at physical cap
    
    // Build current values map for model-based calculation
    final values = <String, int>{};
    for (int i = 0; i < 21; i++) {
      values[CapBreakerEngine.getAttributeId(i)] = _baseRatings[i] + 
          ((_appliedCapBreakers[i]?.fold<int>(0, (s, g) => s + g)) ?? 0);
    }
    final body = CapBreakerBody(
      position: _position.name.toUpperCase(),
      height: _heightInches,
      weight: _weightLb,
      wingspan: _wingspanInches,
    );
    return _cbEngine.getNextGain(attrIndex, currentRating, appliedCount, 
        values: values, body: body, physicalCaps: _physicalCaps);
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

  // ── Missing methods needed by attribute_group.dart ──────
  int getCapBreakerGainForAttr(int attrIndex) {
    final gains = _appliedCapBreakers[attrIndex];
    if (gains == null || gains.isEmpty) return 0;
    return gains.reduce((a, b) => a + b);
  }

  int getAppliedCapBreakerCount(int attrIndex) {
    return _appliedCapBreakers[attrIndex]?.length ?? 0;
  }

  /// Get the list of cap breaker gains for an attribute
  List<int> getAppliedCapBreakerGains(int attrIndex) {
    return List<int>.from(_appliedCapBreakers[attrIndex] ?? []);
  }

  /// Apply a specific cap breaker gain to an attribute
  bool applyCapBreakerWithGain(int attrIndex, int gain) {
    final appliedCount = _appliedCapBreakers[attrIndex]?.length ?? 0;
    if (appliedCount >= 5) return false;
    _appliedCapBreakers.putIfAbsent(attrIndex, () => []);
    _appliedCapBreakers[attrIndex]!.add(gain);
    _recalculateFinalRatings();
    notifyListeners();
    return true;
  }

  String? validateRatingChange(int attrIndex, int newValue) {
    if (_lockedAttributes.isEmpty && _goalActive.isEmpty && _goalConstrainedFloors.isEmpty) return null;
    if (_goalActive.contains(attrIndex)) {
      return "Remove Goal First";
    }
    // Check if lowering below a goal-constrained floor
    final floor = _goalConstrainedFloors[attrIndex];
    if (floor != null && newValue < floor) {
      return "Remove Goal First";
    }
    // Check if lowering would violate locked attribute constraints
    if (newValue < _baseRatings[attrIndex] && _lockedAttributes.isNotEmpty) {
      final lockFloor = _getMinimumValueDueToLocks(attrIndex);
      if (lockFloor != null && newValue < lockFloor) {
        // Find which locked attribute causes this constraint
        final lockedName = _getBlockingLockedAttributeName(attrIndex);
        if (lockedName != null) {
          return '$lockedName is Locked';
        }
        return 'Locked Attribute';
      }
    }
    return null;
  }

  /// Get the minimum value for an attribute due to locked attribute constraints
  int? _getMinimumValueDueToLocks(int attrIndex) {
    if (_lockedAttributes.isEmpty) return null;
    final hIdx = _heightInches - 64;
    int floor = 25;

    for (final lockedIdx in _lockedAttributes) {
      if (lockedIdx == attrIndex) continue;
      final srcName = TuningParser.nativeNames[lockedIdx];
      final constraints = _loader.tuning.associatedConstraints[srcName]?[hIdx];
      if (constraints == null) continue;
      for (final c in constraints) {
        if (c.targetAttr.isEmpty) continue;
        final ti = TuningParser.nativeNames.indexOf(c.targetAttr);
        if (ti != attrIndex) continue;
        // Constraint: attrIndex >= lockedValue - maxDelta
        final minVal = _baseRatings[lockedIdx] - c.maxDelta;
        if (minVal > floor) floor = minVal;
      }
    }

    return floor > 25 ? floor : null;
  }

  /// Get the name of the locked attribute that blocks lowering of attrIndex
  String? _getBlockingLockedAttributeName(int attrIndex) {
    if (_lockedAttributes.isEmpty) return null;
    final hIdx = _heightInches - 64;
    String? blockingName;
    int highestFloor = 25;

    for (final lockedIdx in _lockedAttributes) {
      if (lockedIdx == attrIndex) continue;
      final srcName = TuningParser.nativeNames[lockedIdx];
      final constraints = _loader.tuning.associatedConstraints[srcName]?[hIdx];
      if (constraints == null) continue;
      for (final c in constraints) {
        if (c.targetAttr.isEmpty) continue;
        final ti = TuningParser.nativeNames.indexOf(c.targetAttr);
        if (ti != attrIndex) continue;
        final minVal = _baseRatings[lockedIdx] - c.maxDelta;
        if (minVal > highestFloor) {
          highestFloor = minVal;
          final attr = _loader.attributes[lockedIdx];
          blockingName = attr.displayName;
        }
      }
    }

    return blockingName;
  }
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
    if (_lockedAttributes.contains(attrIndex)) return;
    if (_goalActive.contains(attrIndex)) return; // Goal-locked attributes cannot be modified
    // Check goal-constrained floors
    final floor = _goalConstrainedFloors[attrIndex];
    if (floor != null && value < floor) return; // Cannot go below goal-constrained floor
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

    // Recalculate applied cap breaker gains AFTER constraint propagation
    // (constraints may modify _baseRatings, so gains must use final values)
    _recalculateCapBreakerGains();

    _recalculateFinalRatings();
    notifyListeners();
  }

  void _propagateDown(int attrIndex, int newValue) {
    final hIdx = _heightInches - 64;
    for (int si = 0; si < 21; si++) {
      // Skip locked attributes - they should never be modified by constraint propagation
      if (_lockedAttributes.contains(si)) continue;
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
    // Save locked attribute values before applying constraints
    final lockedValues = <int, int>{};
    for (final idx in _lockedAttributes) {
      lockedValues[idx] = _baseRatings[idx];
    }

    final constrained = _loader.tuning.applyConstraints(_heightInches, _baseRatings);
    for (int i = 0; i < 21; i++) {
      _baseRatings[i] = constrained[i].clamp(25, _physicalCaps[i]);
    }

    // Restore locked attributes to their original values
    for (final entry in lockedValues.entries) {
      _baseRatings[entry.key] = entry.value;
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
      // Restore locked attributes again after revert
      for (final entry in lockedValues.entries) {
        _baseRatings[entry.key] = entry.value;
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
      _finalRatings[i] = (base + cbGain).clamp(25, _physicalCaps[i]);
    }
  }

  /// Recalculate all applied cap breaker gains from current base values.
  /// Called after constraint propagation when _baseRatings may have changed.
  void _recalculateCapBreakerGains() {
    if (_appliedCapBreakers.isEmpty) return;
    final body = CapBreakerBody(
      position: _position.name.toUpperCase(),
      height: _heightInches,
      weight: _weightLb,
      wingspan: _wingspanInches,
    );
    final values = <String, int>{};
    for (int i = 0; i < 21; i++) {
      values[CapBreakerEngine.getAttributeId(i)] = _baseRatings[i];
    }
    final entries = _appliedCapBreakers.entries.toList();
    for (final entry in entries) {
      final attrIndex = entry.key;
      final count = entry.value.length;
      final newGains = _cbEngine.getChainedGains(
        attrIndex, _baseRatings[attrIndex],
        values: values, body: body, physicalCaps: _physicalCaps,
        count: count,
      );
      if (newGains.length == count) {
        _appliedCapBreakers[attrIndex] = newGains;
      } else {
        _appliedCapBreakers[attrIndex] = newGains;
      }
    }
  }

  List<int> getAttributeCaps() => _loader.getAttributeCaps(_position, _heightInches, _weightLb, _wingspanInches);
  List<int> getTokenBudget() => _loader.getTokenBudget(_position.name.toUpperCase(), _heightInches, _finalRatings);
  List<int> getSlotBudget() => _loader.getSlotBudget(_position.name.toUpperCase(), _heightInches, _finalRatings);

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


  // ── Lock methods (manual only, never auto-lock) ────────
  Map<int, int> get goalRatings => Map.unmodifiable(_goalRatings);
  Set<int> get goalActive => Set.unmodifiable(_goalActive);

  bool isAttributeLocked(int attrIndex) => _lockedAttributes.contains(attrIndex);

  void toggleAttributeLock(int attrIndex) {
    if (_lockedAttributes.contains(attrIndex)) {
      _lockedAttributes.remove(attrIndex);
    } else {
      _lockedAttributes.add(attrIndex);
    }
    notifyListeners();
  }

  bool canAdjustAttribute(int attrIndex) {
    if (_lockedAttributes.contains(attrIndex)) return false;
    if (_goalActive.contains(attrIndex)) return false;
    // Goal-constrained attributes can still be adjusted UP, just not below floor
    return true;
  }

  Set<int> get lockedAttributes => Set.unmodifiable(_lockedAttributes);

  // ── Goal methods ──────────────────────────────────────
  bool isGoalActive(int attrIndex) => _goalActive.contains(attrIndex);
  int? getGoalRating(int attrIndex) => _goalRatings[attrIndex];

  void toggleGoal(int attrIndex) {
    if (_goalActive.contains(attrIndex)) {
      _goalActive.remove(attrIndex);
    } else {
      _goalActive.add(attrIndex);
      if (!_goalRatings.containsKey(attrIndex)) {
        _goalRatings[attrIndex] = _baseRatings[attrIndex];
      }
    }
    notifyListeners();
  }

  void setGoalRating(int attrIndex, int value) {
    _goalRatings[attrIndex] = value;
    notifyListeners();
  }

  void confirmGoal(int attrIndex) {
    _goalActive.remove(attrIndex);
    notifyListeners();
  }

  void clearGoal(int attrIndex) {
    _goalRatings.remove(attrIndex);
    _goalActive.remove(attrIndex);
    notifyListeners();
  }

  // GoalData management methods
  void addGoalBadge(GoalBadge badge) {
    _goalData = _goalData.copyWith(
      badges: [..._goalData.badges, badge],
    );
    _applyGoalConstraintsFromBadgesMoves();
    notifyListeners();
  }

  void removeGoalBadge(int badgeId) {
    _goalData = _goalData.copyWith(
      badges: _goalData.badges.where((b) => b.badgeId != badgeId).toList(),
    );
    _applyGoalConstraintsFromBadgesMoves();
    notifyListeners();
  }

  void addGoalMove(GoalMove move) {
    _goalData = _goalData.copyWith(
      moves: [..._goalData.moves, move],
    );
    _applyGoalConstraintsFromBadgesMoves();
    notifyListeners();
  }

  void removeGoalMove(String moveId) {
    _goalData = _goalData.copyWith(
      moves: _goalData.moves.where((m) => m.moveId != moveId).toList(),
    );
    _applyGoalConstraintsFromBadgesMoves();
    notifyListeners();
  }

  bool hasGoalBadge(int badgeId) {
    return _goalData.badges.any((b) => b.badgeId == badgeId);
  }

  bool hasGoalMove(String moveId) {
    return _goalData.moves.any((m) => m.moveId == moveId);
  }

  /// Get the maximum attribute requirements across all goal badges and moves
  Map<int, int> getGoalAttributeRequirements() {
    return _goalData.getAttributeRequirements();
  }

  String? validateGoalBadge(int badgeId, int targetValue) {
    // Badge tiers: bronze(1), silver(2), gold(3), hallOfFame(4), legend(5)
    if (targetValue < 1 || targetValue > 5) {
      return 'Target value must be between 1 and 5';
    }
    return null;
  }
  String? validateGoalMove(String moveId, int targetValue) {
    // For moves, we need to check against the move's max value
    // This would depend on the move data structure
    // For now, return null (no validation)
    return null;
  }

  // ── Goal Attribute methods ────────────────────────────
  bool hasGoalAttribute(int attrIndex) {
    return _goalData.attributes.any((a) => a.attributeIndex == attrIndex);
  }

  void addGoalAttribute(GoalAttribute attr) {
    _goalData = _goalData.copyWith(
      attributes: [..._goalData.attributes, attr],
    );
    // Sync _goalActive and _goalRatings for UI display
    _goalActive.add(attr.attributeIndex);
    _goalRatings[attr.attributeIndex] = attr.targetValue;

    // Actually apply the goal value to _baseRatings and trigger constraint propagation
    final attrIndex = attr.attributeIndex;
    // Don't modify locked attributes
    if (_lockedAttributes.contains(attrIndex)) {
      notifyListeners();
      return;
    }
    final goalValue = attr.targetValue.clamp(25, _physicalCaps[attrIndex]);
    final oldValue = _baseRatings[attrIndex];
    _baseRatings[attrIndex] = goalValue;
    _userTouched[attrIndex] = true;

    if (goalValue < oldValue) {
      _propagateDown(attrIndex, goalValue);
    }

    _applyConstraintsAndOvrBudget(attrIndex, oldValue);
    _autoDowngradeBadges();
    _recalculateCapBreakerGains();
    _recalculateFinalRatings();

    // Snapshot floors: any attribute raised by constraint propagation is now goal-constrained
    for (int i = 0; i < 21; i++) {
      final existing = _goalConstrainedFloors[i] ?? 0;
      if (_baseRatings[i] > existing) {
        _goalConstrainedFloors[i] = _baseRatings[i];
      }
    }

    notifyListeners();
  }

  void removeGoalAttribute(int attrIndex) {
    _goalData = _goalData.copyWith(
      attributes: _goalData.attributes.where((a) => a.attributeIndex != attrIndex).toList(),
    );
    // Sync _goalActive and _goalRatings
    _goalActive.remove(attrIndex);
    _goalRatings.remove(attrIndex);
    // Recalculate constrained floors from remaining goals
    _recalculateGoalFloors();
    notifyListeners();
  }

  /// Apply attribute requirements from all goal badges/moves as real constraints
  void _applyGoalConstraintsFromBadgesMoves() {
    // First, remove old badge/move goal locks (for attributes not directly goal-locked)
    for (final attrIndex in _goalFromBadgesMoves.toList()) {
      if (!_goalData.attributes.any((a) => a.attributeIndex == attrIndex)) {
        // Not directly set as a Goal attribute - remove the lock
        _goalActive.remove(attrIndex);
        _goalRatings.remove(attrIndex);
      }
    }
    _goalFromBadgesMoves.clear();

    // Calculate combined attribute requirements from all badges/moves
    final combinedReqs = _goalData.getAttributeRequirements();

    // Apply each requirement
    for (final entry in combinedReqs.entries) {
      final attrIndex = entry.key;
      final requiredValue = entry.value.clamp(25, _physicalCaps[attrIndex]);

      // Skip if already directly goal-locked (direct Goal takes priority)
      if (_goalData.attributes.any((a) => a.attributeIndex == attrIndex)) continue;

      // Only apply if the requirement is higher than current rating
      // Don't modify locked attributes
      if (_lockedAttributes.contains(attrIndex)) continue;
      if (_baseRatings[attrIndex] < requiredValue || !_goalActive.contains(attrIndex)) {
        _goalActive.add(attrIndex);
        _goalRatings[attrIndex] = requiredValue;
        _goalFromBadgesMoves.add(attrIndex);

        final oldValue = _baseRatings[attrIndex];
        _baseRatings[attrIndex] = requiredValue;
        _userTouched[attrIndex] = true;

        _applyConstraintsAndOvrBudget(attrIndex, oldValue);
      } else if (_goalActive.contains(attrIndex) && _goalFromBadgesMoves.contains(attrIndex)) {
        // Already locked by badge/move, update value if needed
        _goalRatings[attrIndex] = requiredValue;
        _goalFromBadgesMoves.add(attrIndex);
      }
    }

    // Snapshot floors
    for (int i = 0; i < 21; i++) {
      final existing = _goalConstrainedFloors[i] ?? 0;
      if (_baseRatings[i] > existing) {
        _goalConstrainedFloors[i] = _baseRatings[i];
      }
    }

    _autoDowngradeBadges();
    _recalculateCapBreakerGains();
    _recalculateFinalRatings();
  }

  /// Recalculate goal-constrained floors from remaining active goals
  void _recalculateGoalFloors() {
    _goalConstrainedFloors.clear();
    if (_goalActive.isEmpty) return;
    
    // Save current ratings, temporarily remove all goals, restore, and reapply
    final savedBase = List<int>.from(_baseRatings);
    
    // Reset to defaults (25) and reapply each goal to calculate floors
    _baseRatings = List.filled(21, 25);
    
    for (final goalIndex in _goalActive) {
      final goalVal = _goalRatings[goalIndex] ?? 25;
      _baseRatings[goalIndex] = goalVal.clamp(25, _physicalCaps[goalIndex]);
      _applyConstraintsAndOvrBudget(goalIndex, 25);
    }
    
    // Snapshot floors: any attribute above 25 is goal-constrained
    for (int i = 0; i < 21; i++) {
      if (_baseRatings[i] > 25) {
        _goalConstrainedFloors[i] = _baseRatings[i];
      }
    }
    
    // Restore saved ratings
    _baseRatings = savedBase;
  }

  void updateGoalAttributeValue(int attrIndex, int newValue) {
    final attrs = _goalData.attributes.map((a) {
      if (a.attributeIndex == attrIndex) {
        return a.copyWith(targetValue: newValue);
      }
      return a;
    }).toList();
    _goalData = _goalData.copyWith(attributes: attrs);
    // Sync _goalRatings
    _goalRatings[attrIndex] = newValue;
    notifyListeners();
  }

  String? validateGoalAttribute(int attrIndex, int targetValue) {
    if (targetValue < 25) {
      return 'Minimum value is 25';
    }
    final caps = getAttributeCaps();
    if (attrIndex < caps.length && targetValue > caps[attrIndex]) {
      return 'Cannot exceed cap of ${caps[attrIndex]}';
    }
    return null;
  }
  // ── Cap breaker sequence ──────────────────────────────
  CapBreakerBody get capBreakerBody => CapBreakerBody(
    position: _position.name.toUpperCase(),
    height: _heightInches,
    weight: _weightLb,
    wingspan: _wingspanInches,
  );

  List<int> getCapBreakerSequence(int attrIndex, {int? attrCap}) {
    final values = <String, int>{};
    for (int i = 0; i < 21; i++) {
      // Always use BASE ratings for archetype matching (no cap breaker gains)
      values[CapBreakerEngine.getAttributeId(i)] = _baseRatings[i];
    }
    // Always use BASE value as starting point (gains are fixed from base)
    final currentValue = _baseRatings[attrIndex];
    // Use override cap if provided, otherwise use cached physical caps
    final caps = List<int>.from(_physicalCaps);
    if (attrCap != null) caps[attrIndex] = attrCap;
    return _cbEngine.getChainedGains(attrIndex, currentValue,
        values: values, body: capBreakerBody, physicalCaps: caps);
  }

}


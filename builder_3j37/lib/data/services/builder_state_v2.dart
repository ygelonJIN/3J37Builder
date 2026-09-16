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
  
  const AttributeState({
    required this.baseValue,
    required this.capBreakerGain,
    required this.baseCap,
  });
  
  /// Final value including cap breakers
  int get finalValue => baseValue + capBreakerGain;
  
  /// Whether this attribute has cap breakers applied
  bool get hasCapBreakers => capBreakerGain > 0;
  
  /// Available headroom before hitting base cap
  int get headroomBeforeCap => (baseCap - baseValue).clamp(0, 999);
  
  /// Whether more cap breakers can be applied (value < cap)
  bool get canApplyMoreCapBreakers => baseValue < baseCap;
}

class BuilderStateV2 extends ChangeNotifier {
  final DatasetLoader _loader = DatasetLoader();

  Position _position = Position.pg;
  int _heightInches = 75;
  int _weightLb = 185;
  int _wingspanInches = 75;

  // Base ratings (what user sets, within physical caps)
  List<int> _baseRatings = List.filled(21, 25);
  
  // Final ratings (base + cap breakers)
  List<int> _finalRatings = List.filled(21, 25);
  
  // Cap breaker state
  CapBreakerState _capBreakerState = CapBreakerState();
  
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
  CapBreakerState get capBreakerState => _capBreakerState;
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
    return AttributeState(
      baseValue: _baseRatings[attrIndex],
      capBreakerGain: _capBreakerState.getTotalGain(attrIndex),
      baseCap: _physicalCaps[attrIndex],
    );
  }

  /// 获取某个属性的完整 cap breaker 增益序列（链式逻辑）
  /// 
  /// 这是新的正确实现，每次增益基于前一次的结果
  List<int> getCapBreakerGainSequence(int attrIndex) {
    final engine = CapBreakerEngine();
    final values = <String, int>{};
    for (int i = 0; i < 21; i++) {
      values[CapBreakerEngine.getAttributeId(i)] = _baseRatings[i] + _capBreakerState.getTotalGain(i);
    }
    final body = CapBreakerBody(
      position: _position.name.toUpperCase(),
      height: _heightInches,
      weight: _weightLb,
      wingspan: _wingspanInches,
    );
    return engine.getChainedGains(attrIndex, _baseRatings[attrIndex], values: values, body: body, physicalCaps: _physicalCaps);
  }

  /// 获取某个属性的完整 cap breaker 应用结果
  /// 获取某个属性的完整增益序列
  List<int> getCapBreakerGains(int attrIndex) {
    final engine = CapBreakerEngine();
    final values = <String, int>{};
    for (int i = 0; i < 21; i++) {
      values[CapBreakerEngine.getAttributeId(i)] = _baseRatings[i] + _capBreakerState.getTotalGain(i);
    }
    final body = CapBreakerBody(
      position: _position.name.toUpperCase(),
      height: _heightInches,
      weight: _weightLb,
      wingspan: _wingspanInches,
    );
    return engine.getChainedGains(attrIndex, _baseRatings[attrIndex], values: values, body: body, physicalCaps: _physicalCaps);
  }

  /// 获取某个属性可用的增益序列（已应用的除外）
  List<int> getAvailableCapBreakerGains(int attrIndex) {
    final allGains = getCapBreakerGains(attrIndex);
    final appliedCount = _capBreakerState.getAppliedCount(attrIndex);
    if (appliedCount >= allGains.length) return [];
    return allGains.sublist(appliedCount);
  }

  /// Check if a cap breaker can be applied to an attribute
  bool canApplyCapBreaker(int attrIndex) {
    final appliedCount = _capBreakerState.getAppliedCount(attrIndex);
    if (appliedCount >= 5) return false;
    
    // 获取当前增益序列
    final gains = getCapBreakerGainSequence(attrIndex);
    if (appliedCount >= gains.length) return false;
    
    final gain = gains[appliedCount];
    final currentTotal = _capBreakerState.getTotalGain(attrIndex);
    
    // 检查是否会超过上限
    if (_baseRatings[attrIndex] + currentTotal + gain > _physicalCaps[attrIndex]) {
      return false;
    }
    
    return true;
  }

  /// Apply a cap breaker to an attribute
  /// 使用链式逻辑：每次应用的增益基于当前 rating
  bool applyCapBreaker(int attrIndex) {
    final appliedCount = _capBreakerState.getAppliedCount(attrIndex);
    
    // 获取当前增益序列
    final gains = getCapBreakerGainSequence(attrIndex);
    if (appliedCount >= gains.length) return false;
    
    final gain = gains[appliedCount];
    final currentTotal = _capBreakerState.getTotalGain(attrIndex);
    
    // 检查是否会超过上限
    if (_baseRatings[attrIndex] + currentTotal + gain > _physicalCaps[attrIndex]) {
      return false;
    }
    
    _capBreakerState.apply(attrIndex, gain);
    _recalculateFinalRatings();
    notifyListeners();
    return true;
  }

  /// Remove the last cap breaker from an attribute
  bool removeCapBreaker(int attrIndex) {
    final removed = _capBreakerState.removeLast(attrIndex);
    if (removed > 0) {
      _recalculateFinalRatings();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Remove all cap breakers from an attribute
  void clearCapBreakers(int attrIndex) {
    _capBreakerState.removeAll(attrIndex);
    _recalculateFinalRatings();
    notifyListeners();
  }

  /// Clear all cap breakers
  void removeAllCapBreakers(int attrIndex) {
    _capBreakerState.removeAll(attrIndex);
    _recalculateFinalRatings();
    notifyListeners();
  }

  void clearAllCapBreakers() {
    _capBreakerState.clear();
    _recalculateFinalRatings();
    notifyListeners();
  }

  void setPosition(Position p) {
    _position = p;
    _recalcAll();
    notifyListeners();
  }

  void setHeight(int h) {
    _heightInches = h;
    _recalcAll();
    notifyListeners();
  }

  void setWeight(int w) {
    _weightLb = w;
    _recalcAll();
    notifyListeners();
  }

  void setWingspan(int w) {
    _wingspanInches = w;
    _recalcAll();
    notifyListeners();
  }

  void setRating(int attrIndex, int value) {
    _baseRatings[attrIndex] = value.clamp(25, _physicalCaps[attrIndex]);
    _userTouched[attrIndex] = true;
    _recalculateFinalRatings();
    _enforceBadgeDowngrade();
    notifyListeners();
  }

  void _enforceBadgeDowngrade() {
    final badgesToDowngrade = <int, BadgeTier?>{};
    
    _equippedBadges.forEach((badgeId, currentTier) {
      if (currentTier != null) {
        final highestTier = _loader.getHighestQualifiedTier(badgeId, _finalRatings);
        final tierOrder = [BadgeTier.bronze, BadgeTier.silver, BadgeTier.gold, BadgeTier.hallOfFame];
        final currentIndex = tierOrder.indexOf(currentTier);
        final highestIndex = tierOrder.indexOf(highestTier!);
        
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
      final cbGain = _capBreakerState.getTotalGain(i);
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
    _capBreakerState.clear();
    
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
      'capBreakers': _capBreakerState.toJson(),
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
      _capBreakerState = CapBreakerState.fromJson(cbJson);
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

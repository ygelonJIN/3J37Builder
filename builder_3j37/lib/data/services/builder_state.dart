import 'package:flutter/foundation.dart';
import '../models/enums.dart';
import '../models/attribute.dart';
import '../models/badge_data.dart';
import 'dataset_loader.dart';
import 'tuning_parser.dart';

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

class BuilderState extends ChangeNotifier {
  final DatasetLoader _loader = DatasetLoader();

  Position _position = Position.pg;
  int _heightInches = 75;
  int _weightLb = 185;
  int _wingspanInches = 75;

  List<int> _userRatings = List.filled(21, 25);
  List<int> _ratings = List.filled(21, 25);
  List<bool> _userTouched = List.filled(21, false);

  Map<int, BadgeTier?> _equippedBadges = {};

  Position get position => _position;
  int get heightInches => _heightInches;
  int get weightLb => _weightLb;
  int get wingspanInches => _wingspanInches;
  List<int> get ratings => _ratings;
  List<bool> get userTouched => _userTouched;
  Map<int, BadgeTier?> get equippedBadges => _equippedBadges;

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

  int get overallRating => _loader.getOvr(_position, _heightInches, _ratings).round();

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
    final caps = getAttributeCaps();
    final newValue = value.clamp(25, caps[attrIndex]);
    if (_userRatings[attrIndex] == newValue) return;

    final oldValue = _userRatings[attrIndex];
    _userRatings[attrIndex] = newValue;
    _userTouched[attrIndex] = true;

    if (newValue < oldValue) {
      _propagateDown(attrIndex, newValue, caps);
    }

    _applyConstraintsAndOvrBudget(attrIndex, oldValue, caps);
    _autoDowngradeBadges();
    notifyListeners();
  }

  void _propagateDown(int attrIndex, int newValue, List<int> caps) {
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
        if (_userRatings[si] > maxSource) {
          _userRatings[si] = maxSource.clamp(25, caps[si]);
          _propagateDown(si, _userRatings[si], caps);
        }
      }
    }
  }

  void _applyConstraintsAndOvrBudget(int changedIndex, int oldValue, List<int> caps) {
    final constrained = _loader.tuning.applyConstraints(_heightInches, _userRatings);
    for (int i = 0; i < 21; i++) {
      _ratings[i] = constrained[i].clamp(25, caps[i]);
    }

    final ovr = _loader.getOvr(_position, _heightInches, _ratings);
    if (ovr >= 99.0) {
      _userRatings[changedIndex] = oldValue;
      final revertedConstrained = _loader.tuning.applyConstraints(_heightInches, _userRatings);
      for (int i = 0; i < 21; i++) {
        _ratings[i] = revertedConstrained[i].clamp(25, caps[i]);
      }
    }
  }

  /// 自动降级徽章：如果当前装备的等级不再满足要求，自动降到最高等级
  void _autoDowngradeBadges() {
    final badgesToDowngrade = <int, BadgeTier?>{};
    
    _equippedBadges.forEach((badgeId, currentTier) {
      if (currentTier == null) return;
      
      // 获取当前徽章的最高等级
      final highestTier = _loader.getHighestQualifiedTier(badgeId, _ratings);
      final badge = _loader.badgeDefinitions.firstWhere(
        (b) => b.badgeId == badgeId,
        orElse: () => BadgeDef(badgeId: badgeId, name: '', discipline: Discipline.finishing, group: 0, minHeight: 0, maxHeight: 99, allowed: false),
      );
      final meetsHeight = badge.isHeightEligible(_heightInches);
      
      if (highestTier == null || !meetsHeight) {
        // 如果没有满足的等级或身高不符合，卸装
        badgesToDowngrade[badgeId] = null;
      } else {
        // 检查当前等级是否仍然满足
        final tierOrder = [BadgeTier.bronze, BadgeTier.silver, BadgeTier.gold, BadgeTier.hallOfFame];
        final currentIndex = tierOrder.indexOf(currentTier);
        final highestIndex = tierOrder.indexOf(highestTier);
        
        if (currentIndex > highestIndex) {
          // 当前等级高于最高等级，降级
          badgesToDowngrade[badgeId] = highestTier;
        }
      }
    });
    
    // 应用降级
    badgesToDowngrade.forEach((badgeId, newTier) {
      if (newTier == null) {
        _equippedBadges.remove(badgeId);
      } else {
        _equippedBadges[badgeId] = newTier;
      }
    });
  }

  List<int> getAttributeCaps() => _loader.getAttributeCaps(_position, _heightInches, _weightLb, _wingspanInches);
  List<int> getTokenBudget() => _loader.getTokenBudget(_heightInches, _ratings);

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
    final budget = getTokenBudget(); final spent = getTokensSpent();
    return List.generate(6, (i) => (budget[i] - spent[i]).clamp(0, 999));
  }

  List<BadgeStatus> getBadgeStatuses() {
    return _loader.badgeDefinitions.map((badge) {
      final highestTier = _loader.getHighestQualifiedTier(badge.badgeId, _ratings);
      final equipped = _equippedBadges[badge.badgeId];
      return BadgeStatus(badge: badge, highestTier: highestTier, equippedTier: equipped, heightEligible: badge.isHeightEligible(_heightInches));
    }).toList();
  }

  bool equipBadge(int badgeId, BadgeTier? tier) {
    if (tier == null) {
      _equippedBadges.remove(badgeId);
      notifyListeners();
      return true;
    }
    
    final cost = _loader.getBadgeTokenCost(badgeId, tier, _heightInches);
    final badge = _loader.badgeDefinitions.firstWhere((b) => b.badgeId == badgeId, orElse: () => BadgeDef(badgeId: badgeId, name: '', discipline: Discipline.finishing, group: 0, minHeight: 0, maxHeight: 99, allowed: false));
    if (getTokensRemaining()[badge.discipline.index] < cost) return false;
    _equippedBadges[badgeId] = tier; 
    notifyListeners(); 
    return true;
  }

  void _recalcAll() {
    _userRatings = List.filled(21, 25);
    _userTouched = List.filled(21, false);
    _equippedBadges = {};
    final constrained = _loader.tuning.applyConstraints(_heightInches, _userRatings);
    final caps = getAttributeCaps();
    for (int i = 0; i < 21; i++) {
      _ratings[i] = constrained[i].clamp(25, caps[i]);
    }
  }
}

import 'package:flutter/foundation.dart';
import '../models/enums.dart';
import '../models/badge_data.dart';
import '../models/goal_data.dart';
import 'dataset_loader.dart';
import 'cap_breaker_engine.dart';
import 'website_logic.dart' as website_logic;

class BuilderState extends ChangeNotifier {
  final DatasetLoader _loader = DatasetLoader();
  Position _position = Position.pg;
  int _heightInches = 75;
  int _weightLb = 198;
  int _wingspanInches = 78;
  late List<int> _userRatings;  // what the user explicitly set
  late List<int> _ratings;      // final ratings after constraints
  final Map<int, BadgeTier?> _equippedBadges = {};
  final Set<int> _lockedAttributes = {}; // 锁定的属性索引
  final Map<int, List<int>> _appliedCapBreakers = {}; // attrIndex -> list of gains
  final CapBreakerEngine _cbEngine = CapBreakerEngine();
  
  // Goal state
  GoalData _goalData = const GoalData();

  Position get position => _position;
  int get heightInches => _heightInches;
  int get weightLb => _weightLb;
  int get wingspanInches => _wingspanInches;
  List<int> get ratings => List.unmodifiable(_ratings);
  Map<int, BadgeTier?> get equippedBadges => Map.unmodifiable(_equippedBadges);
  Set<int> get lockedAttributes => Set.unmodifiable(_lockedAttributes);
  GoalData get goalData => _goalData;
  DatasetLoader get loader => _loader;

  BuilderState() {
    _userRatings = List.filled(21, 25);
    _ratings = List.filled(21, 25);
    final lb = _loader.getLegalBody(_position);
    if (lb != null) {
      _heightInches = lb.defaultHeight;
      final br = _loader.getBodyRange(_position, _heightInches);
      if (br != null) { _weightLb = br.defaultWeight; _wingspanInches = br.defaultWingspan; }
    }
  }

  void setPosition(Position pos) {
    if (_position == pos) return;
    _position = pos; _equippedBadges.clear();
    final lb = _loader.getLegalBody(pos);
    if (lb != null) {
      _heightInches = lb.defaultHeight.clamp(lb.minHeight, lb.maxHeight);
      final br = _loader.getBodyRange(pos, _heightInches);
      if (br != null) { _weightLb = br.defaultWeight; _wingspanInches = br.defaultWingspan; }
    }
    _userRatings = List.filled(21, 25);
    _ratings = List.filled(21, 25);
    _lockedAttributes.clear();
    _goalData = const GoalData(); // Reset goal data when position changes
    notifyListeners();
  }

  void setHeight(int inches) {
    if (_heightInches == inches) return;
    _heightInches = inches; _equippedBadges.clear();
    final br = _loader.getBodyRange(_position, inches);
    if (br != null) { _weightLb = _weightLb.clamp(br.minWeight, br.maxWeight); _wingspanInches = _wingspanInches.clamp(br.minWingspan, br.maxWingspan); }
    notifyListeners();
  }

  void setWeight(int lb) { if (_weightLb == lb) return; _weightLb = lb; notifyListeners(); }
  void setWingspan(int inches) { if (_wingspanInches == inches) return; _wingspanInches = inches; notifyListeners(); }

  void toggleAttributeLock(int attrIndex) {
    if (_lockedAttributes.contains(attrIndex)) {
      _lockedAttributes.remove(attrIndex);
    } else {
      _lockedAttributes.add(attrIndex);
    }
    notifyListeners();
  }

  bool isAttributeLocked(int attrIndex) {
    return _lockedAttributes.contains(attrIndex);
  }

  bool canAdjustAttribute(int attrIndex) {
    return !_lockedAttributes.contains(attrIndex);
  }

  // Goal management methods
  void updateGoalBadges(List<GoalBadge> badges) {
    _goalData = _goalData.copyWith(badges: badges);
    notifyListeners();
  }

  void updateGoalMoves(List<GoalMove> moves) {
    _goalData = _goalData.copyWith(moves: moves);
    notifyListeners();
  }

  void addGoalBadge(GoalBadge badge) {
    final updatedBadges = List<GoalBadge>.from(_goalData.badges)..add(badge);
    _goalData = _goalData.copyWith(badges: updatedBadges);
    notifyListeners();
  }

  void removeGoalBadge(int badgeId) {
    final updatedBadges = _goalData.badges.where((b) => b.badgeId != badgeId).toList();
    _goalData = _goalData.copyWith(badges: updatedBadges);
    notifyListeners();
  }

  void addGoalMove(GoalMove move) {
    final updatedMoves = List<GoalMove>.from(_goalData.moves)..add(move);
    _goalData = _goalData.copyWith(moves: updatedMoves);
    notifyListeners();
  }

  void removeGoalMove(String moveId) {
    final updatedMoves = _goalData.moves.where((m) => m.moveId != moveId).toList();
    _goalData = _goalData.copyWith(moves: updatedMoves);
    notifyListeners();
  }

  bool hasGoalBadge(int badgeId) {
    return _goalData.badges.any((b) => b.badgeId == badgeId);
  }

  bool hasGoalMove(String moveId) {
    return _goalData.moves.any((m) => m.moveId == moveId);
  }

  GoalBadge? getGoalBadge(int badgeId) {
    try {
      return _goalData.badges.firstWhere((b) => b.badgeId == badgeId);
    } catch (e) {
      return null;
    }
  }

  GoalMove? getGoalMove(String moveId) {
    try {
      return _goalData.moves.firstWhere((m) => m.moveId == moveId);
    } catch (e) {
      return null;
    }
  }

  String? validateGoalBadge(int badgeId, int targetValue) {
    final badge = _loader.badgeDefinitions.firstWhere(
      (b) => b.badgeId == badgeId,
      orElse: () => BadgeDef(badgeId: badgeId, name: '', discipline: Discipline.finishing, group: 0, minHeight: 0, maxHeight: 99, allowed: false),
    );
    
    // Check height eligibility
    if (!badge.isHeightEligible(_heightInches)) {
      return 'Badge not eligible for current height';
    }
    
    // Check if badge is allowed
    if (!badge.allowed) {
      return 'Badge not allowed';
    }
    
    // Check if target value exceeds cap
    final highestTier = _loader.getHighestQualifiedTier(badgeId, _ratings);
    if (highestTier != null) {
      final tierIndex = BadgeTier.values.indexOf(highestTier);
      final targetTierIndex = BadgeTier.values.indexOf(BadgeTierX.fromKey(targetValue.toString()));
      if (targetTierIndex > tierIndex) {
        return 'Target tier exceeds maximum unlocked tier';
      }
    }
    
    return null;
  }

  String? validateGoalMove(String moveId, int targetValue) {
    // This would need to be implemented based on move validation logic
    // For now, return null (no error)
    return null;
  }

  /// 验证属性修改是否会违反锁定属性的约束
  /// 返回错误信息字符串，如果合法则返回null
  String? validateRatingChange(int attrIndex, int newValue) {
    if (_lockedAttributes.isEmpty) return null;
    
    final caps = getAttributeCaps();
    final clampedValue = newValue.clamp(25, caps[attrIndex]);
    
    // 构建当前值映射
    final values = <String, int>{};
    for (int i = 0; i < 21; i++) {
      values[website_logic.attrIds[i]] = _userRatings[i];
    }
    values[website_logic.attrIds[attrIndex]] = clampedValue;
    
    final body = {'height': _heightInches, 'weight': _weightLb, 'wingspan': _wingspanInches, 'position': _position.name.toUpperCase()};
    final capsMap = <String, int>{};
    for (int i = 0; i < 21; i++) {
      capsMap[website_logic.attrIds[i]] = caps[i];
    }
    
    // 应用约束
    final result = website_logic.applyConstraints(
      values: values,
      changedAttrId: website_logic.attrIds[attrIndex],
      body: body,
      loader: _loader,
      caps: capsMap,
    );
    
    final constrained = result['values'] as Map<String, int>;
    
    // 检查是否有锁定属性被违反
    for (int i = 0; i < 21; i++) {
      if (_lockedAttributes.contains(i)) {
        final lockedValue = _userRatings[i];
        final constrainedValue = (constrained[website_logic.attrIds[i]] ?? 25).clamp(25, caps[i]);
        
        if (constrainedValue != lockedValue) {
          final attrName = _loader.attributes[i].displayName;
          return '$attrName已锁定';
        }
      }
    }
    
    return null;
  }

  void setRating(int attrIndex, int value) {
    // 检查是否锁定
    if (_lockedAttributes.contains(attrIndex)) {
      debugPrint('[BuilderState] Attribute $attrIndex is locked, ignoring setRating');
      return;
    }

    final caps = getAttributeCaps();
    final newValue = value.clamp(25, caps[attrIndex]);
    if (_userRatings[attrIndex] == newValue) return;

    final oldValue = _userRatings[attrIndex];
    _userRatings[attrIndex] = newValue;
    debugPrint('[BuilderState] setRating $attrIndex: $oldValue -> $newValue');

    // Bidirectional constraint propagation:
    if (newValue < oldValue) {
      debugPrint('[BuilderState] Propagating down from $attrIndex');
      _propagateDown(attrIndex, newValue, caps);
    }

    _applyConstraintsAndBudget(caps, changedAttrIndex: attrIndex);
    
    
    notifyListeners();
  }

  /// When user lowers a constrained attribute, also lower the source attributes
  /// that were forcing it up.
  void _propagateDown(int attrIndex, int newValue, List<int> caps) {
    // 使用网站逻辑的约束传播
    final values = <String, int>{};
    for (int i = 0; i < 21; i++) {
      values[website_logic.attrIds[i]] = _userRatings[i];
    }
    values[website_logic.attrIds[attrIndex]] = newValue;
    
    final body = {'height': _heightInches, 'weight': _weightLb, 'wingspan': _wingspanInches, 'position': _position.name.toUpperCase()};
    final capsMap = <String, int>{};
    for (int i = 0; i < 21; i++) {
      capsMap[website_logic.attrIds[i]] = caps[i];
    }
    
    final result = website_logic.applyConstraints(
      values: values,
      changedAttrId: website_logic.attrIds[attrIndex],
      body: body,
      loader: _loader,
      caps: capsMap,
    );
    
    final newValues = result['values'] as Map<String, int>;
    for (int i = 0; i < 21; i++) {
      if (!_lockedAttributes.contains(i)) {
        _userRatings[i] = (newValues[website_logic.attrIds[i]] ?? 25).clamp(25, caps[i]);
      }
    }
  }

  void _applyConstraintsAndBudget(List<int> caps, {int changedAttrIndex = -1}) {
    // 直接从 _userRatings 同步到 _ratings
    for (int i = 0; i < 21; i++) {
      _ratings[i] = _userRatings[i].clamp(25, caps[i]);
    }

    final body = {'height': _heightInches, 'weight': _weightLb, 'wingspan': _wingspanInches, 'position': _position.name.toUpperCase()};
    final capsMap = <String, int>{};
    for (int i = 0; i < 21; i++) {
      capsMap[website_logic.attrIds[i]] = caps[i];
    }
  }

  List<int> getCapBreakerGain() {
    return List.generate(21, (i) {
      final gains = _appliedCapBreakers[i];
      if (gains == null || gains.isEmpty) return 0;
      return gains.reduce((a, b) => a + b);
    });
  }

  int getCapBreakerGainForAttr(int attrIndex) {
    final gains = _appliedCapBreakers[attrIndex];
    if (gains == null || gains.isEmpty) return 0;
    return gains.reduce((a, b) => a + b);
  }

  int getAppliedCapBreakerCount(int attrIndex) {
    final gains = _appliedCapBreakers[attrIndex];
    return gains?.length ?? 0;
  }

  bool applyCapBreaker(int attrIndex, int gain) {
    if (!_cbEngine.hasModelData) return false;
    final appliedCount = _appliedCapBreakers[attrIndex]?.length ?? 0;
    if (appliedCount >= CapBreakerConstants.maxPerAttribute) return false;
    
    _appliedCapBreakers[attrIndex] ??= [];
    _appliedCapBreakers[attrIndex]!.add(gain);
    notifyListeners();
    return true;
  }

  bool removeCapBreaker(int attrIndex) {
    final gains = _appliedCapBreakers[attrIndex];
    if (gains == null || gains.isEmpty) return false;
    gains.removeLast();
    if (gains.isEmpty) _appliedCapBreakers.remove(attrIndex);
    notifyListeners();
    return true;
  }

  void removeAllCapBreakers(int attrIndex) {
    _appliedCapBreakers.remove(attrIndex);
    notifyListeners();
  }

  void clearAllCapBreakers() {
    _appliedCapBreakers.clear();
    notifyListeners();
  }

  List<int> getCapBreakerSequence(int attrIndex) {
    if (!_cbEngine.hasModelData) return [];
    final values = <String, int>{};
    for (int i = 0; i < 21; i++) {
      // Always use BASE ratings for archetype matching (no cap breaker gains)
      values[CapBreakerEngine.getAttributeId(i)] = _ratings[i];
    }
    return _cbEngine.getChainedGains(attrIndex, _ratings[attrIndex], values: values, body: capBreakerBody, physicalCaps: getAttributeCaps());
  }

  CapBreakerBody get capBreakerBody => CapBreakerBody(
    position: _position.name.toUpperCase(),
    height: _heightInches,
    weight: _weightLb,
    wingspan: _wingspanInches,
  );

  List<int> getAttributeCapsWithBreakers() {
    final caps = getAttributeCaps();
    return caps;
  }

  // Get final ratings including cap breaker gains
  List<int> get finalRatings {
    final result = List<int>.from(_ratings);
    final caps = getAttributeCaps();
    for (int i = 0; i < 21; i++) {
      result[i] = (_ratings[i] + getCapBreakerGainForAttr(i)).clamp(25, caps[i]);
    }
    return result;
  }

  List<int> getAttributeCaps() {
    final body = {'height': _heightInches, 'weight': _weightLb, 'wingspan': _wingspanInches, 'position': _position.name.toUpperCase()};
    final capsMap = website_logic.getCaps(body, _loader);
    return List.generate(21, (i) => capsMap[website_logic.attrIds[i]] ?? 99);
  }
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
    _equippedBadges[badgeId] = tier; notifyListeners(); return true;
  }

  void unequipBadge(int badgeId) { _equippedBadges.remove(badgeId); notifyListeners(); }

  int get overallRating {
    final body = {'height': _heightInches, 'weight': _weightLb, 'wingspan': _wingspanInches, 'position': _position.name.toUpperCase()};
    final values = <String, int>{};
    final finalVals = finalRatings;
    for (int i = 0; i < 21; i++) {
      values[website_logic.attrIds[i]] = finalVals[i];
    }
    return website_logic.calculateOvr(values, body, _loader).round().clamp(25, 99);
  }
  String get heightDisplay { final f = _heightInches ~/ 12; final i = _heightInches % 12; final cm = (_heightInches * 2.54).round(); return "$f'$i\" / ${cm}cm"; }
  String get weightDisplay { final kg = (_weightLb * 0.453592).round(); return '$_weightLb lbs / ${kg}kg'; }
  String get wingspanDisplay { final f = _wingspanInches ~/ 12; final i = _wingspanInches % 12; final cm = (_wingspanInches * 2.54).round(); return "$f'$i\" / ${cm}cm"; }

}

class BadgeStatus {
  final BadgeDef badge;
  final BadgeTier? highestTier;
  final BadgeTier? equippedTier;
  final bool heightEligible;
  const BadgeStatus({required this.badge, this.highestTier, this.equippedTier, required this.heightEligible});
  bool get isUnlocked => highestTier != null && heightEligible;
  bool get isEquipped => equippedTier != null;
}

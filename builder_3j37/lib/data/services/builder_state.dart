import 'package:flutter/foundation.dart';
import '../models/enums.dart';
import '../models/badge_data.dart';
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

  Position get position => _position;
  int get heightInches => _heightInches;
  int get weightLb => _weightLb;
  int get wingspanInches => _wingspanInches;
  List<int> get ratings => List.unmodifiable(_ratings);
  Map<int, BadgeTier?> get equippedBadges => Map.unmodifiable(_equippedBadges);
  Set<int> get lockedAttributes => Set.unmodifiable(_lockedAttributes);

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

    _applyConstraintsAndBudget(caps);
    
    
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

  void _applyConstraintsAndBudget(List<int> caps) {
    // 使用网站逻辑的约束传播
    final body = {'height': _heightInches, 'weight': _weightLb, 'wingspan': _wingspanInches, 'position': _position.name.toUpperCase()};
    final capsMap = <String, int>{};
    for (int i = 0; i < 21; i++) {
      capsMap[website_logic.attrIds[i]] = caps[i];
    }
    
    // 对每个属性应用约束
    final values = <String, int>{};
    for (int i = 0; i < 21; i++) {
      values[website_logic.attrIds[i]] = _userRatings[i];
    }
    
    // 应用所有约束
    Map<String, int> constrained = Map.from(values);
    for (int i = 0; i < 21; i++) {
      final result = website_logic.applyConstraints(
        values: constrained,
        changedAttrId: website_logic.attrIds[i],
        body: body,
        loader: _loader,
        caps: capsMap,
      );
      constrained = Map.from(result['values'] as Map<String, int>);
    }
    
    for (int i = 0; i < 21; i++) {
      _ratings[i] = (constrained[website_logic.attrIds[i]] ?? 25).clamp(25, caps[i]);
    }

    // Check OVR budget
    final ovr = website_logic.calculateOvr(_ratings.asMap().map((k, v) => MapEntry(website_logic.attrIds[k], v)), body, _loader);
    if (ovr >= 99.0) {
      for (int i = 0; i < 21; i++) {
        if (_userRatings[i] > 25 && !_lockedAttributes.contains(i)) {
          int lo = 25, hi = _userRatings[i], best = 25;
          while (lo <= hi) {
            final mid = (lo + hi) ~/ 2;
            _userRatings[i] = mid;
            final testValues = <String, int>{};
            for (int j = 0; j < 21; j++) {
              testValues[website_logic.attrIds[j]] = _userRatings[j];
            }
            Map<String, int> testConstrained = Map.from(testValues);
            for (int j = 0; j < 21; j++) {
              final result = website_logic.applyConstraints(
                values: testConstrained,
                changedAttrId: website_logic.attrIds[j],
                body: body,
                loader: _loader,
                caps: capsMap,
              );
              testConstrained = Map.from(result['values'] as Map<String, int>);
            }
            for (int j = 0; j < 21; j++) { _ratings[j] = (testConstrained[website_logic.attrIds[j]] ?? 25).clamp(25, caps[j]); }
            final testOvr = website_logic.calculateOvr(_ratings.asMap().map((k, v) => MapEntry(website_logic.attrIds[k], v)), body, _loader);
            if (testOvr < 99.0) { best = mid; lo = mid + 1; } else { hi = mid - 1; }
          }
          _userRatings[i] = best;
        }
      }
      // Recompute final ratings
      final finalValues = <String, int>{};
      for (int i = 0; i < 21; i++) {
        finalValues[website_logic.attrIds[i]] = _userRatings[i];
      }
      Map<String, int> finalConstrained = Map.from(finalValues);
      for (int i = 0; i < 21; i++) {
        final result = website_logic.applyConstraints(
          values: finalConstrained,
          changedAttrId: website_logic.attrIds[i],
          body: body,
          loader: _loader,
          caps: capsMap,
        );
        finalConstrained = Map.from(result['values'] as Map<String, int>);
      }
      for (int i = 0; i < 21; i++) { _ratings[i] = (finalConstrained[website_logic.attrIds[i]] ?? 25).clamp(25, caps[i]); }
    }
  }

  // ===== Cap Breaker Methods =====

  int get totalCapBreakersApplied {
    return _appliedCapBreakers.values.fold(0, (sum, gains) => sum + gains.length);
  }

  bool get hasAnyCapBreakers => _appliedCapBreakers.isNotEmpty;

  int get capBreakerGainTotal {
    return _appliedCapBreakers.values.fold(0, (sum, gains) => sum + gains.fold(0, (s, g) => s + g));
  }

  int getCapBreakerGain(int attrIndex) {
    final gains = _appliedCapBreakers[attrIndex];
    if (gains == null || gains.isEmpty) return 0;
    return gains.fold(0, (sum, g) => sum + g);
  }

  int getAppliedCapBreakerCount(int attrIndex) {
    return _appliedCapBreakers[attrIndex]?.length ?? 0;
  }

  int? getNextCapBreakerGain(int attrIndex) {
    final appliedCount = _appliedCapBreakers[attrIndex]?.length ?? 0;
    if (appliedCount >= 5) return null;
    final currentRating = _ratings[attrIndex] + getCapBreakerGain(attrIndex);
    final physCaps = getAttributeCaps();
    if (currentRating >= physCaps[attrIndex]) return null;
    // Build current values map for model-based calculation
    final values = <String, int>{};
    for (int i = 0; i < 21; i++) {
      values[CapBreakerEngine.getAttributeId(i)] = _ratings[i] + getCapBreakerGain(i);
    }
    return _cbEngine.getNextGain(attrIndex, currentRating, appliedCount, values: values, body: capBreakerBody, physicalCaps: physCaps);
  }

  bool canApplyCapBreaker(int attrIndex) {
    return getNextCapBreakerGain(attrIndex) != null;
  }

  bool applyCapBreaker(int attrIndex) {
    final gain = getNextCapBreakerGain(attrIndex);
    if (gain == null) return false;
    _appliedCapBreakers.putIfAbsent(attrIndex, () => []);
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
      values[CapBreakerEngine.getAttributeId(i)] = _ratings[i] + getCapBreakerGain(i);
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
    for (int i = 0; i < 21; i++) {
      result[i] = (_ratings[i] + getCapBreakerGain(i)).clamp(25, 99);
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
    for (int i = 0; i < 21; i++) {
      values[website_logic.attrIds[i]] = _ratings[i];
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

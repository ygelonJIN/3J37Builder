import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/enums.dart';
import '../models/attribute.dart';
import '../models/badge_data.dart';
import '../models/takeover_data.dart';
import '../models/animation_data.dart';
import 'tuning_parser.dart';

class DatasetLoaderV2 {
  static final DatasetLoaderV2 _instance = DatasetLoaderV2._();
  factory DatasetLoaderV2() => _instance;
  DatasetLoaderV2._();

  static final TuningParser tuningParser = TuningParser();
  TuningParser get tuning => tuningParser;

  List<AttributeDef> attributes = [];
  List<LegalBody> legalBodies = [];
  List<BadgeDef> badgeDefinitions = [];
  List<BadgeTierRequirement> tierRequirements = [];
  Map<TokenCostKey, int> tokenCostMap = {};
  Map<TokenKey, TokenContribution> tokenContribMap = {};
  List<TakeoverAbility> takeovers = [];
  List<AnimTab> animTabs = [];

  // Cap Breakers data - structured for efficient lookup
  // Key: '$scenario-$attributeIndex-$rating' -> List of5 gains
  Map<String, List<int>> _capBreakerGainsMap = {};
  
  // Also store by attribute for quick access
  // Key: attributeIndex -> Map<rating, Map<scenario, List<int>>>
  Map<int, Map<int, Map<String, List<int>>>> _capBreakerByAttr = {};

  bool _essentialLoaded = false;
  bool _heavyLoaded = false;

  bool get isLoaded => _essentialLoaded && _heavyLoaded;
  bool get isEssentialLoaded => _essentialLoaded;

  /// Get cap breaker gains for an attribute at a specific rating
  /// Returns a list of 5 gains (one for each application)
  /// Uses near_caps scenario by default, falls back to isolated
  List<int> getCapBreakerGains(int attributeIndex, int rating, {String scenario = 'near_caps'}) {
    // Try to get from the structured map first
    final key = '$scenario-$attributeIndex-$rating';
    if (_capBreakerGainsMap.containsKey(key)) {
      return _capBreakerGainsMap[key]!;
    }
    
    // Fallback to isolated scenario
    final fallbackKey = 'isolated-$attributeIndex-$rating';
    if (_capBreakerGainsMap.containsKey(fallbackKey)) {
      return _capBreakerGainsMap[fallbackKey]!;
    }
    
    // If no data found, return empty (no cap breakers available for this rating)
    return [];
  }

  /// Get all available cap breaker gains for an attribute
  /// Returns a map of rating -> list of 5 gains
  Map<int, List<int>> getAllCapBreakerGains(int attributeIndex, {String scenario = 'near_caps'}) {
    final result = <int, List<int>>{};
    
    _capBreakerGainsMap.forEach((key, gains) {
      final parts = key.split('-');
      if (parts.length == 3) {
        final attr = int.tryParse(parts[1]);
        final rating = int.tryParse(parts[2]);
        if (attr == attributeIndex && parts[0] == scenario) {
          result[rating!] = gains;
        }
      }
    });
    
    return result;
  }

  /// Phase 1: Load essential data + tuning file
  Future<void> loadEssential() async {
    if (_essentialLoaded) return;
    debugPrint('[DatasetLoaderV2] loadEssential START');

    try {
      final results = await Future.wait([
        _loadJson('assets/data/attributes.json'),
        _loadJson('assets/data/legal_bodies.json'),
        _loadJson('assets/data/definitions.json'),
        _loadJson('assets/data/tier_requirements.json'),
        _loadJson('assets/data/requirements.json'),
        _loadJson('assets/data/token_costs.json'),
        rootBundle.loadString('assets/data/progression_attributes.txt'),
      ]);

      final attrJson = results[0] as Map<String, dynamic>;
      final bodyJson = results[1] as Map<String, dynamic>;
      final defJson = results[2] as Map<String, dynamic>;
      final tierJson = results[3] as Map<String, dynamic>;
      final takeoverJson = results[4] as Map<String, dynamic>;
      final costJson = results[5] as Map<String, dynamic>;

      attributes = (attrJson['data'] as List).map((a) => AttributeDef.fromJson(a)).toList();
      legalBodies = (bodyJson['data'] as List).map((b) => LegalBody.fromJson(b)).toList();
      badgeDefinitions = (defJson['data'] as List).map((b) => BadgeDef.fromJson(b)).toList();
      tierRequirements = (tierJson['data'] as List).map((t) => BadgeTierRequirement.fromJson(t)).toList();
      takeovers = (takeoverJson['data'] as List).map((t) => TakeoverAbility.fromJson(t)).toList();

      for (final c in (costJson['data'] as List)) {
        final tc = BadgeTokenCost.fromJson(c);
        tokenCostMap[TokenCostKey(tc.badgeId, tc.tier, tc.heightInches)] = tc.cost;
      }

      final tuningContent = results[6] as String;
      debugPrint('[DatasetLoaderV2] Tuning content length: ${tuningContent.length}');
      tuning.parse(tuningContent);
      tuning.finalize();
      debugPrint('[DatasetLoaderV2] Tuning parsed: ${tuning.heightMultiplier.length} height entries');

      _essentialLoaded = true;
      debugPrint('[DatasetLoaderV2] loadEssential DONE');
    } catch (e, st) {
      debugPrint('[DatasetLoaderV2] loadEssential ERROR: $e');
      debugPrint('[DatasetLoaderV2] Stack: $st');
      _essentialLoaded = true;
    }
  }

  /// Phase 2: Load heavy JSON
  Future<void> loadHeavy() async {
    if (_heavyLoaded) return;
    debugPrint('[DatasetLoaderV2] loadHeavy START');

    // Load token contributions
    try {
      final contribStr = await rootBundle.loadString('assets/data/token_contributions.json');
      debugPrint('[DatasetLoaderV2] token_contributions loaded: ${contribStr.length} bytes');
      final contribJson = json.decode(contribStr) as Map<String, dynamic>;
      final contribList = contribJson['data'] as List;
      for (final c in contribList) {
        final tc = TokenContribution.fromJson(c);
        tokenContribMap[TokenKey(tc.heightInches, tc.attributeIndex, tc.rating)] = tc;
      }
      debugPrint('[DatasetLoaderV2] ${tokenContribMap.length} token contributions parsed');
    } catch (e, st) {
      debugPrint('[DatasetLoaderV2] token_contributions ERROR (non-fatal): $e');
      debugPrint('[DatasetLoaderV2] Stack: $st');
    }

    // Load cap breakers gains - this is the key data for cap breakers
    try {
      final gainsStr = await rootBundle.loadString('assets/data/gains_by_rating.json');
      debugPrint('[DatasetLoaderV2] gains_by_rating loaded: ${gainsStr.length} bytes');
      final gainsJson = json.decode(gainsStr) as Map<String, dynamic>;
      final gainsList = gainsJson['data'] as List;
      
      // Parse into our efficient lookup structure
      _capBreakerGainsMap.clear();
      _capBreakerByAttr.clear();
      
      // Temporary structure to group by (scenario, attribute, rating)
      final grouped = <String, List<Map<String, dynamic>>>{};
      
      for (final g in gainsList) {
        try {
          final scenario = g['scenario'] as String;
          final attribute = g['attribute'] as int;
          final rating = g['rating'] as int;
          final application = g['application'] as int;
          final gain = g['gain'] as int;
          
          final key = '$scenario-$attribute-$rating';
          grouped.putIfAbsent(key, () => []);
          grouped[key]!.add({
            'application': application,
            'gain': gain,
          });
        } catch (e) {
          debugPrint('[DatasetLoaderV2] Error parsing gain entry: $e');
        }
      }
      
      // Convert to our map structure (sorted by application index)
      grouped.forEach((key, entries) {
        entries.sort((a, b) => (a['application'] as int).compareTo(b['application'] as int));
        final gains = entries.map((e) => e['gain'] as int).toList();
        _capBreakerGainsMap[key] = gains;
        
        // Also populate the by-attribute structure
        final parts = key.split('-');
        if (parts.length == 3) {
          final scenario = parts[0];
          final attrIndex = int.parse(parts[1]);
          final rating = int.parse(parts[2]);
          
          _capBreakerByAttr.putIfAbsent(attrIndex, () => {});
          _capBreakerByAttr[attrIndex]!.putIfAbsent(rating, () => {});
          _capBreakerByAttr[attrIndex]![rating]![scenario] = gains;
        }
      });
      
      debugPrint('[DatasetLoaderV2] ${_capBreakerGainsMap.length} cap breaker gain entries parsed');
      debugPrint('[DatasetLoaderV2] Cap breaker data for ${_capBreakerByAttr.length} attributes');
    } catch (e, st) {
      debugPrint('[DatasetLoaderV2] gains_by_rating ERROR (non-fatal): $e');
      debugPrint('[DatasetLoaderV2] Stack: $st');
    }

    _heavyLoaded = true;
    debugPrint('[DatasetLoaderV2] loadHeavy DONE');
  }

  Future<Map<String, dynamic>> _loadJson(String path) async {
    final str = await rootBundle.loadString(path);
    return json.decode(str) as Map<String, dynamic>;
  }

  LegalBody? getLegalBody(Position pos) {
    try {
      return legalBodies.firstWhere((b) => b.position == pos);
    } catch (_) {
      return null;
    }
  }

  BodyRange? getBodyRange(Position pos, int heightInches) {
    try {
      final legal = getLegalBody(pos);
      if (legal == null) return null;
      return BodyRange(
        heightInches: heightInches,
        minWeight: 150,
        maxWeight: 300,
        defaultWeight: 185,
        minWingspan: heightInches,
        maxWingspan: heightInches + 6,
        defaultWingspan: heightInches + 3,
      );
    } catch (_) {
      return null;
    }
  }

  List<int> getAttributeCaps(Position pos, int heightInches, int weightLb, int wingspanInches) {
    return tuning.computeAttributeCaps(heightInches, weightLb, wingspanInches);
  }

  List<int> getTokenBudget(int heightInches, List<int> ratings) {
    final budget = List.filled(6, 0);
    for (int i = 0; i < 21; i++) {
      final key = TokenKey(heightInches, i, ratings[i]);
      final contrib = tokenContribMap[key];
      if (contrib != null) {
        for (int d = 0; d < 6; d++) {
          budget[d] += contrib.tokens[d];
        }
      }
    }
    return budget;
  }

  double getOvr(Position pos, int heightInches, List<int> ratings) {
    return tuning.computeOvr(heightInches, ratings, pos.label);
  }

  BadgeTier? getHighestQualifiedTier(int badgeId, List<int> ratings) {
    final tiers = [BadgeTier.hallOfFame, BadgeTier.gold, BadgeTier.silver, BadgeTier.bronze];
    for (final tier in tiers) {
      if (_meetsTierRequirements(badgeId, tier, ratings)) return tier;
    }
    return null;
  }

  bool _meetsTierRequirements(int badgeId, BadgeTier tier, List<int> ratings) {
    final reqs = tierRequirements.where((r) => r.badgeId == badgeId && r.tier == tier);
    if (reqs.isEmpty) return false;
    for (final req in reqs) {
      bool result = true;
      for (int i = 0; i < req.requirements.length; i++) {
        final r = req.requirements[i];
        final meets = ratings[r.attributeIndex] >= r.minimum;
        if (i == 0) {
          result = meets;
        } else {
          final prevOp = req.requirements[i - 1].operatorToNext;
          if (prevOp == 'AND') { result = result && meets; }
          else if (prevOp == 'OR') { result = result || meets; }
        }
      }
      if (result) return true;
    }
    return false;
  }

  int getBadgeTokenCost(int badgeId, BadgeTier tier, int heightInches) {
    // Sum all costs from bronze up to and including the requested tier
    int total = 0;
    for (final t in BadgeTier.values) {
      total += tokenCostMap[TokenCostKey(badgeId, t, heightInches)] ?? 0;
      if (t == tier) break;
    }
    return total;
  }
}

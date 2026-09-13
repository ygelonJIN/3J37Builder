import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/enums.dart';
import '../models/attribute.dart';
import '../models/badge_data.dart';
import '../models/takeover_data.dart';
import '../models/animation_data.dart';
import 'tuning_parser.dart';

class DatasetLoader {
  static final DatasetLoader _instance = DatasetLoader._();
  factory DatasetLoader() => _instance;
  DatasetLoader._();

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

  // Cap Breakers 数据
  Map<String, List<CapBreakerGain>> capBreakerGains = {};

  bool _essentialLoaded = false;
  bool _heavyLoaded = false;

  bool get isLoaded => _essentialLoaded && _heavyLoaded;
  bool get isEssentialLoaded => _essentialLoaded;

  /// 获取某个属性在当前 rating 下的 Cap Breaker 增益
  List<CapBreakerGain> getCapBreakerGains(int attributeIndex, int rating, {String scenario = 'near_caps'}) {
    // 优先使用 near_caps，回退到 isolated
    return capBreakerGains['$scenario-$attributeIndex-$rating'] 
        ?? capBreakerGains['isolated-$attributeIndex-$rating'] 
        ?? [];
  }

  /// Phase 1: Load essential data + tuning file
  Future<void> loadEssential() async {
    if (_essentialLoaded) return;
    debugPrint('[DatasetLoader] loadEssential START');

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
      debugPrint('[DatasetLoader] Tuning content length: ${tuningContent.length}');
      tuning.parse(tuningContent);
      tuning.finalize();
      debugPrint('[DatasetLoader] Tuning parsed: ${tuning.heightMultiplier.length} height entries');

      _essentialLoaded = true;
      debugPrint('[DatasetLoader] loadEssential DONE');
    } catch (e, st) {
      debugPrint('[DatasetLoader] loadEssential ERROR: $e');
      debugPrint('[DatasetLoader] Stack: $st');
      _essentialLoaded = true;
    }
  }

  /// Phase 2: Load heavy JSON
  Future<void> loadHeavy() async {
    if (_heavyLoaded) return;
    debugPrint('[DatasetLoader] loadHeavy START');

    // Load token contributions
    try {
      final contribStr = await rootBundle.loadString('assets/data/token_contributions.json');
      debugPrint('[DatasetLoader] token_contributions loaded: ${contribStr.length} bytes');
      final contribJson = json.decode(contribStr) as Map<String, dynamic>;
      final contribList = contribJson['data'] as List;
      for (final c in contribList) {
        final tc = TokenContribution.fromJson(c);
        tokenContribMap[TokenKey(tc.heightInches, tc.attributeIndex, tc.rating)] = tc;
      }
      debugPrint('[DatasetLoader] ${tokenContribMap.length} token contributions parsed');
    } catch (e, st) {
      debugPrint('[DatasetLoader] token_contributions ERROR (non-fatal): $e');
      debugPrint('[DatasetLoader] Stack: $st');
    }

    // Load cap breakers gains
    try {
      final gainsStr = await rootBundle.loadString('assets/data/gains_by_rating.json');
      debugPrint('[DatasetLoader] gains_by_rating loaded: ${gainsStr.length} bytes');
      final gainsJson = json.decode(gainsStr) as Map<String, dynamic>;
      final gainsList = gainsJson['data'] as List;
      for (final g in gainsList) {
        final scenario = g['scenario'] as String;
        final attrIndex = g['attribute'] as int;
        final rating = g['rating'] as int;
        final application = g['application'] as int;
        final gain = g['gain'] as int;
        final key = '$scenario-$attrIndex-$rating';
        capBreakerGains.putIfAbsent(key, () => []);
        capBreakerGains[key]!.add(CapBreakerGain(application: application, gain: gain));
      }
      debugPrint('[DatasetLoader] ${capBreakerGains.length} cap breaker entries parsed');
    } catch (e, st) {
      debugPrint('[DatasetLoader] gains_by_rating ERROR (non-fatal): $e');
      debugPrint('[DatasetLoader] Stack: $st');
    }

    // Load animation glossary
    debugPrint('[DatasetLoader] About to load glossary...');
    try {
      final glossaryStr = await rootBundle.loadString('assets/data/glossary.json');
      debugPrint('[DatasetLoader] glossary loaded: ${glossaryStr.length} bytes');
      final glossaryJson = json.decode(glossaryStr) as Map<String, dynamic>;
      _parseAnimations(glossaryJson);
      debugPrint('[DatasetLoader] ${animTabs.length} animation tabs parsed');
    } catch (e, st) {
      debugPrint('[DatasetLoader] glossary ERROR (non-fatal): $e');
      debugPrint('[DatasetLoader] Stack: $st');
    }

    _heavyLoaded = true;
    debugPrint('[DatasetLoader] loadHeavy DONE');
  }

  void _parseAnimations(Map<String, dynamic> json) {
    try {
      final tabs = json['Anim Glossary Tabs'] as List?;
      if (tabs == null || tabs.isEmpty) {
        debugPrint('[DatasetLoader] _parseAnimations: no tabs found');
        return;
      }
      debugPrint('[DatasetLoader] _parseAnimations: ${tabs.length} tabs');
      for (int ti = 0; ti < tabs.length; ti++) {
        try {
          final tab = tabs[ti] as Map;
          final nameMap = <String, String>{};
          final rawName = tab['Tab Name'] as Map?;
          if (rawName != null) {
            for (final k in ['EN', 'ZH-HANS']) {
              if (rawName.containsKey(k)) nameMap[k] = rawName[k].toString();
            }
          }
          final groups = <AnimGroup>[];
          final groupsRaw = tab['Anim Groups'] as List? ?? [];
          debugPrint('[DatasetLoader] Tab $ti: ${nameMap['EN']} has ${groupsRaw.length} groups');
          for (final g in groupsRaw) {
            if (g is! Map) continue;
            final gNameMap = <String, String>{};
            final rawGName = g['Group Name'] as Map?;
            if (rawGName != null) {
              for (final k in ['EN', 'ZH-HANS']) {
                if (rawGName.containsKey(k)) gNameMap[k] = rawGName[k].toString();
              }
            }
            final anims = <AnimEntry>[];
            final animsRaw = g['Anims'] as List? ?? [];
            for (final a in animsRaw) {
              if (a is! Map) continue;
              try {
                final aNameMap = <String, String>{};
                final rawAName = a['Anim Name'] as Map?;
                if (rawAName != null) {
                  for (final k in ['EN', 'ZH-HANS']) {
                    if (rawAName.containsKey(k)) aNameMap[k] = rawAName[k].toString();
                  }
                }
                final reqsRaw = a['Attrib Reqs'] as List? ?? [];
                final reqs = <AnimAttribReq>[];
                for (final r in reqsRaw) {
                  if (r is! Map) continue;
                  reqs.add(AnimAttribReq(
                    attrib: (r['Attrib Type'] ?? '').toString(),
                    value: (r['Attrib Min'] as num?)?.toInt() ?? 0,
                  ));
                }
                final allowedRaw = a['Allowed Sizes'];
                final List<String> allowed;
                if (allowedRaw is List) {
                  allowed = allowedRaw.map((e) => e.toString()).toList();
                } else {
                  allowed = [allowedRaw?.toString() ?? 'ANY'];
                }
                anims.add(AnimEntry(
                  animId: (a['Anim ID'] ?? '').toString(),
                  name: aNameMap,
                  allowedSizes: allowed,
                  attribReqsOperator: a['Attrib Reqs Operator']?.toString(),
                  attribReqs: reqs,
                  isPrized: a['Is Prized'] == true,
                ));
              } catch (e) {
                debugPrint('[DatasetLoader] Error parsing anim in group ${g['Anim Type']}: $e');
              }
            }
            groups.add(AnimGroup(
              animType: (g['Anim Type'] ?? '').toString(),
              name: gNameMap,
              anims: anims,
            ));
          }
          animTabs.add(AnimTab(
            tabId: (tab['Tab ID'] ?? '').toString(),
            name: nameMap,
            groups: groups,
          ));
          debugPrint('[DatasetLoader] Tab $ti done: ${groups.length} groups');
        } catch (e) {
          debugPrint('[DatasetLoader] Error parsing tab $ti: $e');
        }
      }
      debugPrint('[DatasetLoader] _parseAnimations done: ${animTabs.length} tabs');
    } catch (e, st) {
      debugPrint('[DatasetLoader] _parseAnimations ERROR: $e');
      debugPrint('[DatasetLoader] Stack: $st');
    }
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
    return tokenCostMap[TokenCostKey(badgeId, tier, heightInches)] ?? 0;
  }
}

class CapBreakerGain {
  final int application;
  final int gain;

  const CapBreakerGain({required this.application, required this.gain});

  factory CapBreakerGain.fromJson(Map<String, dynamic> json) {
    return CapBreakerGain(
      application: json['application'] as int,
      gain: json['gain'] as int,
    );
  }
}

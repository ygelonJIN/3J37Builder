import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/enums.dart';
import '../models/attribute.dart';
import '../models/badge_data.dart';
import '../models/takeover_data.dart';
import '../models/animation_data.dart';
import 'tuning_parser.dart';
import 'website_logic.dart' as website_logic;

// ============================================================
// Data model classes for cap_breaker_model.json new fields
// ============================================================

/// Constraint pair: [attributeIndex, minimumValue]
typedef ConstraintPair = List<int>;

/// Body caps lookup tables from cap_breaker_model.json
/// Each table has 420 values (20 heights × 21 attributes), stored in row-major order.
class BodyCapsTables {
  /// Base caps multiplier (20 heights × 21 attrs)
  final List<double> base;

  /// Weight-low interpolation table (20 heights × 21 attrs)
  final List<double> weightLow;

  /// Weight-high interpolation table (20 heights × 21 attrs)
  final List<double> weightHigh;

  /// Wingspan-low interpolation table (20 heights × 21 attrs)
  final List<double> wingspanLow;

  /// Wingspan-high interpolation table (20 heights × 21 attrs)
  final List<double> wingspanHigh;

  const BodyCapsTables({
    required this.base,
    required this.weightLow,
    required this.weightHigh,
    required this.wingspanLow,
    required this.wingspanHigh,
  });

  /// Look up a value in a flat table by heightIndex (0-19) and attributeIndex (0-20)
  static double lookup(List<double> table, int heightIndex, int attrIndex) {
    return table[heightIndex * 21 + attrIndex];
  }
}

/// Ranges for weight and wingspan per height (indexed by availableHeights index)
class BodyCapsRanges {
  /// Minimum weight for each height (20 values)
  final List<int> weightMin;

  /// Maximum weight for each height (20 values)
  final List<int> weightMax;

  /// Minimum wingspan for each height (20 values)
  final List<int> wingspanMin;

  /// Maximum wingspan for each height (20 values)
  final List<int> wingspanMax;

  const BodyCapsRanges({
    required this.weightMin,
    required this.weightMax,
    required this.wingspanMin,
    required this.wingspanMax,
  });
}

/// Complete body caps data: tables + ranges
class BodyCapsData {
  final BodyCapsTables tables;
  final BodyCapsRanges ranges;

  const BodyCapsData({required this.tables, required this.ranges});
}

/// Badge model from cap_breaker_model.json
/// Contains heightBase, heightCount, and the full badge definitions with per-height max levels.
class ModelBadge {
  /// Badge name (e.g. "Float Game")
  final String name;

  /// Category (e.g. "finishing")
  final String category;

  /// 5 tiers (Bronze/Silver/Gold/HoF/Legend). Each tier is a list of requirement groups.
  /// Each requirement group is a list of [attributeIndex, minimum, operator].
  /// operator: 0 = AND, 2 = OR (matches website logic).
  final List<List<List<int>>> levels;

  /// Max level achievable at each height index (31 values, indexed from heightBase).
  final List<int> heightMaxLevels;

  const ModelBadge({
    required this.name,
    required this.category,
    required this.levels,
    required this.heightMaxLevels,
  });

  /// Parse from JSON (single badge object)
  factory ModelBadge.fromJson(Map<String, dynamic> json) {
    final levelsRaw = json['levels'] as List;
    final levels = <List<List<int>>>[];
    for (final tier in levelsRaw) {
      final tierGroups = <List<int>>[];
      if (tier is List) {
        for (final req in tier) {
          if (req is Map) {
            tierGroups.add([
              req['attributeIndex'] as int,
              req['minimum'] as int,
              req['operator'] as int,
            ]);
          }
        }
      }
      levels.add(tierGroups);
    }

    return ModelBadge(
      name: json['name'] as String,
      category: json['category'] as String,
      levels: levels,
      heightMaxLevels: (json['heightMaxLevels'] as List).cast<int>(),
    );
  }

  /// Get max level for a given height in inches
  int getMaxLevel(int heightInches, int heightBase) {
    final idx = heightInches - heightBase;
    if (idx < 0 || idx >= heightMaxLevels.length) return 0;
    return heightMaxLevels[idx];
  }
}

/// Badge model data container
class BadgeModelData {
  /// Height base (e.g. 63 = 5'3")
  final int heightBase;

  /// Number of height entries (e.g. 31)
  final int heightCount;

  /// All badge definitions
  final List<ModelBadge> badges;

  const BadgeModelData({
    required this.heightBase,
    required this.heightCount,
    required this.badges,
  });
}

/// Badge token tuning entry (one position+height combination)
class BadgeTokenTuning {
  final String position;
  final int height;
  final List<String> attrNames;

  /// Map of attributeName -> discipline string (e.g. "finishing")
  final Map<String, String> discipline;

  /// Map of attributeName -> rate (double)
  final Map<String, double> rate;

  /// Map of attributeName -> baseline (int)
  final Map<String, int> baseline;

  const BadgeTokenTuning({
    required this.position,
    required this.height,
    required this.attrNames,
    required this.discipline,
    required this.rate,
    required this.baseline,
  });

  factory BadgeTokenTuning.fromJson(Map<String, dynamic> json) {
    final attrNames = (json['attrNames'] as List).map((e) => e.toString()).toList();
    final disciplineMap = <String, String>{};
    final rateMap = <String, double>{};
    final baselineMap = <String, int>{};

    final disciplineRaw = json['discipline'] as Map<String, dynamic>;
    final rateRaw = json['rate'] as Map<String, dynamic>;
    final baselineRaw = json['baseline'] as Map<String, dynamic>;

    for (final attr in attrNames) {
      disciplineMap[attr] = disciplineRaw[attr].toString();
      rateMap[attr] = (rateRaw[attr] as num).toDouble();
      baselineMap[attr] = (baselineRaw[attr] as num).toInt();
    }

    return BadgeTokenTuning(
      position: json['position'] as String,
      height: json['height'] as int,
      attrNames: attrNames,
      discipline: disciplineMap,
      rate: rateMap,
      baseline: baselineMap,
    );
  }
}

/// Badge token model container (tunings + costs)
class BadgeTokenModelData {
  final int version;
  final String gameVersion;
  final List<BadgeTokenTuning> tunings;

  /// Map of badgeName -> Map of tierName -> cost
  /// e.g. { "FloatGame": { "Bronze": 3, "Silver": 2, ... } }
  final Map<String, Map<String, int>> costs;

  const BadgeTokenModelData({
    required this.version,
    required this.gameVersion,
    required this.tunings,
    required this.costs,
  });
}

/// Takeover requirement from cap_breaker_model.json (model version)
class ModelTakeoverRequirement {
  /// Attribute name (e.g. "closeShot")
  final String attribute;

  /// Minimum rating required
  final int minValue;

  const ModelTakeoverRequirement({
    required this.attribute,
    required this.minValue,
  });
}

/// Takeover entry from cap_breaker_model.json
class ModelTakeover {
  /// Internal name (e.g. "INSIDE_TOUCH")
  final String name;

  /// Display name (e.g. "Inside Touch")
  final String displayName;

  /// Requirements to unlock this takeover
  final List<ModelTakeoverRequirement> requirements;

  const ModelTakeover({
    required this.name,
    required this.displayName,
    required this.requirements,
  });
}

/// Takeover model container
class TakeoverModelData {
  final List<ModelTakeover> takeovers;

  const TakeoverModelData({required this.takeovers});
}

// ============================================================
// DatasetLoader - main loader class
// ============================================================

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

  bool _essentialLoaded = false;
  bool _heavyLoaded = false;

  /// 解密的破帽器模型数据
  List<double>? modelWeights;
  List<double>? modelCurves;
  List<double>? modelOverallScale;

  // ============================================================
  // NEW: Fields from cap_breaker_model.json
  // ============================================================

  /// Available heights list (e.g. [69, 70, ..., 88])
  List<int> availableHeights = [];

  /// Body caps data (tables + ranges) from model
  BodyCapsData? bodyCapsData;

  /// Constraint graphs: indexed by [heightIndex][attrIndex] -> list of [attrIndex, minValue] pairs
  /// 20 heights × 21 attributes, each with a list of constraint pairs
  List<List<List<ConstraintPair>>> constraintGraphs = [];

  /// Badge model (heightBase, heightCount, badges with per-height max levels)
  BadgeModelData? badgeModelData;

  /// Badge token model (tunings + costs)
  BadgeTokenModelData? badgeTokenModelData;

  /// Takeover model (takeovers with requirements)
  TakeoverModelData? takeoverModelData;

  /// gameVersion string from model (e.g. "2K27")
  String gameVersion = '';

  bool get isLoaded => _essentialLoaded && _heavyLoaded;
  bool get isEssentialLoaded => _essentialLoaded;

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

    // Load cap breaker model (decrypted from 2khoopscope.com)
    try {
      final modelStr = await rootBundle.loadString('assets/data/cap_breaker_model.json');
      debugPrint('[DatasetLoader] cap_breaker_model loaded: ${modelStr.length} bytes');
      final modelJson = json.decode(modelStr) as Map<String, dynamic>;

      // Existing fields
      modelWeights = (modelJson['weights'] as List).map((e) => (e as num).toDouble()).toList();
      modelCurves = (modelJson['curves'] as List).map((e) => (e as num).toDouble()).toList();
      modelOverallScale = (modelJson['overallScale'] as List).map((e) => (e as num).toDouble()).toList();
      debugPrint('[DatasetLoader] Model: ${modelWeights?.length} weights, ${modelCurves?.length} curves');

      // NEW: gameVersion
      gameVersion = modelJson['gameVersion']?.toString() ?? '';
      debugPrint('[DatasetLoader] gameVersion: $gameVersion');

      // NEW: availableHeights
      availableHeights = (modelJson['availableHeights'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
      debugPrint('[DatasetLoader] availableHeights: ${availableHeights.length} entries');

      // NEW: bodyCaps (tables + ranges)
      final bodyCapsJson = modelJson['bodyCaps'] as Map<String, dynamic>?;
      if (bodyCapsJson != null) {
        final tablesJson = bodyCapsJson['tables'] as Map<String, dynamic>;
        final rangesJson = bodyCapsJson['ranges'] as Map<String, dynamic>;

        final tables = BodyCapsTables(
          base: (tablesJson['base'] as List).map((e) => (e as num).toDouble()).toList(),
          weightLow: (tablesJson['weightLow'] as List).map((e) => (e as num).toDouble()).toList(),
          weightHigh: (tablesJson['weightHigh'] as List).map((e) => (e as num).toDouble()).toList(),
          wingspanLow: (tablesJson['wingspanLow'] as List).map((e) => (e as num).toDouble()).toList(),
          wingspanHigh: (tablesJson['wingspanHigh'] as List).map((e) => (e as num).toDouble()).toList(),
        );

        final ranges = BodyCapsRanges(
          weightMin: (rangesJson['weightMin'] as List).map((e) => (e as num).toInt()).toList(),
          weightMax: (rangesJson['weightMax'] as List).map((e) => (e as num).toInt()).toList(),
          wingspanMin: (rangesJson['wingspanMin'] as List).map((e) => (e as num).toInt()).toList(),
          wingspanMax: (rangesJson['wingspanMax'] as List).map((e) => (e as num).toInt()).toList(),
        );

        bodyCapsData = BodyCapsData(tables: tables, ranges: ranges);
        debugPrint('[DatasetLoader] bodyCaps loaded: ${tables.base.length} base values, ${ranges.weightMin.length} heights');
      }

      // NEW: constraintGraphs (20 heights × 21 attrs × N constraint pairs)
      final constraintGraphsJson = modelJson['constraintGraphs'] as List?;
      if (constraintGraphsJson != null) {
        constraintGraphs = [];
        for (final heightEntry in constraintGraphsJson) {
          final heightGraphs = <List<ConstraintPair>>[];
          if (heightEntry is List) {
            for (final attrEntry in heightEntry) {
              final pairs = <ConstraintPair>[];
              if (attrEntry is List) {
                for (final pair in attrEntry) {
                  if (pair is List && pair.length >= 2) {
                    pairs.add([(pair[0] as num).toInt(), (pair[1] as num).toInt()]);
                  }
                }
              }
              heightGraphs.add(pairs);
            }
          }
          constraintGraphs.add(heightGraphs);
        }
        debugPrint('[DatasetLoader] constraintGraphs loaded: ${constraintGraphs.length} heights × ${constraintGraphs.isNotEmpty ? constraintGraphs[0].length : 0} attrs');
      }

      // NEW: badgeModel (heightBase, heightCount, badges)
      final badgeModelJson = modelJson['badgeModel'] as Map<String, dynamic>?;
      if (badgeModelJson != null) {
        final heightBase = badgeModelJson['heightBase'] as int;
        final heightCount = badgeModelJson['heightCount'] as int;
        final badgesList = (badgeModelJson['badges'] as List)
            .map((b) => ModelBadge.fromJson(b as Map<String, dynamic>))
            .toList();

        badgeModelData = BadgeModelData(
          heightBase: heightBase,
          heightCount: heightCount,
          badges: badgesList,
        );
        debugPrint('[DatasetLoader] badgeModel loaded: heightBase=$heightBase, heightCount=$heightCount, ${badgesList.length} badges');
      }

      // NEW: badgeTokenModel (tunings + costs)
      final badgeTokenModelJson = modelJson['badgeTokenModel'] as Map<String, dynamic>?;
      if (badgeTokenModelJson != null) {
        final version = badgeTokenModelJson['version'] as int;
        final versionGame = badgeTokenModelJson['gameVersion']?.toString() ?? '';
        final tuningsList = (badgeTokenModelJson['tunings'] as List)
            .map((t) => BadgeTokenTuning.fromJson(t as Map<String, dynamic>))
            .toList();

        final costsMap = <String, Map<String, int>>{};
        final costsRaw = badgeTokenModelJson['costs'] as Map<String, dynamic>;
        costsRaw.forEach((badgeName, tierCosts) {
          if (tierCosts is Map) {
            final tierMap = <String, int>{};
            tierCosts.forEach((tier, cost) {
              tierMap[tier.toString()] = (cost as num).toInt();
            });
            costsMap[badgeName] = tierMap;
          }
        });

        badgeTokenModelData = BadgeTokenModelData(
          version: version,
          gameVersion: versionGame,
          tunings: tuningsList,
          costs: costsMap,
        );
        debugPrint('[DatasetLoader] badgeTokenModel loaded: ${tuningsList.length} tunings, ${costsMap.length} cost entries');
      }

      // NEW: takeoverModel (takeovers)
      final takeoverModelJson = modelJson['takeoverModel'] as Map<String, dynamic>?;
      if (takeoverModelJson != null) {
        final takeoversList = (takeoverModelJson['takeovers'] as List).map((t) {
          final tMap = t as Map<String, dynamic>;
          final reqsRaw = tMap['requirements'] as List? ?? [];
          final reqs = reqsRaw.map((r) {
            final rMap = r as Map<String, dynamic>;
            return ModelTakeoverRequirement(
              attribute: rMap['attribute'].toString(),
              minValue: (rMap['minValue'] as num).toInt(),
            );
          }).toList();

          return ModelTakeover(
            name: tMap['name'].toString(),
            displayName: tMap['displayName'].toString(),
            requirements: reqs,
          );
        }).toList();

        takeoverModelData = TakeoverModelData(takeovers: takeoversList);
        debugPrint('[DatasetLoader] takeoverModel loaded: ${takeoversList.length} takeovers');
      }

    } catch (e, st) {
      debugPrint('[DatasetLoader] cap_breaker_model ERROR (non-fatal): $e');
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
      // Use model data if available, otherwise fall back to hardcoded defaults
      if (bodyCapsData != null && availableHeights.isNotEmpty) {
        final heightIdx = availableHeights.indexOf(heightInches);
        if (heightIdx >= 0) {
          return BodyRange(
            heightInches: heightInches,
            minWeight: bodyCapsData!.ranges.weightMin[heightIdx],
            maxWeight: bodyCapsData!.ranges.weightMax[heightIdx],
            defaultWeight: bodyCapsData!.ranges.weightMin[heightIdx], // Default = min
            minWingspan: bodyCapsData!.ranges.wingspanMin[heightIdx],
            maxWingspan: bodyCapsData!.ranges.wingspanMax[heightIdx],
            defaultWingspan: bodyCapsData!.ranges.wingspanMin[heightIdx], // Default = min
          );
        }
      }
      // Fallback to hardcoded defaults
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
    final body = {'height': heightInches, 'weight': weightLb, 'wingspan': wingspanInches, 'position': pos.label};
    final capsMap = website_logic.getCaps(body, this);
    return List.generate(21, (i) => capsMap[website_logic.attrIds[i]] ?? 99);
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
    final body = {'height': heightInches, 'weight': 190, 'wingspan': heightInches + 3, 'position': pos.label};
    final values = <String, int>{};
    for (int i = 0; i < 21; i++) {
      values[website_logic.attrIds[i]] = ratings[i];
    }
    return website_logic.calculateOvr(values, body, this);
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

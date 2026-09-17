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
import 'dart:math' as math;

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

  /// Slot allocation lookup: "height|values_hash" key -> slots
  Map<String, List<int>> _slotAllocByKey = {};
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

  /// Tuning lookup by "position|height" key for fast token calculation
  Map<String, BadgeTokenTuning> _tokenTuningMap = {};

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

    // Load cap breaker model (decrypted game data)
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
        // Build tuning lookup map
        for (final t in tuningsList) {
          _tokenTuningMap['${t.position}|${t.height}'] = t;
        }
        debugPrint('[DatasetLoader] badgeTokenModel loaded: ${tuningsList.length} tunings, ${costsMap.length} cost entries, ${_tokenTuningMap.length} tuning keys');
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
    // Load slot allocations
    try {
      final slotStr = await rootBundle.loadString('assets/data/slot_allocations.json');
      final slotJson = json.decode(slotStr) as Map<String, dynamic>;
      final slotList = slotJson['data'] as List;
      final byKey = <String, List<int>>{};
      for (final r in slotList) {
        final h = r['height_inches'] as int;
        final vals = (r['values'] as List).cast<int>();
        final sl = (r['slots'] as List).cast<int>();
        // Use attribute values hash as key
        final key = '$h|${vals.join(',')}';
        byKey[key] = sl;
      }
      _slotAllocByKey = byKey;
      debugPrint('[DatasetLoader] slot_allocations loaded: ${slotList.length} records, ${byKey.length} unique keys');
    } catch (e) {
      debugPrint('[DatasetLoader] slot_allocations ERROR (non-fatal): $e');
    }

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

  /// Round half even (银行家舍入) — 与网站 H 函数完全一致
  /// 网站: function H(e){const t=Math.floor(e),n=e-t;return n<.5?t:n>.5?t+1:t%2===0?t:t+1}
  static int _roundHalfEven(double x) {
    final t = x.floor();
    final n = x - t;
    if (n < 0.5) return t;
    if (n > 0.5) return t + 1;
    return t % 2 == 0 ? t : t + 1;
  }

  /// Discipline name to index map
  static const _disciplineIndex = {
    'finishing': 0, 'shooting': 1, 'playmaking': 2,
    'defense': 3, 'rebounding': 4, 'physical': 5,
  };

  /// Attribute name to index map (matches ATTRIBUTES_RAW order)
  static const _attrNameToIndex = {
    'closeShot': 0, 'layup': 1, 'drivingDunk': 2, 'standingDunk': 3,
    'postControl': 4, 'midRange': 5, 'threePoint': 6, 'freeThrow': 7,
    'passAccuracy': 8, 'ballHandle': 9, 'speedWithBall': 10,
    'interiorDefense': 11, 'perimeterDefense': 12, 'steal': 13, 'block': 14,
    'offensiveRebound': 15, 'defensiveRebound': 16, 'speed': 17, 'agility': 18,
    'strength': 19, 'vertical': 20,
  };

  /// Calculate badge token budget using the exact website formula:
  /// For each attribute, tokens[discipline] += H((value - baseline) / rate)
  /// where H is round-half-down.
  /// Tunings are position+height specific from badgeTokenModel.
  List<int> getTokenBudget(String position, int heightInches, List<int> ratings) {
    final budget = List.filled(6, 0);
    final tuning = _tokenTuningMap['$position|$heightInches'];
    if (tuning == null) return budget;

    for (final attrName in tuning.attrNames) {
      final rate = tuning.rate[attrName] ?? 0;
      if (rate <= 0) continue;
      final attrIdx = _attrNameToIndex[attrName];
      if (attrIdx == null) continue;
      final value = ratings[attrIdx];
      final baseline = tuning.baseline[attrName] ?? 0;
      final diff = value - baseline;
      if (diff <= 0) continue;
      final discName = tuning.discipline[attrName];
      if (discName == null) continue;
      final discIdx = _disciplineIndex[discName];
      if (discIdx == null) continue;
      budget[discIdx] += _roundHalfEven(diff / rate);
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

  /// 获取徽章最高等级 — 使用 badgeModelData，与网站 pe 函数完全一致
  /// 网站: function pe(e,t){const n=N;...const i=Math.trunc(Number(t.height))-n.heightBase;
  ///   return n.badges.map(r=>{...let o=0;for(let u=0;u<math.min(5,s);u+=1)
  ///   me(r.levels[u],e)&&(o=u+1);...})}
  BadgeTier? getHighestQualifiedTier(int badgeId, List<int> ratings) {
    if (badgeModelData == null) return null;
    // 通过 badgeId 找到对应的徽章名称
    final def = badgeDefinitions.where((b) => b.badgeId == badgeId);
    if (def.isEmpty) return null;
    final badgeName = def.first.name;
    // 在 badgeModelData 中查找匹配的徽章
    ModelBadge? modelBadge;
    for (final b in badgeModelData!.badges) {
      if (_normalizeName(b.name) == _normalizeName(badgeName)) {
        modelBadge = b;
        break;
      }
    }
    if (modelBadge == null) return null;
    return _getHighestTierFromModel(modelBadge, ratings);
  }

  /// 根据 badgeModel 中的徽章定义和属性值计算最高等级
  /// 与网站 pe 函数逻辑完全一致:
  /// let o=0; for(let u=0;u<math.min(5,s);u+=1) me(r.levels[u],e)&&(o=u+1);
  BadgeTier? _getHighestTierFromModel(ModelBadge badge, List<int> ratings) {
    // 使用默认最大等级5（无身高限制时）
    const maxLevel = 5;
    int highestLevel = 0;
    for (int level = 0; level < math.min(5, maxLevel); level++) {
      if (level >= badge.levels.length) break;
      final reqs = badge.levels[level];
      if (reqs.isEmpty) continue; // 空需求=自动满足
      if (_meetsRequirements(reqs, ratings)) {
        highestLevel = level + 1;
      }
    }
    if (highestLevel <= 0) return null;
    const tierMap = [BadgeTier.bronze, BadgeTier.silver, BadgeTier.gold, BadgeTier.hallOfFame];
    return highestLevel <= tierMap.length ? tierMap[highestLevel - 1] : BadgeTier.hallOfFame;
  }

  /// 考虑身高限制的版本（用于 getBadgeStatuses 等需要身高的场景）
  BadgeTier? getHighestQualifiedTierWithHeight(int badgeId, List<int> ratings, int heightInches) {
    if (badgeModelData == null) return getHighestQualifiedTier(badgeId, ratings);
    final def = badgeDefinitions.where((b) => b.badgeId == badgeId);
    if (def.isEmpty) return null;
    final badgeName = def.first.name;
    ModelBadge? modelBadge;
    for (final b in badgeModelData!.badges) {
      if (_normalizeName(b.name) == _normalizeName(badgeName)) {
        modelBadge = b;
        break;
      }
    }
    if (modelBadge == null) return null;
    // 身高限制: s = i>=0&&i<n.heightCount ? r.heightMaxLevels[i] : 5
    final heightIdx = heightInches - badgeModelData!.heightBase;
    final maxLevel = (heightIdx >= 0 && heightIdx < badgeModelData!.heightCount)
        ? modelBadge.heightMaxLevels[heightIdx]
        : 5;
    if (maxLevel <= 0) return null;
    int highestLevel = 0;
    for (int level = 0; level < maxLevel.clamp(0, 5); level++) {
      if (level >= modelBadge.levels.length) break;
      final reqs = modelBadge.levels[level];
      if (reqs.isEmpty) continue;
      if (_meetsRequirements(reqs, ratings)) {
        highestLevel = level + 1;
      }
    }
    if (highestLevel <= 0) return null;
    const tierMap = [BadgeTier.bronze, BadgeTier.silver, BadgeTier.gold, BadgeTier.hallOfFame];
    return highestLevel <= tierMap.length ? tierMap[highestLevel - 1] : BadgeTier.hallOfFame;
  }

  static String _normalizeName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  int getBadgeTokenCost(int badgeId, BadgeTier tier, int heightInches) {
    return tokenCostMap[TokenCostKey(badgeId, tier, heightInches)] ?? 0;
  }

  // 网站决胜数组 (来自 logic-CMaECw5P.js: Sl 和 Tl)
  // 注意：平分时按 Sl/Tl 值降序排列（值大的优先）
  static const _addTiebreak = [2, 4, 3, 1, 6, 5];   // Sl: [finishing, shooting, playmaking, defense, rebounding, physical]
  static const _removeTiebreak = [3, 1, 2, 4, 5, 6]; // Tl: [finishing, shooting, playmaking, defense, rebounding, physical]

  /// 计算各学科的徽章槽位数 — 与网站 Pl 函数逻辑完全一致
  /// 使用 0.6 * badgeRatio + 0.4 * tokenRatio 混合公式
  /// 调整阶段使用动态分数排序 + 决胜数组，而非固定优先级
  /// 返回6个值 [finishing, shooting, playmaking, defense, rebounding, physical]
  List<int> getSlotBudget(String position, int heightInches, List<int> ratings) {
    if (badgeModelData == null) return [4, 4, 4, 4, 1, 3];
    
    // 网站定义的上限
    const maxSlots = [7, 7, 7, 7, 5, 6]; // [finishing, shooting, playmaking, defense, rebounding, physical]
    
    // 1. 统计每个类别的达标徽章数
    final badgeCounts = List.filled(6, 0);
    final heightIdx = heightInches - badgeModelData!.heightBase;
    
    for (final badge in badgeModelData!.badges) {
      final badgeMaxLevel = (heightIdx >= 0 && heightIdx < badgeModelData!.heightCount)
          ? badge.heightMaxLevels[heightIdx]
          : 5;
      if (badgeMaxLevel <= 0) continue;
      
      bool qualifies = false;
      for (int level = 0; level < badgeMaxLevel.clamp(0, 5); level++) {
        if (level >= badge.levels.length) break;
        final reqs = badge.levels[level];
        if (reqs.isEmpty) continue;
        if (_meetsRequirements(reqs, ratings)) {
          qualifies = true;
          break;
        }
      }
      if (!qualifies) continue;
      
      final discIdx = _disciplineIndex[badge.category];
      if (discIdx != null) badgeCounts[discIdx]++;
    }
    
    final totalBadges = badgeCounts.reduce((a, b) => a + b);
    if (totalBadges == 0) return List.filled(6, 0);
    
    // 2. 获取代币预算
    final tokenBudget = getTokenBudget(position, heightInches, ratings);
    final totalTokens = tokenBudget.reduce((a, b) => a + b);
    
    // 3. 计算混合分数并分配槽位
    final slots = List.filled(6, 0);
    final scores = List.filled(6, 0.0); // 保存分数用于排序
    
    for (int i = 0; i < 6; i++) {
      final minSlots = badgeCounts[i] > 0 ? 1 : 0;
      final tokenRatio = totalTokens > 0 ? tokenBudget[i] / totalTokens : 0.0;
      final badgeRatio = badgeCounts[i] / totalBadges;
      
      // 网站公式: 0.6 * badgeRatio + 0.4 * tokenRatio
      final blended = 0.6 * badgeRatio + 0.4 * tokenRatio;
      scores[i] = blended;
      
      // 分配槽位，受多重限制: min(max(rounded, min), badgeCount, maxSlots)
      final rawSlots = _roundHalfEven(20 * blended);
      final limit = [badgeCounts[i], maxSlots[i]].reduce((a, b) => a < b ? a : b);
      slots[i] = rawSlots.clamp(minSlots, limit);
    }
    
    // 4. 调整确保总数恰好为20（使用网站的动态排序逻辑）
    int currentTotal = slots.reduce((a, b) => a + b);
    
    // 如果不足20，按分数降序添加（平分时 Sl 值大的优先）
    if (currentTotal < 20) {
      final addOrder = List.generate(6, (i) => i);
      addOrder.sort((a, b) {
        final scoreDiff = scores[b].compareTo(scores[a]); // 分数降序
        if (scoreDiff.abs() > 1e-9) return scoreDiff;
        return _addTiebreak[b].compareTo(_addTiebreak[a]); // 平分时 Sl 值大的优先
      });
      
      for (int round = 0; round < 3 && currentTotal < 20; round++) {
        bool added = true;
        while (added && currentTotal < 20) {
          added = false;
          for (final idx in addOrder) {
            if (currentTotal >= 20) break;
            final limit = round == 0 
                ? [badgeCounts[idx], maxSlots[idx]].reduce((a, b) => a < b ? a : b)
                : round == 1 ? maxSlots[idx] : 999999;
            if (badgeCounts[idx] > 0 && slots[idx] < limit) {
              slots[idx]++;
              added = true;
              currentTotal++;
              if (currentTotal >= 20) break;
            }
          }
        }
      }
    }
    
    // 如果超过20，按分数升序移除（平分时 Tl 值大的优先）
    if (currentTotal > 20) {
      final removeOrder = List.generate(6, (i) => i);
      removeOrder.sort((a, b) {
        final scoreDiff = scores[a].compareTo(scores[b]); // 分数升序
        if (scoreDiff.abs() > 1e-9) return scoreDiff;
        return _removeTiebreak[b].compareTo(_removeTiebreak[a]); // 平分时 Tl 值大的优先
      });
      
      for (final idx in removeOrder) {
        while (currentTotal > 20 && slots[idx] > (badgeCounts[idx] > 0 ? 1 : 0)) {
          slots[idx]--;
          currentTotal--;
        }
      }
    }
    
    return slots;
  }

  /// Count qualified badges per discipline for given attribute values.
  /// A badge qualifies at any tier if it meets at least one tier's requirements.
  List<int> _countQualifiedBadges(int heightInches, List<int> ratings) {
    final counts = List.filled(6, 0);
    if (badgeModelData == null) return counts;
    final heightIdx = heightInches - badgeModelData!.heightBase;
    if (heightIdx < 0 || heightIdx >= badgeModelData!.heightCount) return counts;

    for (final badge in badgeModelData!.badges) {
      final maxLevel = badge.heightMaxLevels[heightIdx];
      if (maxLevel <= 0) continue;
      final discIdx = _disciplineIndex[badge.category];
      if (discIdx == null) continue;

      bool qualifies = false;
      // Check each tier from highest to lowest
      for (int tier = maxLevel - 1; tier >= 0; tier--) {
        if (tier >= badge.levels.length) continue;
        final reqs = badge.levels[tier];
        if (reqs.isEmpty) continue;
        if (_meetsRequirements(reqs, ratings)) {
          qualifies = true;
          break;
        }
      }
      if (qualifies) counts[discIdx]++;
    }
    return counts;
  }

  /// 检查属性是否满足徽章需求列表 — 与网站 me 函数完全一致
  /// 网站: function me(e,t){if(!e.length)return!1;let n=!1,i=!1;for(const r of e){...}}
  /// operator: 0=OR(累积或组), 1=AND(检查并重置), 2=BREAK(检查并终止)
  bool _meetsRequirements(List<List<int>> reqs, List<int> ratings) {
    if (reqs.isEmpty) return false;
    bool orGroupSatisfied = false;
    bool hasConditions = false;
    for (final req in reqs) {
      final attrIdx = req[0];
      final minimum = req[1];
      final operator = req.length > 2 ? req[2] : 0;
      final meets = attrIdx >= 0 && attrIdx < ratings.length &&
          ratings[attrIdx] >= minimum;
      orGroupSatisfied = orGroupSatisfied || meets;
      hasConditions = true;
      if (operator != 0) {
        if (!orGroupSatisfied) return false;
        orGroupSatisfied = false;
        hasConditions = false;
        if (operator == 2) break;
      }
    }
    return !hasConditions || orGroupSatisfied;
  }

  /// Compute token budget for raw attribute values using a specific tuning
  List<int> _computeTokenBudgetForTuning(BadgeTokenTuning tuning, List<int> values) {
    final budget = List.filled(6, 0);
    for (final attrName in tuning.attrNames) {
      final rate = tuning.rate[attrName] ?? 0;
      if (rate <= 0) continue;
      final attrIdx = _attrNameToIndex[attrName];
      if (attrIdx == null) continue;
      final value = values[attrIdx];
      final baseline = tuning.baseline[attrName] ?? 0;
      final diff = value - baseline;
      if (diff <= 0) continue;
      final discName = tuning.discipline[attrName];
      if (discName == null) continue;
      final discIdx = _disciplineIndex[discName];
      if (discIdx == null) continue;
      budget[discIdx] += _roundHalfEven(diff / rate);
    }
    return budget;
  }
}

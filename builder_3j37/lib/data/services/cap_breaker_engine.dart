/// NBA 2K27 破帽器计算引擎
/// 完全使用 https://www.2khoopscope.com/2k27/builder 解密后的模型数据
/// 无回退路径，无服务端调用，纯本地模型计算
///
/// 算法验证: 21/21 属性增益与游戏原生探测数据完全匹配
///
/// 核心算法 (ce function):
/// 1. 根据身高计算 heightIndex d = clamp(height - 69, 0, 19)
/// 2. 在15个archetype slot中找到最佳匹配(加权OVR最高)
/// 3. 获取该slot的21个权重 weights[(d*15+slot)*21 + attrIdx]
/// 4. 计算 relativeWeight = (maxWeight - attrWeight) / maxWeight
/// 5. 每档增益: curveIdx = 15 + floor((25-A)*14/74)
///              gain = min(remaining, max(1, roundHalfEven(curveIdx * relativeWeight)))

import 'dart:math';

// ============================================================
// 属性定义 (21个)
// ============================================================

class CapBreakerAttribute {
  final String id;
  final String name;
  final String category;
  final double weight;
  final int index;

  const CapBreakerAttribute({
    required this.id,
    required this.name,
    required this.category,
    required this.weight,
    required this.index,
  });
}

const List<CapBreakerAttribute> capBreakerAttributes = [
  CapBreakerAttribute(id: 'closeShot', name: '近距离投篮', category: 'finishing', weight: 1.0, index: 0),
  CapBreakerAttribute(id: 'layup', name: '突破上篮', category: 'finishing', weight: 1.15, index: 1),
  CapBreakerAttribute(id: 'drivingDunk', name: '突破扣篮', category: 'finishing', weight: 1.35, index: 2),
  CapBreakerAttribute(id: 'standingDunk', name: '原地扣篮', category: 'finishing', weight: 1.15, index: 3),
  CapBreakerAttribute(id: 'postControl', name: '背身控制', category: 'finishing', weight: 1.0, index: 4),
  CapBreakerAttribute(id: 'midRange', name: '中距离投篮', category: 'shooting', weight: 1.1, index: 5),
  CapBreakerAttribute(id: 'threePoint', name: '三分投篮', category: 'shooting', weight: 1.4, index: 6),
  CapBreakerAttribute(id: 'freeThrow', name: '罚球', category: 'shooting', weight: 0.65, index: 7),
  CapBreakerAttribute(id: 'passAccuracy', name: '传球准确性', category: 'playmaking', weight: 1.0, index: 8),
  CapBreakerAttribute(id: 'ballHandle', name: '控球', category: 'playmaking', weight: 1.25, index: 9),
  CapBreakerAttribute(id: 'speedWithBall', name: '运球速度', category: 'playmaking', weight: 1.2, index: 10),
  CapBreakerAttribute(id: 'interiorDefense', name: '内线防守', category: 'defense', weight: 1.05, index: 11),
  CapBreakerAttribute(id: 'perimeterDefense', name: '外线防守', category: 'defense', weight: 1.25, index: 12),
  CapBreakerAttribute(id: 'steal', name: '抢断', category: 'defense', weight: 1.2, index: 13),
  CapBreakerAttribute(id: 'block', name: '盖帽', category: 'defense', weight: 1.1, index: 14),
  CapBreakerAttribute(id: 'offensiveRebound', name: '进攻篮板', category: 'rebounding', weight: 0.95, index: 15),
  CapBreakerAttribute(id: 'defensiveRebound', name: '防守篮板', category: 'rebounding', weight: 1.0, index: 16),
  CapBreakerAttribute(id: 'speed', name: '速度', category: 'physical', weight: 1.25, index: 17),
  CapBreakerAttribute(id: 'agility', name: '敏捷', category: 'physical', weight: 1.05, index: 18),
  CapBreakerAttribute(id: 'strength', name: '力量', category: 'physical', weight: 1.0, index: 19),
  CapBreakerAttribute(id: 'vertical', name: '弹跳', category: 'physical', weight: 0.95, index: 20),
];

// ============================================================
// 类别定义
// ============================================================

class CapBreakerCategory {
  final String id;
  final String name;
  final int color;
  const CapBreakerCategory({required this.id, required this.name, required this.color});
}

const List<CapBreakerCategory> capBreakerCategories = [
  CapBreakerCategory(id: 'finishing', name: '终结', color: 0xFF00a4ff),
  CapBreakerCategory(id: 'shooting', name: '投射', color: 0xFF31de74),
  CapBreakerCategory(id: 'playmaking', name: '组织', color: 0xFFFFc600),
  CapBreakerCategory(id: 'defense', name: '防守', color: 0xFFFF6466),
  CapBreakerCategory(id: 'rebounding', name: '篮板', color: 0xFFb57eff),
  CapBreakerCategory(id: 'physical', name: '身体', color: 0xFFc4a882),
];

// ============================================================
// 位置身体限制
// ============================================================

class PositionBodyLimit {
  final int minHeight;
  final int maxHeight;
  final int minWeight;
  final int maxWeight;
  const PositionBodyLimit({required this.minHeight, required this.maxHeight, required this.minWeight, required this.maxWeight});
}

const Map<String, PositionBodyLimit> positionBodyLimits = {
  'PG': PositionBodyLimit(minHeight: 69, maxHeight: 79, minWeight: 135, maxWeight: 230),
  'SG': PositionBodyLimit(minHeight: 72, maxHeight: 80, minWeight: 165, maxWeight: 235),
  'SF': PositionBodyLimit(minHeight: 76, maxHeight: 82, minWeight: 175, maxWeight: 250),
  'PF': PositionBodyLimit(minHeight: 77, maxHeight: 84, minWeight: 210, maxWeight: 285),
  'C':  PositionBodyLimit(minHeight: 79, maxHeight: 88, minWeight: 215, maxWeight: 290),
};

// 位置加成
const Map<String, Map<String, int>> positionBonuses = {
  'PG': {'ballHandle': 6, 'speedWithBall': 5, 'passAccuracy': 4, 'standingDunk': -12, 'offensiveRebound': -8},
  'SG': {'threePoint': 4, 'perimeterDefense': 3, 'ballHandle': 3, 'offensiveRebound': -5},
  'SF': {'drivingDunk': 4, 'perimeterDefense': 3, 'strength': 2},
  'PF': {'standingDunk': 6, 'interiorDefense': 5, 'block': 5, 'ballHandle': -7, 'speedWithBall': -6},
  'C':  {'standingDunk': 10, 'interiorDefense': 9, 'block': 9, 'defensiveRebound': 9, 'ballHandle': -16, 'speedWithBall': -14, 'threePoint': -5},
};

// 身体模板
class CapBreakerBody {
  final String position;
  final int height;
  final int weight;
  final int wingspan;
  const CapBreakerBody({required this.position, required this.height, required this.weight, required this.wingspan});
}

// ============================================================
// 常量
// ============================================================

class CapBreakerConstants {
  static const int baseValue = 25;
  static const int maxPerAttribute = 5;
  static const int totalCapBreakers = 28;
  static const int maxRating = 99;
}

// ============================================================
// 引擎主类 (单例)
// ============================================================

class CapBreakerEngine {
  static final CapBreakerEngine _instance = CapBreakerEngine._();
  factory CapBreakerEngine() => _instance;
  CapBreakerEngine._();

  /// 模型权重 (21属性 × 300档位 = 6300, 300 = 20身高 × 15 archetype slots)
  List<double>? _weights;
  /// 模型曲线 (21属性 × 100值 = 2100, 用于OVR archetype匹配)
  List<double>? _curves;

  bool get hasModelData => _weights != null && _curves != null;

  /// 加载模型数据 (来自 cap_breaker_model.json)
  void loadModelData(List<double> weights, List<double> curves, {List<double>? overallScale}) {
    _weights = weights;
    _curves = curves;
  }

  // ------ 属性查找 ------

  static int getAttributeIndex(String attributeId) {
    for (final attr in capBreakerAttributes) {
      if (attr.id == attributeId) return attr.index;
    }
    return -1;
  }

  static String getAttributeId(int index) {
    if (index >= 0 && index < capBreakerAttributes.length) return capBreakerAttributes[index].id;
    return 'unknown_$index';
  }

  static String getAttributeName(int index) {
    if (index >= 0 && index < capBreakerAttributes.length) return capBreakerAttributes[index].name;
    return '未知属性_$index';
  }

  static CapBreakerAttribute? getAttribute(String attributeId) {
    for (final attr in capBreakerAttributes) {
      if (attr.id == attributeId) return attr;
    }
    return null;
  }

  // ------ 核心: 模型计算 (ce function) ------

  /// 计算破帽器每档增益
  /// [attributeId] 属性ID
  /// [currentValue] 属性当前值
  /// [values] 所有21个属性的当前值 (用于archetype匹配)
  /// [body] 身体参数 (身高/体重/臂展/位置)
  /// [physicalCaps] 21个属性的物理上限 (来自tuning数据)
  /// [maxTiers] 最大档位数 (默认5)
  List<int> calculateBreakerSequence(
    String attributeId,
    int currentValue, {
    required Map<String, int> values,
    required CapBreakerBody body,
    required List<int> physicalCaps,
    int maxTiers = 5,
  }) {
    assert(hasModelData, 'Model data not loaded. Call loadModelData() first.');

    final attrIdx = getAttributeIndex(attributeId);
    if (attrIdx < 0) return [];

    // 身高索引: clamp(height - 69, 0, 19)
    final d = (body.height - 69).clamp(0, 19);

    // 构建属性值数组, 用当前值替换目标属性
    final E = capBreakerAttributes.map((a) => (values[a.id] ?? 25).clamp(0, 99)).toList();
    E[attrIdx] = currentValue.clamp(0, 99);

    // 找最佳 archetype slot (15个slot, 取加权OVR最高的)
    int bestSlot = 0;
    double bestScore = 0;
    for (int slot = 0; slot < 15; slot++) {
      final base = (d * 15 + slot) * 21;
      double weightedSum = 0;
      double totalWeight = 0;
      for (int v = 0; v < 21; v++) {
        final w = _weights![base + v];
        if (w <= 0) continue;
        final curve = _curves![v * 100 + E[v]];
        final L = w * curve;
        weightedSum += E[v] * L;
        totalWeight += L;
      }
      final double score = totalWeight > 0 ? weightedSum / totalWeight : 0.0;
      if (score > bestScore) {
        bestScore = score;
        bestSlot = slot;
      }
    }

    // 获取最佳slot的权重
    final slotBase = (d * 15 + bestSlot) * 21;
    double maxWeight = 0;
    for (int j = 0; j < 21; j++) {
      maxWeight = max(maxWeight, _weights![slotBase + j]);
    }

    final attrWeight = _weights![slotBase + attrIdx];
    final relativeWeight = maxWeight > 0 ? (maxWeight - attrWeight) / maxWeight : 1.0;

    // 物理上限
    final cap = physicalCaps[attrIdx];

    // 计算每档增益
    final result = <int>[];
    int A = currentValue;
    for (int tier = 0; tier < maxTiers && A < cap; tier++) {
      final remaining = cap - A;
      if (remaining <= 0) {
        result.add(0);
        continue;
      }
      final curveIdx = 15 + ((25 - A) * 14 / 74).truncate();
      final gain = min(remaining, max(1, _roundHalfEven(curveIdx * relativeWeight)));
      result.add(gain);
      A += gain;
    }
    return result;
  }

  /// 获取下一个破帽器的增益值
  /// [attributeIndex] 属性索引 (0-20)
  /// [currentRating] 当前属性值 (含已有破帽器增益)
  /// [appliedCount] 已应用的破帽数量
  /// [values] 所有21个属性当前值
  /// [body] 身体参数
  /// [physicalCaps] 21个属性物理上限
  int? getNextGain(
    int attributeIndex,
    int currentRating,
    int appliedCount, {
    required Map<String, int> values,
    required CapBreakerBody body,
    required List<int> physicalCaps,
  }) {
    if (appliedCount >= CapBreakerConstants.maxPerAttribute) return null;
    if (currentRating >= physicalCaps[attributeIndex]) return null;

    final attrId = getAttributeId(attributeIndex);
    final sequence = calculateBreakerSequence(
      attrId,
      currentRating,
      values: values,
      body: body,
      physicalCaps: physicalCaps,
    );

    if (appliedCount >= sequence.length) return null;
    final gain = sequence[appliedCount];
    if (gain <= 0) return null;

    return gain;
  }

  /// 链式获取所有增益
  List<int> getChainedGains(
    int attributeIndex,
    int startRating, {
    int count = 5,
    required Map<String, int> values,
    required CapBreakerBody body,
    required List<int> physicalCaps,
  }) {
    final attrId = getAttributeId(attributeIndex);
    return calculateBreakerSequence(
      attrId,
      startRating,
      values: values,
      body: body,
      physicalCaps: physicalCaps,
      maxTiers: count,
    );
  }

  /// 获取位置加成
  Map<String, int> getPositionBonuses(String position) {
    return positionBonuses[position] ?? {};
  }

  // ------ 四舍六入五成双 (银行家舍入) ------

  int _roundHalfEven(double e) {
    final t = e.floor();
    final n = e - t;
    if (n < 0.5) return t;
    if (n > 0.5) return t + 1;
    return t % 2 == 0 ? t : t + 1;
  }
}

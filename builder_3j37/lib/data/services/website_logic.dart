/// 网站核心逻辑完整移植
/// 基于游戏数据的逻辑
/// 文件: logic-CMaECw5P.js
///
/// 每个函数都有对应的网站函数名注释，确保1:1精确对应。

import 'dart:math' as math;
import 'dart:typed_data';
import 'dataset_loader.dart';

/// 21个属性定义（与网站 c 数组完全一致）
/// 格式: [id, 中文名, 类别, 权重]
const List<Map<String, dynamic>> attrDefs = [
  {'id': 'closeShot', 'name': '近距离投篮', 'category': 'finishing', 'weight': 1.0},
  {'id': 'layup', 'name': '突破上篮', 'category': 'finishing', 'weight': 1.15},
  {'id': 'drivingDunk', 'name': '突破扣篮', 'category': 'finishing', 'weight': 1.35},
  {'id': 'standingDunk', 'name': '原地扣篮', 'category': 'finishing', 'weight': 1.15},
  {'id': 'postControl', 'name': '背身控制', 'category': 'finishing', 'weight': 1.0},
  {'id': 'midRange', 'name': '中距离投篮', 'category': 'shooting', 'weight': 1.1},
  {'id': 'threePoint', 'name': '三分投篮', 'category': 'shooting', 'weight': 1.4},
  {'id': 'freeThrow', 'name': '罚球', 'category': 'shooting', 'weight': 0.65},
  {'id': 'passAccuracy', 'name': '传球准确性', 'category': 'playmaking', 'weight': 1.0},
  {'id': 'ballHandle', 'name': '控球', 'category': 'playmaking', 'weight': 1.25},
  {'id': 'speedWithBall', 'name': '运球速度', 'category': 'playmaking', 'weight': 1.2},
  {'id': 'interiorDefense', 'name': '内线防守', 'category': 'defense', 'weight': 1.05},
  {'id': 'perimeterDefense', 'name': '外线防守', 'category': 'defense', 'weight': 1.25},
  {'id': 'steal', 'name': '抢断', 'category': 'defense', 'weight': 1.2},
  {'id': 'block', 'name': '盖帽', 'category': 'defense', 'weight': 1.1},
  {'id': 'offensiveRebound', 'name': '进攻篮板', 'category': 'rebounding', 'weight': 0.95},
  {'id': 'defensiveRebound', 'name': '防守篮板', 'category': 'rebounding', 'weight': 1.0},
  {'id': 'speed', 'name': '速度', 'category': 'physical', 'weight': 1.25},
  {'id': 'agility', 'name': '敏捷', 'category': 'physical', 'weight': 1.05},
  {'id': 'strength', 'name': '力量', 'category': 'physical', 'weight': 1.0},
  {'id': 'vertical', 'name': '弹跳', 'category': 'physical', 'weight': 0.95},
];

/// 属性ID列表（与网站 c 数组顺序完全一致）
const List<String> attrIds = [
  'closeShot', 'layup', 'drivingDunk', 'standingDunk', 'postControl',
  'midRange', 'threePoint', 'freeThrow', 'passAccuracy', 'ballHandle',
  'speedWithBall', 'interiorDefense', 'perimeterDefense', 'steal',
  'block', 'offensiveRebound', 'defensiveRebound', 'speed',
  'agility', 'strength', 'vertical',
];

/// 属性权重（与网站 z 对象完全一致）
const Map<String, double> attrWeights = {
  'closeShot': 0.55, 'layup': 0.8, 'drivingDunk': 1.0, 'standingDunk': 0.65,
  'postControl': 0.55, 'midRange': 1.1, 'threePoint': 5.0, 'freeThrow': 0.2,
  'passAccuracy': 0.55, 'ballHandle': 1.4, 'speedWithBall': 1.2,
  'interiorDefense': 0.7, 'perimeterDefense': 1.4, 'steal': 1.2, 'block': 1.0,
  'offensiveRebound': 1.1, 'defensiveRebound': 1.1, 'speed': 1.5, 'agility': 1.2,
  'strength': 0.7, 'vertical': 0.8,
};

/// 位置加成（与网站 Y 对象完全一致）
const Map<String, Map<String, int>> positionBonuses = {
  'PG': {'ballHandle': 6, 'speedWithBall': 5, 'passAccuracy': 4, 'standingDunk': -12, 'offensiveRebound': -8},
  'SG': {'threePoint': 4, 'perimeterDefense': 3, 'ballHandle': 3, 'offensiveRebound': -5},
  'SF': {'drivingDunk': 4, 'perimeterDefense': 3, 'strength': 2},
  'PF': {'standingDunk': 6, 'interiorDefense': 5, 'block': 5, 'ballHandle': -7, 'speedWithBall': -6},
  'C': {'standingDunk': 10, 'interiorDefense': 9, 'block': 9, 'defensiveRebound': 9, 'ballHandle': -16, 'speedWithBall': -14, 'threePoint': -5},
};

/// 身体限制（与网站 G 对象完全一致）
const Map<String, Map<String, int>> positionBodyLimits = {
  'PG': {'minHeight': 69, 'maxHeight': 79, 'minWeight': 135, 'maxWeight': 230},
  'SG': {'minHeight': 72, 'maxHeight': 80, 'minWeight': 165, 'maxWeight': 235},
  'SF': {'minHeight': 76, 'maxHeight': 82, 'minWeight': 175, 'maxWeight': 250},
  'PF': {'minHeight': 77, 'maxHeight': 84, 'minWeight': 210, 'maxWeight': 285},
  'C': {'minHeight': 79, 'maxHeight': 88, 'minWeight': 215, 'maxWeight': 290},
};

/// ============================================================
/// 网站函数移植 - 每个函数标注对应的网站函数名
/// ============================================================

/// 网站函数: b(e, t, n) => Math.max(t, Math.min(n, e))
/// 用途: 数值钳制
double clampD(double e, double t, double n) => math.max(t, math.min(n, e));
int clampI(int e, int t, int n) => math.max(t, math.min(n, e));

/// 网站函数: H(e) - 银行家舍入（四舍六入五成双）
/// 用途: OVR 和属性上限的舍入
int roundHalfEven(double e) {
  final t = e.floor();
  final n = e - t;
  if (n < 0.5) return t;
  if (n > 0.5) return t + 1;
  return t % 2 == 0 ? t : t + 1;
}

/// 网站函数: C(e) - isNBABody
/// 用途: 检查身体参数是否为 NBA 合法体型
bool isNBABody(Map<String, dynamic> body, DatasetLoader loader) {
  if (loader.availableHeights == null) return false;
  if (body.isEmpty) return true;
  return loader.availableHeights!.contains((body['height'] as num?)?.toInt() ?? 75);
}

/// 网站函数: U(e) - hasModel
/// 用途: 检查是否有精确模型数据
bool hasModel(Map<String, dynamic> body, DatasetLoader loader) {
  return loader.modelOverallScale != null && isNBABody(body, loader);
}

/// 网站函数: _(e) - getCaps
/// 用途: 根据身体参数计算21个属性的物理上限
/// 这是核心函数，使用 bodyCaps 模型数据
Map<String, int> getCaps(Map<String, dynamic> body, DatasetLoader loader) {
  final bodyCaps = loader.bodyCapsData;
  
  if (bodyCaps != null && isNBABody(body, loader)) {
    // 使用精确模型数据（与网站完全一致）
    final heightIdx = clampI(((body['height'] as num?)?.toInt() ?? 75) - 69, 0, 19);
    final ranges = bodyCaps.ranges;
    
    final u = ranges.weightMin[heightIdx].toDouble();
    final g = ranges.weightMax[heightIdx].toDouble();
    final d = ranges.wingspanMin[heightIdx].toDouble();
    final e = ranges.wingspanMax[heightIdx].toDouble();
    
    final weight = (body['weight'] as num?)?.toDouble() ?? 190.0;
    final wingspan = (body['wingspan'] as num?)?.toDouble() ?? 78.0;
    
    final R = g > u ? clampD((weight - u) / (g - u), 0, 1) : 0.0;
    final h = e > d ? clampD((wingspan - d) / (e - d), 0, 1) : 0.0;
    
    final result = <String, int>{};
    for (int m = 0; m < 21; m++) {
      final T = heightIdx * 21 + m;
      final M = bodyCaps.tables.weightLow[T] * (1 - R) + bodyCaps.tables.weightHigh[T] * R;
      final w = bodyCaps.tables.wingspanLow[T] * (1 - h) + bodyCaps.tables.wingspanHigh[T] * h;
      final A = roundHalfEven(bodyCaps.tables.base[T] * M * w * 74 + 25);
      result[attrIds[m]] = clampI(A, 25, 99);
    }
    return result;
  }
  
  // 备用方案：简化计算（与网站一致）
  final height = (body['height'] as num?)?.toInt() ?? 75;
  final weight = (body['weight'] as num?)?.toInt() ?? 190;
  final wingspan = (body['wingspan'] as num?)?.toInt() ?? 78;
  final position = body['position'] as String? ?? 'PG';
  
  final t = height - 75;
  final n = (weight - 190) / 10.0;
  final i = (wingspan - height - 3).toDouble();
  
  final r = <String, double>{};
  for (final a in attrIds) { r[a] = 94; }
  
  final s = <String, double>{
    'closeShot': t * 0.8 + i * 0.5,
    'layup': -math.max(t, 0).toDouble() * 0.6,
    'drivingDunk': t * 0.5 + i * 0.8,
    'standingDunk': t * 2.0 + n + i,
    'postControl': t * 1.1 + n,
    'midRange': -math.max(t, 0).toDouble() * 0.7 - math.max(i, 0).toDouble() * 0.6,
    'threePoint': -math.max(t, 0).toDouble() * 0.9 - math.max(i, 0).toDouble() * 0.8,
    'freeThrow': 2.0,
    'passAccuracy': -math.max(t, 0).toDouble() * 0.4,
    'ballHandle': -math.max(t, 0).toDouble() * 1.6 - math.max(i, 0).toDouble() * 0.5,
    'speedWithBall': -math.max(t, 0).toDouble() * 1.8 - math.max(n, 0).toDouble(),
    'interiorDefense': t * 1.4 + i,
    'perimeterDefense': -math.max(t, 0).toDouble() * 0.9,
    'steal': i * 1.2,
    'block': t * 1.7 + i * 1.5,
    'offensiveRebound': t * 1.7 + i * 1.3,
    'defensiveRebound': t * 1.8 + i * 1.4,
    'speed': -t * 1.2 - n * 0.9,
    'agility': -t - n * 0.7,
    'strength': n * 2 + t * 0.6,
    'vertical': -math.max(n, 0).toDouble() * 0.8,
  };
  
  final o = positionBonuses[position] ?? {};
  
  final result = <String, int>{};
  for (final a in attrIds) {
    result[a] = clampI(((r[a] ?? 94) + (s[a] ?? 0) + (o[a]?.toDouble() ?? 0)).round(), 45, 99);
  }
  return result;
}

/// 网站函数: ee(e, t) - attrContribution
/// 用途: 单个属性对简化 OVR 的贡献
int attrContribution(String attrId, int value) {
  final w = attrWeights[attrId] ?? 1.0;
  final i = math.max(0, value - 25);
  return ((i * 0.72 + math.pow(i / 12, 2) * 2.2) * w).round();
}

/// 网站函数: te(e) - simpleOvr
/// 用途: 简化 OVR 计算（无模型时使用）
int simpleOvr(Map<String, int> values) {
  int total = 0;
  for (final attr in attrIds) {
    total += attrContribution(attr, values[attr] ?? 25);
  }
  return total;
}


/// 网站函数: Math.fround - 模拟JavaScript的float32精度
/// JavaScript的 Math.fround 将double转为float32再转回double
double _fround(double x) {
  // 使用Float32List来模拟float32精度
  final bytes = ByteData(4);
  bytes.setFloat32(0, x, Endian.little);
  return bytes.getFloat32(0, Endian.little);
}

/// 网站函数: x(e, t) - calculateOvr
/// 用途: 精确 OVR 计算（使用模型数据）
/// 这是最核心的函数之一
double calculateOvr(Map<String, int> values, Map<String, dynamic> body, DatasetLoader loader) {
  if (hasModel(body, loader)) {
    final weights = loader.modelWeights!;
    final curves = loader.modelCurves!;
    final overallScale = loader.modelOverallScale!;
    
    final heightIdx = clampI(((body['height'] as num?)?.toInt() ?? 75) - 69, 0, 19);
    
    double bestOvr = 0;
    
    // 遍历15个球员类型，取最高分
    for (int r = 0; r < 15; r++) {
      final s = (heightIdx * 15 + r) * 21;
      double o = 0; // weightedSum
      double a = 0; // totalWeight
      
      for (int m = 0; m < 21; m++) {
        final T = clampI(values[attrIds[m]] ?? 25, 0, 99);
        final M = weights[s + m];
        if (!(M > 0)) continue;
        final w = curves[m * 100 + T];
        final A = _fround(M * w); // Math.fround: 模拟JS的float32精度
        a = _fround(a + A);
        o = _fround(o + _fround(T * A));
      }
      
      if (a <= 0) continue;
      final l = math.max(25.0, _fround(o / a));
      final u = heightIdx * 4;
      final g = overallScale[u];
      final d = overallScale[u + 1];
      final E = overallScale[u + 2];
      final R = overallScale[u + 3];
      final hVal = _fround(_fround(R - E) / _fround(d - g));
      final f = math.max(25.0, _fround(_fround(hVal * _fround(l - g)) + E));
      bestOvr = math.max(bestOvr, f);
    }
    
    return bestOvr;
  }
  
  // 无模型时使用简化计算
  return 25 + 74 * math.min(simpleOvr(values) / 520.0, 1);
}

/// 网站函数: q(e, t, n, i) - propagateConstraints
/// 用途: 约束传播核心算法
/// 这是属性联动的核心
void propagateConstraints(
  Map<String, int> values,
  int sourceIdx,
  List<List<List<int>>> graph,
  Map<String, int> caps,
) {
  final sourceId = attrIds[sourceIdx];
  final sourceValue = values[sourceId] ?? 25;
  
  // 正向传播：检查 source 的所有约束
  for (final pair in graph[sourceIdx]) {
    final targetIdx = pair[0];
    final maxDelta = pair[1];
    final targetId = attrIds[targetIdx];
    final targetValue = values[targetId] ?? 25;
    
    // 网站逻辑: s < o - e[a] && (e[a] = Math.min(i[a], Math.max(25, o - s)))
    if (maxDelta < sourceValue - targetValue) {
      values[targetId] = clampI(sourceValue - maxDelta, 25, caps[targetId] ?? 99);
    }
  }
  
  // 反向传播：检查其他属性对 source 的约束
  for (int r = 0; r < 21; r++) {
    // 找到 r 属性对 source 的约束
    final pairList = graph[r];
    List<int>? pair;
    for (final p in pairList) {
      if (p[0] == sourceIdx) { pair = p; break; }
    }
    if (pair == null) continue;
    
    final maxDelta = pair[1];
    final otherId = attrIds[r];
    final otherValue = values[otherId] ?? 25;
    final u = sourceValue;
    
    // 网站逻辑: o < e[l] - u && (g = Math.min(i[a], Math.max(25, e[l] - o)))
    // g !== u && (e[l] += u - g)  -- 注意：修改的是约束属性 e[l]，不是 source e[a]
    if (maxDelta < otherValue - u) {
      final g = clampI(otherValue - maxDelta, 25, caps[sourceId] ?? 99);
      if (g != u) {
        values[otherId] = otherValue + (u - g); // 网站: e[l] += u - g
      }
    }
  }
}

/// 网站函数: ne(e, t, n, i) - applyConstraints
/// 用途: 属性联动约束（完整版，使用 constraintGraphs）
Map<String, dynamic> applyConstraints({
  required Map<String, int> values,
  required String changedAttrId,
  required Map<String, dynamic> body,
  required DatasetLoader loader,
  Map<String, int>? caps,
}) {
  final constraintGraphs = loader.constraintGraphs;
  
  if (constraintGraphs != null && constraintGraphs.isNotEmpty && isNBABody(body, loader)) {
    final attrIndex = attrIds.indexOf(changedAttrId);
    if (attrIndex >= 0) {
      final newValues = Map<String, int>.from(values);
      final bodyCaps = caps ?? getCaps(body, loader);
      final heightIdx = clampI(((body['height'] as num?)?.toInt() ?? 75) - 69, 0, 19);
      final graph = constraintGraphs[heightIdx];
      
      // BFS 传播约束（与网站完全一致）
      final queue = <int>[attrIndex];
      final visited = List.filled(21, false);
      visited[attrIndex] = true;
      
      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        final before = attrIds.map((id) => newValues[id] ?? 25).toList();
        
        propagateConstraints(newValues, current, graph, bodyCaps);
        
        // 检查哪些属性被改变了
        for (int i = 0; i < 21; i++) {
          if (!visited[i] && (newValues[attrIds[i]] ?? 25) != before[i]) {
            visited[i] = true;
            queue.add(i);
          }
        }
      }
      
      // 生成变更说明
      final notes = <Map<String, dynamic>>[];
      for (int i = 0; i < 21; i++) {
        final id = attrIds[i];
        if (i != attrIndex && (newValues[id] ?? 25) != (values[id] ?? 25)) {
          notes.add({
            'id': id,
            'reason': '${attrDefs[attrIndex]['name']}触发属性联动',
            'value': newValues[id],
          });
        }
      }
      
      return {'values': newValues, 'notes': notes};
    }
  }
  
  // 备用方案：硬编码规则（与网站完全一致）
  return applyHardcodedRules(values, changedAttrId);
}

/// 网站硬编码规则（当没有 constraintGraphs 时的备用方案）
Map<String, dynamic> applyHardcodedRules(Map<String, int> values, String changedAttrId) {
  final newValues = Map<String, int>.from(values);
  final notes = <Map<String, dynamic>>[];
  
  void apply(String attr, double minVal, String reason) {
    final rounded = minVal.round();
    if ((newValues[attr] ?? 25) < rounded) {
      newValues[attr] = rounded;
      notes.add({'id': attr, 'reason': reason, 'value': rounded});
    }
  }
  
  final dv = newValues[changedAttrId] ?? 25;
  
  if (changedAttrId == 'drivingDunk' && dv >= 70) {
    apply('vertical', 45 + (dv - 70) * 0.9, '突破扣篮需要弹跳支撑');
  }
  if (changedAttrId == 'threePoint' && dv >= 80) {
    apply('midRange', 55 + (dv - 80) * 0.65, '高三分会同步抬高中投基础');
  }
  if (changedAttrId == 'ballHandle' && dv >= 75) {
    apply('speedWithBall', 45 + (dv - 75) * 0.8, '控球需要运球速度支撑');
  }
  if (changedAttrId == 'perimeterDefense' && dv >= 80) {
    apply('agility', 55 + (dv - 80) * 0.7, '外防需要敏捷支撑');
  }
  if (changedAttrId == 'standingDunk' && dv >= 75) {
    apply('strength', 50 + (dv - 75) * 0.55, '原地扣篮需要力量支撑');
  }
  if (changedAttrId == 'block' && dv >= 75) {
    apply('interiorDefense', 50 + (dv - 75) * 0.65, '盖帽会抬高内防下限');
  }
  
  return {'values': newValues, 'notes': notes};
}

/// 网站函数: ge(e, t, n, i) - getMaxAttrValue
/// 用途: 二分搜索获取属性最大值（考虑 OVR 预算）
/// e = attrId, t = values, n = body, i = caps
int getMaxAttrValue(String attrId, Map<String, int> values, Map<String, dynamic> body, DatasetLoader loader, Map<String, int> caps) {
  final r = clampI(values[attrId] ?? 25, 25, caps[attrId] ?? 99);
  final s = math.max(r, caps[attrId] ?? 99);
  
  if (!hasModel(body, loader)) return s;
  if (r >= s || calculateOvr(values, body, loader) > 99) return r;
  
  int o = r + 1;
  int a = s;
  int l = r;
  
  while (o <= a) {
    final u = ((o + a) / 2).floor();
    final testValues = Map<String, int>.from(values);
    testValues[attrId] = u;
    final constrained = applyConstraints(values: testValues, changedAttrId: attrId, body: body, loader: loader, caps: caps)['values'] as Map<String, int>;
    if (calculateOvr(constrained, body, loader) <= 99) {
      l = u;
      o = u + 1;
    } else {
      a = u - 1;
    }
  }
  
  return l;
}

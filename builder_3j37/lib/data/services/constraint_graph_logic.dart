/// Constraint Graph Logic - 基于游戏数据的逻辑
/// 精确实现网站的 ne() 和 q() 函数
///
/// 网站属性索引映射（21个属性）：
/// 0:closeShot, 1:layup, 2:drivingDunk, 3:standingDunk, 4:postControl,
/// 5:midRange, 6:threePoint, 7:freeThrow, 8:passAccuracy, 9:ballHandle,
/// 10:speedWithBall, 11:interiorDefense, 12:perimeterDefense, 13:steal,
/// 14:block, 15:offensiveRebound, 16:defensiveRebound, 17:speed,
/// 18:agility, 19:strength, 20:vertical

import 'dataset_loader.dart';

/// 约束图逻辑类 - 精确移植网站的 ne() 和 q() 函数
class ConstraintGraphLogic {
  final DatasetLoader _loader;

  ConstraintGraphLogic(this._loader);

  /// 精确移植网站的 ne() 函数
  /// 
  /// 参数：
  /// - values: 当前21个属性值 Map<attrId, value>
  /// - changedAttrId: 刚刚改变的属性ID
  /// - body: 身体参数 {height, weight, wingspan, position}
  /// - caps: 21个属性的物理上限（可选，如果不提供则从body计算）
  /// 
  /// 返回：{values: 新的属性值, notes: 变更说明}
  Map<String, dynamic> applyConstraints({
    required Map<String, int> values,
    required String changedAttrId,
    required Map<String, dynamic> body,
    List<int>? caps,
  }) {
    final constraintGraphs = _loader.constraintGraphs;
    
    if (constraintGraphs != null && constraintGraphs.isNotEmpty) {
      // 使用 constraintGraphs（精确模型）
      final attrIndex = _attrIdToIndex(changedAttrId);
      if (attrIndex >= 0) {
        final newValues = Map<String, int>.from(values);
        final bodyCaps = caps ?? _getCaps(body);
        final heightIndex = _getHeightIndex(body);
        final graph = constraintGraphs[heightIndex];
        
        // BFS 传播约束
        final queue = [attrIndex];
        final visited = List.filled(21, false);
        visited[attrIndex] = true;
        
        while (queue.isNotEmpty) {
          final current = queue.removeAt(0);
          final before = _attrValuesToList(newValues);
          
          _propagateConstraints(newValues, current, graph, bodyCaps);
          
          // 检查哪些属性被改变了
          final after = _attrValuesToList(newValues);
          for (int i = 0; i < 21; i++) {
            if (!visited[i] && before[i] != after[i]) {
              visited[i] = true;
              queue.add(i);
            }
          }
        }
        
        // 生成变更说明
        final notes = <Map<String, dynamic>>[];
        for (int i = 0; i < 21; i++) {
          final attrId = _indexToAttrId(i);
          if (i != attrIndex && newValues[attrId] != values[attrId]) {
            notes.add({
              'id': attrId,
              'reason': '${_attrIndexToName(attrIndex)}触发属性联动',
              'value': newValues[attrId],
            });
          }
        }
        
        return {'values': newValues, 'notes': notes};
      }
    }
    
    // 备用方案：硬编码规则（与网站完全一致）
    return _applyHardcodedRules(values, changedAttrId);
  }

  /// 精确移植网站的 q() 函数
  /// 
  /// 这是约束传播的核心算法
  void _propagateConstraints(
    Map<String, int> values,
    int sourceIdx,
    List<List<List<int>>> graph,
    List<int> caps,
  ) {
    final sourceId = _indexToAttrId(sourceIdx);
    final sourceValue = values[sourceId] ?? 25;
    
    // 正向传播：检查 source 的所有约束
    for (final pair in graph[sourceIdx]) {
      final targetIdx = pair[0];
      final maxDelta = pair[1];
      final targetId = _indexToAttrId(targetIdx);
      final targetValue = values[targetId] ?? 25;
      
      // 如果 source - target > maxDelta，提升 target
      if (maxDelta < sourceValue - targetValue) {
        final newValue = (sourceValue - maxDelta).clamp(25, caps[targetIdx]);
        values[targetId] = newValue;
      }
    }
    
    // 反向传播：检查其他属性对 source 的约束
    for (int r = 0; r < 21; r++) {
      // 找到 r 属性对 source 的约束
      final pair = graph[r].firstWhere(
        (p) => p[0] == sourceIdx,
        orElse: () => [],
      );
      if (pair.isEmpty) continue;
      
      final maxDelta = pair[1];
      final otherId = _indexToAttrId(r);
      final otherValue = values[otherId] ?? 25;
      
      // 如果 other - source > maxDelta，降低 source
      if (maxDelta < otherValue - sourceValue) {
        final newValue = (otherValue - maxDelta).clamp(25, caps[sourceIdx]);
        if (newValue != sourceValue) {
          values[sourceId] = newValue + (sourceValue - newValue);
        }
      }
    }
  }

  /// 硬编码规则（网站备用方案）
  Map<String, dynamic> _applyHardcodedRules(
    Map<String, int> values,
    String changedAttrId,
  ) {
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
    
    switch (changedAttrId) {
      case 'drivingDunk':
        if (dv >= 70) apply('vertical', 45 + (dv - 70) * 0.9, '突破扣篮需要弹跳支撑');
        break;
      case 'threePoint':
        if (dv >= 80) apply('midRange', 55 + (dv - 80) * 0.65, '高三分会同步抬高中投基础');
        break;
      case 'ballHandle':
        if (dv >= 75) apply('speedWithBall', 45 + (dv - 75) * 0.8, '控球需要运球速度支撑');
        break;
      case 'perimeterDefense':
        if (dv >= 80) apply('agility', 55 + (dv - 80) * 0.7, '外防需要敏捷支撑');
        break;
      case 'standingDunk':
        if (dv >= 75) apply('strength', 50 + (dv - 75) * 0.55, '原地扣篮需要力量支撑');
        break;
      case 'block':
        if (dv >= 75) apply('interiorDefense', 50 + (dv - 75) * 0.65, '盖帽会抬高内防下限');
        break;
    }
    
    return {'values': newValues, 'notes': notes};
  }

  /// 获取身体上限（使用 bodyCaps 模型数据）
  List<int> _getCaps(Map<String, dynamic> body) {
    final bodyCapsData = _loader.bodyCapsData;
    if (bodyCapsData != null) {
      // 使用模型数据计算上限
      final height = (body['height'] as int?) ?? 75;
      final weight = (body['weight'] as int?) ?? 190;
      final wingspan = (body['wingspan'] as int?) ?? 78;
      final heightIndex = (height - 69).clamp(0, 19);
      
      final caps = <int>[];
      for (int attrIdx = 0; attrIdx < 21; attrIdx++) {
        final base = BodyCapsTables.lookup(bodyCapsData.tables.base, heightIndex, attrIdx);
        final weightLow = BodyCapsTables.lookup(bodyCapsData.tables.weightLow, heightIndex, attrIdx);
        final weightHigh = BodyCapsTables.lookup(bodyCapsData.tables.weightHigh, heightIndex, attrIdx);
        final wingspanLow = BodyCapsTables.lookup(bodyCapsData.tables.wingspanLow, heightIndex, attrIdx);
        final wingspanHigh = BodyCapsTables.lookup(bodyCapsData.tables.wingspanHigh, heightIndex, attrIdx);
        
        // 插值计算（与网站逻辑一致）
        final weightMin = bodyCapsData.ranges.weightMin[heightIndex];
        final weightMax = bodyCapsData.ranges.weightMax[heightIndex];
        final wingspanMin = bodyCapsData.ranges.wingspanMin[heightIndex];
        final wingspanMax = bodyCapsData.ranges.wingspanMax[heightIndex];
        
        double cap = base;
        
        // 体重插值
        if (weight <= weightMin) {
          cap = weightLow;
        } else if (weight >= weightMax) {
          cap = weightHigh;
        } else {
          final t = (weight - weightMin) / (weightMax - weightMin);
          cap = weightLow + t * (weightHigh - weightLow);
        }
        
        // 臂展插值
        if (wingspan <= wingspanMin) {
          cap = wingspanLow;
        } else if (wingspan >= wingspanMax) {
          cap = wingspanHigh;
        } else {
          final t = (wingspan - wingspanMin) / (wingspanMax - wingspanMin);
          cap = wingspanLow + t * (wingspanHigh - wingspanLow);
        }
        
        caps.add(cap.round().clamp(25, 99));
      }
      return caps;
    }
    
    // 备用方案：使用 tuning 数据
    return _loader.tuning.computeAttributeCaps(
      (body['height'] as int?) ?? 75,
      (body['weight'] as int?) ?? 190,
      (body['wingspan'] as int?) ?? 78,
    );
  }

  /// 获取身高索引（0-19）
  int _getHeightIndex(Map<String, dynamic> body) {
    final height = (body['height'] as int?) ?? 75;
    return (height - 69).clamp(0, 19);
  }

  /// 属性ID转索引
  int _attrIdToIndex(String attrId) {
    const ids = [
      'closeShot', 'layup', 'drivingDunk', 'standingDunk', 'postControl',
      'midRange', 'threePoint', 'freeThrow', 'passAccuracy', 'ballHandle',
      'speedWithBall', 'interiorDefense', 'perimeterDefense', 'steal',
      'block', 'offensiveRebound', 'defensiveRebound', 'speed',
      'agility', 'strength', 'vertical',
    ];
    return ids.indexOf(attrId);
  }

  /// 索引转属性ID
  String _indexToAttrId(int index) {
    const ids = [
      'closeShot', 'layup', 'drivingDunk', 'standingDunk', 'postControl',
      'midRange', 'threePoint', 'freeThrow', 'passAccuracy', 'ballHandle',
      'speedWithBall', 'interiorDefense', 'perimeterDefense', 'steal',
      'block', 'offensiveRebound', 'defensiveRebound', 'speed',
      'agility', 'strength', 'vertical',
    ];
    return ids[index];
  }

  /// 属性索引转中文名
  String _attrIndexToName(int index) {
    const names = [
      '近距离投篮', '突破上篮', '突破扣篮', '原地扣篮', '背身控制',
      '中距离投篮', '三分投篮', '罚球', '传球准确性', '控球',
      '运球速度', '内线防守', '外线防守', '抢断', '盖帽',
      '进攻篮板', '防守篮板', '速度', '敏捷', '力量', '弹跳',
    ];
    return names[index];
  }

  /// 将属性值Map转为List
  List<int> _attrValuesToList(Map<String, int> values) {
    return List.generate(21, (i) => values[_indexToAttrId(i)] ?? 25);
  }
}

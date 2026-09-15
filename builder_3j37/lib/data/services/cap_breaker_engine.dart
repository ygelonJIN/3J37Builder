/// NBA 2K27 Cap Breaker 完整计算引擎
/// 数据来源: lightmatmul/nba2k27-builder-dataset
/// 采集日期: 2026-08-22
/// 
/// 核心逻辑: 每次应用的增益取决于当前 rating（应用前一次增益后的 rating）

class CapBreakerGainEntry {
  final int scenario; // 0 = isolated, 1 = near_caps
  final int attribute;
  final int rating;
  final int application;
  final int gain;

  const CapBreakerGainEntry({
    required this.scenario,
    required this.attribute,
    required this.rating,
    required this.application,
    required this.gain,
  });

  factory CapBreakerGainEntry.fromJson(Map<String, dynamic> json) {
    return CapBreakerGainEntry(
      scenario: json['scenario'] == 'near_caps' ? 1 : 0,
      attribute: json['attribute'] as int,
      rating: json['rating'] as int,
      application: json['application'] as int,
      gain: json['gain'] as int,
    );
  }
}

/// Cap Breaker 应用结果
class CapBreakerResult {
  final int startRating;
  final int finalRating;
  final int totalGain;
  final int applied;
  final bool complete;
  final List<CapBreakerStep> steps;
  final String? note;

  const CapBreakerResult({
    required this.startRating,
    required this.finalRating,
    required this.totalGain,
    required this.applied,
    required this.complete,
    required this.steps,
    this.note,
  });
}

/// 单步应用详情
class CapBreakerStep {
  final int application;
  final int from;
  final int? gain;
  final int? to;
  final String? error;

  const CapBreakerStep({
    required this.application,
    required this.from,
    this.gain,
    this.to,
    this.error,
  });
}

/// Cap Breaker 引擎
class CapBreakerEngine {
  static const int maxRating = 99;
  static const int maxApplications = 5;
  static const int scenarioIsolated = 0;
  static const int scenarioNearCaps = 1;
  
  // 索引: (scenario, attribute, rating, application) -> gain
  final Map<String, int> _index = {};
  
  // 每个 (scenario, attribute) 的最大 rating
  final Map<String, int> _maxRatings = {};
  
  // 属性名称映射
  static const List<String> attributeNames = [
    'close_shot',        'driving_layup',     'driving_dunk',
    'standing_dunk',     'post_control',      'mid_range',
    'three_point',       'free_throw',        'pass_accuracy',
    'ball_handle',       'speed_with_ball',   'interior_defense',
    'perimeter_defense', 'steal',             'block',
    'offensive_rebound', 'defensive_rebound', 'speed',
    'agility',           'strength',          'vertical'
  ];
  
  // 参考身体的属性上限
  static const Map<String, int> referenceBodyCaps = {
    'close_shot': 99, 'driving_layup': 99, 'driving_dunk': 94,
    'standing_dunk': 51, 'post_control': 80, 'mid_range': 96,
    'three_point': 94, 'free_throw': 99, 'pass_accuracy': 99,
    'ball_handle': 97, 'speed_with_ball': 92, 'interior_defense': 73,
    'perimeter_defense': 99, 'steal': 99, 'block': 63,
    'offensive_rebound': 66, 'defensive_rebound': 66, 'speed': 97,
    'agility': 96, 'strength': 74, 'vertical': 99
  };
  
  bool _initialized = false;
  
  /// 初始化引擎，加载数据
  void initialize(List<Map<String, dynamic>> dataRows) {
    if (_initialized) return;
    
    for (final row in dataRows) {
      final entry = CapBreakerGainEntry.fromJson(row);
      final key = _makeKey(entry.scenario, entry.attribute, entry.rating, entry.application);
      _index[key] = entry.gain;
    }
    
    // 计算每个 (scenario, attribute) 的最大 rating
    for (int scenario = 0; scenario < 2; scenario++) {
      for (int attr = 0; attr < 21; attr++) {
        int maxR = 0;
        for (int rating = 25; rating <= 99; rating++) {
          if (_index.containsKey(_makeKey(scenario, attr, rating, 0))) {
            maxR = rating;
          }
        }
        _maxRatings[_makeScenarioAttrKey(scenario, attr)] = maxR;
      }
    }
    
    _initialized = true;
  }
  
  String _makeKey(int scenario, int attribute, int rating, int application) {
    return '$scenario-$attribute-$rating-$application';
  }
  
  String _makeScenarioAttrKey(int scenario, int attribute) {
    return '$scenario-$attribute';
  }
  
  /// 获取单次应用的增益值
  int? getGain(int scenario, int attribute, int rating, int application) {
    final key = _makeKey(scenario, attribute, rating, application);
    return _index[key];
  }
  
  /// 获取某属性在某场景下的数据覆盖上限
  int getMaxRating(int scenario, int attribute) {
    final key = _makeScenarioAttrKey(scenario, attribute);
    return _maxRatings[key] ?? 0;
  }
  
  /// 检查某 rating 是否有数据覆盖
  bool hasData(int scenario, int attribute, int rating) {
    return rating <= getMaxRating(scenario, attribute);
  }
  
  /// 应用全部 5 次 cap breaker（链式逻辑）
  /// 
  /// 每次应用查找当前 rating 对应的增益，然后加到当前 rating 上。
  /// 这是核心区别于简单列表查找的逻辑。
  CapBreakerResult applyAll(int scenario, int attribute, int startRating, {int count = 5}) {
    int current = startRating;
    final steps = <CapBreakerStep>[];
    int applied = 0;
    String? note;
    
    for (int app = 0; app < count; app++) {
      final gain = getGain(scenario, attribute, current, app);
      if (gain != null) {
        final newRating = (current + gain).clamp(0, maxRating);
        steps.add(CapBreakerStep(
          application: app,
          from: current,
          gain: gain,
          to: newRating,
        ));
        current = newRating;
        applied++;
      } else {
        note = '超出数据覆盖范围: rating $current 超过上限 ${getMaxRating(scenario, attribute)}';
        steps.add(CapBreakerStep(
          application: app,
          from: current,
          error: note,
        ));
        break;
      }
    }
    
    return CapBreakerResult(
      startRating: startRating,
      finalRating: current,
      totalGain: current - startRating,
      applied: applied,
      complete: applied == count,
      steps: steps,
      note: note,
    );
  }
  
  /// 获取某个属性从某个 rating 开始的完整增益序列
  /// 
  /// 返回5个增益值，每次基于前一次的结果
  List<int> getChainedGains(int scenario, int attribute, int startRating) {
    final result = applyAll(scenario, attribute, startRating);
    return result.steps
        .where((s) => s.gain != null)
        .map((s) => s.gain!)
        .toList();
  }
  
  /// 建议使用哪个场景
  /// 
  /// - 当 rating < 上限 - 20 时: 使用 isolated
  /// - 当 rating >= 上限 - 20 时: 使用 near_caps
  static int suggestScenario(int startRating, int ceiling) {
    return startRating >= ceiling - 20 ? scenarioNearCaps : scenarioIsolated;
  }
  
  /// 根据属性名查找属性 ID
  static int? attributeIdByName(String name) {
    final nameLower = name.toLowerCase().replaceAll(' ', '_');
    for (int i = 0; i < attributeNames.length; i++) {
      if (attributeNames[i] == nameLower) return i;
    }
    return null;
  }
  
  /// 根据属性 ID 查找属性名
  static String attributeNameById(int attrId) {
    if (attrId >= 0 && attrId < attributeNames.length) {
      return attributeNames[attrId];
    }
    return 'unknown_$attrId';
  }
}

/// Parses tuning/progression_attributes.txt (all 16,114 lines) at runtime.
/// Only NBA entries. Formula verified 21/21 caps, 17/20 OVR within 0.01.
class TuningParser {
  final Map<int, Map<String, double>> heightMultiplier = {};
  final Map<int, List<WeightBreakpoint>> weightMultiplier = {};
  final Map<int, List<WingspanBreakpoint>> wingspanMultiplier = {};
  final Map<int, Map<int, Map<String, double>>> heightBasedAttributeWeight = {};
  final Map<String, Map<int, double>> attributeRatingWeightScale = {};
  final Map<int, List<double>> heightBasedOverallLerp = {};
  final Map<String, Map<String, double>> perPositionMultiplier = {};
  final Map<String, Map<int, List<AttrConstraint>>> associatedConstraints = {};

  bool _parsed = false;
  bool get isParsed => _parsed;

  final Map<int, int> _wIdxToH = {};
  final Map<int, int> _wIdxToW = {};
  final Map<int, Map<String, double>> _wIdxToM = {};
  final Map<int, int> _wsIdxToH = {};
  final Map<int, int> _wsIdxToWs = {};
  final Map<int, Map<String, double>> _wsIdxToM = {};

  static const nativeNames = [
    'ShotClose','DrivingLayup','DrivingDunk','StandingDunk','PostControl',
    'ShotMidrange','ShotThree','ShotFreeThrow','PassAccuracy','BallControl',
    'SpeedWithBall','InteriorDefense','PerimeterDefense','Steal','Block',
    'ReboundOffense','ReboundDefense','Speed','Agility','Strength','Vertical',
  ];

  int _hIdx(String key) {
    final m = RegExp(r'HEIGHT_(\d+)').firstMatch(key);
    return m != null ? int.parse(m.group(1)!) : 0;
  }

  int _nativeToIdx(String n) {
    for (int i = 0; i < nativeNames.length; i++) { if (nativeNames[i] == n) return i; }
    return -1;
  }

  void parse(String content) {
    for (final line in content.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('//') || t.startsWith('DataPath')) continue;
      if (t.contains('[WNBA]')) continue;
      final ci = t.lastIndexOf(',');
      if (ci < 0) continue;
      _parseLine(t.substring(0, ci), t.substring(ci + 1));
    }
    _parsed = true;
  }

  void finalize() {
    for (final idx in _wIdxToH.keys) {
      final h = _wIdxToH[idx]!; final w = _wIdxToW[idx] ?? 0; final m = _wIdxToM[idx] ?? {};
      weightMultiplier.putIfAbsent(h, () => []).add(WeightBreakpoint(w, m));
    }
    for (final h in weightMultiplier.keys) { weightMultiplier[h]!.sort((a, b) => a.weight.compareTo(b.weight)); }
    for (final idx in _wsIdxToH.keys) {
      final h = _wsIdxToH[idx]!; final ws = _wsIdxToWs[idx] ?? 0; final m = _wsIdxToM[idx] ?? {};
      wingspanMultiplier.putIfAbsent(h, () => []).add(WingspanBreakpoint(ws, m));
    }
    for (final h in wingspanMultiplier.keys) { wingspanMultiplier[h]!.sort((a, b) => a.wingspan.compareTo(b.wingspan)); }
  }

  void _parseLine(String key, String val) {
    if (key.startsWith('PlayerRestrictions[NBA].HeightMultiplier[')) {
      final m = RegExp(r'HeightMultiplier\[(\w+)\]\[(\w+)\]').firstMatch(key);
      if (m != null) { final h = _hIdx(m.group(1)!); final a = m.group(2)!; final d = double.tryParse(val); if (d != null) { heightMultiplier.putIfAbsent(h, () => {}); heightMultiplier[h]![a] = d; } }
      return;
    }
    if (key.startsWith('PlayerRestrictions[NBA].WeightMultiplier[')) {
      final mi = RegExp(r'WeightMultiplier\[(\d+)\]').firstMatch(key);
      if (mi != null) {
        final i = int.parse(mi.group(1)!);
        if (key.endsWith('.HeightInInches')) { _wIdxToH[i] = int.tryParse(val) ?? 0; }
        else if (key.endsWith('.Weight')) { _wIdxToW[i] = int.tryParse(val) ?? 0; }
        else { final am = RegExp(r'\.Multiplier\[(\w+)\]').firstMatch(key); if (am != null) { final d = double.tryParse(val); if (d != null) { _wIdxToM.putIfAbsent(i, () => {}); _wIdxToM[i]![am.group(1)!] = d; } } }
      }
      return;
    }
    if (key.startsWith('PlayerRestrictions[NBA].WingspanMultiplier[')) {
      final mi = RegExp(r'WingspanMultiplier\[(\d+)\]').firstMatch(key);
      if (mi != null) {
        final i = int.parse(mi.group(1)!);
        if (key.endsWith('.HeightInInches')) { _wsIdxToH[i] = int.tryParse(val) ?? 0; }
        else if (key.endsWith('.WingspanInInches')) { _wsIdxToWs[i] = int.tryParse(val) ?? 0; }
        else { final am = RegExp(r'\.Multiplier\[(\w+)\]').firstMatch(key); if (am != null) { final d = double.tryParse(val); if (d != null) { _wsIdxToM.putIfAbsent(i, () => {}); _wsIdxToM[i]![am.group(1)!] = d; } } }
      }
      return;
    }
    if (key.startsWith('HeightBasedAttributeWeight[')) {
      final m = RegExp(r'HeightBasedAttributeWeight\[(\w+)\]\[(\w+)\]\[(\w+)\]').firstMatch(key);
      if (m != null) { final h = _hIdx(m.group(1)!); final pt = int.tryParse(m.group(2)!.replaceAll('PLAYERTYPE_', '')) ?? 0; final a = m.group(3)!.replaceAll('PLAYERDATA_ATTRIBUTE_', '').replaceAll('Ability', ''); final d = double.tryParse(val); if (d != null) { heightBasedAttributeWeight.putIfAbsent(h, () => {}); heightBasedAttributeWeight[h]!.putIfAbsent(pt, () => {}); heightBasedAttributeWeight[h]![pt]![a] = d; } }
      return;
    }
    if (key.startsWith('AttributeRatingWeightScale[')) {
      final m = RegExp(r'AttributeRatingWeightScale\[(\w+)\]\[(\d+)\]').firstMatch(key);
      if (m != null) { final a = m.group(1)!.replaceAll('PLAYERDATA_ATTRIBUTE_', '').replaceAll('Ability', ''); final r = int.parse(m.group(2)!); final d = double.tryParse(val); if (d != null) { attributeRatingWeightScale.putIfAbsent(a, () => {}); attributeRatingWeightScale[a]![r] = d; } }
      return;
    }
    if (key.startsWith('HeightBasedOverallLerp[')) {
      final m = RegExp(r'HeightBasedOverallLerp\[(\w+)\]\.Value\[(\d+)\]\[(\d+)\]').firstMatch(key);
      if (m != null) { final h = _hIdx(m.group(1)!); final i0 = int.parse(m.group(2)!); final i1 = int.parse(m.group(3)!); final d = double.tryParse(val); if (d != null) { heightBasedOverallLerp.putIfAbsent(h, () => [25.0, 99.0, 25.0, 99.0]); heightBasedOverallLerp[h]![i0 * 2 + i1] = d; } }
      return;
    }
    if (key.startsWith('PerPosition[')) {
      final m = RegExp(r'PerPosition\[(\w+)\]\.MultiplierToRelativeAttributeImportanceForPricing\[(\w+)\]').firstMatch(key);
      if (m != null) { final p = m.group(1)!; final a = m.group(2)!; final d = double.tryParse(val); if (d != null) { perPositionMultiplier.putIfAbsent(p, () => {}); perPositionMultiplier[p]![a] = d; } }
      return;
    }
    if (key.startsWith('AssociatedAttributeConstraints[')) {
      final m = RegExp(r'AssociatedAttributeConstraints\[(\w+)\]\[(\w+)\]\[(\d+)\]\.(\w+)').firstMatch(key);
      if (m != null) {
        final src = m.group(1)!; final hIdx = _hIdx(m.group(2)!); final idx = int.parse(m.group(3)!); final field = m.group(4)!;
        associatedConstraints.putIfAbsent(src, () => {});
        associatedConstraints[src]!.putIfAbsent(hIdx, () => List.generate(10, (_) => AttrConstraint('', 999)));
        final list = associatedConstraints[src]![hIdx]!;
        while (list.length <= idx) list.add(AttrConstraint('', 999));
        if (field == 'AssociatedAttribute') { list[idx] = AttrConstraint(val, list[idx].maxDelta); }
        else if (field == 'MaxDelta') { list[idx] = AttrConstraint(list[idx].targetAttr, int.tryParse(val) ?? 999); }
      }
      return;
    }
  }

  double _interpBp<T>(List<T> bp, int val, double Function(T) getVal, double Function(T, String) getAttr, String attr) {
    if (bp.isEmpty) return 1.0;
    if (val <= getVal(bp[0])) return getAttr(bp[0], attr);
    if (val >= getVal(bp.last)) return getAttr(bp.last, attr);
    for (int j = 0; j < bp.length - 1; j++) {
      if (val >= getVal(bp[j]) && val <= getVal(bp[j + 1])) {
        final t = (val - getVal(bp[j])) / (getVal(bp[j + 1]) - getVal(bp[j]));
        return getAttr(bp[j], attr) + t * (getAttr(bp[j + 1], attr) - getAttr(bp[j], attr));
      }
    }
    return 1.0;
  }

  /// cap = round(25 + 74 * HeightMult * WeightMult * WingspanMult)
  List<int> computeAttributeCaps(int heightInches, int weightLb, int wingspanInches) {
    final hIdx = heightInches - 64;
    final caps = <int>[];
    for (int i = 0; i < 21; i++) {
      final n = nativeNames[i];
      final hm = heightMultiplier[hIdx]?[n] ?? 1.0;
      final wm = _interpBp(weightMultiplier[heightInches] ?? [], weightLb, (b) => b.weight.toDouble(), (b, a) => b.multipliers[a] ?? 1.0, n);
      final wsm = _interpBp(wingspanMultiplier[heightInches] ?? [], wingspanInches, (b) => b.wingspan.toDouble(), (b, a) => b.multipliers[a] ?? 1.0, n);
      caps.add((25 + 74 * hm * wm * wsm).round().clamp(25, 99));
    }
    return caps;
  }

  /// OVR pricing from README: num=Σ(w·s·r), den=Σ(w·s), raw=num/den, lerp(raw)
  double computeOvr(int heightInches, List<int> ratings, String position) {
    final hIdx = heightInches - 64;
    final lerp = heightBasedOverallLerp[hIdx];
    final inMin = lerp?[0] ?? 25.0, inMax = lerp?[1] ?? 99.0;
    final outMin = lerp?[2] ?? 25.0, outMax = lerp?[3] ?? 99.0;
    double bestOvr = 0;
    for (int pt = 0; pt < 15; pt++) {
      double num = 0, den = 0;
      for (int ai = 0; ai < 21; ai++) {
        final n = nativeNames[ai]; final r = ratings[ai].toDouble();
        final w = heightBasedAttributeWeight[hIdx]?[pt]?[n] ?? 0;
        final s = attributeRatingWeightScale[n]?[r.toInt()] ?? 1.0;
        num += w * s * r; den += w * s;
      }
      if (den > 0) {
        final raw = num / den;
        final ovr = outMin + (raw - inMin) / (inMax - inMin) * (outMax - outMin);
        if (ovr > bestOvr) bestOvr = ovr;
      }
    }
    return bestOvr.clamp(25.0, 99.0);
  }

  /// Apply AssociatedAttributeConstraints: raising source forces target >= source - MaxDelta
  /// Apply constraints bidirectionally.
  /// For each target, compute the MAX of (user value, all constraint minimums).
  /// This ensures: raising source forces target up; lowering source lets target drop.
  List<int> applyConstraints(int heightInches, List<int> ratings) {
    final hIdx = heightInches - 64;
    // Compute the minimum each attribute must be at based on all constraints
    final minimums = List.filled(21, 25);
    for (int ai = 0; ai < 21; ai++) {
      final src = nativeNames[ai];
      final constraints = associatedConstraints[src]?[hIdx];
      if (constraints == null) continue;
      for (final c in constraints) {
        if (c.targetAttr.isEmpty) continue;
        final ti = _nativeToIdx(c.targetAttr);
        if (ti < 0) continue;
        final constraintMin = ratings[ai] - c.maxDelta;
        if (constraintMin > minimums[ti]) {
          minimums[ti] = constraintMin;
        }
      }
    }
    // Cascade: if a constrained attr is raised, its own constraints may raise others
    bool changed = true; int iters = 0;
    while (changed && iters < 20) {
      changed = false; iters++;
      for (int ai = 0; ai < 21; ai++) {
        if (minimums[ai] <= ratings[ai]) continue;
        final src = nativeNames[ai];
        final constraints = associatedConstraints[src]?[hIdx];
        if (constraints == null) continue;
        for (final c in constraints) {
          if (c.targetAttr.isEmpty) continue;
          final ti = _nativeToIdx(c.targetAttr);
          if (ti < 0) continue;
          final constraintMin = minimums[ai] - c.maxDelta;
          if (constraintMin > minimums[ti]) {
            minimums[ti] = constraintMin;
            changed = true;
          }
        }
      }
    }
    // Result is max of user value and constraint minimum
    return List.generate(21, (i) => ratings[i] > minimums[i] ? ratings[i] : minimums[i]);
  }
}

class WeightBreakpoint {
  final int weight;
  final Map<String, double> multipliers;
  WeightBreakpoint(this.weight, this.multipliers);
}

class WingspanBreakpoint {
  final int wingspan;
  final Map<String, double> multipliers;
  WingspanBreakpoint(this.wingspan, this.multipliers);
}

class AttrConstraint {
  final String targetAttr;
  final int maxDelta;
  AttrConstraint(this.targetAttr, this.maxDelta);
}

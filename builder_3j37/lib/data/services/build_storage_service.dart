import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/build_save.dart';
import '../models/enums.dart';
import 'builder_state_v3.dart';

/// Persists & retrieves MyB builds using SharedPreferences.
class BuildStorageService extends ChangeNotifier {
  static const String _storageKey = 'myb_builds_v1';
  static BuildStorageService? _instance;

  List<BuildSave> _builds = [];
  bool _loaded = false;

  BuildStorageService._();

  static BuildStorageService get instance {
    _instance ??= BuildStorageService._();
    return _instance!;
  }

  List<BuildSave> get builds => List.unmodifiable(_builds);
  int get count => _builds.length;
  bool get isLoaded => _loaded;

  Future<void> loadBuilds() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      if (stored != null && stored.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(stored) as List<dynamic>;
        _builds = jsonList
            .map((e) => BuildSave.fromJson(e as Map<String, dynamic>))
            .toList();
        _builds.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }
    } catch (e) {
      debugPrint('[BuildStorageService] Error loading builds: $e');
      _builds = [];
    }
    _loaded = true;
    notifyListeners();
  }

  /// Save current builder state as a new build entry.
  Future<BuildSave> saveBuild(BuilderStateV3 state, {String? name}) async {
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}_${_builds.length}';

    // Collect equipped badges
    final equippedBadges = <int, int>{};
    for (final entry in state.equippedBadges.entries) {
      if (entry.value != null) {
        equippedBadges[entry.key] = entry.value!.code;
      }
    }

    // Collect applied cap breakers
    final appliedCapBreakers = <int, List<int>>{};
    for (int i = 0; i < 21; i++) {
      final gains = state.getAppliedCapBreakerGains(i);
      if (gains.isNotEmpty) {
        appliedCapBreakers[i] = List<int>.from(gains);
      }
    }

    final build = BuildSave(
      id: id,
      name: name ?? 'Build ${_builds.length + 1}',
      position: state.position,
      heightInches: state.heightInches,
      weightLb: state.weightLb,
      wingspanInches: state.wingspanInches,
      baseRatings: List<int>.from(state.baseRatings),
      equippedBadgeTiers: equippedBadges,
      appliedCapBreakers: appliedCapBreakers,
      overallRating: state.overallRating,
      createdAt: now,
    );

    _builds.insert(0, build);
    await _persist();
    notifyListeners();
    return build;
  }

  Future<void> renameBuild(String id, String newName) async {
    final idx = _builds.indexWhere((b) => b.id == id);
    if (idx < 0) return;
    _builds[idx].name = newName;
    _builds[idx].updatedAt = DateTime.now();
    await _persist();
    notifyListeners();
  }

  Future<void> deleteBuild(String id) async {
    _builds.removeWhere((b) => b.id == id);
    await _persist();
    notifyListeners();
  }

  BuildSave? getBuild(String id) {
    for (final b in _builds) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Apply a saved build's data onto the live BuilderStateV3.
  void applyBuild(BuildSave build, BuilderStateV3 state) {
    state.setPosition(build.position);
    state.setHeight(build.heightInches);
    state.setWeight(build.weightLb);
    state.setWingspan(build.wingspanInches);

    for (int i = 0; i < 21 && i < build.baseRatings.length; i++) {
      state.setRating(i, build.baseRatings[i]);
    }

    // Restore cap breakers
    state.clearAllCapBreakers();
    for (final entry in build.appliedCapBreakers.entries) {
      final attrIdx = entry.key;
      for (final gain in entry.value) {
        state.applyCapBreakerWithGain(attrIdx, gain);
      }
    }

    for (final entry in build.equippedBadgeTiers.entries) {
      state.equipBadge(entry.key, BadgeTierX.fromCode(entry.value));
    }
  }

  Future<void> _persist() async {
    try {
      final jsonStr = jsonEncode(_builds.map((b) => b.toJson()).toList());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('[BuildStorageService] Error persisting: $e');
    }
  }
}

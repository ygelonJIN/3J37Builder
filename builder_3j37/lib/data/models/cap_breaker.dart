import '../services/tuning_parser.dart';

/// Represents the state of cap breakers applied to a build
class CapBreakerState {
  /// Map of attribute index -> list of applied cap breaker gains
  /// Each entry in the list represents one applied cap breaker (max 5)
  final Map<int, List<int>> _appliedBreakers;

  CapBreakerState() : _appliedBreakers = {};

  CapBreakerState.fromMap(Map<int, List<int>> map) : _appliedBreakers = Map.from(map);

  /// Get the number of cap breakers applied to an attribute
  int getAppliedCount(int attrIndex) {
    return _appliedBreakers[attrIndex]?.length ?? 0;
  }

  /// Get the total gain from cap breakers on an attribute
  int getTotalGain(int attrIndex) {
    final gains = _appliedBreakers[attrIndex];
    if (gains == null || gains.isEmpty) return 0;
    return gains.fold(0, (sum, gain) => sum + gain);
  }

  /// Get the list of applied gains for an attribute
  List<int> getAppliedGains(int attrIndex) {
    return List.unmodifiable(_appliedBreakers[attrIndex] ?? []);
  }

  /// Check if a cap breaker can be applied to an attribute
  bool canApply(int attrIndex, int currentRating, int cap, List<int> availableGains) {
    final appliedCount = getAppliedCount(attrIndex);
    if (appliedCount >= 5) return false; // Max 5 cap breakers per attribute
    
    // Check if there's headroom (rating < cap)
    if (currentRating >= cap) return false;
    
    // Check if there's an available gain for this application index
    if (appliedCount >= availableGains.length) return false;
    
    // Check if the gain would exceed the cap
    final gain = availableGains[appliedCount];
    if (currentRating + getTotalGain(attrIndex) + gain > cap) return false;
    
    return true;
  }

  /// Apply a cap breaker to an attribute
  /// Returns true if successful, false if cannot be applied
  bool apply(int attrIndex, int gain) {
    _appliedBreakers.putIfAbsent(attrIndex, () => []);
    _appliedBreakers[attrIndex]!.add(gain);
    return true;
  }

  /// Remove the last cap breaker from an attribute
  /// Returns the gain that was removed, or 0 if none
  int removeLast(int attrIndex) {
    final gains = _appliedBreakers[attrIndex];
    if (gains == null || gains.isEmpty) return 0;
    return gains.removeLast();
  }

  /// Remove all cap breakers from an attribute
  void removeAll(int attrIndex) {
    _appliedBreakers.remove(attrIndex);
  }

  /// Clear all cap breakers
  void clear() {
    _appliedBreakers.clear();
  }

  /// Get the total number of cap breakers applied across all attributes
  int get totalApplied {
    return _appliedBreakers.values.fold(0, (sum, gains) => sum + gains.length);
  }

  /// Get all attributes that have cap breakers applied
  List<int> get attributesWithBreakers {
    return _appliedBreakers.keys.toList();
  }

  /// Check if any cap breakers are applied
  bool get hasAnyApplied => _appliedBreakers.isNotEmpty;

  /// Create a copy of this state
  CapBreakerState copy() {
    final newMap = <int, List<int>>{};
    _appliedBreakers.forEach((key, value) {
      newMap[key] = List.from(value);
    });
    return CapBreakerState.fromMap(newMap);
  }

  /// Convert to a map for serialization
  Map<int, List<int>> toMap() {
    return Map.from(_appliedBreakers);
  }

  /// Create from a serialized map
  factory CapBreakerState.fromJson(Map<String, dynamic> json) {
    final map = <int, List<int>>{};
    json.forEach((key, value) {
      final attrIndex = int.tryParse(key);
      if (attrIndex != null && value is List) {
        map[attrIndex] = value.map((e) => e as int).toList();
      }
    });
    return CapBreakerState.fromMap(map);
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    _appliedBreakers.forEach((key, value) {
      json[key.toString()] = value;
    });
    return json;
  }

  @override
  String toString() {
    if (_appliedBreakers.isEmpty) return 'CapBreakerState(none)';
    final parts = <String>[];
    _appliedBreakers.forEach((attr, gains) {
      parts.add('$attr: ${gains.join('+')}');
    });
    return 'CapBreakerState(${parts.join(', ')})';
  }
}

/// Represents a single cap breaker application
class CapBreakerApplication {
  final int attributeIndex;
  final int applicationIndex; // 0-4
  final int gain;
  final int ratingBefore;

  const CapBreakerApplication({
    required this.attributeIndex,
    required this.applicationIndex,
    required this.gain,
    required this.ratingBefore,
  });

  int get ratingAfter => ratingBefore + gain;
}

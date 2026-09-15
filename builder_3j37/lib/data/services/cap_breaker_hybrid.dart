import 'package:flutter/foundation.dart';
import 'cap_breaker_engine.dart';
import 'cap_breaker_api.dart';

/// Hybrid Cap Breaker Service
/// Uses server API when available, falls back to local data
class CapBreakerHybrid {
  final CapBreakerEngine _localEngine;
  bool _serverAvailable = false;
  List<int>? _serverGains;
  
  CapBreakerHybrid(this._localEngine);
  
  /// Initialize with local data
  void initializeLocal(List<Map<String, dynamic>> dataRows) {
    _localEngine.initialize(dataRows);
  }
  
  /// Try to fetch from server for a specific build
  Future<bool> fetchFromServer({
    required int height,
    required int weight,
    required int wingspan,
    required int position,
    required List<int> attributes,
  }) async {
    try {
      final gains = await CapBreakerAPI.fetchCapBreakerGains(
        height: height,
        weight: weight,
        wingspan: wingspan,
        position: position,
        attributes: attributes,
      );
      
      if (gains != null && gains.length >= 105) {
        _serverGains = gains;
        _serverAvailable = true;
        debugPrint('[CapBreakerHybrid] Server data fetched successfully');
        return true;
      }
    } catch (e) {
      debugPrint('[CapBreakerHybrid] Server fetch failed: $e');
    }
    
    _serverAvailable = false;
    return false;
  }
  
  /// Get gain for a specific attribute and application
  /// Uses server data if available, otherwise falls back to local
  int? getGain({
    required int attribute,
    required int rating,
    required int application,
    required int scenario,
  }) {
    // Try server data first
    if (_serverAvailable && _serverGains != null) {
      // Server returns gains based on current build, not rating
      // We need to find the right tier based on application index
      final gain = CapBreakerAPI.getGain(_serverGains!, attribute, application);
      if (gain != null) {
        return gain;
      }
    }
    
    // Fall back to local engine
    return _localEngine.getGain(scenario, attribute, rating, application);
  }
  
  /// Apply all cap breakers for an attribute
  CapBreakerResult applyAll({
    required int attribute,
    required int startRating,
    required int scenario,
    int count = 5,
  }) {
    // Try server data first
    if (_serverAvailable && _serverGains != null) {
      return _applyAllFromServer(attribute, startRating, count);
    }
    
    // Fall back to local engine
    return _localEngine.applyAll(scenario, attribute, startRating, count: count);
  }
  
  CapBreakerResult _applyAllFromServer(int attribute, int startRating, int count) {
    int current = startRating;
    final steps = <CapBreakerStep>[];
    int applied = 0;
    
    for (int app = 0; app < count; app++) {
      final gain = CapBreakerAPI.getGain(_serverGains!, attribute, app);
      if (gain != null && gain > 0) {
        final newRating = (current + gain).clamp(0, 99);
        steps.add(CapBreakerStep(
          application: app,
          from: current,
          gain: gain,
          to: newRating,
        ));
        current = newRating;
        applied++;
      } else {
        steps.add(CapBreakerStep(
          application: app,
          from: current,
          error: 'No gain available',
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
    );
  }
  
  bool get isUsingServerData => _serverAvailable;
}

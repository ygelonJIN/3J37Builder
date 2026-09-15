import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cap Breaker API Service
/// Fetches cap breaker values from the server based on actual build configuration
class CapBreakerAPI {
  static const String _baseUrl = 'https://2kcourtvision.com';
  static const String _endpoint = '/api/telemetry/sample';
  
  /// Fetch cap breaker gains for a specific build
  /// 
  /// Parameters:
  /// - height: height in inches
  /// - weight: weight in lbs
  /// - wingspan: wingspan in inches
  /// - position: position index (0=PG, 1=SG, 2=SF, 3=PF, 4=C)
  /// - attributes: list of 21 attribute values
  /// 
  /// Returns: list of 105 values (5 tiers × 21 attributes)
  /// Each group of 21 values represents one tier
  static Future<List<int>?> fetchCapBreakerGains({
    required int height,
    required int weight,
    required int wingspan,
    required int position,
    required List<int> attributes,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl$_endpoint');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'h': height,
          'w': weight,
          's': wingspan,
          'p': position,
          'a': attributes,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = response.bodyBytes;
        if (data.length >= 105) {
          return data.sublist(0, 105).map((e) => e.toInt()).toList();
        }
      }
      
      debugPrint('[CapBreakerAPI] Failed to fetch: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[CapBreakerAPI] Error: $e');
      return null;
    }
  }
  
  /// Parse the 105 values into 5 tiers of 21 attributes each
  static List<List<int>> parseGains(List<int> rawGains) {
    final tiers = <List<int>>[];
    for (int tier = 0; tier < 5; tier++) {
      final tierGains = <int>[];
      for (int attr = 0; attr < 21; attr++) {
        tierGains.add(rawGains[tier * 21 + attr]);
      }
      tiers.add(tierGains);
    }
    return tiers;
  }
  
  /// Get cap breaker gains for a specific attribute and tier
  static int? getGain(List<int> rawGains, int attribute, int tier) {
    if (tier < 0 || tier >= 5) return null;
    if (attribute < 0 || attribute >= 21) return null;
    if (rawGains.length < 105) return null;
    
    return rawGains[tier * 21 + attribute];
  }
}

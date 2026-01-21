import 'package:shared_preferences/shared_preferences.dart';

/// Settings for graph physics simulation
class GraphSettings {
  final double repelForce;      // 1000-10000, how strongly nodes push apart
  final double linkForce;       // 0.001-0.1, how strongly linked nodes attract
  final double centerForce;     // 0-0.05, pull toward center
  final double baseDistance;    // 50-200, base link distance
  final double similarityInfluence; // 0.5-2.0, how much similarity affects distance
  
  const GraphSettings({
    this.repelForce = 5000.0,
    this.linkForce = 0.01,
    this.centerForce = 0.01,
    this.baseDistance = 100.0,
    this.similarityInfluence = 1.0,
  });
  
  static const GraphSettings defaults = GraphSettings();
  
  GraphSettings copyWith({
    double? repelForce,
    double? linkForce,
    double? centerForce,
    double? baseDistance,
    double? similarityInfluence,
  }) {
    return GraphSettings(
      repelForce: repelForce ?? this.repelForce,
      linkForce: linkForce ?? this.linkForce,
      centerForce: centerForce ?? this.centerForce,
      baseDistance: baseDistance ?? this.baseDistance,
      similarityInfluence: similarityInfluence ?? this.similarityInfluence,
    );
  }
  
  /// Save to SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('graph_repelForce', repelForce);
    await prefs.setDouble('graph_linkForce', linkForce);
    await prefs.setDouble('graph_centerForce', centerForce);
    await prefs.setDouble('graph_baseDistance', baseDistance);
    await prefs.setDouble('graph_similarityInfluence', similarityInfluence);
  }
  
  /// Load from SharedPreferences
  static Future<GraphSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return GraphSettings(
      repelForce: prefs.getDouble('graph_repelForce') ?? 5000.0,
      linkForce: prefs.getDouble('graph_linkForce') ?? 0.01,
      centerForce: prefs.getDouble('graph_centerForce') ?? 0.01,
      baseDistance: prefs.getDouble('graph_baseDistance') ?? 100.0,
      similarityInfluence: prefs.getDouble('graph_similarityInfluence') ?? 1.0,
    );
  }
}

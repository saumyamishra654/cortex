import 'package:flutter/material.dart';
import '../models/graph_settings.dart';

/// Collapsible settings panel for graph physics controls
class GraphSettingsPanel extends StatefulWidget {
  final GraphSettings settings;
  final ValueChanged<GraphSettings> onSettingsChanged;
  
  const GraphSettingsPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });
  
  @override
  State<GraphSettingsPanel> createState() => _GraphSettingsPanelState();
}

class _GraphSettingsPanelState extends State<GraphSettingsPanel> {
  bool _isExpanded = false;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Positioned(
      right: 16,
      bottom: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: _isExpanded ? 280 : 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: _isExpanded ? _buildExpandedPanel(theme) : _buildCollapsedButton(theme),
      ),
    );
  }
  
  Widget _buildCollapsedButton(ThemeData theme) {
    return SizedBox(
      height: 48,
      child: IconButton(
        icon: const Icon(Icons.tune_rounded),
        tooltip: 'Graph Settings',
        onPressed: () => setState(() => _isExpanded = true),
      ),
    );
  }
  
  Widget _buildExpandedPanel(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Graph Settings', style: theme.textTheme.titleSmall),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _isExpanded = false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Sliders
          _buildSlider(
            label: 'Repel Force',
            value: widget.settings.repelForce,
            min: 1000,
            max: 10000,
            onChanged: (v) => _updateSettings(widget.settings.copyWith(repelForce: v)),
          ),
          _buildSlider(
            label: 'Link Force',
            value: widget.settings.linkForce * 1000, // Scale for slider
            min: 1,
            max: 100,
            onChanged: (v) => _updateSettings(widget.settings.copyWith(linkForce: v / 1000)),
          ),
          _buildSlider(
            label: 'Center Force',
            value: widget.settings.centerForce * 1000,
            min: 0,
            max: 50,
            onChanged: (v) => _updateSettings(widget.settings.copyWith(centerForce: v / 1000)),
          ),
          _buildSlider(
            label: 'Base Distance',
            value: widget.settings.baseDistance,
            min: 50,
            max: 200,
            onChanged: (v) => _updateSettings(widget.settings.copyWith(baseDistance: v)),
          ),
          _buildSlider(
            label: 'Similarity Influence',
            value: widget.settings.similarityInfluence,
            min: 0.5,
            max: 2.0,
            onChanged: (v) => _updateSettings(widget.settings.copyWith(similarityInfluence: v)),
          ),
          
          const SizedBox(height: 8),
          
          // Reset button
          Center(
            child: TextButton.icon(
              onPressed: _resetToDefaults,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        SizedBox(
          height: 32,
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
  
  void _updateSettings(GraphSettings newSettings) {
    widget.onSettingsChanged(newSettings);
  }
  
  void _resetToDefaults() {
    widget.onSettingsChanged(GraphSettings.defaults);
  }
}

import 'package:flutter/material.dart';
import '../models/fact.dart';
import '../theme/app_theme.dart';

class Flashcard extends StatelessWidget {
  final Fact fact;
  final String? sourceName;
  final VoidCallback onForgot;
  final VoidCallback onSkip;
  final VoidCallback onGotIt;
  final int currentIndex;
  final int totalCount;

  const Flashcard({
    super.key,
    required this.fact,
    this.sourceName,
    required this.onForgot,
    required this.onSkip,
    required this.onGotIt,
    required this.currentIndex,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Card ${currentIndex + 1} of $totalCount',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: totalCount > 0 ? (currentIndex + 1) / totalCount : 0,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          
          // Flashcard
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark 
                      ? AppTheme.darkPrimary.withValues(alpha: 0.3)
                      : AppTheme.lightCardBorder,
                  width: isDark ? 2 : 1,
                ),
                boxShadow: isDark ? [
                  BoxShadow(
                    color: AppTheme.darkPrimary.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ] : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          fact.displayText,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  if (fact.subjects.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: fact.subjects.map((subject) {
                        return Chip(
                          label: Text(subject),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ],
                  if (sourceName != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.source_rounded,
                          size: 16,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'From: $sourceName',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: Icons.close_rounded,
                label: 'Forgot',
                color: isDark ? AppTheme.darkError : AppTheme.lightError,
                onPressed: onForgot,
              ),
              _ActionButton(
                icon: Icons.arrow_forward_rounded,
                label: 'Skip',
                color: theme.colorScheme.secondary,
                onPressed: onSkip,
              ),
              _ActionButton(
                icon: Icons.check_rounded,
                label: 'Got it',
                color: isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess,
                onPressed: onGotIt,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
          ),
          child: Icon(icon, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

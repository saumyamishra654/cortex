import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/source.dart';
import '../theme/app_theme.dart';

class SourceCard extends StatelessWidget {
  final Source source;
  final int factCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SourceCard({
    super.key,
    required this.source,
    required this.factCount,
    this.onTap,
    this.onLongPress,
  });

  IconData _getIcon() {
    switch (source.type) {
      case SourceType.book:
        return Icons.menu_book_rounded;
      case SourceType.article:
        return Icons.article_rounded;
      case SourceType.podcast:
        return Icons.podcasts_rounded;
      case SourceType.video:
        return Icons.video_library_rounded;
      case SourceType.conversation:
        return Icons.chat_rounded;
      case SourceType.course:
        return Icons.school_rounded;
      case SourceType.other:
        return Icons.folder_rounded;
      case SourceType.research_paper:
        return Icons.science_rounded;
      case SourceType.audiobook:
        return Icons.headphones_rounded;
      case SourceType.reels:
        return Icons.smartphone_rounded;
      case SourceType.social_post:
        return Icons.public_rounded;
      case SourceType.document:
        return Icons.description_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: isDark ? BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkPrimary.withValues(alpha: 0.1),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ) : null,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIcon(),
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            source.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (source.url != null && source.url!.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () async {
                              final uri = Uri.parse(source.url!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              } else {
                                // Try adding https if missing
                                final fixedUri = Uri.parse('https://${source.url}');
                                if (await canLaunchUrl(fixedUri)) {
                                  await launchUrl(fixedUri);
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.open_in_new, 
                                size: 16, 
                                color: theme.colorScheme.primary.withValues(alpha: 0.7)
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${source.typeLabel} • $factCount facts',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

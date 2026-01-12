import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Widget that renders fact content with clickable [[wiki links]]
class LinkedText extends StatelessWidget {
  final String content;
  final TextStyle? style;
  final Function(String linkText)? onLinkTap;
  final int? maxLines;
  final TextOverflow? overflow;

  const LinkedText({
    super.key,
    required this.content,
    this.style,
    this.onLinkTap,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final spans = _parseContentSpans(content);

    if (spans.isEmpty) {
      return Text(
        content,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final textSpans = spans.map((span) {
      if (span.isLink && onLinkTap != null) {
        return TextSpan(
          text: span.text,
          style: (style ?? theme.textTheme.bodyLarge)?.copyWith(
            color: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor:
                (isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary)
                    .withValues(alpha: 0.5),
            decorationThickness: 2,
            backgroundColor:
                (isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary)
                    .withValues(alpha: 0.15),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              onLinkTap!(span.text);
            },
        );
      } else {
        return TextSpan(
          text: span.text,
          style: style ?? theme.textTheme.bodyLarge,
        );
      }
    }).toList();

    return RichText(
      text: TextSpan(children: textSpans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  /// Parse content into spans (local implementation to avoid circular deps)
  List<ContentSpan> _parseContentSpans(String content) {
    final linkPattern = RegExp(r'\[\[([^\]]+)\]\]');
    final spans = <ContentSpan>[];
    int lastEnd = 0;

    for (final match in linkPattern.allMatches(content)) {
      // Add text before this match
      if (match.start > lastEnd) {
        spans.add(
          ContentSpan(
            text: content.substring(lastEnd, match.start),
            isLink: false,
          ),
        );
      }

      // Add the link (without the brackets)
      spans.add(
        ContentSpan(
          text: match.group(1)!,
          isLink: true,
          fullMatch: match.group(0)!,
        ),
      );

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < content.length) {
      spans.add(ContentSpan(text: content.substring(lastEnd), isLink: false));
    }

    return spans;
  }
}

/// Represents a span of content (either plain text or a link)
class ContentSpan {
  final String text;
  final bool isLink;
  final String? fullMatch;

  ContentSpan({required this.text, required this.isLink, this.fullMatch});
}

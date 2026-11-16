import 'package:flutter/material.dart';

import '../theme/app_text.dart';

/// Heading above a group of content, with an optional widget on the right
/// (a "See all" link, a year, a count).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.title,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

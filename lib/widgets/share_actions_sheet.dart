import 'package:flutter/material.dart';

import '../services/share_helper.dart';
import '../theme/marefat_theme.dart';

/// Bottom sheet with Copy + Share for any text payload.
Future<void> showShareActionsSheet({
  required BuildContext context,
  required String text,
  String title = 'کپی و اشتراک',
  String? subject,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: MarefatColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MarefatColors.mist.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SingleChildScrollView(
                child: Text(
                  text.trim(),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ShareHelper.copyText(text);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('متن کپی شد.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('کپی'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await ShareHelper.shareText(text, subject: subject);
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('اشتراک'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

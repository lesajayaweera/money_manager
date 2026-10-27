import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';
import '../models/sms_draft_model.dart';

/// Displays the bank SMS behind a captured draft so the user can read the
/// original message before confirming what kind of transaction it is.
class SmsMessageCard extends StatelessWidget {
  final SmsDraftModel draft;

  const SmsMessageCard({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final hintColor = Theme.of(context).textTheme.bodySmall?.color;

    final original = draft.originalBody.trim();
    final redacted = draft.rawBody.trim();
    final body = original.isNotEmpty ? original : redacted;
    final isLegacyDraft = original.isEmpty && redacted.isNotEmpty;

    final (accent, label) = switch (draft.kind) {
      DraftKind.income => (AppColors.income, 'Detected Income'),
      DraftKind.withdrawal => (AppColors.primary, 'Detected Withdrawal'),
      DraftKind.expense => (AppColors.expense, 'Detected Expense'),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sms_rounded, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Captured bank SMS',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'From ${draft.sender} · ${draft.bank}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: hintColor,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: SelectableText(
              body.isEmpty ? 'Message content unavailable.' : body,
              style: GoogleFonts.sourceCodePro(
                fontSize: 12,
                height: 1.5,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isLegacyDraft
                    ? Icons.info_outline_rounded
                    : Icons.lock_outline_rounded,
                size: 12,
                color: hintColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isLegacyDraft
                      ? 'Original message is not available for this older draft — showing the privacy-redacted version.'
                      : 'Read the message, then confirm the transaction type below. Stored only on this device.',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: hintColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

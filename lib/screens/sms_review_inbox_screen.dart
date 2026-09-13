import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/sms_draft_model.dart';
import '../models/transaction_model.dart';
import '../providers/settings_provider.dart';
import '../providers/sms_draft_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';

/// Review inbox: every captured bank SMS appears here as an editable draft.
/// Nothing becomes a real transaction until the user taps Save.
class SmsReviewInboxScreen extends StatelessWidget {
  const SmsReviewInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SmsDraftProvider>();
    final pending = provider.pendingDrafts;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Review Inbox',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (pending.isNotEmpty)
            IconButton(
              tooltip: 'Clear drafts',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmClear(context, provider),
            ),
        ],
      ),
      body: pending.isEmpty
          ? _EmptyState(enabled: provider.enabled)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${pending.length} draft(s) — review before anything is saved.',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.bodySmall?.color),
                        ),
                      ),
                      _SaveAllButton(onSaved: () {
                        var count = 0;
                        for (final d in pending) {
                          context
                              .read<TransactionProvider>()
                              .addTransaction(provider.toTransaction(d));
                          provider.markSaved(d.id!);
                          count++;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('$count transaction(s) saved',
                              style: GoogleFonts.poppins(fontSize: 13)),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: pending.length,
                    itemBuilder: (context, index) {
                      final draft = pending[index];
                      return _DraftTile(
                        draft: draft,
                        onTap: () => _showEditSheet(context, draft),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmClear(BuildContext context, SmsDraftProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Clear all drafts?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'This removes all pending drafts. Nothing is saved as a transaction.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.clearAllDrafts();
    }
  }

  void _showEditSheet(BuildContext context, SmsDraftModel draft) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _DraftEditSheet(draft: draft),
      ),
    );
  }
}

// ─── Draft tile ────────────────────────────────────────────────────────────────

class _DraftTile extends StatelessWidget {
  final SmsDraftModel draft;
  final VoidCallback onTap;

  const _DraftTile({required this.draft, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIncome = draft.txType == TransactionType.income;
    final accent = isIncome ? AppColors.income : AppColors.expense;
    final symbol = context.watch<SettingsProvider>().currencySymbol;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurface
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkDivider
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(draft.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text('${draft.bank} · ${draft.category}',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.bodySmall?.color)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}$symbol ${CurrencyFormatter.format(draft.amount)}',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700, color: accent),
                ),
                const SizedBox(height: 3),
                Text(
                  draft.transactionDate == null
                      ? 'Now'
                      : CurrencyFormatter.shortDate(draft.transactionDate!),
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

// ─── Edit / save / dismiss sheet ──────────────────────────────────────────────

class _DraftEditSheet extends StatefulWidget {
  final SmsDraftModel draft;
  const _DraftEditSheet({required this.draft});

  @override
  State<_DraftEditSheet> createState() => _DraftEditSheetState();
}

class _DraftEditSheetState extends State<_DraftEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late TransactionType _type;
  late String _category;
  late String _wallet;
  late DateTime? _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draft.title);
    _amountController =
        TextEditingController(text: widget.draft.amount.toStringAsFixed(2));
    _type = widget.draft.txType;
    _category = widget.draft.category;
    _wallet = widget.draft.walletName;
    _date = widget.draft.transactionDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  List<String> _categoryOptions() {
    final categories = _type == TransactionType.income
        ? CategoryModel.incomeCategories
        : CategoryModel.expenseCategories;
    final names = categories.map((c) => c.name).toList();
    if (!names.contains(_category)) names.add(_category);
    return names;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enter a valid amount.', style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.expense,
      ));
      return;
    }
    setState(() => _saving = true);

    final provider = context.read<SmsDraftProvider>();
    final updated = widget.draft.copyWith(
      title: _titleController.text.trim().isEmpty
          ? widget.draft.bank
          : _titleController.text.trim(),
      amount: amount,
      txType: _type,
      category: _category,
      walletName: _wallet,
      transactionDate: _date,
    );

    await context
        .read<TransactionProvider>()
        .addTransaction(provider.toTransaction(updated));
    await provider.markSaved(widget.draft.id!);

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _dismiss() async {
    await context.read<SmsDraftProvider>().dismissDraft(widget.draft.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;
    final symbol = context.watch<SettingsProvider>().currencySymbol;
    final wallets = context.watch<WalletProvider>().wallets;
    final walletNames =
        wallets.map((w) => w.name).toList()..add(_wallet);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Edit Draft',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).textTheme.titleLarge?.color)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Type toggle
                _TypeToggle(
                  type: _type,
                  onChange: (t) => setState(() {
                    _type = t;
                    if (!_categoryOptions().contains(_category)) {
                      _category = _type == TransactionType.income
                          ? 'Other'
                          : 'Other';
                    }
                  }),
                ),
                const SizedBox(height: 16),

                _Label('Title'),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration('Merchant / description', borderColor, isDark),
                ),
                const SizedBox(height: 14),

                _Label('Amount'),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration('$symbol 0.00', borderColor, isDark)
                      .copyWith(prefixText: '$symbol  '),
                ),
                const SizedBox(height: 14),

                _Label('Category'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categoryOptions()
                      .map((c) => _Chip(
                            label: c,
                            selected: c == _category,
                            onTap: () => setState(() => _category = c),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 14),

                _Label('Wallet'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: walletNames.contains(_wallet) ? _wallet : null,
                  isExpanded: true,
                  decoration: _inputDecoration('Wallet', borderColor, isDark),
                  style: GoogleFonts.poppins(fontSize: 14),
                  items: walletNames
                      .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _wallet = v);
                  },
                ),
                const SizedBox(height: 14),

                _Label('Date'),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Text(
                          _date == null
                              ? 'Now'
                              : CurrencyFormatter.shortDate(_date!),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _saving ? null : _dismiss,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.expense,
                            side: const BorderSide(color: AppColors.expense),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Dismiss',
                              style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Text('Save',
                                  style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Small widgets ─────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  final TransactionType type;
  final ValueChanged<TransactionType> onChange;
  const _TypeToggle({required this.type, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeButton(
              label: 'Expense',
              icon: Icons.arrow_upward_rounded,
              color: AppColors.expense,
              selected: type == TransactionType.expense,
              onTap: () => onChange(TransactionType.expense),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TypeButton(
              label: 'Income',
              icon: Icons.arrow_downward_rounded,
              color: AppColors.income,
              selected: type == TransactionType.income,
              onTap: () => onChange(TransactionType.income),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _TypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color.withOpacity(0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? color : Theme.of(context).textTheme.bodySmall?.color)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.12)
              : Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurface
                  : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary.withOpacity(0.4)
                : (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkDivider
                    : Colors.grey.shade300),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : Theme.of(context).textTheme.bodySmall?.color)),
      ),
    );
  }
}

class _SaveAllButton extends StatelessWidget {
  final VoidCallback onSaved;
  const _SaveAllButton({required this.onSaved});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSaved,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('Save all',
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool enabled;
  const _EmptyState({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded,
                size: 56,
                color: enabled ? AppColors.primary.withOpacity(0.4) : AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              enabled ? 'No drafts yet' : 'Auto Capture is off',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.titleLarge?.color),
            ),
            const SizedBox(height: 6),
            Text(
              enabled
                  ? 'Bank SMS will appear here for review.'
                  : 'Turn on Auto Capture to start tracking bank SMS.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint, Color borderColor, bool isDark) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.poppins(
        fontSize: 14, color: isDark ? AppColors.darkTextHint : AppColors.textHint),
    filled: true,
    fillColor: isDark ? AppColors.darkSurface : Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.titleLarge?.color));
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/sms_draft_model.dart';
import '../providers/sms_draft_provider.dart';
import '../services/sms_capture_service.dart';
import '../services/sms_parser.dart';

/// A message a bank SMS becomes once examined on-device (never persisted).
class _MessageItem {
  final String sender;
  final DateTime receivedAt;
  final String rawBody;
  final String redactedBody;
  final String? bank;
  final SmsParseResult? result;

  _MessageItem({
    required this.sender,
    required this.receivedAt,
    required this.rawBody,
    required this.redactedBody,
    required this.bank,
    required this.result,
  });

  bool get isBank => bank != null;
}

/// Recent SMS from detected banks — plus the senders being filtered out —
/// with a redacted preview and a per-message status badge.
class SmsMessagesScreen extends StatefulWidget {
  const SmsMessagesScreen({super.key});

  @override
  State<SmsMessagesScreen> createState() => _SmsMessagesScreenState();
}

class _SmsMessagesScreenState extends State<SmsMessagesScreen> {
  String _permission = 'unknown';
  bool _loading = true;
  List<_MessageItem> _items = const [];

  /// null = all, 'other' = non-bank senders, otherwise a canonical bank name.
  String? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await SmsCaptureService.permissionStatus();
    if (status != 'granted') {
      if (mounted) {
        setState(() {
          _permission = status;
          _loading = false;
        });
      }
      return;
    }

    final raw = await SmsCaptureService.getRecentMessages();
    final items = raw.map(_toItem).toList();
    if (mounted) {
      setState(() {
        _permission = status;
        _loading = false;
        _items = items;
      });
    }
  }

  _MessageItem _toItem(Map<String, dynamic> raw) {
    final sender = raw['sender'] as String? ?? '';
    final body = raw['body'] as String? ?? '';
    final date = DateTime.fromMillisecondsSinceEpoch(raw['date'] as int? ?? 0);
    final bank = SmsParser.bankNameForSender(sender);
    final result = bank == null
        ? null
        : SmsParser.parse(sender: sender, body: body, receivedAt: date);
    return _MessageItem(
      sender: sender,
      receivedAt: date,
      rawBody: body,
      redactedBody: SmsParser.redactSmsBody(body),
      bank: bank,
      result: result,
    );
  }

  Future<void> _grantPermission() async {
    final granted = await SmsCaptureService.requestSmsPermission();
    if (!mounted) return;
    if (granted) {
      setState(() => _loading = true);
      await _load();
    } else {
      setState(() => _permission = 'denied');
    }
  }

  List<String> _bankChips(SmsDraftProvider provider) {
    final banks = <String>{...provider.detectedBanks};
    for (final s in provider.senders) {
      final bank = SmsParser.bankNameForSender(s);
      if (bank != null) banks.add(bank);
    }
    final list = banks.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SmsDraftProvider>();
    final banks = _bankChips(provider);
    final draftKeys = provider.drafts.map((d) => d.dedupKey).toSet();

    final visible = _filter == null
        ? _items
        : _filter == 'other'
            ? _items.where((m) => !m.isBank).toList()
            : _items.where((m) => m.bank == _filter).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Bank SMS',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _permission != 'granted'
              ? _PermissionBanner(onGrant: _grantPermission)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (banks.isNotEmpty || _items.any((m) => !m.isBank)) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            _FilterChip(
                                label: 'All',
                                selected: _filter == null,
                                onTap: () => setState(() => _filter = null)),
                            for (final b in banks) ...[
                              const SizedBox(width: 8),
                              _FilterChip(
                                  label: b,
                                  selected: _filter == b,
                                  onTap: () => setState(() => _filter = b)),
                            ],
                            if (_items.any((m) => !m.isBank)) ...[
                              const SizedBox(width: 8),
                              _FilterChip(
                                  label: 'Other',
                                  selected: _filter == 'other',
                                  muted: true,
                                  onTap: () =>
                                      setState(() => _filter = 'other')),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Expanded(
                      child: visible.isEmpty
                          ? _EmptyState()
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 4, 20, 24),
                                itemCount: visible.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = visible[index];
                                  return _MessageTile(
                                    item: item,
                                    alreadyDraft: item.result?.matched ==
                                            true &&
                                        item.result!.dedupKey.isNotEmpty &&
                                        draftKeys
                                            .contains(item.result!.dedupKey),
                                    onTap: () =>
                                        _showDetails(context, item, provider),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  void _showDetails(
      BuildContext context, _MessageItem item, SmsDraftProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;
    final status = _Status.describe(item, provider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: status.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                          item.isBank
                              ? Icons.account_balance_rounded
                              : Icons.sms_rounded,
                          color: status.color,
                          size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.bank ?? item.sender,
                              style: GoogleFonts.poppins(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            '${CurrencyFormatter.relativeDate(item.receivedAt)} · '
                            '${CurrencyFormatter.time(item.receivedAt)}'
                            '${item.isBank ? '' : ' · ${item.sender}'}',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _StatusChip(
                    label: status.label,
                    color: status.color,
                    dimmed: !item.isBank),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(item.redactedBody,
                      style: GoogleFonts.poppins(fontSize: 13, height: 1.5)),
                ),
                if (!item.isBank) ...[
                  const SizedBox(height: 14),
                  Text(
                    'This sender is not one of the banks we track, so its '
                    'messages are filtered out and never captured.',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Status model ─────────────────────────────────────────────────────────────

class _Status {
  final String label;
  final Color color;
  final bool dimmed;

  const _Status(this.label, this.color, {this.dimmed = false});

  static _Status describe(_MessageItem item, SmsDraftProvider provider) {
    final r = item.result;
    if (!item.isBank) {
      return const _Status('Filtered out', AppColors.textHint, dimmed: true);
    }
    if (r == null) {
      return const _Status('Skipped · Not recognised', AppColors.textSecondary);
    }
    if (r.matched) {
      final alreadyDraft = r.dedupKey.isNotEmpty &&
          provider.drafts.any((d) => d.dedupKey == r.dedupKey);
      if (alreadyDraft) {
        return const _Status('Already a draft', AppColors.textSecondary);
      }
      final color = switch (r.kind) {
        DraftKind.income => AppColors.income,
        DraftKind.withdrawal => AppColors.budget,
        DraftKind.expense => AppColors.expense,
      };
      return _Status(
          'Draft · ${r.kind.name[0].toUpperCase()}${r.kind.name.substring(1)}',
          color);
    }
    return _Status(
        switch (r.skipReason) {
          SmsSkipReason.otpOrPromo => 'Skipped · OTP / promo',
          SmsSkipReason.notTransaction => 'Skipped · Not a transaction',
          SmsSkipReason.notRecognised => 'Skipped · Not recognised',
          _ => 'Skipped',
        },
        AppColors.textSecondary,
        dimmed: true);
  }
}

// ─── Widgets ───────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool muted;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.muted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (muted ? AppColors.textHint : AppColors.primary)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? (muted ? AppColors.textHint : AppColors.primary)
                : (isDark ? AppColors.darkDivider : Colors.grey.shade300),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodySmall?.color)),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool dimmed;

  const _StatusChip(
      {required this.label, required this.color, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dimmed
            ? color.withValues(alpha: 0.18)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: dimmed ? AppColors.textSecondary : color)),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final _MessageItem item;
  final bool alreadyDraft;
  final VoidCallback onTap;

  const _MessageTile({
    required this.item,
    required this.alreadyDraft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;
    final opacity = item.isBank ? 1.0 : 0.55;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (item.isBank ? AppColors.primary : AppColors.textHint)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.isBank
                      ? Icons.account_balance_rounded
                      : Icons.sms_rounded,
                  color: item.isBank ? AppColors.primary : AppColors.textHint,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.bank ?? item.sender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.time(item.receivedAt),
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      CurrencyFormatter.relativeDate(item.receivedAt),
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.redactedBody,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          height: 1.35,
                          color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _StatusChip(
                        label: _tileStatusLabel(),
                        color: _tileStatusColor(),
                        dimmed: !item.isBank,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _tileStatusLabel() {
    if (alreadyDraft) return 'Already a draft';
    if (!item.isBank) return 'Filtered out';
    final r = item.result;
    if (r == null || !r.matched) {
      return switch (r?.skipReason) {
        SmsSkipReason.otpOrPromo => 'Skipped · OTP / promo',
        SmsSkipReason.notTransaction => 'Skipped · Not a transaction',
        SmsSkipReason.notRecognised => 'Skipped · Not recognised',
        _ => 'Skipped',
      };
    }
    return switch (r.kind) {
      DraftKind.income => 'Draft · Income',
      DraftKind.withdrawal => 'Draft · Withdrawal',
      DraftKind.expense => 'Draft · Expense',
    };
  }

  Color _tileStatusColor() {
    if (alreadyDraft || !item.isBank) return AppColors.textHint;
    final r = item.result;
    if (r == null || !r.matched) return AppColors.textSecondary;
    return switch (r.kind) {
      DraftKind.income => AppColors.income,
      DraftKind.withdrawal => AppColors.budget,
      DraftKind.expense => AppColors.expense,
    };
  }
}

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onGrant;

  const _PermissionBanner({required this.onGrant});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.sms_rounded, color: AppColors.expense, size: 30),
            const SizedBox(height: 12),
            Text('SMS permission needed',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'We need SMS read permission to show the messages sent by '
              'your banks.',
              style: GoogleFonts.poppins(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: onGrant,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Grant',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sms_rounded,
                size: 48, color: Theme.of(context).textTheme.bodySmall?.color),
            const SizedBox(height: 12),
            Text('No messages found',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Nothing from the tracked banks (or any other sender) in the '
              'last 7 days.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

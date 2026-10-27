import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../providers/sms_draft_provider.dart';
import '../services/sms_capture_service.dart';
import '../services/sms_parser.dart';
import 'sms_messages_screen.dart';
import 'sms_review_inbox_screen.dart';

/// Auto Capture setup: permission, kill-switch, sender whitelist, and a
/// self-test that parses a sample SMS on-device.
class SmsCaptureScreen extends StatefulWidget {
  const SmsCaptureScreen({super.key});

  @override
  State<SmsCaptureScreen> createState() => _SmsCaptureScreenState();
}

class _SmsCaptureScreenState extends State<SmsCaptureScreen> {
  String _permission = 'unknown';

  @override
  void initState() {
    super.initState();
    _refreshPermission();
    // Pull any SMS captured while the app was away so drafts are shown right
    // away instead of on the next cold start.
    final provider = context.read<SmsDraftProvider>();
    if (provider.enabled) provider.refresh();
  }

  Future<void> _refreshPermission() async {
    final status = await SmsCaptureService.permissionStatus();
    if (mounted) setState(() => _permission = status);
  }

  bool get _hasPermission => _permission == 'granted';

  Future<void> _grantPermission() async {
    final granted = await SmsCaptureService.requestSmsPermission();
    if (mounted) {
      _permission = granted ? 'granted' : 'denied';
      setState(() {});
      if (granted) {
        final provider = context.read<SmsDraftProvider>();
        await provider.setEnabled(true);
        _showSnack('SMS capture is on. Bank SMS will be tracked silently.');
      } else {
        _showSnack('SMS permission is required for Auto Capture.');
      }
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value && !_hasPermission) {
      await _grantPermission();
      return;
    }
    await context.read<SmsDraftProvider>().setEnabled(value);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _startHistoryScan() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistoryScanProgressSheet(
        provider: context.read<SmsDraftProvider>(),
        onDone: () {
          Navigator.pop(context); // close sheet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SmsReviewInboxScreen(),
            ),
          );
        },
      ),
    );
    // Start the scan (non-blocking — sheet listens to the stream)
    context.read<SmsDraftProvider>().importFullHistory();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SmsDraftProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Auto Capture',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (provider.pendingCount > 0)
                    _TapCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SmsReviewInboxScreen()),
                      ),
                      color: AppColors.primary,
                      title: '${provider.pendingCount} draft(s) waiting',
                      subtitle: 'Review and save captured transactions',
                      icon: Icons.inbox_rounded,
                    ),
                  if (provider.hasDetectedBanks) ...[
                    const SizedBox(height: 12),
                    _DetectedBanksCard(
                      banks: provider.detectedBanks,
                      isScanning: provider.isImportingHistory,
                      onRescan: () => context
                          .read<SmsDraftProvider>()
                          .detectBanks(force: true),
                      onHistoryScan: () => _startHistoryScan(),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SmsMessagesScreen()),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Permission ──────────────────────────────────────────────
                  _SectionTitle('SMS Permission'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        _SectionRow(
                          icon: Icons.sms_rounded,
                          iconColor: _hasPermission
                              ? AppColors.income
                              : AppColors.expense,
                          title: 'Read bank SMS',
                          subtitle: _hasPermission
                              ? 'Granted — capture is active'
                              : 'Needed to scan and capture bank messages',
                          trailing: _hasPermission
                              ? Icon(Icons.check_circle_rounded,
                                  color: AppColors.income, size: 22)
                              : _TinyButton(
                                  label: 'Grant',
                                  onTap: _grantPermission,
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Enable toggle ──────────────────────────────────────────
                  _SectionTitle('Capture'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: SwitchListTile(
                      value: provider.enabled,
                      onChanged: _toggleEnabled,
                      activeColor: AppColors.primary,
                      title: Text('Auto Capture',
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        'Drafts appear when your bank texts. You review before anything is saved.',
                        style: GoogleFonts.poppins(fontSize: 12, height: 1.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Whitelist ──────────────────────────────────────────────
                  _SectionTitle('Sender Whitelist'),
                  const SizedBox(height: 4),
                  Text(
                    'Only messages from these senders are captured — the rest are never touched.',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _SenderWhitelist(isDark: isDark),
                  const SizedBox(height: 24),

                  // ── Test ───────────────────────────────────────────────────
                  _SectionTitle('Test with a sample SMS'),
                  const SizedBox(height: 12),
                  _ParseTester(isDark: isDark),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sender whitelist ──────────────────────────────────────────────────────────

class _SenderWhitelist extends StatefulWidget {
  final bool isDark;
  const _SenderWhitelist({required this.isDark});

  @override
  State<_SenderWhitelist> createState() => _SenderWhitelistState();
}

class _SenderWhitelistState extends State<_SenderWhitelist> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(context.read<SmsDraftProvider>().senders);
  }

  Future<void> _persist() async {
    await context.read<SmsDraftProvider>().setSenders(_selected);
  }

  void _toggle(String sender, bool value) {
    setState(() {
      if (value) {
        if (!_selected.contains(sender)) _selected.add(sender);
      } else {
        _selected.remove(sender);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        widget.isDark ? AppColors.darkDivider : Colors.grey.shade200;

    final presets = SmsParser.presetSenders;
    final selectedSet = _selected.toSet();

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          for (int i = 0; i < presets.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: borderColor),
            CheckboxListTile(
              value: selectedSet.contains(presets[i]),
              onChanged: (v) {
                _toggle(presets[i], v ?? false);
                _persist();
              },
              activeColor: AppColors.primary,
              dense: true,
              title: Text(presets[i],
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
          Divider(height: 1, thickness: 1, color: borderColor),
          _CustomSenderAdder(
            existing: selectedSet,
            onAdd: (id) {
              _toggle(id, true);
              _persist();
            },
            onRemove: (id) {
              _toggle(id, false);
              _persist();
            },
          ),
        ],
      ),
    );
  }
}

class _CustomSenderAdder extends StatefulWidget {
  final Set<String> existing;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  const _CustomSenderAdder({
    required this.existing,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_CustomSenderAdder> createState() => _CustomSenderAdderState();
}

class _CustomSenderAdderState extends State<_CustomSenderAdder> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Custom senders already added (excluding presets).
    final custom = widget.existing
        .where((s) => !SmsParser.presetSenders.contains(s))
        .toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final id in custom)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.alt_route_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  _TinyButton(
                      label: 'Remove', onTap: () => widget.onRemove(id)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add custom sender ID',
                    hintStyle: GoogleFonts.poppins(fontSize: 13),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TinyButton(
                label: 'Add',
                onTap: () {
                  final id = _controller.text.trim();
                  if (id.isEmpty || widget.existing.contains(id)) return;
                  _controller.clear();
                  widget.onAdd(id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Detected banks card ──────────────────────────────────────────────────────

class _DetectedBanksCard extends StatelessWidget {
  final List<String> banks;
  final bool isScanning;
  final VoidCallback onRescan;
  final VoidCallback onHistoryScan;
  final VoidCallback onTap;
  const _DetectedBanksCard({
    required this.banks,
    required this.isScanning,
    required this.onRescan,
    required this.onHistoryScan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;
    final joined = banks.length > 3
        ? '${banks.take(3).join(', ')} +${banks.length - 3} more'
        : banks.join(', ');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // ── Bank info row ────────────────────────────────────────────────
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.income.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.account_balance_rounded,
                        color: AppColors.income, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${banks.length} bank${banks.length == 1 ? '' : 's'} detected',
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Capturing: $joined',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rescan for banks',
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: AppColors.primary,
                    onPressed: onRescan,
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 22,
                      color: Theme.of(context).textTheme.bodySmall?.color),
                ],
              ),
            ),
          ),
          // ── History scan button ──────────────────────────────────────────
          Divider(height: 1, thickness: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: isScanning
                ? Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Scanning SMS history…',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: onHistoryScan,
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: Text(
                        'Scan Full SMS History',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Parse self-test ───────────────────────────────────────────────────────────

class _ParseTester extends StatefulWidget {
  final bool isDark;
  const _ParseTester({required this.isDark});

  @override
  State<_ParseTester> createState() => _ParseTesterState();
}

class _ParseTesterState extends State<_ParseTester> {
  final _controller = TextEditingController();
  String? _resultText;
  bool _isError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run() {
    final result = SmsParser.parse(
      sender: 'HNB',
      body: _controller.text.trim(),
      receivedAt: DateTime.now(),
    );
    setState(() {
      _isError = !result.matched;
      _resultText = !result.matched
          ? switch (result.skipReason) {
              null => 'Could not recognise a transaction.',
              SmsSkipReason.notBankSender =>
                'Sender is not a whitelisted bank.',
              SmsSkipReason.otpOrPromo =>
                'Blocked: looks like an OTP or promo.',
              SmsSkipReason.notTransaction => 'No transaction keywords found.',
              SmsSkipReason.notRecognised =>
                'No amount found — cannot build a draft.',
            }
          : '${result.type.name.toUpperCase()} · ${result.category} · '
              'Rs ${result.amount.toStringAsFixed(2)} · ${result.title}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            maxLines: 4,
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Paste a real bank SMS to verify on-device parsing…',
              hintStyle: GoogleFonts.poppins(fontSize: 13),
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : Colors.white,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _run,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Parse',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              if (_resultText != null)
                Expanded(
                  child: Text(
                    _resultText!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isError ? AppColors.expense : AppColors.income,
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

// ─── Shared widgets ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).textTheme.titleLarge?.color,
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SectionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.titleLarge?.color)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _TapCard extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final String title;
  final String subtitle;
  final IconData icon;

  const _TapCard({
    required this.onTap,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.85), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _TinyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TinyButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
      ),
    );
  }
}

// ─── History Scan Progress Sheet ──────────────────────────────────────────────
//
// A non-dismissible modal sheet that shows a live counter while the full-history
// import runs. Auto-closes when the scan is done and calls onDone.

class _HistoryScanProgressSheet extends StatefulWidget {
  final SmsDraftProvider provider;
  final VoidCallback onDone;

  const _HistoryScanProgressSheet({
    required this.provider,
    required this.onDone,
  });

  @override
  State<_HistoryScanProgressSheet> createState() =>
      _HistoryScanProgressSheetState();
}

class _HistoryScanProgressSheetState extends State<_HistoryScanProgressSheet> {
  int _scanned = 0;
  int _inserted = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    widget.provider.historyImportProgress.listen((p) {
      if (!mounted) return;
      setState(() {
        _scanned = p.scanned;
        _inserted = p.inserted;
        _done = p.done;
      });
      if (p.done) {
        // Short pause so the user sees the "Done" state before auto-dismiss.
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) widget.onDone();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: borderColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 28),

            // Animated icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _done
                  ? Container(
                      key: const ValueKey('done'),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.income.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_rounded,
                          color: AppColors.income, size: 36),
                    )
                  : Container(
                      key: const ValueKey('scanning'),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: AppColors.primary),
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              _done ? 'Scan Complete!' : 'Scanning SMS History…',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            Text(
              _done
                  ? 'Found $_inserted transaction${_inserted == 1 ? '' : 's'} in $_scanned messages'
                  : 'Read $_scanned messages • $_inserted transaction${_inserted == 1 ? '' : 's'} found',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Progress bar
            if (!_done) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  backgroundColor: borderColor,
                  color: AppColors.primary,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This may take a moment for large inboxes…',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            if (_done) ...[
              const SizedBox(height: 16),
              Text(
                'Opening draft inbox…',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

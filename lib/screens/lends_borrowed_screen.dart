import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/lend_borrow_model.dart';
import '../providers/lend_borrow_provider.dart';
import '../providers/settings_provider.dart';
import 'add_lend_borrow_screen.dart';
import 'lend_borrow_detail_screen.dart';

class LendsBorrowedScreen extends StatefulWidget {
  final int initialIndex;
  const LendsBorrowedScreen({super.key, this.initialIndex = 0});

  @override
  State<LendsBorrowedScreen> createState() => _LendsBorrowedScreenState();
}

class _LendsBorrowedScreenState extends State<LendsBorrowedScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LendBorrowProvider>().loadEntries();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openAddEntry({LendBorrowType initialType = LendBorrowType.lent}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddLendBorrowScreen(initialType: initialType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Consumer<LendBorrowProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.entries.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => provider.loadEntries(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lent / Borrowed toggle tabs
                  _ToggleTabs(controller: _tabController),
                  const SizedBox(height: 16),

                  // Summary cards
                  _SummaryCards(provider: provider),
                  const SizedBox(height: 24),

                  // Tab content
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (_, __) {
                      final isLent = _tabController.index == 0;
                      final lentEntries = provider.lentEntries;
                      final borrowedEntries = provider.borrowedEntries;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isLent) ...[
                            _SectionTitle('Lent to Others'),
                            const SizedBox(height: 12),
                            if (lentEntries.isEmpty)
                              _EmptySection(
                                label: 'No lent entries',
                                sub: 'Tap + Add Entry to record money you lent',
                              )
                            else
                              _EntriesList(entries: lentEntries),
                          ] else ...[
                            _SectionTitle('Borrowed from Others'),
                            const SizedBox(height: 12),
                            if (borrowedEntries.isEmpty)
                              _EmptySection(
                                label: 'No borrowed entries',
                                sub: 'Tap + Add Entry to record money you borrowed',
                              )
                            else
                              _EntriesList(entries: borrowedEntries),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  _AddEntryButton(
                    onTap: () => _openAddEntry(
                      initialType: _tabController.index == 0
                          ? LendBorrowType.lent
                          : LendBorrowType.borrowed,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        'Lends & Borrowed',
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined,
                  color: AppColors.textPrimary, size: 26),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.expense,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () {},
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ─── Toggle Tabs ──────────────────────────────────────────────────────────────

class _ToggleTabs extends StatelessWidget {
  final TabController controller;
  const _ToggleTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFEEECFD),
        borderRadius: BorderRadius.circular(22),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(22),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        dividerColor: Colors.transparent,
        labelStyle:
            GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Lent'),
          Tab(text: 'Borrowed'),
        ],
      ),
    );
  }
}

// ─── Summary Cards ────────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  final LendBorrowProvider provider;
  const _SummaryCards({required this.provider});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Row(
      children: [
        // You Will Receive (lent)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F9F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You Will Receive',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.income,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.format(provider.totalToReceive,
                            symbol: settings.currencySymbol),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.income,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.income,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_upward_rounded,
                      color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // You Need to Pay (borrowed)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF0EC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You Need to Pay',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.expense,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.format(provider.totalToPay,
                            symbol: settings.currencySymbol),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.expense,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_downward_rounded,
                      color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Section Title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ─── Entries List ─────────────────────────────────────────────────────────────

class _EntriesList extends StatelessWidget {
  final List<LendBorrowModel> entries;
  const _EntriesList({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          indent: 70,
          endIndent: 16,
        ),
        itemBuilder: (_, i) => _EntryTile(entry: entries[i]),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final LendBorrowModel entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final initials = entry.personName.isNotEmpty
        ? entry.personName[0].toUpperCase()
        : '?';

    // Avatar color based on initial
    final colors = [
      AppColors.primary,
      AppColors.income,
      AppColors.expense,
      AppColors.budget,
      AppColors.spending,
    ];
    final avatarColor = colors[initials.codeUnitAt(0) % colors.length];

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LendBorrowDetailScreen(entry: entry),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.personName,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(entry.amount,
                        symbol: settings.currencySymbol),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Due: ${CurrencyFormatter.shortDate(entry.dueDate)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Status badge
            _StatusBadge(status: entry.status),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final LendBorrowStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.lightColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: status.color,
        ),
      ),
    );
  }
}

// ─── Empty Section ────────────────────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  final String label;
  final String sub;
  const _EmptySection({required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.swap_horiz_rounded,
                size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(sub,
              style:
                  GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Add Entry Button ─────────────────────────────────────────────────────────

class _AddEntryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddEntryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          'Add Entry',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/salary_plan_model.dart';
import '../providers/salary_plan_provider.dart';
import '../providers/settings_provider.dart';
import 'create_monthly_plan_screen.dart';

class MonthlyPlanScreen extends StatefulWidget {
  const MonthlyPlanScreen({super.key});

  @override
  State<MonthlyPlanScreen> createState() => _MonthlyPlanScreenState();
}

class _MonthlyPlanScreenState extends State<MonthlyPlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalaryPlanProvider>().loadPlans();
    });
  }

  Future<void> _openCreate({SalaryPlan? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateMonthlyPlanScreen(existing: existing),
      ),
    );
  }

  Future<void> _deletePlan(BuildContext ctx, SalaryPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Plan?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will remove "${plan.name}" permanently.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('Delete',
                style: GoogleFonts.poppins(color: AppColors.expense)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<SalaryPlanProvider>().deletePlan(plan.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, isDark),
      floatingActionButton: _buildFab(),
      body: Consumer<SalaryPlanProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.plans.isEmpty) {
            return Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (provider.plans.isEmpty) {
            return _EmptyState(onCreateTap: () => _openCreate());
          }
          return _PlanList(
            plans: provider.plans,
            onEdit: (p) => _openCreate(existing: p),
            onDelete: (p) => _deletePlan(context, p),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Theme.of(context).textTheme.titleLarge?.color),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Monthly Plan',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.titleLarge?.color,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.info_outline_rounded,
              color: Theme.of(context).textTheme.bodySmall?.color),
          onPressed: () => _showInfoSheet(context),
        ),
        IconButton(
          icon: Icon(Icons.bar_chart_rounded,
              color: Theme.of(context).textTheme.bodySmall?.color),
          onPressed: () => _showAllocationBreakdown(context),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: () => _openCreate(),
      backgroundColor: AppColors.income,
      elevation: 4,
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
    );
  }

  void _showInfoSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('How it works',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _infoRow(Icons.attach_money_rounded, AppColors.income,
                'Enter monthly income',
                'Type your salary or pull from recent income transactions.'),
            _infoRow(Icons.pie_chart_rounded, AppColors.primary,
                'Allocate every rupee',
                'Assign amounts to expenses, savings goals, loans, and credit cards until the Unallocated counter reaches zero.'),
            _infoRow(Icons.sync_rounded, AppColors.budget,
                'Auto-syncs to Budget',
                'Expense allocations are written as budget limits — the existing Budget screen reflects them automatically.'),
            _infoRow(Icons.show_chart_rounded, AppColors.spending,
                'Track planned vs actual',
                'As you spend during the month, compare actual vs planned per category.'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
      IconData icon, Color color, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color)),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showAllocationBreakdown(BuildContext context) {
    final provider = context.read<SalaryPlanProvider>();
    if (provider.latestPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No plans yet. Create one first.',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.darkSurface,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    final plan = provider.latestPlan!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AllocationBreakdownSheet(plan: plan),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface
                    : AppColors.primary.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                size: 64,
                color: isDark
                    ? AppColors.darkTextHint
                    : AppColors.primary.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No Monthly Plans Yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first plan to start budgeting',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 180,
              height: 50,
              child: ElevatedButton(
                onPressed: onCreateTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.income,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Create Plan',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Plan List ────────────────────────────────────────────────────────────────

class _PlanList extends StatelessWidget {
  final List<SalaryPlan> plans;
  final void Function(SalaryPlan) onEdit;
  final void Function(SalaryPlan) onDelete;

  const _PlanList(
      {required this.plans, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final symbol =
        context.watch<SettingsProvider>().currencySymbol;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _PlanCard(
        plan: plans[i],
        symbol: symbol,
        onEdit: () => onEdit(plans[i]),
        onDelete: () => onDelete(plans[i]),
      ),
    );
  }
}

// ─── Plan Card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final SalaryPlan plan;
  final String symbol;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlanCard({
    required this.plan,
    required this.symbol,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unallocated = plan.unallocated;
    final isComplete = plan.isComplete;
    final allocPct =
        plan.monthlyIncome > 0 ? plan.totalAllocated / plan.monthlyIncome : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.monthYear(plan.periodStart),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(isComplete: isComplete),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        size: 20,
                      ),
                      color: isDark ? AppColors.darkSurface2 : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) {
                        if (v == 'edit') onEdit();
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_rounded,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text('Edit',
                                style: GoogleFonts.poppins(fontSize: 13)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 16, color: AppColors.expense),
                            const SizedBox(width: 8),
                            Text('Delete',
                                style: GoogleFonts.poppins(
                                    fontSize: 13, color: AppColors.expense)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Income row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Monthly Income',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color)),
                    Text(
                      CurrencyFormatter.format(plan.monthlyIncome,
                          symbol: symbol),
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: allocPct.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor:
                        isDark ? AppColors.darkDivider : AppColors.primary.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete ? AppColors.income : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Allocation chips row
                Row(
                  children: [
                    _MiniChip(
                      icon: AllocationType.category.icon,
                      color: AllocationType.category.color,
                      label: CurrencyFormatter.formatCompact(
                          plan.categoryTotal, symbol: symbol),
                    ),
                    const SizedBox(width: 6),
                    _MiniChip(
                      icon: AllocationType.savingsGoal.icon,
                      color: AllocationType.savingsGoal.color,
                      label: CurrencyFormatter.formatCompact(
                          plan.savingsTotal, symbol: symbol),
                    ),
                    const SizedBox(width: 6),
                    _MiniChip(
                      icon: AllocationType.loan.icon,
                      color: AllocationType.loan.color,
                      label: CurrencyFormatter.formatCompact(
                          plan.loanTotal, symbol: symbol),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          unallocated >= 0
                              ? CurrencyFormatter.format(unallocated,
                                  symbol: symbol)
                              : '-${CurrencyFormatter.format(unallocated.abs(), symbol: symbol)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: unallocated < 0
                                ? AppColors.expense
                                : isComplete
                                    ? AppColors.income
                                    : AppColors.primary,
                          ),
                        ),
                        Text(
                          'unallocated',
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isComplete;
  const _StatusChip({required this.isComplete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isComplete
            ? AppColors.income.withOpacity(0.12)
            : AppColors.spending.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isComplete ? 'Complete' : 'Incomplete',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isComplete ? AppColors.income : AppColors.spending,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _MiniChip(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

// ─── Allocation Breakdown Sheet ───────────────────────────────────────────────

class _AllocationBreakdownSheet extends StatelessWidget {
  final SalaryPlan plan;
  const _AllocationBreakdownSheet({required this.plan});

  @override
  Widget build(BuildContext context) {
    final symbol =
        context.watch<SettingsProvider>().currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkDivider : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(plan.name,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          Text(CurrencyFormatter.monthYear(plan.periodStart),
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color)),
          const SizedBox(height: 20),
          for (final type in AllocationType.values)
            _TypeSection(type: type, plan: plan, symbol: symbol),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Unallocated',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(
                CurrencyFormatter.format(plan.unallocated, symbol: symbol),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: plan.unallocated <= 0
                      ? AppColors.income
                      : AppColors.spending,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeSection extends StatelessWidget {
  final AllocationType type;
  final SalaryPlan plan;
  final String symbol;

  const _TypeSection(
      {required this.type, required this.plan, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final items = plan.byType(type);
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(type.icon, size: 14, color: type.color),
            const SizedBox(width: 6),
            Text(type.shortLabel,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: type.color,
                )),
          ],
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.name,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyMedium?.color)),
                Text(
                  CurrencyFormatter.format(item.amount, symbol: symbol),
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

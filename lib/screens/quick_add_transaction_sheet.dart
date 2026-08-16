import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/settings_provider.dart';
import 'add_transaction_screen.dart';
import 'add_edit_category_screen.dart';

/// Call this to show the quick-add bottom sheet.
Future<void> showQuickAddSheet(BuildContext context, TransactionType type) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuickAddSheet(type: type),
  );
}

class _QuickAddSheet extends StatefulWidget {
  final TransactionType type;
  const _QuickAddSheet({required this.type});

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  int _step = 0; // 0=category, 1=amount
  AppCategory? _selectedCategory;
  String _amountRaw = '0';
  String _searchQuery = '';
  String _selectedWallet = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallets = context.read<WalletProvider>().wallets;
      if (wallets.isNotEmpty && mounted) {
        setState(() => _selectedWallet = wallets.first.name);
      }
    });
  }

  List<AppCategory> _categories(BuildContext ctx) {
    final catType = widget.type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;
    final all = ctx.read<CategoryProvider>().categoriesForType(catType);
    if (_searchQuery.isEmpty) return all;
    return all
        .where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  double get _amount => double.tryParse(_amountRaw) ?? 0;

  void _onKey(String key) {
    setState(() {
      if (key == 'C') {
        _amountRaw = '0';
      } else if (key == '⌫') {
        if (_amountRaw.length > 1) {
          _amountRaw = _amountRaw.substring(0, _amountRaw.length - 1);
        } else {
          _amountRaw = '0';
        }
      } else if (key == '=' || key == '÷' || key == '×' || key == '-' || key == '+') {
        // ignore operators for now
      } else if (key == '.') {
        if (!_amountRaw.contains('.')) _amountRaw += '.';
      } else {
        if (_amountRaw == '0') {
          _amountRaw = key;
        } else {
          if (_amountRaw.contains('.')) {
            final parts = _amountRaw.split('.');
            if (parts[1].length < 2) _amountRaw += key;
          } else {
            _amountRaw += key;
          }
        }
      }
    });
  }

  Future<void> _quickSave(BuildContext ctx) async {
    if (_amount <= 0) {
      _showSnack(ctx, 'Please enter a valid amount');
      return;
    }
    if (_selectedCategory == null) {
      setState(() => _step = 0);
      return;
    }

    final txProvider = ctx.read<TransactionProvider>();
    final walletProvider = ctx.read<WalletProvider>();

    final tx = TransactionModel(
      title: _selectedCategory!.name,
      amount: _amount,
      type: widget.type,
      category: _selectedCategory!.name,
      date: DateTime.now(),
      note: null,
      walletName: _selectedWallet.isEmpty ? 'Cash' : _selectedWallet,
    );

    try {
      await txProvider.addTransaction(tx);
      final wallets = walletProvider.wallets;
      if (wallets.isNotEmpty) {
        final wallet = wallets.firstWhere(
          (w) => w.name == tx.walletName,
          orElse: () => wallets.first,
        );
        final newBalance = widget.type == TransactionType.income
            ? wallet.balance + _amount
            : wallet.balance - _amount;
        await walletProvider.updateWallet(wallet.copyWith(balance: newBalance));
      }
      if (ctx.mounted) {
        Navigator.pop(ctx, true);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                '${widget.type == TransactionType.income ? 'Income' : 'Expense'} saved!',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ]),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: AppColors.income,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) _showSnack(ctx, 'Error: ${e.toString()}');
    }
  }

  void _addMoreDetails(BuildContext ctx) {
    Navigator.pop(ctx);
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(initialType: widget.type),
      ),
    );
  }

  void _showSnack(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 14)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.expense,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = widget.type == TransactionType.income;
    final accentColor = isIncome ? AppColors.income : AppColors.expense;

    return Container(
      height: _step == 0 ? screenHeight * 0.85 : screenHeight * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: _step == 0
                ? _CategoryStep(
                    type: widget.type,
                    accentColor: accentColor,
                    isDark: isDark,
                    searchQuery: _searchQuery,
                    onSearchChanged: (v) => setState(() => _searchQuery = v),
                    categories: _categories(context),
                    onCategorySelected: (cat) {
                      setState(() {
                        _selectedCategory = cat;
                        _step = 1;
                      });
                    },
                    onCreateCategory: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditCategoryScreen(
                            initialType: widget.type == TransactionType.income
                                ? CategoryType.income
                                : CategoryType.expense,
                          ),
                        ),
                      );
                      setState(() {});
                    },
                  )
                : _AmountStep(
                    type: widget.type,
                    accentColor: accentColor,
                    isDark: isDark,
                    selectedCategory: _selectedCategory!,
                    amountRaw: _amountRaw,
                    selectedWallet: _selectedWallet,
                    onWalletChanged: (w) => setState(() => _selectedWallet = w),
                    onKey: _onKey,
                    onBack: () => setState(() => _step = 0),
                    onQuickSave: () => _quickSave(context),
                    onAddMoreDetails: () => _addMoreDetails(context),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 1: Category ─────────────────────────────────────────────────────────

class _CategoryStep extends StatelessWidget {
  final TransactionType type;
  final Color accentColor;
  final bool isDark;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final List<AppCategory> categories;
  final ValueChanged<AppCategory> onCategorySelected;
  final VoidCallback onCreateCategory;

  const _CategoryStep({
    required this.type,
    required this.accentColor,
    required this.isDark,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.categories,
    required this.onCategorySelected,
    required this.onCreateCategory,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).textTheme.titleLarge?.color;
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Category',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose a category for this transaction',
                      style: GoogleFonts.poppins(fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onCreateCategory,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Create',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              onChanged: onSearchChanged,
              style: GoogleFonts.poppins(fontSize: 14, color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Search categories',
                hintStyle: GoogleFonts.poppins(fontSize: 14, color: textSecondary),
                prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Count row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ALL CATEGORIES',
                style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2,
                  color: textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${categories.length}',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Grid
        Expanded(
          child: categories.isEmpty
              ? Center(
                  child: Text(
                    'No categories found',
                    style: GoogleFonts.poppins(fontSize: 14, color: textSecondary),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (ctx, i) {
                    final cat = categories[i];
                    return _CategoryGridItem(
                      category: cat,
                      accentColor: accentColor,
                      isDark: isDark,
                      onTap: () => onCategorySelected(cat),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CategoryGridItem extends StatelessWidget {
  final AppCategory category;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryGridItem({
    required this.category,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).textTheme.titleLarge?.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(category.icon, color: category.color, size: 26),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 2: Amount + Numpad ──────────────────────────────────────────────────

class _AmountStep extends StatelessWidget {
  final TransactionType type;
  final Color accentColor;
  final bool isDark;
  final AppCategory selectedCategory;
  final String amountRaw;
  final String selectedWallet;
  final ValueChanged<String> onWalletChanged;
  final ValueChanged<String> onKey;
  final VoidCallback onBack;
  final VoidCallback onQuickSave;
  final VoidCallback onAddMoreDetails;

  const _AmountStep({
    required this.type,
    required this.accentColor,
    required this.isDark,
    required this.selectedCategory,
    required this.amountRaw,
    required this.selectedWallet,
    required this.onWalletChanged,
    required this.onKey,
    required this.onBack,
    required this.onQuickSave,
    required this.onAddMoreDetails,
  });

  @override
  Widget build(BuildContext context) {
    final wallets = context.watch<WalletProvider>().wallets;
    final settings = context.watch<SettingsProvider>();
    final textPrimary = Theme.of(context).textTheme.titleLarge?.color;
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color;
    final surfaceColor = isDark ? AppColors.darkSurface2 : Colors.white;

    final effectiveWallet = wallets.isNotEmpty
        ? (wallets.any((w) => w.name == selectedWallet)
            ? selectedWallet
            : wallets.first.name)
        : '';

    return Column(
      children: [
        // Back + chip row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      'Category',
                      style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600, color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: selectedCategory.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(selectedCategory.icon, size: 16, color: selectedCategory.color),
                    const SizedBox(width: 6),
                    Text(
                      selectedCategory.name,
                      style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600, color: selectedCategory.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Account selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3, height: 16,
                    decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Select Account',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 62,
                child: wallets.isEmpty
                    ? Text('No wallets available', style: GoogleFonts.poppins(fontSize: 13, color: textSecondary))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: wallets.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final w = wallets[i];
                          final isSelected = effectiveWallet == w.name;
                          return GestureDetector(
                            onTap: () => onWalletChanged(w.name),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? accentColor.withOpacity(0.12) : surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? accentColor : Theme.of(context).dividerColor,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        w.name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13, fontWeight: FontWeight.w600,
                                          color: isSelected ? accentColor : textPrimary,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 4),
                                        Icon(Icons.check_circle_rounded, size: 14, color: accentColor),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    CurrencyFormatter.format(w.balance, symbol: settings.currencySymbol),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: isSelected ? accentColor.withOpacity(0.8) : textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Amount display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3, height: 14,
                      decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Enter Amount',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      settings.currencySymbol,
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500, color: textSecondary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      amountRaw,
                      style: GoogleFonts.poppins(
                        fontSize: 36, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Numpad
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _Numpad(accentColor: accentColor, isDark: isDark, onKey: onKey),
          ),
        ),

        // Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: onQuickSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Quick Save',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: onAddMoreDetails,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(color: accentColor, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Add More Details',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Custom Numpad ────────────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  final Color accentColor;
  final bool isDark;
  final ValueChanged<String> onKey;

  const _Numpad({required this.accentColor, required this.isDark, required this.onKey});

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? AppColors.darkSurface2 : Colors.white;
    final textPrimary = Theme.of(context).textTheme.titleLarge?.color;

    final rows = [
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '-'],
      ['C', '0', '⌫', '+'],
      ['.', '='],
    ];

    Widget buildKey(String label) {
      final isOperator = ['÷', '×', '-', '+'].contains(label);
      final isEquals = label == '=';
      final isClear = label == 'C';
      final isBackspace = label == '⌫';

      Color bgColor;
      Color fgColor;

      if (isEquals) {
        bgColor = accentColor;
        fgColor = Colors.white;
      } else if (isOperator) {
        bgColor = accentColor.withOpacity(isDark ? 0.22 : 0.12);
        fgColor = accentColor;
      } else if (isClear) {
        bgColor = AppColors.expense.withOpacity(isDark ? 0.22 : 0.12);
        fgColor = AppColors.expense;
      } else {
        bgColor = baseColor;
        fgColor = textPrimary ?? Colors.black;
      }

      return Expanded(
        flex: isEquals ? 3 : 1,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Material(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onKey(label),
              child: Container(
                alignment: Alignment.center,
                child: isBackspace
                    ? Icon(Icons.backspace_outlined, color: fgColor, size: 20)
                    : Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: isEquals ? 22 : 20,
                          fontWeight: FontWeight.w600,
                          color: fgColor,
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: rows.map((row) {
        return Expanded(
          child: Row(children: row.map(buildKey).toList()),
        );
      }).toList(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/wallet_model.dart';
import '../providers/settings_provider.dart';
import '../providers/wallet_provider.dart';
import 'add_edit_wallet_screen.dart';
import 'wallet_detail_screen.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().loadWallets();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Consumer<WalletProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.wallets.isEmpty) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => provider.loadWallets(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _WalletSummaryCard(provider: provider),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Text(
                      'My Wallets',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                      ),
                    ),
                  ),
                ),
                if (provider.wallets.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _EmptyWallets(onAdd: _openAddWallet),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _WalletTile(
                            wallet: provider.wallets[index],
                            onTap: () => _openWalletDetail(
                                provider.wallets[index]),
                          ),
                        ),
                        childCount: provider.wallets.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddWallet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        'Wallets',
        style: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
        ),
      ),
    );
  }

  Future<void> _openAddWallet() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddEditWalletScreen()),
    );
    if (result == true && mounted) {
      context.read<WalletProvider>().loadWallets();
    }
  }

  void _openWalletDetail(WalletModel wallet) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WalletDetailScreen(wallet: wallet)),
    );
  }
}

// ─── Summary Card ──────────────────────────────────────────────────────────────

class _WalletSummaryCard extends StatelessWidget {
  final WalletProvider provider;
  const _WalletSummaryCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative wallet icon (bottom right)
          Positioned(
            right: -10,
            bottom: -14,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 90,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          // Sparkle decorations
          Positioned(
            right: 28,
            top: 8,
            child: Icon(
              Icons.auto_awesome,
              size: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Positioned(
            left: 50,
            bottom: 12,
            child: Icon(
              Icons.auto_awesome,
              size: 10,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          // Content
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Balance
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Balance',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.formatCompact(provider.totalBalance,
                            symbol: settings.currencySymbol),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Vertical divider
              Container(
                width: 1,
                height: 48,
                color: Colors.white.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),
              // Active Wallets
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Wallets',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${provider.activeWalletCount}',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Vertical divider
              Container(
                width: 1,
                height: 48,
                color: Colors.white.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),
              // This Month Transfers
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Month Transfers',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.formatCompact(provider.thisMonthTransfers,
                            symbol: settings.currencySymbol),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Wallet Tile ───────────────────────────────────────────────────────────────

class _WalletTile extends StatelessWidget {
  final WalletModel wallet;
  final VoidCallback onTap;
  const _WalletTile({required this.wallet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final status = wallet.status;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: wallet.lightColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(wallet.icon, color: wallet.color, size: 24),
            ),
            const SizedBox(width: 14),
            // Name + balance
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    wallet.status == WalletStatus.installment
                        ? '${CurrencyFormatter.format(wallet.balance, symbol: settings.currencySymbol)} due'
                        : CurrencyFormatter.format(wallet.balance,
                            symbol: settings.currencySymbol),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: status.lightColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: status.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    status.displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: status.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────────────────

class _EmptyWallets extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyWallets({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkPrimarySurface
                  : AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Wallets Yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your first wallet to start\ntracking your money',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Add Wallet',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

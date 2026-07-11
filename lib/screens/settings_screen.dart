import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<Map<String, dynamic>> _currencies = [
    {'symbol': 'Rs.', 'name': 'Indian Rupee (Rs.)'},
    {'symbol': '₹', 'name': 'Indian Rupee (₹)'},
    {'\$': '\$', 'symbol': '\$', 'name': 'US Dollar (\$)'},
    {'symbol': '€', 'name': 'Euro (€)'},
    {'symbol': '£', 'name': 'British Pound (£)'},
    {'symbol': '¥', 'name': 'Japanese Yen (¥)'},
    {'symbol': 'AED', 'name': 'UAE Dirham (AED)'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile card
                _ProfileCard(),
                const SizedBox(height: 24),

                // Preferences section
                _SectionHeader(title: 'Preferences'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _ToggleTile(
                      icon: Icons.visibility_outlined,
                      iconColor: AppColors.primary,
                      title: 'Show Balance',
                      subtitle: 'Display balance on dashboard',
                      value: settings.balanceVisible,
                      onChanged: (_) => settings.toggleBalanceVisibility(),
                    ),
                    const Divider(height: 1, indent: 56),
                    _ToggleTile(
                      icon: Icons.notifications_outlined,
                      iconColor: AppColors.spending,
                      title: 'Notifications',
                      subtitle: 'Spending alerts and reminders',
                      value: settings.notificationsEnabled,
                      onChanged: (_) => settings.toggleNotifications(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Currency section
                _SectionHeader(title: 'Currency'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: DropdownButtonFormField<String>(
                        value: settings.currencySymbol,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          prefixIcon: Icon(Icons.currency_exchange_rounded,
                              color: AppColors.income, size: 20),
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        dropdownColor: AppColors.surface,
                        items: _currencies
                            .map((c) => DropdownMenuItem<String>(
                                  value: c['symbol'] as String,
                                  child: Text(c['name'] as String,
                                      style: GoogleFonts.inter(fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (symbol) {
                          if (symbol != null) {
                            settings.setCurrencySymbol(symbol);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // About section
                _SectionHeader(title: 'About'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _InfoTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppColors.budget,
                      title: 'Version',
                      trailing: '1.0.0',
                    ),
                    const Divider(height: 1, indent: 56),
                    _InfoTile(
                      icon: Icons.security_rounded,
                      iconColor: AppColors.income,
                      title: 'Privacy Policy',
                      trailing: null,
                      showChevron: true,
                    ),
                    const Divider(height: 1, indent: 56),
                    _InfoTile(
                      icon: Icons.star_outline_rounded,
                      iconColor: AppColors.spending,
                      title: 'Rate the App',
                      trailing: null,
                      showChevron: true,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Danger zone
                _SectionHeader(title: 'Data'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _DangerTile(
                      icon: Icons.delete_forever_rounded,
                      title: 'Clear All Data',
                      subtitle: 'Delete all transactions permanently',
                      onTap: () => _showClearDataDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'Made with ❤️ • Money Manager',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear All Data',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will permanently delete all your transactions. This action cannot be undone.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('All data cleared successfully')),
              );
            },
            child: Text('Clear',
                style: GoogleFonts.inter(
                    color: AppColors.expense,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Money Manager',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Offline • Secure • Private',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

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
      child: Column(children: children),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style:
            GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.primary,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? trailing;
  final bool showChevron;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
      ),
      trailing: trailing != null
          ? Text(
              trailing!,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary),
            )
          : showChevron
              ? const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint)
              : null,
    );
  }
}

class _DangerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DangerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.expense.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.expense, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.expense),
      ),
      subtitle: Text(
        subtitle,
        style:
            GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textHint),
    );
  }
}

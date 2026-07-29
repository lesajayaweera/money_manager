import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/preference_keys.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'main_scaffold.dart';
import 'providers/category_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/lend_borrow_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/splash_screen.dart';
import 'services/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await DatabaseService.instance.initialize();

  final prefs = await SharedPreferences.getInstance();

  final hasShownInitialSplash =
      prefs.getBool(PreferenceKeys.hasShownInitialSplash) ?? false;

  runApp(
    MoneyManagerApp(
      showInitialSplash: !hasShownInitialSplash,
    ),
  );
}

class MoneyManagerApp extends StatelessWidget {
  final bool showInitialSplash;

  const MoneyManagerApp({
    super.key,
    required this.showInitialSplash,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => TransactionProvider()..loadAll(),
        ),
        ChangeNotifierProvider(
          create: (_) => GoalProvider()..loadGoals(),
        ),
        ChangeNotifierProvider(
          create: (_) => LendBorrowProvider()..loadEntries(),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => WalletProvider()..loadWallets(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final isDark = settings.isDarkMode;

          // Sync the dynamic palette before building themes
          AppColors.setSeedColor(settings.themeColor);

          final overlayStyle = SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: isDark
                ? const Color(0xFF1C1C2E)
                : Colors.white,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          );

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyle,
            child: MaterialApp(
              title: 'Money Manager',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode:
                  isDark ? ThemeMode.dark : ThemeMode.light,
              home: showInitialSplash
                  ? const SplashScreen()
                  : const MainScaffold(),
              routes: {
                '/main': (_) => const MainScaffold(),
              },
            ),
          );
        },
      ),
    );
  }
}

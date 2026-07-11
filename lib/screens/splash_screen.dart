import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _walletController;
  late AnimationController _fadeController;
  late AnimationController _sparkleController;
  late AnimationController _buttonController;

  late Animation<double> _walletScale;
  late Animation<double> _walletFloat;
  late Animation<double> _fadeIn;
  late Animation<double> _sparkleAnim;
  late Animation<Offset> _buttonSlide;
  late Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();

    _walletController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _walletScale = CurvedAnimation(
      parent: _walletController,
      curve: Curves.elasticOut,
    );
    _walletFloat = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeInOut),
    );
    _fadeIn = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _sparkleAnim = CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeInOut,
    );
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOutCubic,
    ));
    _buttonFade = CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOut,
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _walletController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _buttonController.forward();
  }

  @override
  void dispose() {
    _walletController.dispose();
    _fadeController.dispose();
    _sparkleController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacementNamed('/main');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.splashGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                // Wallet Illustration
                AnimatedBuilder(
                  animation: Listenable.merge(
                      [_walletScale, _walletFloat, _sparkleAnim]),
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Sparkles
                        ..._buildSparkles(_sparkleAnim.value),
                        // Wallet
                        Transform.translate(
                          offset: Offset(0, -_walletFloat.value),
                          child: Transform.scale(
                            scale: _walletScale.value,
                            child: const _WalletIllustration(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const Spacer(flex: 1),
                // Title
                FadeTransition(
                  opacity: _fadeIn,
                  child: Column(
                    children: [
                      Text(
                        'Money Manager',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Manage your money\nsmartly and easily',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                // Button
                SlideTransition(
                  position: _buttonSlide,
                  child: FadeTransition(
                    opacity: _buttonFade,
                    child: _StartButton(onTap: _navigateToDashboard),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSparkles(double animValue) {
    final positions = [
      const Offset(-90, -80),
      const Offset(90, -90),
      const Offset(-110, 20),
      const Offset(100, 10),
      const Offset(-60, 90),
      const Offset(70, 80),
    ];
    final sizes = [12.0, 16.0, 10.0, 14.0, 8.0, 12.0];
    final delays = [0.0, 0.3, 0.6, 0.1, 0.8, 0.5];

    return List.generate(positions.length, (i) {
      final phase = (animValue + delays[i]) % 1.0;
      final opacity = (math.sin(phase * math.pi)).clamp(0.3, 1.0).toDouble();
      return Positioned(
        left: 110 + positions[i].dx,
        top: 110 + positions[i].dy,
        child: Opacity(
          opacity: opacity,
          child: _SparkleWidget(size: sizes[i]),
        ),
      );
    });
  }
}

class _SparkleWidget extends StatelessWidget {
  final double size;
  const _SparkleWidget({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SparklePainter(),
    );
  }
}

class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final outerX = cx + r * math.cos(angle);
      final outerY = cy + r * math.sin(angle);
      final innerAngle2 = angle + math.pi / 4;
      final ir = r * 0.15;
      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(cx + ir * math.cos(innerAngle2),
          cy + ir * math.sin(innerAngle2));
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WalletIllustration extends StatelessWidget {
  const _WalletIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Wallet body
          Positioned(
            bottom: 30,
            child: Container(
              width: 160,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF5543C8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
          // Wallet flap
          Positioned(
            bottom: 110,
            child: Container(
              width: 160,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF6655DC),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
            ),
          ),
          // Wallet clasp
          Positioned(
            bottom: 60,
            right: 28,
            child: Container(
              width: 28,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFFDAA3D),
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
          // Paper money (back)
          Positioned(
            top: 20,
            left: 30,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                width: 90,
                height: 55,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '\$',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Paper money (front)
          Positioned(
            top: 25,
            left: 50,
            child: Transform.rotate(
              angle: 0.12,
              child: Container(
                width: 90,
                height: 55,
                decoration: BoxDecoration(
                  color: const Color(0xFF66BB6A),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '\$',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Gold coin left
          Positioned(
            bottom: 55,
            left: 15,
            child: _GoldCoin(size: 36),
          ),
          // Gold coin bottom-center
          Positioned(
            bottom: 20,
            left: 60,
            child: _GoldCoin(size: 30),
          ),
        ],
      ),
    );
  }
}

class _GoldCoin extends StatelessWidget {
  final double size;
  const _GoldCoin({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFFD54F), Color(0xFFFDAA3D)],
          center: Alignment(-0.3, -0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFDAA3D).withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '\$',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatefulWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Start Managing Money',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

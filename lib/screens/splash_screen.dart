import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pin_screen.dart';
import 'setup_pin_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controllers
  late AnimationController _bgController;
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _particleController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;

  // Background gradient animation
  late Animation<double> _bgAnim;

  // Logo animations
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoRotate;

  // Text animations
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleOpacity;
  late Animation<Offset> _subtitleSlide;

  // Shimmer
  late Animation<double> _shimmerAnim;

  // Pulse glow
  late Animation<double> _pulseAnim;

  // Particles
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _generateParticles();
    _setupAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _startAnimations();
    });

Future.delayed(const Duration(milliseconds: 4500), () async {
  if (!mounted) return;
  final prefs = await SharedPreferences.getInstance();
  final pin = prefs.getString('app_pin');
  if (!mounted) return;
  Navigator.pushReplacement(
    context,
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 800),
      pageBuilder: (_, animation, __) =>
          pin == null ? const SetupPinScreen() : const PinScreen(),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
});
  }

  void _generateParticles() {
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 4 + 1,
        speed: _random.nextDouble() * 0.3 + 0.1,
        opacity: _random.nextDouble() * 0.5 + 0.1,
        angle: _random.nextDouble() * 2 * pi,
      ));
    }
  }

  void _setupAnimations() {
    // Background
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _bgAnim = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);

    // Logo
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    _logoRotate = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Text
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.8),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Shimmer
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Particle
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
  }

  void _startAnimations() async {
    _bgController.forward();
    _particleController.repeat();

    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 800));
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    _shimmerController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _particleController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _bgController,
          _logoController,
          _textController,
          _particleController,
          _shimmerController,
          _pulseController,
        ]),
        builder: (context, _) {
          return Stack(
            children: [
              // === BACKGROUND GRADIENT ===
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        const Color(0xFF0D1B2A),
                        const Color(0xFF1A0533),
                        _bgAnim.value,
                      )!,
                      Color.lerp(
                        const Color(0xFF1B2A4A),
                        const Color(0xFF0D2B45),
                        _bgAnim.value,
                      )!,
                      Color.lerp(
                        const Color(0xFF0A1628),
                        const Color(0xFF1A0A2E),
                        _bgAnim.value,
                      )!,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // === RADIAL GLOW ===
              Center(
                child: ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF4F8EF7).withOpacity(0.12 * _bgAnim.value),
                          const Color(0xFF8B5CF6).withOpacity(0.06 * _bgAnim.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // === PARTICLES ===
              ..._particles.map((p) {
                final t = (_particleController.value + p.speed) % 1.0;
                final dx = p.x + sin(t * 2 * pi + p.angle) * 0.05;
                final dy = (p.y - t * 0.15) % 1.0;
                return Positioned(
                  left: dx * size.width,
                  top: dy * size.height,
                  child: Opacity(
                    opacity: p.opacity * _bgAnim.value,
                    child: Container(
                      width: p.size,
                      height: p.size,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }),

              // === DECORATIVE RINGS ===
              Center(
                child: Opacity(
                  opacity: _bgAnim.value * 0.15,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF4F8EF7),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: _bgAnim.value * 0.08,
                  child: Container(
                    width: 420,
                    height: 420,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF8B5CF6),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),

              // === MAIN CONTENT ===
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo container with glow
                    FadeTransition(
                      opacity: _logoOpacity,
                      child: Transform.rotate(
                        angle: _logoRotate.value,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glow behind logo
                              Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4F8EF7).withOpacity(0.4),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                      blurRadius: 60,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                              // Logo border ring
                              Container(
                                width: 126,
                                height: 126,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF4F8EF7),
                                      Color(0xFF8B5CF6),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4F8EF7).withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(3),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF0D1B2A),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Image.asset(
                                    'assets/logo.png',
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Title with shimmer
                    FadeTransition(
                      opacity: _titleOpacity,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: _ShimmerText(
                          text: 'Putra Anugrah App',
                          shimmerValue: _shimmerAnim.value,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Subtitle
                    FadeTransition(
                      opacity: _subtitleOpacity,
                      child: SlideTransition(
                        position: _subtitleSlide,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF4F8EF7).withOpacity(0.3),
                              width: 1,
                            ),
                            color: const Color(0xFF4F8EF7).withOpacity(0.08),
                          ),
                          child: const Text(
                            'Kelola bisnis dengan mudah',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF90B8F8),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Loading dots
                    FadeTransition(
                      opacity: _subtitleOpacity,
                      child: _LoadingDots(controller: _particleController),
                    ),
                  ],
                ),
              ),

              // === VERSION TAG ===
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _subtitleOpacity,
                  child: const Center(
                    child: Text(
                      'v1.0.0',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white24,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================
// Shimmer Text Widget
// =============================================
class _ShimmerText extends StatelessWidget {
  final String text;
  final double shimmerValue;
  final TextStyle style;

  const _ShimmerText({
    required this.text,
    required this.shimmerValue,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Colors.white,
          Color(0xFFB8D4FF),
          Colors.white,
          Color(0xFFD4B8FF),
          Colors.white,
        ],
        stops: [
          (shimmerValue - 0.5).clamp(0.0, 1.0),
          (shimmerValue - 0.25).clamp(0.0, 1.0),
          shimmerValue.clamp(0.0, 1.0),
          (shimmerValue + 0.25).clamp(0.0, 1.0),
          (shimmerValue + 0.5).clamp(0.0, 1.0),
        ],
      ).createShader(bounds),
      child: Text(text, style: style),
    );
  }
}

// =============================================
// Loading Dots Widget
// =============================================
class _LoadingDots extends StatelessWidget {
  final AnimationController controller;

  const _LoadingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.15;
            final t = ((controller.value * 3) - delay) % 1.0;
            final bounce = sin(t * pi).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: Offset(0, -8 * bounce),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      const Color(0xFF4F8EF7).withOpacity(0.4),
                      const Color(0xFF8B5CF6),
                      bounce,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F8EF7).withOpacity(0.5 * bounce),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// =============================================
// Particle Model
// =============================================
class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final double angle;

  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.angle,
  });
}
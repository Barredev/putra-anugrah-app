import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/pin_numpad.dart';
import 'dashboard_screen.dart';

class PinScreen extends StatefulWidget {
  /// Jika true, hanya memverifikasi PIN lalu mengembalikan `true` via Navigator.pop.
  final bool verifyOnly;

  const PinScreen({super.key, this.verifyOnly = false});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxAttempts = 5;
  static const String _kFailedAttempts = 'pin_failed_attempts';
  static const String _kLockoutUntil = 'pin_lockout_until';
  static const String _kLockoutCount = 'pin_lockout_count';

  String _currentInput = '';
  bool _hasError = false;
  int _attemptCount = 0;
  int _lockoutCount = 0;
  int _remainingLockSeconds = 0;
  Timer? _lockoutTimer;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  bool get _isLockedOut => _remainingLockSeconds > 0;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _loadLockoutState();
  }

  Future<void> _loadLockoutState() async {
    final prefs = await SharedPreferences.getInstance();
    final failed = prefs.getInt(_kFailedAttempts) ?? 0;
    final lockoutCount = prefs.getInt(_kLockoutCount) ?? 0;
    final lockoutUntil = prefs.getInt(_kLockoutUntil) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (!mounted) return;
    setState(() {
      _attemptCount = failed;
      _lockoutCount = lockoutCount;
      if (lockoutUntil > nowMs) {
        _remainingLockSeconds = ((lockoutUntil - nowMs) / 1000).ceil();
        _hasError = true;
      }
    });

    if (_remainingLockSeconds > 0) {
      _startLockoutTimer(lockoutUntil);
    }
  }

  void _startLockoutTimer(int lockoutUntilMs) {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final remaining = ((lockoutUntilMs - nowMs) / 1000).ceil();
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _remainingLockSeconds = 0;
          _hasError = false;
        });
      } else {
        setState(() {
          _remainingLockSeconds = remaining;
        });
      }
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyTap(String key) {
    if (_isLockedOut || _currentInput.length >= 4) return;
    setState(() {
      _currentInput += key;
      _hasError = false;
    });
    if (_currentInput.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _checkPin);
    }
  }

  void _onDelete() {
    if (_isLockedOut || _currentInput.isEmpty) return;
    setState(() {
      _currentInput =
          _currentInput.substring(0, _currentInput.length - 1);
      _hasError = false;
    });
  }

  Future<void> _checkPin() async {
    if (!mounted || _isLockedOut) return;
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('app_pin') ?? '';

    if (_currentInput == savedPin) {
      // PIN benar → reset counter gagal & lanjut
      await prefs.remove(_kFailedAttempts);
      await prefs.remove(_kLockoutUntil);
      await prefs.remove(_kLockoutCount);
      if (!mounted) return;
      if (widget.verifyOnly) {
        Navigator.pop(context, true);
        return;
      }
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, animation, _) => const DashboardScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } else {
      // PIN salah
      _shakeController.forward(from: 0);
      _attemptCount++;

      if (_attemptCount >= _maxAttempts) {
        // Lockout dengan cooldown bertingkat (30d, 60d, 120d, maks 300d)
        _lockoutCount++;
        final int cooldownSec =
            (30 * (1 << (_lockoutCount - 1).clamp(0, 4))).clamp(30, 300);
        final int lockoutUntilMs =
            DateTime.now().millisecondsSinceEpoch + (cooldownSec * 1000);

        _attemptCount = 0;
        await prefs.setInt(_kFailedAttempts, 0);
        await prefs.setInt(_kLockoutCount, _lockoutCount);
        await prefs.setInt(_kLockoutUntil, lockoutUntilMs);

        if (!mounted) return;
        setState(() {
          _hasError = true;
          _currentInput = '';
          _remainingLockSeconds = cooldownSec;
        });
        _startLockoutTimer(lockoutUntilMs);
      } else {
        await prefs.setInt(_kFailedAttempts, _attemptCount);
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _currentInput = '';
        });
      }
    }
  }

  String _formatLockTime(int totalSeconds) {
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    if (mins > 0) {
      return '$mins menit ${secs.toString().padLeft(2, '0')} detik';
    }
    return '$secs detik';
  }

  @override
  Widget build(BuildContext context) {
    final sisa = _maxAttempts - _attemptCount;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: widget.verifyOnly
          ? AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              title: const Text('Verifikasi PIN Lama'),
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Spacer(),

                    // Icon lock
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isLockedOut
                                ? Colors.red
                                : const Color(0xFF4F8EF7))
                            .withValues(alpha: 0.15),
                        border: Border.all(
                            color: (_isLockedOut
                                    ? Colors.red
                                    : const Color(0xFF4F8EF7))
                                .withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                          _isLockedOut ? Icons.lock_clock : Icons.lock_outline,
                          color: _isLockedOut
                              ? Colors.red
                              : const Color(0xFF4F8EF7),
                          size: 32),
                    ),

                    const SizedBox(height: 20),

                    // Judul
                    Text(
                      widget.verifyOnly
                          ? 'Masukkan PIN Saat Ini'
                          : 'Masukkan PIN',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Putra Anugrah App',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),

                    const SizedBox(height: 28),

                    // Indikator 4 titik dengan animasi shake
                    AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (ctx, child) {
                        final offset = sin(_shakeAnim.value * pi * 6) * 12;
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final filled = i < _currentInput.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _hasError || _isLockedOut
                                  ? Colors.red
                                  : filled
                                      ? const Color(0xFF4F8EF7)
                                      : Colors.white24,
                              boxShadow: filled && !_hasError && !_isLockedOut
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF4F8EF7)
                                            .withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      )
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Pesan error / lockout cooldown
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        height: 36,
                        child: _isLockedOut
                            ? Text(
                                'Terlalu banyak percobaan salah.\nCoba lagi dalam ${_formatLockTime(_remainingLockSeconds)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.redAccent, fontSize: 13),
                              )
                            : _hasError
                                ? Text(
                                    'PIN salah. Sisa percobaan: $sisa',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 13),
                                  )
                                : null,
                      ),
                    ),

                    const Spacer(),

                    // Numpad
                    Opacity(
                      opacity: _isLockedOut ? 0.35 : 1.0,
                      child: IgnorePointer(
                        ignoring: _isLockedOut,
                        child: PinNumpad(
                          onKeyTap: _onKeyTap,
                          onDelete: _onDelete,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
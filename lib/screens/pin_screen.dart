import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';
import 'setup_pin_screen.dart';
import 'dart:math';


class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  String _currentInput = '';
  bool _hasError = false;
  int _attemptCount = 0;
  static const int _maxAttempts = 5;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

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
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyTap(String key) {
    if (_currentInput.length >= 4) return;
    setState(() {
      _currentInput += key;
      _hasError = false;
    });
    if (_currentInput.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _checkPin);
    }
  }

  void _onDelete() {
    if (_currentInput.isEmpty) return;
    setState(() {
      _currentInput =
          _currentInput.substring(0, _currentInput.length - 1);
      _hasError = false;
    });
  }

  Future<void> _checkPin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('app_pin') ?? '';

    if (_currentInput == savedPin) {
      // PIN benar → ke dashboard
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, animation, __) => const DashboardScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } else {
      // PIN salah
      _shakeController.forward(from: 0);
      _attemptCount++;
      

      setState(() {
        _hasError = true;
        _currentInput = '';
      });

      if (_attemptCount >= _maxAttempts) {
        // Terlalu banyak percobaan — reset PIN
        _showResetDialog();
      }
    }
  }

  Future<void> _showResetDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Terlalu Banyak Percobaan'),
        content: const Text(
          'PIN salah 5 kali. PIN akan direset.\nAnda perlu membuat PIN baru.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('app_pin');
              if (!mounted) return;
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const SetupPinScreen()),
              );
            },
            child: const Text('Buat PIN Baru'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sisa = _maxAttempts - _attemptCount;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Icon lock
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4F8EF7).withOpacity(0.15),
                border: Border.all(
                    color: const Color(0xFF4F8EF7).withOpacity(0.3)),
              ),
              child: const Icon(Icons.lock_outline,
                  color: Color(0xFF4F8EF7), size: 36),
            ),

            const SizedBox(height: 24),

            // Judul
            const Text(
              'Masukkan PIN',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Putra Anugrah App',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),

            const SizedBox(height: 40),

            // Indikator 4 titik dengan animasi shake
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (ctx, child) {
                final offset =
                    sin(_shakeAnim.value * pi * 6) * 12;
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
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hasError
                          ? Colors.red
                          : filled
                              ? const Color(0xFF4F8EF7)
                              : Colors.white24,
                      boxShadow: filled && !_hasError
                          ? [
                              BoxShadow(
                                color: const Color(0xFF4F8EF7)
                                    .withOpacity(0.5),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // Pesan error / percobaan tersisa
            SizedBox(
              height: 20,
              child: _hasError
                  ? Text(
                      _attemptCount >= _maxAttempts
                          ? 'Terlalu banyak percobaan'
                          : 'PIN salah. Sisa percobaan: $sisa',
                      style: const TextStyle(
                          color: Colors.red, fontSize: 13),
                    )
                  : null,
            ),

            const Spacer(),

            // Numpad
            _buildNumpad(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _numpadRow(['1', '2', '3']),
          const SizedBox(height: 16),
          _numpadRow(['4', '5', '6']),
          const SizedBox(height: 16),
          _numpadRow(['7', '8', '9']),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 72),
              _numKey('0'),
              _deleteKey(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numpadRow(List<String> keys) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map(_numKey).toList(),
      );

  Widget _numKey(String key) => GestureDetector(
        onTap: () => _onKeyTap(key),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white12),
          ),
          child: Center(
            child: Text(
              key,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
      );

  Widget _deleteKey() => GestureDetector(
        onTap: _onDelete,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.06),
          ),
          child: const Center(
            child: Icon(Icons.backspace_outlined,
                color: Colors.white70, size: 24),
          ),
        ),
      );
}
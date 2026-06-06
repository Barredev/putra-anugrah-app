import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';
import 'dart:math';

class SetupPinScreen extends StatefulWidget {
  /// true = ganti PIN (dari settings), false = setup pertama kali
  final bool isChanging;

  const SetupPinScreen({super.key, this.isChanging = false});

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen>
    with SingleTickerProviderStateMixin {
  // Step 1: input PIN baru, Step 2: konfirmasi PIN
  int _step = 1;
  String _firstPin = '';
  String _currentInput = '';
  bool _hasError = false;
  String _errorMsg = '';

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
      Future.delayed(const Duration(milliseconds: 150), _onPinComplete);
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

  Future<void> _onPinComplete() async {
    if (_step == 1) {
      // Simpan PIN pertama, minta konfirmasi
      setState(() {
        _firstPin = _currentInput;
        _currentInput = '';
        _step = 2;
      });
    } else {
      // Konfirmasi — cek cocok
      if (_currentInput == _firstPin) {
        // Simpan PIN ke SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_pin', _currentInput);

        if (!mounted) return;

        if (widget.isChanging) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN berhasil diubah'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          // Setup pertama — langsung ke dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const DashboardScreen()),
          );
        }
      } else {
        // PIN tidak cocok — shake & reset
        _shakeController.forward(from: 0);
        setState(() {
          _hasError = true;
          _errorMsg = 'PIN tidak cocok. Coba lagi.';
          _currentInput = '';
          _step = 1;
          _firstPin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: widget.isChanging
          ? AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              title: const Text('Ganti PIN'),
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Judul
            Text(
              _step == 1 ? 'Buat PIN Baru' : 'Konfirmasi PIN',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _step == 1
                  ? 'Masukkan 4 digit PIN untuk mengamankan app'
                  : 'Masukkan kembali PIN yang sama',
              style: const TextStyle(
                  color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Indikator PIN (4 titik)
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
                  return Container(
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
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // Pesan error
            SizedBox(
              height: 20,
              child: _hasError
                  ? Text(
                      _errorMsg,
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
              const SizedBox(width: 72), // placeholder
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
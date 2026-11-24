import 'package:flutter/material.dart';

/// Numpad PIN bersama untuk PinScreen & SetupPinScreen.
class PinNumpad extends StatelessWidget {
  final ValueChanged<String> onKeyTap;
  final VoidCallback onDelete;

  const PinNumpad({
    super.key,
    required this.onKeyTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
        onTap: () => onKeyTap(key),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white12),
          ),
          child: Center(
            child: Text(
              key,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );

  Widget _deleteKey() => GestureDetector(
        onTap: onDelete,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          child: const Center(
            child: Icon(
              Icons.backspace_outlined,
              color: Colors.white70,
              size: 24,
            ),
          ),
        ),
      );
}

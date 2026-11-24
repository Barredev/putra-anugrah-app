import 'package:flutter/services.dart';

/// Format angka menjadi format mata uang Indonesia, misal: `150000` -> `Rp 150.000`.
String formatRupiah(num amount) {
  final isNeg = amount < 0;
  final formatted = formatThousands(amount.toInt().abs());
  return isNeg ? '-Rp $formatted' : 'Rp $formatted';
}

/// Format angka bulat dengan pemisah ribuan titik, misal: `150000` -> `150.000`.
String formatThousands(int amount) {
  final str = amount.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
    buf.write(str[i]);
  }
  return buf.toString();
}

/// Mengubah string berformat ribuan (`150.000`) kembali menjadi integer (`150000`).
int? parseFormattedInt(String text) {
  final raw = text.replaceAll('.', '').trim();
  if (raw.isEmpty) return null;
  return int.tryParse(raw);
}

/// Format qty desimal secara ringkas (`2.0` -> `2`, `1.5` -> `1.5`).
String formatQty(num v, {int decimals = 2}) =>
    v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(decimals);

/// Format ISO-8601 date/time menjadi tampilan ringkas: `23 Nov 2026 • 14:30`.
String formatDateTimeShort(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final dt = DateTime.tryParse(iso);
  if (dt == null) {
    return iso.length >= 10 ? iso.substring(0, 10) : iso;
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final d = dt.day.toString().padLeft(2, '0');
  final m = months[dt.month - 1];
  final y = dt.year;
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$d $m $y • $hh:$mm';
}

/// Formatter input angka ribuan otomatis (`100000` -> `100.000`).
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final numericOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numericOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Hapus nol di depan agar tidak jadi "00.123", kecuali angka "0" saja
    final cleaned = numericOnly.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final buf = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && (cleaned.length - i) % 3 == 0) buf.write('.');
      buf.write(cleaned[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

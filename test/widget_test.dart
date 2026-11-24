import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putra_anugrah_app/database/database_helper.dart';
import 'package:putra_anugrah_app/models/category.dart';
import 'package:putra_anugrah_app/models/debt.dart';
import 'package:putra_anugrah_app/models/product.dart';
import 'package:putra_anugrah_app/screens/pin_screen.dart';
import 'package:putra_anugrah_app/utils/formatters.dart';
import 'package:putra_anugrah_app/widgets/month_picker_dialog.dart';
import 'package:putra_anugrah_app/widgets/pin_numpad.dart';

void main() {
  test('Product model toMap / fromMap roundtrip', () {
    final p = Product(
      id: 7,
      name: 'Lemari 2 Pintu',
      categoryId: 3,
      stock: 4.5,
      purchasePrice: 800000,
      sellingPrice: 1500000,
      unit: 'unit',
      minStock: 1.0,
    );
    final restored = Product.fromMap(p.toMap());
    expect(restored.id, 7);
    expect(restored.name, 'Lemari 2 Pintu');
    expect(restored.stock, 4.5);
    expect(restored.purchasePrice, 800000);
    expect(restored.sellingPrice, 1500000);
  });

  test('Category & Debt models, remaining balance, dan logika overdue', () {
    final cat = Category.fromMap(
      const Category(id: 2, name: 'Bahan Baku Mebel', type: 'RAW').toMap(),
    );
    expect(cat.id, 2);
    expect(cat.type, 'RAW');

    final today = DateTime.now();
    final yesterdayStr = today
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    final todayStr = today.toIso8601String().substring(0, 10);

    final overdueDebt = Debt(
      id: 1,
      contactId: 1,
      debtType: 'RECEIVABLE',
      amount: 500000,
      amountPaid: 200000,
      dueDate: yesterdayStr,
      status: 'PARTIAL',
    );
    final dueTodayDebt = Debt(
      id: 2,
      contactId: 1,
      debtType: 'RECEIVABLE',
      amount: 500000,
      amountPaid: 0,
      dueDate: todayStr,
      status: 'OPEN',
    );
    final paidOldDebt = Debt(
      id: 3,
      contactId: 1,
      debtType: 'PAYABLE',
      amount: 500000,
      amountPaid: 500000,
      dueDate: yesterdayStr,
      status: 'PAID',
    );

    expect(overdueDebt.remaining, 300000);
    expect(overdueDebt.isOverdue, isTrue);
    expect(dueTodayDebt.isOverdue, isFalse);
    expect(paidOldDebt.isOverdue, isFalse);
  });

  test('Validasi header SQLite menolak file non-SQLite dan menerima header valid', () {
    final validHeader = [...utf8.encode('SQLite format 3'), 0, 1, 2, 3];
    final invalidHeader = utf8.encode('Ini bukan file sqlite');
    final tooShort = [0x53, 0x51];

    expect(DatabaseHelper.isValidSqliteHeader(validHeader), isTrue);
    expect(DatabaseHelper.isValidSqliteHeader(invalidHeader), isFalse);
    expect(DatabaseHelper.isValidSqliteHeader(tooShort), isFalse);
  });

  test('Utilitas formatters (Rupiah, Qty, Tanggal, CurrencyInputFormatter)', () {
    expect(formatRupiah(1500000), 'Rp 1.500.000');
    expect(formatRupiah(-25000), '-Rp 25.000');
    expect(formatQty(3.0), '3');
    expect(formatQty(2.5), '2.50');
    expect(formatQty(2.5, decimals: 1), '2.5');
    expect(parseFormattedInt('1.250.000'), 1250000);
    expect(parseFormattedInt(''), isNull);
    expect(formatDateTimeShort('2026-11-23T14:05:00'), '23 Nov 2026 • 14:05');

    final formatter = CurrencyInputFormatter();
    final formatted = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '00250000'),
    );
    expect(formatted.text, '250.000');
  });

  testWidgets('PinNumpad meneruskan tap digit dan tombol hapus',
      (WidgetTester tester) async {
    final tapped = <String>[];
    int deletes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0D1B2A),
          body: PinNumpad(
            onKeyTap: tapped.add,
            onDelete: () => deletes++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('1'));
    await tester.tap(find.text('9'));
    await tester.tap(find.byIcon(Icons.backspace_outlined));

    expect(tapped, ['1', '9']);
    expect(deletes, 1);
  });

  testWidgets('showMonthPickerDialog mengembalikan bulan & tahun terpilih',
      (WidgetTester tester) async {
    MonthYearSelection? picked;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                picked = await showMonthPickerDialog(
                  context: context,
                  initialYear: 2026,
                  initialMonth: 1,
                );
              },
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nov'));
    await tester.pump();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.formatted, '2026-11');
  });

  testWidgets(
      'PinScreen mengunci sementara (cooldown) setelah 5x salah, tidak langsung reset PIN',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({'app_pin': '1234'});

    await tester.pumpWidget(
      const MaterialApp(home: PinScreen(verifyOnly: true)),
    );
    await tester.pumpAndSettle();

    // Masukkan PIN salah 5 kali ('0000')
    for (int attempt = 0; attempt < 5; attempt++) {
      for (int digit = 0; digit < 4; digit++) {
        await tester.tap(find.text('0'));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Pastikan TIDAK ada tombol reset bypass 'Buat PIN Baru'
    expect(find.text('Buat PIN Baru'), findsNothing);
    // Pastikan pesan lockout cooldown muncul
    expect(
      find.textContaining('Terlalu banyak percobaan salah.'),
      findsOneWidget,
    );
    expect(find.textContaining('detik'), findsOneWidget);

    // Pastikan app_pin TIDAK terhapus
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_pin'), '1234');
    expect(prefs.getInt('pin_lockout_until'), isNotNull);
  });
}

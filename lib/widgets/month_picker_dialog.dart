import 'package:flutter/material.dart';

/// Hasil pilihan bulan & tahun dari [showMonthPickerDialog].
class MonthYearSelection {
  final int year;
  final int month;

  const MonthYearSelection({required this.year, required this.month});

  String get formatted => '$year-${month.toString().padLeft(2, '0')}';
}

/// Dialog pemilih bulan & tahun seragam untuk AnalysisScreen & ProfitScreen.
Future<MonthYearSelection?> showMonthPickerDialog({
  required BuildContext context,
  required int initialYear,
  required int initialMonth,
}) async {
  int tYear = initialYear;
  int tMonth = initialMonth;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  return showDialog<MonthYearSelection>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Pilih Bulan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setD(() => tYear--),
                    ),
                    Text(
                      '$tYear',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setD(() => tYear++),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.0,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: List.generate(12, (i) {
                    final m = i + 1;
                    final sel = m == tMonth;
                    return GestureDetector(
                      onTap: () => setD(() => tMonth = m),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel ? Colors.blueAccent : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                sel ? Colors.blueAccent : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          months[i],
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.black87,
                            fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(
              dialogCtx,
              MonthYearSelection(year: tYear, month: tMonth),
            ),
            child: const Text('Pilih'),
          ),
        ],
      ),
    ),
  );
}

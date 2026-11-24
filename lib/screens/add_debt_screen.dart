import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/formatters.dart';

class AddDebtScreen extends StatefulWidget {
  final String initialType; // 'RECEIVABLE' | 'PAYABLE'

  const AddDebtScreen({super.key, required this.initialType});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _newContactNameController = TextEditingController();
  final _newContactPhoneController = TextEditingController();

  late String _debtType;
  List<Map<String, dynamic>> _contacts = [];
  int? _selectedContactId;
  bool _isNewContact = false;
  DateTime? _dueDate;
  bool _isSaving = false;
  bool _isLoadingContacts = true;

  @override
  void initState() {
    super.initState();
    _debtType = widget.initialType;
    _loadContacts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _newContactNameController.dispose();
    _newContactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final type = _debtType == 'RECEIVABLE' ? 'CUSTOMER' : 'SUPPLIER';
    final contacts = await DatabaseHelper.instance.getContacts(type: type);
    if (mounted) {
      setState(() {
        _contacts = List<Map<String, dynamic>>.from(contacts);
        _isLoadingContacts = false;
      });
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  InputDecoration _inputDecor(
    String label,
    String hint,
    IconData icon, {
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(
        icon,
        color: Colors.blueAccent.withValues(alpha: 0.75),
        size: 22,
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isNewContact && _selectedContactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kontak atau tambah kontak baru'),
        ),
      );
      return;
    }
    if (_isNewContact && _newContactNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama kontak wajib diisi')),
      );
      return;
    }

    final amount = parseFormattedInt(_amountController.text) ?? 0;
    setState(() => _isSaving = true);

    try {
      int contactId;

      if (_isNewContact) {
        final contactType =
            _debtType == 'RECEIVABLE' ? 'CUSTOMER' : 'SUPPLIER';
        contactId = await DatabaseHelper.instance.insertContact({
          'name': _newContactNameController.text.trim(),
          'phone': _newContactPhoneController.text.trim(),
          'type': contactType,
        });
      } else {
        contactId = _selectedContactId!;
      }

      await DatabaseHelper.instance.insertDebt({
        'contact_id': contactId,
        'debt_type': _debtType,
        'amount': amount,
        'due_date': _dueDate?.toIso8601String().substring(0, 10),
        'note': _noteController.text.trim(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal simpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _typeToggleButton({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final selected = _debtType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_debtType == value) return;
          setState(() {
            _debtType = value;
            _selectedContactId = null;
            _isLoadingContacts = true;
          });
          _loadContacts();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Colors.grey, size: 22),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: selected ? color : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReceivable = _debtType == 'RECEIVABLE';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          isReceivable ? 'Tambah Piutang' : 'Tambah Hutang',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoadingContacts
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Jenis Tagihan ─────────────────────
                    const Text(
                      'Jenis Tagihan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _typeToggleButton(
                          value: 'RECEIVABLE',
                          title: 'Piutang',
                          subtitle: 'Pelanggan hutang',
                          icon: Icons.arrow_downward_rounded,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _typeToggleButton(
                          value: 'PAYABLE',
                          title: 'Hutang',
                          subtitle: 'Toko hutang',
                          icon: Icons.arrow_upward_rounded,
                          color: Colors.redAccent,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Kontak ────────────────────────────
                    const Text(
                      'Informasi Kontak',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _isNewContact = false),
                            icon: const Icon(Icons.person_search, size: 18),
                            label: const Text('Pilih Kontak'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              foregroundColor: !_isNewContact
                                  ? Colors.blueAccent
                                  : Colors.grey.shade700,
                              backgroundColor: !_isNewContact
                                  ? Colors.blueAccent.withValues(alpha: 0.1)
                                  : Colors.white,
                              side: BorderSide(
                                color: !_isNewContact
                                    ? Colors.blueAccent
                                    : Colors.grey.shade300,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _isNewContact = true),
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('Kontak Baru'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              foregroundColor: _isNewContact
                                  ? Colors.blueAccent
                                  : Colors.grey.shade700,
                              backgroundColor: _isNewContact
                                  ? Colors.blueAccent.withValues(alpha: 0.1)
                                  : Colors.white,
                              side: BorderSide(
                                color: _isNewContact
                                    ? Colors.blueAccent
                                    : Colors.grey.shade300,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    if (!_isNewContact)
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _selectedContactId,
                        decoration: _inputDecor(
                          isReceivable ? 'Pilih Pelanggan' : 'Pilih Supplier',
                          _contacts.isEmpty
                              ? 'Belum ada kontak — gunakan Kontak Baru'
                              : 'Pilih kontak',
                          Icons.person_outline,
                        ),
                        items: _contacts.map((c) {
                          final phone = (c['phone'] as String?) ?? '';
                          return DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(
                              phone.isNotEmpty
                                  ? '${c['name']} ($phone)'
                                  : c['name'] as String,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedContactId = val),
                      )
                    else ...[
                      TextFormField(
                        controller: _newContactNameController,
                        decoration: _inputDecor(
                          isReceivable ? 'Nama Pelanggan' : 'Nama Supplier',
                          'Masukkan nama kontak...',
                          Icons.person_outline,
                        ),
                        validator: (v) => _isNewContact &&
                                (v == null || v.trim().isEmpty)
                            ? 'Nama wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _newContactPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecor(
                          'No. HP (opsional)',
                          '08xxxxxxxxxx',
                          Icons.phone_outlined,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Detail Tagihan ────────────────────
                    const Text(
                      'Detail Tagihan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: _inputDecor(
                        'Total Tagihan',
                        '0',
                        Icons.payments_outlined,
                        prefixText: 'Rp ',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Total tagihan wajib diisi';
                        }
                        final parsed = parseFormattedInt(v);
                        if (parsed == null) return 'Harus berupa angka bulat';
                        if (parsed <= 0) return 'Harus lebih dari 0';
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pickDueDate,
                      child: InputDecorator(
                        decoration: _inputDecor(
                          'Jatuh Tempo (opsional)',
                          'Pilih tanggal',
                          Icons.calendar_today_outlined,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _dueDate == null
                                  ? 'Pilih tanggal'
                                  : _dueDate!
                                      .toIso8601String()
                                      .substring(0, 10),
                              style: TextStyle(
                                color: _dueDate == null
                                    ? Colors.grey.shade500
                                    : Colors.black87,
                                fontSize: 15,
                              ),
                            ),
                            if (_dueDate != null)
                              GestureDetector(
                                onTap: () => setState(() => _dueDate = null),
                                child: const Icon(
                                  Icons.clear,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: _inputDecor(
                        'Catatan (opsional)',
                        'Contoh: Pembelian lemari 2 pintu',
                        Icons.note_outlined,
                      ),
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox.shrink()
                            : const Icon(Icons.check_circle_outline, size: 22),
                        label: _isSaving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isReceivable
                                    ? 'Simpan Piutang'
                                    : 'Simpan Hutang',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}

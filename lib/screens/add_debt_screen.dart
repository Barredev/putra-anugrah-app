import 'package:flutter/material.dart';
import '../database/database_helper.dart';

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
  bool _isNewContact = false; // true = ketik nama baru
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
    // Load kontak sesuai tipe: RECEIVABLE → CUSTOMER, PAYABLE → SUPPLIER
    final type = _debtType == 'RECEIVABLE' ? 'CUSTOMER' : 'SUPPLIER';
    final contacts =
        await DatabaseHelper.instance.getContacts(type: type);
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
      initialDate:
          DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validasi kontak
    if (!_isNewContact && _selectedContactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pilih kontak atau tambah kontak baru')),
      );
      return;
    }
    if (_isNewContact &&
        _newContactNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama kontak wajib diisi')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      int contactId;

      if (_isNewContact) {
        // Simpan kontak baru dulu
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
        'amount': int.tryParse(_amountController.text) ?? 0,
        'due_date': _dueDate?.toIso8601String().substring(0, 10),
        'note': _noteController.text.trim(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal simpan: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_debtType == 'RECEIVABLE'
            ? 'Tambah Piutang'
            : 'Tambah Hutang'),
      ),
      body: _isLoadingContacts
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Toggle Piutang / Hutang ──────────
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'RECEIVABLE',
                            label: Text('Piutang (pelanggan hutang)'),
                            icon: Icon(Icons.arrow_downward,
                                color: Colors.green),
                          ),
                          ButtonSegment(
                            value: 'PAYABLE',
                            label: Text('Hutang (toko hutang)'),
                            icon: Icon(Icons.arrow_upward,
                                color: Colors.red),
                          ),
                        ],
                        selected: {_debtType},
                        onSelectionChanged: (val) {
                          setState(() {
                            _debtType = val.first;
                            _selectedContactId = null;
                            _isLoadingContacts = true;
                          });
                          _loadContacts();
                        },
                      ),

                      const SizedBox(height: 20),

                      // ── Kontak ───────────────────────────
                      const Text('Kontak',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 8),

                      // Toggle pilih kontak / buat baru
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(
                                  () => _isNewContact = false),
                              icon: const Icon(Icons.person_search,
                                  size: 16),
                              label: const Text('Pilih Kontak'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: !_isNewContact
                                    ? Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.1)
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(
                                  () => _isNewContact = true),
                              icon: const Icon(Icons.person_add,
                                  size: 16),
                              label: const Text('Kontak Baru'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _isNewContact
                                    ? Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.1)
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (!_isNewContact) ...[
                        // Dropdown pilih kontak yang ada
                        DropdownButtonFormField<int>(
                          value: _selectedContactId,
                          decoration: InputDecoration(
                            labelText: _debtType == 'RECEIVABLE'
                                ? 'Pilih Pelanggan'
                                : 'Pilih Supplier',
                            border: const OutlineInputBorder(),
                            prefixIcon:
                                const Icon(Icons.person_outline),
                          ),
                          hint: Text(_contacts.isEmpty
                              ? 'Belum ada kontak — gunakan "Kontak Baru"'
                              : 'Pilih kontak'),
                          items: _contacts.map((c) {
                            final phone =
                                (c['phone'] as String?) ?? '';
                            return DropdownMenuItem<int>(
                              value: c['id'] as int,
                              child: Text(
                                phone.isNotEmpty
                                    ? '${c['name']} ($phone)'
                                    : c['name'] as String,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedContactId = val),
                        ),
                      ] else ...[
                        // Form kontak baru
                        TextFormField(
                          controller: _newContactNameController,
                          decoration: InputDecoration(
                            labelText: _debtType == 'RECEIVABLE'
                                ? 'Nama Pelanggan'
                                : 'Nama Supplier',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.person),
                          ),
                          validator: (v) =>
                              _isNewContact &&
                                      (v == null || v.trim().isEmpty)
                                  ? 'Nama wajib diisi'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newContactPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'No. HP (opsional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ── Total tagihan ────────────────────
                      const Text('Detail Tagihan',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total Tagihan (Rp)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Total tagihan wajib diisi';
                          if (int.tryParse(v) == null)
                            return 'Harus berupa angka bulat';
                          if (int.parse(v) <= 0)
                            return 'Harus lebih dari 0';
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // ── Jatuh tempo ──────────────────────
                      InkWell(
                        onTap: _pickDueDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Jatuh Tempo (opsional)',
                            border: OutlineInputBorder(),
                            prefixIcon:
                                Icon(Icons.calendar_today),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dueDate == null
                                    ? 'Pilih tanggal'
                                    : _dueDate!
                                        .toIso8601String()
                                        .substring(0, 10),
                                style: TextStyle(
                                  color: _dueDate == null
                                      ? Colors.grey
                                      : null,
                                ),
                              ),
                              if (_dueDate != null)
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _dueDate = null),
                                  child: const Icon(Icons.clear,
                                      size: 18, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Catatan ──────────────────────────
                      TextFormField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Catatan (opsional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note),
                          hintText: 'Contoh: Pembelian lemari 2 pintu',
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Tombol simpan ────────────────────
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : Text(
                                  _debtType == 'RECEIVABLE'
                                      ? 'Simpan Piutang'
                                      : 'Simpan Hutang',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
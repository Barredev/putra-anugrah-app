class Debt {
  final int? id;
  final int contactId;
  final String? contactName;
  final String? contactPhone;
  final String debtType; // RECEIVABLE | PAYABLE
  final int amount;
  final int amountPaid;
  final String? dueDate;
  final String status; // OPEN | PARTIAL | PAID
  final String? note;
  final String? createdAt;

  const Debt({
    this.id,
    required this.contactId,
    this.contactName,
    this.contactPhone,
    required this.debtType,
    required this.amount,
    this.amountPaid = 0,
    this.dueDate,
    this.status = 'OPEN',
    this.note,
    this.createdAt,
  });

  int get remaining => amount - amountPaid;

  bool get isPaid => status == 'PAID';

  bool get isOverdue {
    if (dueDate == null || dueDate!.length < 10 || isPaid) return false;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return dueDate!.substring(0, 10).compareTo(today) < 0;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'contact_id': contactId,
        'debt_type': debtType,
        'amount': amount,
        'amount_paid': amountPaid,
        'due_date': dueDate,
        'status': status,
        'note': note,
        'created_at': createdAt,
      };

  factory Debt.fromMap(Map<String, dynamic> map) => Debt(
        id: map['id'] as int?,
        contactId: (map['contact_id'] as num?)?.toInt() ?? 0,
        contactName: map['contact_name'] as String?,
        contactPhone: map['contact_phone'] as String?,
        debtType: (map['debt_type'] as String?) ?? 'RECEIVABLE',
        amount: (map['amount'] as num?)?.toInt() ?? 0,
        amountPaid: (map['amount_paid'] as num?)?.toInt() ?? 0,
        dueDate: map['due_date'] as String?,
        status: (map['status'] as String?) ?? 'OPEN',
        note: map['note'] as String?,
        createdAt: map['created_at'] as String?,
      );
}

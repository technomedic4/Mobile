import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/hospital_models.dart';
import '../providers/hospital_provider.dart';
import '../services/hospital_api_client.dart';

class BillListScreen extends StatelessWidget {
  const BillListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HospitalProvider>();
    final bills = provider.bills;
    return Scaffold(
      appBar: AppBar(title: const Text('Tagihan')),
      body: RefreshIndicator(
        onRefresh: provider.refreshBills,
        child: bills.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Belum ada tagihan untuk akun ini.')),
                  SizedBox(height: 8),
                  Center(
                    child: Text('Tarik layar ke bawah untuk memuat ulang.'),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Daftar tagihan pasien yang terhubung dengan akun Anda.',
                  ),
                  const SizedBox(height: 12),
                  ...bills.map(
                    (bill) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.receipt_long_outlined),
                        ),
                        title: Text(
                          bill.billNumber.isEmpty
                              ? bill.patientName
                              : bill.billNumber,
                        ),
                        subtitle: Text(
                          '${bill.patientName} · ${bill.date}\n'
                          '${_billStatus(bill.status)}',
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          _rupiah(bill.balanceDue),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BillDetailScreen(bill: bill),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class BillDetailScreen extends StatefulWidget {
  const BillDetailScreen({required this.bill, super.key});

  final Bill bill;

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  final _picker = ImagePicker();
  final _referenceController = TextEditingController();
  XFile? _proof;
  String _method = 'Transfer';
  bool _submitting = false;

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HospitalProvider>();
    Bill? refreshedBill;
    for (final item in provider.bills) {
      if (item.id == widget.bill.id) {
        refreshedBill = item;
        break;
      }
    }
    final bill = refreshedBill ?? widget.bill;
    PaymentSubmission? pendingSubmission;
    for (final submission in bill.paymentSubmissions) {
      if (submission.status.toLowerCase() == 'pending') {
        pendingSubmission = submission;
        break;
      }
    }
    final instructions = provider.paymentInstructions;
    final bankName = instructions['bank_name'] as String? ?? '';
    final bankAccount = instructions['bank_account'] as String? ?? '';
    final bankAccountName = instructions['bank_account_name'] as String? ?? '';
    final qrisName = instructions['qris_merchant_name'] as String? ?? '';
    final qrisImage = instructions['qris_image_url'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Rincian tagihan')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.patientName,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('No. tagihan: ${bill.billNumber}'),
                  Text('Tanggal: ${bill.date}'),
                  const SizedBox(height: 12),
                  Chip(label: Text(_billStatus(bill.status))),
                  const Divider(height: 24),
                  ...bill.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.name)),
                          Text(
                            item.quantity > 1
                                ? '${item.quantity} × '
                                      '${_rupiah(item.price / item.quantity)} = '
                                      '${_rupiah(item.price)}'
                                : _rupiah(item.price),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total tagihan',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        _rupiah(bill.totalAmount),
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AmountLine(label: 'Sudah dibayar', amount: bill.amountPaid),
          _AmountLine(label: 'Sisa tagihan', amount: bill.balanceDue),
          if (bill.paymentSubmissions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Riwayat pengajuan pembayaran',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            ...bill.paymentSubmissions.map(
              (submission) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(
                  '${submission.method} · ${_billStatus(submission.status)}',
                ),
                subtitle: Text(
                  '${_rupiah(submission.amount)}'
                  '${submission.reviewNote == null ? '' : '\n${submission.reviewNote}'}',
                ),
              ),
            ),
          ],
          if (pendingSubmission != null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Bukti pembayaran sedang menunggu verifikasi petugas. '
                  'Status tagihan diperbarui setelah disetujui.',
                ),
              ),
            )
          else if (bill.balanceDue > 0 &&
              bill.status.toLowerCase() != 'cancelled')
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Bayar melalui Transfer / QRIS',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _method,
                      decoration: const InputDecoration(
                        labelText: 'Metode pembayaran',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Transfer',
                          child: Text('Transfer bank'),
                        ),
                        DropdownMenuItem(value: 'QRIS', child: Text('QRIS')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _method = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_method == 'Transfer')
                      _PaymentInstructions(
                        title: bankName.isEmpty
                            ? 'Rekening rumah sakit'
                            : bankName,
                        lines: [
                          if (bankAccount.isNotEmpty)
                            'Nomor rekening: $bankAccount',
                          if (bankAccountName.isNotEmpty)
                            'Atas nama: $bankAccountName',
                          if (bankAccount.isEmpty) 'Informasi rekening belum dikonfigurasi. Hubungi petugas keuangan.',
                        ],
                      )
                    else ...[
                      _PaymentInstructions(
                        title: 'QRIS',
                        lines: [
                          if (qrisName.isNotEmpty) 'Merchant: $qrisName',
                          if (qrisImage.isEmpty) 'Kode QRIS belum dikonfigurasi. Hubungi petugas keuangan.',
                        ],
                      ),
                      if (qrisImage.startsWith('https://'))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Image.network(
                            qrisImage,
                            height: 180,
                            errorBuilder: (_, error, stackTrace) =>
                                const Text('Gambar QRIS tidak dapat dimuat.'),
                          ),
                        ),
                    ],
                    TextFormField(
                      controller: _referenceController,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Nomor referensi transaksi (opsional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _pickProof,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(
                        _proof == null
                            ? 'Pilih foto bukti pembayaran'
                            : 'Ganti foto bukti',
                      ),
                    ),
                    if (_proof != null)
                      FutureBuilder<List<int>>(
                        future: _proof!.readAsBytes(),
                        builder: (context, snapshot) => snapshot.hasData
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Image.memory(
                                  Uint8List.fromList(snapshot.data!),
                                  height: 180,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(),
                              ),
                      ),
                    FilledButton.icon(
                      onPressed: _proof == null || _submitting
                          ? null
                          : _submitProof,
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                      label: const Text('Kirim bukti untuk diverifikasi'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tagihan dianggap dibayar setelah petugas memeriksa '
                      'dan menyetujui bukti transaksi.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickProof() async {
    final proof = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (proof != null && mounted) setState(() => _proof = proof);
  }

  Future<void> _submitProof() async {
    final proof = _proof;
    if (proof == null) return;
    setState(() => _submitting = true);
    try {
      await context.read<HospitalProvider>().submitPayment(
        billId: widget.bill.id,
        method: _method,
        proof: proof,
        reference: _referenceController.text,
      );
      if (!mounted) return;
      setState(() => _proof = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bukti pembayaran dikirim untuk verifikasi.'),
        ),
      );
    } on HospitalApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _PaymentInstructions extends StatelessWidget {
  const _PaymentInstructions({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ...lines.map((line) => Text(line)),
      ],
    ),
  );
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(_rupiah(amount)),
      ],
    ),
  );
}

class VisitHistoryScreen extends StatelessWidget {
  const VisitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hospital = context.watch<HospitalProvider>();
    final reports = hospital.reports;
    final visits = hospital.visits;
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat & laporan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Laporan pasien',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (reports.isEmpty)
            const _InfoEmptyCard(
              message: 'Belum ada ringkasan pemeriksaan untuk pasien.',
            )
          else
            ...reports.map(
              (report) => Card(
                child: ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text(report.title),
                  subtitle: Text(
                    '${_patientName(hospital, report.patientId)} · '
                    '${report.date}\n${report.content}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Riwayat kunjungan',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (visits.isEmpty)
            const _InfoEmptyCard(message: 'Belum ada riwayat kunjungan.')
          else
            ...visits.map(
              (visit) => Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.medical_information_outlined),
                  title: Text('${visit.poly} · ${visit.date}'),
                  subtitle: Text(
                    '${_patientName(hospital, visit.patientId)} · ${visit.doctor}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _MedicalLine(label: 'Keluhan', value: visit.complaint),
                    _MedicalLine(label: 'Diagnosis', value: visit.diagnosis),
                    _MedicalLine(label: 'Tindakan', value: visit.treatment),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Ringkasan pemeriksaan memuat diagnosis dan tindakan yang '
            'tersimpan. Catatan internal tenaga medis tidak ditampilkan.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class NotificationListScreen extends StatelessWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hospital = context.watch<HospitalProvider>();
    final notifications = hospital.notifications;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: hospital.unreadNotificationCount == 0
                ? null
                : hospital.markAllNotificationsRead,
            child: const Text('Tandai dibaca'),
          ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(child: Text('Belum ada notifikasi.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: notifications
                  .map(
                    (notification) => Card(
                      color: notification.isRead
                          ? null
                          : const Color(0xFFEAF4F3),
                      child: ListTile(
                        leading: Icon(
                          _notificationIcon(notification.title),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          notification.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${notification.message}\n${notification.date}',
                        ),
                        isThreeLine: true,
                        trailing: notification.isRead
                            ? null
                            : const Icon(Icons.circle, size: 10),
                        onTap: () =>
                            hospital.markNotificationRead(notification.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hospital = context.watch<HospitalProvider>();
    final patients = hospital.patients;
    final ownPatient = patients.isEmpty
        ? null
        : patients
              .where((patient) => patient.relationship == 'Diri sendiri')
              .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil akun')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 38,
            child: Icon(Icons.person_outline, size: 40),
          ),
          const SizedBox(height: 12),
          Text(
            hospital.currentName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(hospital.currentRole, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(hospital.currentEmail),
                ),
                if (ownPatient != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('NIK'),
                    subtitle: Text(ownPatient.nik),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: const Text('Nomor HP'),
                    subtitle: Text(ownPatient.phone),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Perubahan data pasien dikelola melalui layanan rumah sakit.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MedicalLine extends StatelessWidget {
  const _MedicalLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        const Text(': '),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _InfoEmptyCard extends StatelessWidget {
  const _InfoEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
  );
}

String _patientName(HospitalProvider hospital, String patientId) =>
    hospital.patientById(patientId)?.name ?? 'Pasien';

String _rupiah(double amount) {
  final digits = amount.toInt().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
  return 'Rp$grouped';
}

String _billStatus(String status) {
  switch (status) {
    case 'PAID':
      return 'Lunas';
    case 'PARTIALLY_PAID':
      return 'Dibayar sebagian';
    case 'CANCELLED':
      return 'Dibatalkan';
    default:
      return 'Belum dibayar';
  }
}

IconData _notificationIcon(String title) {
  if (title.toLowerCase().contains('tagihan')) {
    return Icons.receipt_long_outlined;
  }
  if (title.toLowerCase().contains('antrean')) {
    return Icons.confirmation_number_outlined;
  }
  if (title.toLowerCase().contains('laporan')) {
    return Icons.assignment_outlined;
  }
  return Icons.notifications_none;
}

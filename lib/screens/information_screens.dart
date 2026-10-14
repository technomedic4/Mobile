import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hospital_models.dart';
import '../providers/hospital_provider.dart';

class BillListScreen extends StatelessWidget {
  const BillListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bills = context.watch<HospitalProvider>().bills;
    return Scaffold(
      appBar: AppBar(title: const Text('Tagihan')),
      body: bills.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Data tagihan belum tersedia di backend web. Tagihan hanya '
                  'akan ditampilkan setelah modul keuangan terhubung.',
                  textAlign: TextAlign.center,
                ),
              ),
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
                      title: Text(bill.patientName),
                      subtitle: Text('${bill.date} · ${_billStatus(bill.status)}'),
                      trailing: Text(
                        _rupiah(bill.totalAmount),
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
    );
  }
}

class BillDetailScreen extends StatelessWidget {
  const BillDetailScreen({required this.bill, super.key});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
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
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
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
                          Text(_rupiah(item.price)),
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
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pembayaran digital belum tersedia di MVP. Silakan gunakan kanal '
            'pembayaran resmi rumah sakit.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
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
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (reports.isEmpty)
            const _InfoEmptyCard(
              message: 'Belum ada laporan yang dibagikan kepada pasien.',
            )
          else
            ...reports.map(
              (report) => Card(
                child: ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text(report.title),
                  subtitle: Text('${_patientName(hospital, report.patientId)} · '
                      '${report.date}\n${report.content}'),
                  isThreeLine: true,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Riwayat kunjungan',
            style: Theme.of(context)
                .textTheme
                .titleLarge
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
            'Yang ditampilkan di sini adalah ringkasan yang dibagikan untuk '
            'pasien. Catatan internal tenaga medis tidak ditampilkan.',
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
                        onTap: () => hospital.markNotificationRead(
                          notification.id,
                        ),
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
        : patients.where((patient) => patient.relationship == 'Diri sendiri')
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
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            hospital.currentRole,
            textAlign: TextAlign.center,
          ),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message),
        ),
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

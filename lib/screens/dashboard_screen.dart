import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hospital_models.dart';
import '../providers/hospital_provider.dart';
import 'appointments_screen.dart';
import 'information_screens.dart';
import 'patients_screen.dart';
import 'teleconsultations_screen.dart';

class PatientPortalScreen extends StatefulWidget {
  const PatientPortalScreen({super.key});

  @override
  State<PatientPortalScreen> createState() => _PatientPortalScreenState();
}

class _PatientPortalScreenState extends State<PatientPortalScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final hospital = context.watch<HospitalProvider>();
    final pages = [
      const _HomeTab(),
      const PatientsScreen(showAppBar: false),
      const AppointmentsScreen(),
      const _MoreTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: _selectedIndex == 1
            ? IconButton(
                tooltip: 'Kembali ke beranda',
                onPressed: () => setState(() => _selectedIndex = 0),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: const Text('SIMRS Sehat'),
        actions: [
          IconButton(
            tooltip: 'Notifikasi',
            onPressed: () => _open(context, const NotificationListScreen()),
            icon: Badge(
              isLabelVisible: hospital.unreadNotificationCount > 0,
              label: Text('${hospital.unreadNotificationCount}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Pasien',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number),
            label: 'Antrean',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Lainnya',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final hospital = context.watch<HospitalProvider>();
    final patient = hospital.patients.firstOrNull;
    final appointment = hospital.appointments
        .where(
          (item) => item.status != 'COMPLETED' && item.status != 'CANCELLED',
        )
        .firstOrNull;
    final bill = hospital.bills
        .where((item) => item.status != 'PAID')
        .firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          'Halo, ${hospital.currentName.split(' ').first}',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Semoga hari Anda sehat.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        _SectionHeading(
          title: 'Antrean saya',
          actionLabel: 'Lihat semua',
          onAction: () => _open(context, const AppointmentsScreen()),
        ),
        if (appointment == null)
          const _EmptyCard(
            icon: Icons.event_available_outlined,
            message: 'Belum ada jadwal berobat.',
          )
        else
          _QueueCard(
            appointment: appointment,
            currentQueue:
                hospital.currentlyServing[appointment.poly] ??
                'Belum dipanggil',
          ),
        const SizedBox(height: 20),
        Text(
          'Layanan',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ServiceButton(
              icon: Icons.add_task,
              label: 'Daftar berobat',
              onTap: () => _open(context, const AppointmentFormScreen()),
            ),
            _ServiceButton(
              icon: Icons.people_alt_outlined,
              label: 'Pasien saya',
              onTap: () => _open(context, const PatientsScreen()),
            ),
            _ServiceButton(
              icon: Icons.receipt_long_outlined,
              label: 'Tagihan',
              onTap: () => _open(context, const BillListScreen()),
            ),
            _ServiceButton(
              icon: Icons.medical_information_outlined,
              label: 'Riwayat & laporan',
              onTap: () => _open(context, const VisitHistoryScreen()),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _SectionHeading(
          title: 'Pasien saya',
          actionLabel: 'Kelola',
          onAction: () => _open(context, const PatientsScreen()),
        ),
        if (patient != null)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(patient.name),
              subtitle: Text(
                '${patient.relationship} · No. RM ${patient.medicalRecordNumber}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  _open(context, PatientDetailScreen(patientId: patient.id)),
            ),
          ),
        const SizedBox(height: 18),
        _SectionHeading(
          title: 'Tagihan terbaru',
          actionLabel: 'Lihat tagihan',
          onAction: () => _open(context, const BillListScreen()),
        ),
        if (bill == null)
          const _EmptyCard(
            icon: Icons.check_circle_outline,
            message: 'Data tagihan belum tersedia dari modul keuangan di portal web.',
          )
        else
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.receipt_long_outlined),
              ),
              title: Text(bill.patientName),
              subtitle: Text('${bill.date} · ${_billStatus(bill.status)}'),
              trailing: Text(
                _rupiah(bill.balanceDue),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () => _open(context, const BillListScreen()),
            ),
          ),
        const SizedBox(height: 18),
        Card(
          color: const Color(0xFFEAF4F3),
          child: ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('Telekonsultasi'),
            subtitle: const Text(
              'Buka ruang chat untuk mengirim pesan kepada dokter.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(context, const TeleconsultationsScreen()),
          ),
        ),
      ],
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.appointment, required this.currentQueue});

  final Appointment appointment;
  final String currentQueue;

  @override
  Widget build(BuildContext context) {
    final statusColor = appointment.status == 'CALLED'
        ? Colors.orange.shade800
        : appointment.status == 'IN_SERVICE'
        ? Colors.blue.shade800
        : Colors.teal.shade800;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nomor antrean',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Chip(
                  avatar: Icon(
                    appointment.status == 'CALLED'
                        ? Icons.notifications_active_outlined
                        : Icons.access_time,
                    size: 18,
                    color: statusColor,
                  ),
                  label: Text(_queueStatus(appointment.status)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              appointment.queueNumber,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text('${appointment.poly} · ${appointment.doctor}'),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.campaign_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Sedang dilayani: $currentQueue')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18),
                const SizedBox(width: 8),
                Text('${appointment.date} · ${appointment.schedule}'),
                const Spacer(),
                Text(
                  _registrationStatus(appointment.registrationStatus),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (appointment.date == _today() &&
                appointment.registrationStatus != 'CHECKED_IN' &&
                appointment.registrationStatus != 'COMPLETED' &&
                appointment.registrationStatus != 'CANCELLED')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Silakan check-in di loket rumah sakit. Check-in dilakukan '
                  'oleh petugas untuk memverifikasi kehadiran Anda.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

class _MoreTab extends StatelessWidget {
  const _MoreTab();

  @override
  Widget build(BuildContext context) {
    final hospital = context.watch<HospitalProvider>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Layanan lainnya',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _MoreTile(
          icon: Icons.history,
          title: 'Riwayat kunjungan & laporan',
          subtitle: 'Informasi pemeriksaan yang dibagikan kepada pasien',
          onTap: () => _open(context, const VisitHistoryScreen()),
        ),
        _MoreTile(
          icon: Icons.chat_outlined,
          title: 'Telekonsultasi',
          subtitle: 'Kirim pesan dan baca balasan dokter',
          onTap: () => _open(context, const TeleconsultationsScreen()),
        ),
        _MoreTile(
          icon: Icons.receipt_long_outlined,
          title: 'Tagihan',
          subtitle: 'Lihat rincian dan status pembayaran',
          onTap: () => _open(context, const BillListScreen()),
        ),
        _MoreTile(
          icon: Icons.notifications_none,
          title: 'Notifikasi',
          subtitle: '${hospital.unreadNotificationCount} belum dibaca',
          onTap: () => _open(context, const NotificationListScreen()),
        ),
        _MoreTile(
          icon: Icons.person_outline,
          title: 'Profil akun',
          subtitle: '${hospital.currentName} · ${hospital.currentRole}',
          onTap: () => _open(context, const ProfileScreen()),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Keluar dari akun?'),
                content: const Text('Anda akan kembali ke halaman masuk.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Keluar'),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              context.read<HospitalProvider>().logout();
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Keluar'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Informasi pasien dan pendaftaran berasal dari server rumah sakit.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF4F3),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _ServiceButton extends StatelessWidget {
  const _ServiceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            child: Column(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(label, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

void _open(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

String _queueStatus(String status) {
  switch (status) {
    case 'CALLED':
      return 'Dipanggil';
    case 'IN_SERVICE':
      return 'Sedang dilayani';
    case 'COMPLETED':
      return 'Selesai';
    case 'CANCELLED':
      return 'Dibatalkan';
    default:
      return 'Menunggu';
  }
}

String _registrationStatus(String status) {
  switch (status) {
    case 'PENDING':
      return 'Menunggu konfirmasi';
    case 'CONFIRMED':
      return 'Terkonfirmasi';
    case 'CHECKED_IN':
      return 'Sudah check-in';
    case 'IN_SERVICE':
      return 'Dalam pemeriksaan';
    case 'COMPLETED':
      return 'Selesai';
    case 'CANCELLED':
      return 'Dibatalkan';
    default:
      return 'Terdaftar';
  }
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

String _rupiah(double amount) {
  final digits = amount.toInt().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
  return 'Rp$grouped';
}

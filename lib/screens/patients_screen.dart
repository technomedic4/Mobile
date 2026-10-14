import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hospital_provider.dart';
import '../services/hospital_api_client.dart';
import 'information_screens.dart';

class PatientsScreen extends StatelessWidget {
  const PatientsScreen({this.showAppBar = true, super.key});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final hospital = context.watch<HospitalProvider>();
    final patients = hospital.patients;
    final accessRequests = hospital.pendingAccessRequests;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: showAppBar ? AppBar(title: const Text('Pasien saya')) : null,
      body: patients.isEmpty
          ? const Center(child: Text('Belum ada pasien terhubung.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              children: [
                ...accessRequests.map(
                  (request) => Card(
                    color: const Color(0xFFFFF4DD),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Persetujuan akses keluarga diperlukan',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${request.patientName} mengajukan akses sebagai '
                            '${request.relationship}. Setujui hanya jika Anda '
                            'mengenali pemohon dan mengizinkan akses.',
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _decideAccess(
                                  context,
                                  request.id,
                                  approve: true,
                                ),
                                child: const Text('Setujui akses'),
                              ),
                              TextButton(
                                onPressed: () => _decideAccess(
                                  context,
                                  request.id,
                                  approve: false,
                                ),
                                child: const Text('Tolak'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Text(
                  'Pasien saya',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Anda hanya dapat melihat pasien yang terhubung ke akun ini.',
                ),
                const SizedBox(height: 12),
                ...patients.map(
                  (patient) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          patient.name.isEmpty
                              ? '?'
                              : patient.name.characters.first.toUpperCase(),
                        ),
                      ),
                      title: Text(patient.name),
                      subtitle: Text(
                        '${patient.relationship} · RM ${patient.medicalRecordNumber}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PatientDetailScreen(patientId: patient.id),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'patients-add-fab',
        onPressed: () => _showAddPatient(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Tambah pasien'),
      ),
    );
  }

  Future<void> _showAddPatient(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddPatientDialog(),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permintaan dikirim. Pasien akan muncul setelah verifikasi '
            'rumah sakit dan persetujuan pasien.',
          ),
        ),
      );
    }
  }

  Future<void> _decideAccess(
    BuildContext context,
    String requestId, {
    required bool approve,
  }) async {
    try {
      await context.read<HospitalProvider>().decidePatientAccess(
            requestId,
            approve: approve,
          );
    } on HospitalApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Akses pasien telah disetujui.'
                : 'Permintaan akses pasien ditolak.',
          ),
        ),
      );
    }
  }
}

class PatientDetailScreen extends StatelessWidget {
  const PatientDetailScreen({required this.patientId, super.key});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final hospital = context.watch<HospitalProvider>();
    final patient = hospital.patientById(patientId);

    if (patient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail pasien')),
        body: const Center(child: Text('Pasien tidak ditemukan.')),
      );
    }

    final visits = hospital.visitsForPatient(patientId);
    final reports = hospital.reportsForPatient(patientId);
    final appointments = hospital.appointmentsForPatient(patientId);
    final bills = hospital.billsForPatient(patientId);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail pasien')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        child: Icon(Icons.person_outline, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient.name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(patient.relationship),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  _DetailLine(
                    label: 'No. rekam medis',
                    value: patient.medicalRecordNumber,
                  ),
                  _DetailLine(label: 'NIK', value: patient.nik),
                  _DetailLine(label: 'Tanggal lahir', value: patient.birthDate),
                  _DetailLine(label: 'Jenis kelamin', value: patient.gender),
                  _DetailLine(label: 'Nomor HP', value: patient.phone),
                  _DetailLine(label: 'Alamat', value: patient.address),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Pendaftaran & antrean',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (appointments.isEmpty)
            const _PatientEmptyCard(message: 'Belum ada pendaftaran.')
          else
            ...appointments.map(
              (appointment) => Card(
                child: ListTile(
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: Text(
                    '${appointment.queueNumber} · ${appointment.poly}',
                  ),
                  subtitle: Text(
                    '${appointment.date} ${appointment.schedule} · '
                    '${_statusName(appointment.status)}',
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            'Laporan untuk pasien',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (reports.isEmpty)
            const _PatientEmptyCard(
              message: 'Belum ada laporan yang dibagikan untuk pasien ini.',
            )
          else
            ...reports.map(
              (report) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(report.date),
                      const SizedBox(height: 8),
                      Text(report.content),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            'Riwayat kunjungan',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (visits.isEmpty)
            const _PatientEmptyCard(message: 'Belum ada riwayat kunjungan.')
          else
            ...visits.map(
              (visit) => Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.medical_information_outlined),
                  title: Text('${visit.poly} · ${visit.date}'),
                  subtitle: Text(visit.doctor),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _DetailLine(label: 'Keluhan', value: visit.complaint),
                    _DetailLine(label: 'Diagnosis', value: visit.diagnosis),
                    _DetailLine(label: 'Tindakan', value: visit.treatment),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            'Tagihan',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (bills.isEmpty)
            const _PatientEmptyCard(message: 'Belum ada tagihan.')
          else
            ...bills.map(
              (bill) => Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(_formatRupiah(bill.totalAmount)),
                  subtitle: Text('${bill.date} · ${_statusName(bill.status)}'),
                  trailing: const Icon(Icons.chevron_right),
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

class _AddPatientDialog extends StatefulWidget {
  const _AddPatientDialog();

  @override
  State<_AddPatientDialog> createState() => _AddPatientDialogState();
}

class _AddPatientDialogState extends State<_AddPatientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nik = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  String _birthDate = '';
  String _gender = 'Perempuan';
  String _relationship = 'Ibu';
  bool _consentGiven = false;

  @override
  void dispose() {
    _name.dispose();
    _nik.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah pasien keluarga'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _textField(_name, 'Nama lengkap'),
                _textField(
                  _nik,
                  'NIK',
                  keyboardType: TextInputType.number,
                  validator: (value) => (value?.trim().length ?? 0) != 16
                      ? 'NIK harus terdiri dari 16 digit.'
                      : null,
                ),
                _textField(
                  _phone,
                  'Nomor HP',
                  keyboardType: TextInputType.phone,
                ),
                _textField(_address, 'Alamat'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Jenis kelamin',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Perempuan',
                      child: Text('Perempuan'),
                    ),
                    DropdownMenuItem(
                      value: 'Laki-laki',
                      child: Text('Laki-laki'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _gender = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _relationship,
                  decoration: const InputDecoration(
                    labelText: 'Hubungan keluarga',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Ibu', child: Text('Ibu')),
                    DropdownMenuItem(value: 'Ayah', child: Text('Ayah')),
                    DropdownMenuItem(value: 'Anak', child: Text('Anak')),
                    DropdownMenuItem(
                      value: 'Suami',
                      child: Text('Suami'),
                    ),
                    DropdownMenuItem(value: 'Istri', child: Text('Istri')),
                    DropdownMenuItem(
                      value: 'Saudara',
                      child: Text('Saudara'),
                    ),
                    DropdownMenuItem(value: 'Wali', child: Text('Wali')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _relationship = value);
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _selectBirthDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _birthDate.isEmpty
                        ? 'Pilih tanggal lahir'
                        : 'Tanggal lahir: $_birthDate',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _consentGiven,
                  onChanged: (value) =>
                      setState(() => _consentGiven = value ?? false),
                  title: const Text(
                    'Saya memiliki izin pasien untuk menghubungkan dan melihat '
                    'informasinya.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const Text(
                  'Permintaan akan diverifikasi petugas. Jika pasien memiliki '
                  'akun, pasien juga harus menyetujui akses sebelum datanya '
                  'dibagikan.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }

  Future<void> _selectBirthDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() => _birthDate = _formatDate(selected));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal lahir wajib diisi.')),
      );
      return;
    }
    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Persetujuan akses pasien harus dikonfirmasi.'),
        ),
      );
      return;
    }
    try {
      await context.read<HospitalProvider>().addPatient(
            nik: _nik.text,
            name: _name.text,
            birthDate: _birthDate,
            gender: _gender,
            address: _address.text,
            phone: _phone.text,
            relationship: _relationship,
          );
    } on HospitalApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator:
            validator ??
            (value) => (value?.trim().isEmpty ?? true)
                ? 'Bagian ini wajib diisi.'
                : null,
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          const Text(': '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PatientEmptyCard extends StatelessWidget {
  const _PatientEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
  );
}

String _formatRupiah(double amount) =>
    'Rp${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')}';

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _statusName(String status) {
  switch (status) {
    case 'WAITING':
      return 'Menunggu';
    case 'CALLED':
      return 'Dipanggil';
    case 'IN_SERVICE':
      return 'Sedang dilayani';
    case 'COMPLETED':
    case 'PAID':
      return 'Selesai';
    case 'PARTIALLY_PAID':
      return 'Dibayar sebagian';
    case 'CANCELLED':
      return 'Dibatalkan';
    default:
      return status;
  }
}

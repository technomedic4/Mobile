import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hospital_models.dart';
import '../providers/hospital_provider.dart';
import '../services/hospital_api_client.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appointments = context.watch<HospitalProvider>().appointments;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => context.read<HospitalProvider>().refreshPortal(),
        child: appointments.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Belum ada pendaftaran berobat.')),
                  SizedBox(height: 12),
                  Center(
                    child: Text('Tarik layar ke bawah untuk memperbarui.'),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                children: [
                  Text(
                    'Pendaftaran & antrean',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tarik ke bawah untuk melihat status terbaru dari server rumah sakit.',
                  ),
                  const SizedBox(height: 12),
                  ...appointments.map(
                    (appointment) => _AppointmentCard(appointment: appointment),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'appointments-add-fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AppointmentFormScreen(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Daftar berobat'),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final hospital = context.watch<HospitalProvider>();
    final currentQueue =
        hospital.currentlyServing[appointment.poly] ?? 'Belum dipanggil';
    final isActive =
        appointment.status != 'COMPLETED' && appointment.status != 'CANCELLED';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    appointment.patientName,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_queueStatus(appointment.status)),
                ),
              ],
            ),
            Text('${appointment.poly} · ${appointment.doctor}'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.queueNumber,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text('Sedang dilayani: $currentQueue'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AppointmentLine(
              icon: Icons.calendar_today_outlined,
              text: '${appointment.date} · ${appointment.schedule}',
            ),
            _AppointmentLine(
              icon: Icons.how_to_reg_outlined,
              text: _registrationStatus(appointment.registrationStatus),
            ),
            if (appointment.complaint.isNotEmpty)
              _AppointmentLine(
                icon: Icons.notes_outlined,
                text: appointment.complaint,
              ),
            if (appointment.registrationStatus == 'PENDING' ||
                appointment.registrationStatus == 'CONFIRMED')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cancel(context, appointment),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Batalkan pendaftaran'),
                ),
              ),
            if (isActive && appointment.status == 'CALLED')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Silakan menuju ruang pemeriksaan.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan pendaftaran?'),
        content: Text(
          'Pendaftaran ${appointment.queueNumber} akan dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<HospitalProvider>().cancelAppointment(appointment.id);
    } on HospitalApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pendaftaran berhasil dibatalkan.')),
      );
    }
  }
}

class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({super.key});

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _complaintController = TextEditingController();
  String? _patientId;
  String _date = _today();
  String? _department;
  String? _scheduleId;
  String _consultationType = 'In-Person';
  late Future<List<DoctorSchedule>> _schedulesFuture;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _schedulesFuture = context.read<HospitalProvider>().schedulesForDate(_date);
  }

  @override
  void dispose() {
    _complaintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patients = context.watch<HospitalProvider>().patients;
    _patientId ??= patients.isEmpty ? null : patients.first.id;
    if (_patientId != null && !patients.any((item) => item.id == _patientId)) {
      _patientId = patients.isEmpty ? null : patients.first.id;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar berobat')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Buat pendaftaran',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih pasien, layanan, dokter, dan jadwal. Nomor antrean '
                'dibuat setelah pendaftaran dikonfirmasi.',
              ),
              const SizedBox(height: 22),
              if (patients.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Tambahkan data pasien terlebih dahulu.'),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _patientId,
                  decoration: const InputDecoration(
                    labelText: 'Pasien',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  items: patients
                      .map(
                        (patient) => DropdownMenuItem(
                          value: patient.id,
                          child: Text(
                            '${patient.name} · ${patient.relationship}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _patientId = value),
                  validator: (value) => value == null ? 'Pilih pasien.' : null,
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _consultationType,
                decoration: const InputDecoration(
                  labelText: 'Jenis layanan',
                  prefixIcon: Icon(Icons.medical_services_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'In-Person',
                    child: Text('Kunjungan langsung'),
                  ),
                  DropdownMenuItem(
                    value: 'Teleconsultation',
                    child: Text('Telekonsultasi via chat'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _consultationType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<DoctorSchedule>>(
                future: _schedulesFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      'Jadwal gagal dimuat: ${snapshot.error}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final schedules = snapshot.data!;
                  final departments = schedules
                      .map((schedule) => schedule.department)
                      .toSet()
                      .toList();
                  final selectedDepartment = departments.contains(_department)
                      ? _department
                      : departments.cast<String?>().firstWhere(
                          (department) =>
                              department?.toLowerCase() == 'poli umum' ||
                              department?.toLowerCase() == 'umum',
                          orElse: () => null,
                        );
                  if (_department != selectedDepartment) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _department = selectedDepartment;
                          _scheduleId = null;
                        });
                      }
                    });
                  }
                  final departmentSchedules = selectedDepartment == null
                      ? <DoctorSchedule>[]
                      : schedules
                            .where(
                              (schedule) =>
                                  schedule.department == selectedDepartment,
                            )
                            .toList();
                  if (departments.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Tidak ada jadwal dengan kuota tersedia pada tanggal ini.',
                        ),
                      ),
                    );
                  }
                  final selectedScheduleId =
                      departmentSchedules.any(
                        (schedule) => schedule.id == _scheduleId,
                      )
                      ? _scheduleId
                      : departmentSchedules.firstOrNull?.id;
                  if (_scheduleId != selectedScheduleId) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _scheduleId = selectedScheduleId);
                      }
                    });
                  }
                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey('department-$_date'),
                        initialValue: selectedDepartment,
                        decoration: const InputDecoration(
                          labelText: 'Poli',
                          prefixIcon: Icon(Icons.local_hospital_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: departments
                            .map(
                              (department) => DropdownMenuItem(
                                value: department,
                                child: Text(department),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _department = value;
                            _scheduleId = null;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Pilih poli.' : null,
                      ),
                      const SizedBox(height: 16),
                      if (departmentSchedules.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Tidak ada jadwal dokter dengan kuota tersedia '
                            'untuk poli ini pada tanggal yang dipilih.',
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: ValueKey('schedule-$selectedDepartment-$_date'),
                          isExpanded: true,
                          initialValue: selectedScheduleId,
                          decoration: const InputDecoration(
                            labelText: 'Dokter dan jadwal tersedia',
                            prefixIcon: Icon(Icons.schedule_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: departmentSchedules
                              .map(
                                (schedule) => DropdownMenuItem(
                                  value: schedule.id,
                                  child: Text(
                                    '${schedule.doctor} · ${schedule.startTime} '
                                    '(${schedule.remainingQuota} slot)',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _scheduleId = value),
                          validator: (value) =>
                              value == null ? 'Pilih jadwal dokter.' : null,
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('Tanggal kunjungan: $_date'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _complaintController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Keluhan awal',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Tuliskan keluhan singkat.'
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: patients.isEmpty || _submitting
                    ? null
                    : _confirmBooking,
                icon: const Icon(Icons.check_circle_outline),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Konfirmasi pendaftaran di server'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pendaftaran menggunakan jadwal dan kuota server rumah sakit '
                'yang sama dengan portal web.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();
    final initialDate = DateTime.tryParse(_date) ?? today;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 30)),
    );
    if (selected != null && mounted) {
      final date = _formatDate(selected);
      setState(() {
        _date = date;
        _scheduleId = null;
        _schedulesFuture = context.read<HospitalProvider>().schedulesForDate(
          date,
        );
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (!_formKey.currentState!.validate() ||
        _patientId == null ||
        _scheduleId == null) {
      return;
    }
    final hospital = context.read<HospitalProvider>();
    final patient = hospital.patientById(_patientId!);
    final schedules = await _schedulesFuture;
    if (!mounted) return;
    final schedule = schedules
        .where((item) => item.id == _scheduleId)
        .firstOrNull;
    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pasien yang dipilih tidak ditemukan.')),
      );
      return;
    }
    if (schedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Jadwal tidak tersedia. Muat ulang jadwal terlebih dahulu.',
          ),
        ),
      );
      return;
    }
    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi pendaftaran'),
        content: Text(
          'Pasien: ${patient.name}\n'
          'Layanan: ${schedule.department}\n'
          'Jenis konsultasi: ${_consultationType == 'Teleconsultation' ? 'Telekonsultasi' : 'Kunjungan langsung'}\n'
          'Dokter: ${schedule.doctor}\n'
          'Jadwal: $_date pukul ${schedule.startTime}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Periksa lagi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
    if (shouldConfirm != true || !mounted) return;
    setState(() => _submitting = true);
    late final Appointment appointment;
    try {
      appointment = await hospital.createAppointment(
        patientId: _patientId!,
        scheduleId: schedule.id,
        date: _date,
        complaint: _complaintController.text,
        consultationType: _consultationType,
      );
    } on HospitalApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
        setState(() => _submitting = false);
      }
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_outline,
          color: Color(0xFF087F8C),
          size: 42,
        ),
        title: const Text('Pendaftaran berhasil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appointment.queueNumber,
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text('${appointment.poly} · ${appointment.doctor}'),
            Text('${appointment.date} · ${appointment.schedule}'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }
}

class _AppointmentLine extends StatelessWidget {
  const _AppointmentLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

String _today() {
  final now = DateTime.now();
  return _formatDate(now);
}

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _queueStatus(String status) {
  switch (status) {
    case 'CALLED':
      return 'Dipanggil';
    case 'IN_SERVICE':
      return 'Sedang dilayani';
    case 'COMPLETED':
      return 'Selesai';
    case 'SKIPPED':
      return 'Dilewati';
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
      return 'Terkonfirmasi';
  }
}

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/hospital_models.dart';
import '../services/hospital_api_client.dart';

class HospitalProvider extends ChangeNotifier {
  HospitalProvider({HospitalApiClient? api})
    : _api =
          api ??
          HospitalApiClient(baseUrl: HospitalApiClient.configuredBaseUrl);

  final HospitalApiClient _api;
  final List<Patient> _patients = [];
  final List<Appointment> _appointments = [];
  final List<Teleconsultation> _teleconsultations = [];
  final List<MedicalVisit> _visits = [];
  final List<PatientReport> _reports = [];
  final List<Bill> _bills = [];
  final List<HospitalNotification> _notifications = [];
  final List<PatientAccessRequest> _pendingAccessRequests = [];
  Map<String, String> _currentlyServing = {};
  String? _currentEmail;
  String? _currentName;
  String? _currentUserId;
  Map<String, dynamic> _paymentInstructions = {};
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  bool get isLoggedIn => _currentEmail != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  String get currentEmail => _currentEmail ?? '';
  String get currentName => _currentName ?? 'Pasien';
  String get currentRole => 'Pasien / Keluarga';
  List<Patient> get patients => List.unmodifiable(_patients);
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  List<Teleconsultation> get teleconsultations =>
      List.unmodifiable(_teleconsultations);
  List<MedicalVisit> get visits => List.unmodifiable(_visits);
  List<PatientReport> get reports => List.unmodifiable(_reports);
  List<Bill> get bills => List.unmodifiable(_bills);
  Map<String, dynamic> get paymentInstructions =>
      Map.unmodifiable(_paymentInstructions);
  List<HospitalNotification> get notifications =>
      List.unmodifiable(_notifications);
  List<PatientAccessRequest> get pendingAccessRequests =>
      List.unmodifiable(_pendingAccessRequests);
  int get unreadNotificationCount =>
      notifications.where((notification) => !notification.isRead).length;
  Map<String, String> get currentlyServing =>
      Map.unmodifiable(_currentlyServing);

  Future<void> initialize() async {
    try {
      final token = await _api.readToken();
      if (token != null && token.isNotEmpty) {
        try {
          await refreshPortal();
        } on HospitalApiException catch (error) {
          if (error.statusCode == 401 || error.statusCode == 403) {
            await _api.clearToken();
            _clearPortal();
          }
          _errorMessage = error.message;
        }
      }
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<String?> login(String email, String password) async {
    _setLoading(true);
    try {
      final session = await _api.post(
        '/auth/login',
        authenticated: false,
        body: {
          'email': email.trim(),
          'password': password,
          'device_name': 'SIMRS Sehat',
        },
      );
      final data = _unwrapData(session);
      final token = data['token'] ?? data['access_token'];
      if (token is! String || token.isEmpty) {
        throw const HospitalApiException(
          'Server tidak mengirim token akses yang valid.',
        );
      }
      await _api.saveToken(token);
      await refreshPortal();
      return null;
    } on HospitalApiException catch (error) {
      await _api.clearToken();
      _clearPortal();
      return error.message;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> registerAccount({
    required String name,
    required String nik,
    required String phone,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String birthDate,
    required String gender,
    required String address,
  }) async {
    _setLoading(true);
    try {
      final response = await _api.post(
        '/auth/register',
        authenticated: false,
        body: {
          'name': name.trim(),
          'nik': nik.trim(),
          'phone': phone.trim(),
          'email': email.trim(),
          'password': password,
          'password_confirmation': passwordConfirmation,
          'birth_date': birthDate,
          'gender': gender,
          'address': address.trim(),
          'device_name': 'SIMRS Sehat',
        },
      );
      final data = _unwrapData(response);
      final token = data['token'] ?? data['access_token'];
      if (token is! String || token.isEmpty) {
        throw const HospitalApiException(
          'Server tidak mengirim token akses yang valid.',
        );
      }
      await _api.saveToken(token);
      await refreshPortal();
      return null;
    } on HospitalApiException catch (error) {
      await _api.clearToken();
      _clearPortal();
      return error.message;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshPortal() async {
    final user = _unwrapData(await _api.get('/me'));
    final patientData = _asList((await _api.get('/patients'))['data']);
    final appointmentPage = _asMap((await _api.get('/appointments'))['data']);
    final appointmentData = _asList(appointmentPage['data']);
    final teleconsultationData = await _fetchAllPages('/teleconsultations');
    final billData = await _fetchAllPages('/bills');
    final patients = patientData.map(_patientFromJson).toList();
    final recordPages = await Future.wait(patients.map(_fetchMedicalRecords));
    final records = recordPages.expand((page) => page).toList();
    final visitData = records
        .where((record) => record['record_type'] == 'consultation')
        .toList();
    final reportData = visitData.map(_consultationReportFromRecord).toList();

    _currentEmail = user['email'] as String? ?? '';
    _currentUserId = user['id']?.toString();
    _patients
      ..clear()
      ..addAll(patients);
    _currentName =
        _patients
            .where((patient) => patient.relationship == 'Diri sendiri')
            .firstOrNull
            ?.name ??
        _patients.firstOrNull?.name ??
        'Pasien';
    _appointments
      ..clear()
      ..addAll(appointmentData.map(_appointmentFromJson));
    _teleconsultations
      ..clear()
      ..addAll(
        teleconsultationData.map(
          (item) => Teleconsultation(_appointmentFromJson(item)),
        ),
      );
    _visits
      ..clear()
      ..addAll(records.map(_visitFromMedicalRecord));
    _reports
      ..clear()
      ..addAll(reportData.map(_reportFromJson));
    _bills
      ..clear()
      ..addAll(billData.map(_billFromJson));
    _notifications.clear();
    _pendingAccessRequests.clear();
    _currentlyServing = {};
    _errorMessage = null;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _fetchAllPages(String path) async {
    final results = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;
    do {
      final response = await _api.get('$path?per_page=100&page=$page');
      if (path == '/bills') {
        _paymentInstructions = _asMap(
          response['payment_instructions'] ?? const {},
        );
      }
      final data = _unwrapData(response);
      final paginator = data['data'];
      if (paginator is List) {
        return _asList(paginator);
      }
      final pageData = _asMap(paginator);
      results.addAll(_asList(pageData['data']));
      page = (pageData['current_page'] as num?)?.toInt() ?? page;
      lastPage = (pageData['last_page'] as num?)?.toInt() ?? page;
      page++;
    } while (page <= lastPage);
    return results;
  }

  Future<void> refreshBills() async {
    final billData = await _fetchAllPages('/bills');
    _bills
      ..clear()
      ..addAll(billData.map(_billFromJson));
    notifyListeners();
  }

  Future<void> submitPayment({
    required String billId,
    required String method,
    required XFile proof,
    String? reference,
  }) async {
    await _api.postMultipart(
      '/bills/$billId/payment-submissions',
      fileField: 'proof',
      fileBytes: await proof.readAsBytes(),
      fileName: proof.name,
      fields: {
        'payment_method': method,
        if (reference != null && reference.trim().isNotEmpty)
          'reference': reference.trim(),
      },
    );
    await refreshBills();
  }

  Future<List<TeleconsultationMessage>> loadTeleconsultationMessages(
    String appointmentId,
  ) async {
    final messages = await _fetchConversationMessages(appointmentId);
    return messages.map((message) {
      final sentAt = DateTime.tryParse(message['created_at'] as String? ?? '');
      return TeleconsultationMessage(
        id: message['id'].toString(),
        senderName: message['sender_name'] as String? ?? 'Pengguna',
        senderRole: message['sender_role'] as String? ?? '',
        message: message['message'] as String? ?? '',
        sentAt: sentAt,
        isMine: message['sender_user_id'].toString() == _currentUserId,
      );
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchConversationMessages(
    String appointmentId,
  ) async {
    final messages = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;
    do {
      final response = _unwrapData(
        await _api.get(
          '/teleconsultations/$appointmentId/messages?per_page=100&page=$page',
        ),
      );
      final messagePage = _asMap(response['messages']);
      messages.addAll(_asList(messagePage['data']));
      page = (messagePage['current_page'] as num?)?.toInt() ?? page;
      lastPage = (messagePage['last_page'] as num?)?.toInt() ?? page;
      page++;
    } while (page <= lastPage);
    return messages;
  }

  Future<bool> canSendTeleconsultationMessage(String appointmentId) async {
    final data = _unwrapData(
      await _api.get(
        '/teleconsultations/$appointmentId/messages?per_page=1',
      ),
    );
    return data['can_send_messages'] as bool? ?? false;
  }

  Future<void> sendTeleconsultationMessage(
    String appointmentId,
    String message,
  ) async {
    await _api.post(
      '/teleconsultations/$appointmentId/messages',
      body: {'message': message.trim()},
    );
  }

  Future<List<Map<String, dynamic>>> _fetchMedicalRecords(
    Patient patient,
  ) async {
    final records = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;
    do {
      final response = _unwrapData(
        await _api.get(
          '/patients/${patient.id}/medical-records?per_page=100&page=$page',
        ),
      );
      final pageData = _asMap(response['records']);
      records.addAll(
        _asList(pageData['data'])
            .map((record) => {...record, 'patient_id': patient.id}),
      );
      page = (pageData['current_page'] as num?)?.toInt() ?? page;
      lastPage = (pageData['last_page'] as num?)?.toInt() ?? page;
      page++;
    } while (page <= lastPage);
    return records;
  }

  Future<List<DoctorSchedule>> schedulesForDate(String date) async {
    final response = await _api.get('/schedules?date=$date');
    final data = _asMap(response['data']);
    return _asList(data['schedules']).map(DoctorSchedule.fromJson).toList();
  }

  Future<bool> addPatient({
    required String nik,
    required String name,
    required String birthDate,
    required String gender,
    required String address,
    required String phone,
    required String relationship,
  }) async {
    throw const HospitalApiException(
      'Pengajuan akses anggota keluarga belum tersedia pada API web.',
    );
  }

  Future<void> decidePatientAccess(
    String requestId, {
    required bool approve,
  }) async {
    throw const HospitalApiException(
      'Persetujuan akses keluarga belum tersedia pada API web.',
    );
  }

  Future<Appointment> createAppointment({
    required String patientId,
    required String scheduleId,
    required String date,
    required String complaint,
    String consultationType = 'In-Person',
  }) async {
    final response = await _api.post(
      '/appointments',
      body: {
        'patient_id': int.parse(patientId),
        'doctor_schedule_id': int.parse(scheduleId),
        'appointment_date': date,
        'initial_complaint': complaint.trim(),
        'consultation_type': consultationType,
      },
    );
    final appointment = _appointmentFromJson(_unwrapData(response));
    await refreshPortal();
    return appointment;
  }

  Future<void> cancelAppointment(String appointmentId) async {
    throw const HospitalApiException(
      'Pembatalan pendaftaran belum tersedia pada API web.',
    );
  }

  Future<void> logout() async {
    HospitalApiException? logoutError;
    try {
      await _api.post('/auth/logout');
    } on HospitalApiException catch (error) {
      logoutError = error;
    } finally {
      await _api.clearToken();
      _clearPortal();
      notifyListeners();
    }
    if (logoutError != null) throw logoutError;
  }

  Patient? patientById(String id) {
    for (final patient in patients) {
      if (patient.id == id) return patient;
    }
    return null;
  }

  List<Appointment> appointmentsForPatient(String patientId) =>
      appointments.where((item) => item.patientId == patientId).toList();

  List<MedicalVisit> visitsForPatient(String patientId) =>
      visits.where((item) => item.patientId == patientId).toList();

  List<PatientReport> reportsForPatient(String patientId) =>
      reports.where((item) => item.patientId == patientId).toList();

  List<Bill> billsForPatient(String patientId) =>
      bills.where((item) => item.patientId == patientId).toList();

  void markNotificationRead(String notificationId) {}

  void markAllNotificationsRead() {}

  void _clearPortal() {
    _currentEmail = null;
    _currentName = null;
    _currentUserId = null;
    _patients.clear();
    _appointments.clear();
    _teleconsultations.clear();
    _visits.clear();
    _reports.clear();
    _bills.clear();
    _notifications.clear();
    _pendingAccessRequests.clear();
    _currentlyServing = {};
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  static Patient _patientFromJson(Map<String, dynamic> json) => Patient(
    id: json['id'].toString(),
    medicalRecordNumber: json['medical_record_number'] as String? ?? '',
    nik: json['nik'] as String? ?? '',
    name: json['name'] as String? ?? json['full_name'] as String? ?? '',
    birthDate: json['birth_date'] as String? ?? '',
    gender: json['gender'] as String? ?? '',
    address: json['address'] as String? ?? '',
    phone: json['phone'] as String? ?? json['phone_number'] as String? ?? '',
    relationship: json['relationship'] as String? ?? 'Diri sendiri',
    isAuthorized: true,
  );

  static Appointment _appointmentFromJson(Map<String, dynamic> json) {
    final status = (json['status'] as String).toUpperCase().replaceAll(
      '-',
      '_',
    );
    final schedule =
        json['schedule'] as String? ??
        (json['start_time'] as String? ?? '08:00');
    return Appointment(
      id: json['id'].toString(),
      patientId: json['patient_id'].toString(),
      patientName:
          json['patient_name'] as String? ?? json['name'] as String? ?? '',
      poly: json['poly'] as String? ?? json['department_name'] as String? ?? '',
      doctor: json['doctor'] as String? ?? json['doctor_name'] as String? ?? '',
      date:
          json['date'] as String? ?? json['appointment_date'] as String? ?? '',
      schedule: schedule.length >= 5 ? schedule.substring(0, 5) : schedule,
      complaint:
          json['complaint'] as String? ??
          json['initial_complaint'] as String? ??
          '',
      queueNumber: json['queue_number'].toString(),
      status: status,
      registrationStatus: status,
      consultationType: json['consultation_type'] as String? ?? 'In-Person',
    );
  }

  static Bill _billFromJson(Map<String, dynamic> json) {
    final rawItems = _asList(json['items']);
    final submissions = json['payment_submissions'] is List
        ? _asList(json['payment_submissions'])
        : <Map<String, dynamic>>[];
    return Bill(
      id: json['id'].toString(),
      patientId: json['patient_id'].toString(),
      patientName: json['patient_name'] as String? ?? '',
      billNumber: json['bill_number'] as String? ?? '',
      date: (json['created_at'] as String? ?? '').split('T').first,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0,
      balanceDue: (json['balance_due'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'Unpaid',
      items: rawItems
          .map(
            (item) => BillItem(
              name: item['item_name'] as String? ?? '',
              quantity: (item['quantity'] as num?)?.toInt() ?? 1,
              price: (item['subtotal'] as num?)?.toDouble() ??
                  (item['unit_price'] as num?)?.toDouble() ??
                  0,
            ),
          )
          .toList(),
      paymentSubmissions: submissions
          .map(
            (submission) => PaymentSubmission(
              id: submission['id'].toString(),
              amount: (submission['amount'] as num?)?.toDouble() ?? 0,
              method: submission['payment_method'] as String? ?? '',
              status: submission['status'] as String? ?? '',
              reviewNote: submission['review_note'] as String?,
            ),
          )
          .toList(),
    );
  }

  static MedicalVisit _visitFromMedicalRecord(Map<String, dynamic> json) {
    final isAdmission = json['record_type'] == 'inpatient_admission';
    final admissionStatus = json['status'] == 'Admitted'
        ? 'Masih dirawat'
        : 'Sudah pulang';
    final occurredAt = json['occurred_at'] as String? ?? '';
    final admissionDetails = [
      if ((json['room_number'] as String? ?? '').isNotEmpty)
        'Kamar ${json['room_number']}',
      if ((json['bed_number'] as String? ?? '').isNotEmpty)
        'Tempat tidur ${json['bed_number']}',
    ].join(' · ');

    return MedicalVisit(
      id: '${json['patient_id']}-${json['record_type']}-${json['id']}',
      patientId: json['patient_id'].toString(),
      date: occurredAt.length >= 10 ? occurredAt.substring(0, 10) : occurredAt,
      poly: isAdmission
          ? 'Rawat Inap'
          : json['department_name'] as String? ?? '',
      doctor: isAdmission ? 'Rawat inap' : json['doctor_name'] as String? ?? '',
      complaint: isAdmission
          ? json['admission_reason'] as String? ?? ''
          : json['initial_complaint'] as String? ?? '',
      diagnosis: isAdmission
          ? admissionStatus
          : json['diagnosis'] as String? ?? '',
      treatment: isAdmission
          ? admissionDetails
          : json['treatment_plan'] as String? ?? '',
    );
  }

  static Map<String, dynamic> _consultationReportFromRecord(
    Map<String, dynamic> record,
  ) => {
    'id': 'report-${record['patient_id']}-${record['id']}',
    'patient_id': record['patient_id'],
    'date': record['occurred_at'] as String? ?? '',
    'title': 'Ringkasan pemeriksaan',
    'content':
        'Diagnosis: ${record['diagnosis'] ?? '-'}\n'
        'Tindakan: ${record['treatment_plan'] ?? '-'}',
  };

  static PatientReport _reportFromJson(Map<String, dynamic> json) =>
      PatientReport(
        id: json['id'].toString(),
        patientId: json['patient_id'].toString(),
        date: json['date'] as String? ?? '',
        title: json['title'] as String? ?? 'Ringkasan pemeriksaan',
        content: json['content'] as String? ?? '',
      );

  static Map<String, dynamic> _unwrapData(Map<String, dynamic> response) {
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : response;
  }

  static List<Map<String, dynamic>> _asList(Object? value) {
    if (value is! List) {
      throw const HospitalApiException('Format data dari server tidak valid.');
    }
    return value.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      throw const HospitalApiException('Format data dari server tidak valid.');
    }
    return Map<String, dynamic>.from(value);
  }
}

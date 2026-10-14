import 'package:flutter/foundation.dart';

import '../models/hospital_models.dart';
import '../services/hospital_api_client.dart';

class HospitalProvider extends ChangeNotifier {
  HospitalProvider({HospitalApiClient? api})
      : _api = api ??
            HospitalApiClient(
              baseUrl: HospitalApiClient.configuredBaseUrl,
            );

  final HospitalApiClient _api;
  final List<Patient> _patients = [];
  final List<Appointment> _appointments = [];
  final List<MedicalVisit> _visits = [];
  final List<PatientReport> _reports = [];
  final List<Bill> _bills = [];
  final List<HospitalNotification> _notifications = [];
  final List<PatientAccessRequest> _pendingAccessRequests = [];
  Map<String, String> _currentlyServing = {};
  String? _currentEmail;
  String? _currentName;
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
  List<MedicalVisit> get visits => List.unmodifiable(_visits);
  List<PatientReport> get reports => List.unmodifiable(_reports);
  List<Bill> get bills => List.unmodifiable(_bills);
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
        body: {'email': email.trim(), 'password': password},
      );
      await _api.saveToken(session['token'] as String);
      await refreshPortal();
      return null;
    } on HospitalApiException catch (error) {
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
      final session = await _api.post(
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
        },
      );
      await _api.saveToken(session['token'] as String);
      await refreshPortal();
      return null;
    } on HospitalApiException catch (error) {
      return error.message;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshPortal() async {
    final portal = await _api.get('/portal');
    final user = _asMap(portal['user']);
    final patientData = _asList(portal['patients']);
    final appointmentData = _asList(portal['appointments']);
    final visitData = _asList(portal['visits']);
    final reportData = _asList(portal['reports']);
    final billData = _asList(portal['bills']);
    final notificationData = _asList(portal['notifications']);
    final accessRequestData = _asList(portal['pending_access_requests']);
    final servingData = _asMap(portal['currently_serving']);

    _currentEmail = user['email'] as String? ?? '';
    _patients
      ..clear()
      ..addAll(patientData.map(_patientFromJson));
    _currentName = _patients
            .where((patient) => patient.relationship == 'Diri sendiri')
            .firstOrNull
            ?.name ??
        'Pasien';
    _appointments
      ..clear()
      ..addAll(appointmentData.map(_appointmentFromJson));
    _visits
      ..clear()
      ..addAll(visitData.map(_visitFromJson));
    _reports
      ..clear()
      ..addAll(reportData.map(_reportFromJson));
    _bills
      ..clear()
      ..addAll(billData.map(_billFromJson));
    _notifications
      ..clear()
      ..addAll(notificationData.map(_notificationFromJson));
    _pendingAccessRequests
      ..clear()
      ..addAll(accessRequestData.map(PatientAccessRequest.fromJson));
    _currentlyServing = servingData.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    _errorMessage = null;
    notifyListeners();
  }

  Future<List<DoctorSchedule>> schedulesForDate(String date) async {
    final response = await _api.get('/schedules?date=$date');
    return _asList(response['data']).map(DoctorSchedule.fromJson).toList();
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
    await _api.post(
      '/patient-access-requests',
      body: {
        'nik': nik.trim(),
        'name': name.trim(),
        'birth_date': birthDate,
        'gender': gender == 'Laki-laki'
            ? 'L'
            : gender == 'Perempuan'
                ? 'P'
                : null,
        'address': address.trim(),
        'phone': phone.trim(),
        'relationship': relationship,
      },
    );
    return true;
  }

  Future<void> decidePatientAccess(
    String requestId, {
    required bool approve,
  }) async {
    await _api.post(
      '/patient-access-requests/$requestId/decision',
      body: {'decision': approve ? 'approve' : 'reject'},
    );
    await refreshPortal();
  }

  Future<Appointment> createAppointment({
    required String patientId,
    required String scheduleId,
    required String date,
    required String complaint,
  }) async {
    final response = await _api.post(
      '/appointments',
      body: {
        'patient_id': int.parse(patientId),
        'doctor_schedule_id': int.parse(scheduleId),
        'appointment_date': date,
        'initial_complaint': complaint.trim(),
      },
    );
    final appointment = _appointmentFromJson(response);
    await refreshPortal();
    return appointment;
  }

  Future<void> cancelAppointment(String appointmentId) async {
    await _api.post('/appointments/$appointmentId/cancel');
    await refreshPortal();
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
    _patients.clear();
    _appointments.clear();
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
        id: json['id'] as String,
        medicalRecordNumber: json['medical_record_number'] as String? ?? '',
        nik: json['nik'] as String? ?? '',
        name: json['name'] as String? ?? '',
        birthDate: json['birth_date'] as String? ?? '',
        gender: json['gender'] as String? ?? '',
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        relationship: json['relationship'] as String? ?? 'Diri sendiri',
        isAuthorized: json['is_authorized'] as bool? ?? false,
      );

  static Appointment _appointmentFromJson(Map<String, dynamic> json) {
    final status = (json['status'] as String).toUpperCase();
    return Appointment(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String,
      poly: json['poly'] as String,
      doctor: json['doctor'] as String,
      date: json['date'] as String,
      schedule: json['schedule'] as String,
      complaint: json['complaint'] as String? ?? '',
      queueNumber: json['queue_number'] as String,
      status: status,
      registrationStatus: status,
    );
  }

  static MedicalVisit _visitFromJson(Map<String, dynamic> json) =>
      MedicalVisit(
        id: json['id'] as String,
        patientId: json['patient_id'] as String,
        date: json['date'] as String,
        poly: json['poly'] as String,
        doctor: json['doctor'] as String,
        complaint: json['complaint'] as String,
        diagnosis: json['diagnosis'] as String,
        treatment: json['treatment'] as String,
      );

  static PatientReport _reportFromJson(Map<String, dynamic> json) =>
      PatientReport(
        id: json['id'] as String,
        patientId: json['patient_id'] as String,
        date: json['date'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
      );

  static Bill _billFromJson(Map<String, dynamic> json) => Bill(
        id: json['id'] as String,
        patientId: json['patient_id'] as String,
        patientName: json['patient_name'] as String,
        totalAmount: (json['total_amount'] as num).toDouble(),
        status: json['status'] as String,
        items: _asList(json['items'])
            .map(
              (item) => BillItem(
                name: item['name'] as String,
                price: (item['price'] as num).toDouble(),
              ),
            )
            .toList(),
        date: json['date'] as String? ?? '',
      );

  static HospitalNotification _notificationFromJson(
    Map<String, dynamic> json,
  ) =>
      HospitalNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        date: json['date'] as String,
        isRead: json['is_read'] as bool? ?? false,
      );

  static List<Map<String, dynamic>> _asList(Object? value) {
    if (value is! List) {
      throw const HospitalApiException('Format data dari server tidak valid.');
    }
    return value
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      throw const HospitalApiException('Format data dari server tidak valid.');
    }
    return Map<String, dynamic>.from(value);
  }
}

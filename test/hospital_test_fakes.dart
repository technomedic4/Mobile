import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sim_kesehatan/providers/hospital_provider.dart';
import 'package:sim_kesehatan/services/hospital_api_client.dart';

class MemoryTokenStore implements AccessTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> delete() async => token = null;
}

class HospitalApiFixture {
  HospitalApiFixture() {
    client = MockClient(_handle);
    provider = HospitalProvider(
      api: HospitalApiClient(
        baseUrl: 'https://hospital.example/api/v1',
        tokenStore: tokenStore,
        client: client,
      ),
    );
  }

  final tokenStore = MemoryTokenStore();
  final requests = <http.Request>[];
  late final MockClient client;
  late final HospitalProvider provider;
  final appointments = <Map<String, Object?>>[];
  final medicalRecords = <Map<String, Object?>>[
    {
      'id': '91',
      'record_type': 'consultation',
      'occurred_at': '2026-10-19',
      'department_name': 'Penyakit Dalam',
      'doctor_name': 'Dr. Ahmad',
      'initial_complaint': 'Demam sejak kemarin',
      'diagnosis': 'Infeksi saluran pernapasan',
      'treatment_plan': 'Istirahat dan minum obat sesuai resep.',
    },
  ];

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;

    if (request.url.path.endsWith('/auth/login') && request.method == 'POST') {
      if (body['password'] != 'correct-password') {
        return _json(422, {'message': 'Email atau password salah.'});
      }
      return _json(200, _session);
    }
    if (request.url.path.endsWith('/auth/register') &&
        request.method == 'POST') {
      return _json(201, _session);
    }
    if (request.url.path.endsWith('/auth/logout')) {
      return _json(200, {'message': 'Anda telah keluar.'});
    }
    if (request.url.path.endsWith('/portal')) {
      return _json(200, {
        'user': {'id': '7', 'email': 'budi@example.test'},
        'patients': [_patient],
        'appointments': appointments,
        'visits': [
          {
            'id': '91',
            'patient_id': '12',
            'date': '2026-10-19',
            'poly': 'Penyakit Dalam',
            'doctor': 'Dr. Ahmad',
            'complaint': 'Demam sejak kemarin',
            'diagnosis': 'Infeksi saluran pernapasan',
            'treatment': 'Istirahat dan minum obat sesuai resep.',
          },
        ],
        'care_updates': [
          {
            'id': '14',
            'patient_id': '12',
            'date': '2026-10-20T08:30:00',
            'condition': 'Membaik',
            'notes': 'Kondisi pasien membaik.',
            'recorded_by': 'Perawat',
            'room_number': '201',
            'bed_number': 'B',
            'temperature_celsius': 36.8,
            'blood_pressure': '120/80',
            'pulse_rate': 80,
            'respiratory_rate': 18,
            'oxygen_saturation': 98,
          },
        ],
        'reports': [
          {
            'id': 'report-91',
            'patient_id': '12',
            'date': '2026-10-19',
            'title': 'Ringkasan pemeriksaan',
            'content': 'Diagnosis: Infeksi saluran pernapasan',
          },
        ],
        'bills': [],
        'notifications': [],
        'currently_serving': {},
        'pending_access_requests': [],
      });
    }
    if (request.url.path.endsWith('/me')) {
      return _json(200, {
        'data': {'id': '7', 'email': 'budi@example.test'},
      });
    }
    if (request.url.path.endsWith('/patients')) {
      return _json(200, {
        'data': [_patient],
      });
    }
    if (request.url.path.endsWith('/teleconsultations')) {
      return _json(200, {
        'data': {'current_page': 1, 'last_page': 1, 'data': []},
      });
    }
    if (request.url.path.endsWith('/bills')) {
      return _json(200, {
        'data': {'current_page': 1, 'last_page': 1, 'data': []},
        'payment_instructions': {
          'bank_name': 'Bank Test',
          'bank_account': '123456',
          'bank_account_name': 'Rumah Sakit',
          'qris_merchant_name': 'Klinik Test',
          'qris_image_url': null,
        },
      });
    }
    if (request.url.path.endsWith('/medical-records')) {
      return _json(200, {
        'data': {
          'patient': {'id': '12', 'full_name': 'Budi Santoso'},
          'records': {
            'current_page': 1,
            'last_page': 1,
            'data': medicalRecords,
          },
        },
      });
    }
    if (request.url.path.endsWith('/appointments') && request.method == 'GET') {
      return _json(200, {
        'data': {'current_page': 1, 'last_page': 1, 'data': appointments},
      });
    }
    if (request.url.path.endsWith('/schedules')) {
      return _json(200, {
        'data': [
          {
            'id': 12,
            'department': 'Kardiologi',
            'doctor': 'Dr. Fauzi',
            'start_time': '08:00',
            'end_time': '12:00',
            'remaining_quota': 5,
          },
          {
            'id': 11,
            'department': 'Poli Umum',
            'doctor': 'Dr. Ahmad',
            'start_time': '09:00',
            'end_time': '12:00',
            'remaining_quota': 4,
          },
        ],
      });
    }
    if (request.url.path.endsWith('/appointments') &&
        request.method == 'POST') {
      final isGeneralPractice = body['doctor_schedule_id'] == 11;
      final created = {
        'id': 33,
        'patient_id': body['patient_id'],
        'patient_name': 'Budi Santoso',
        'poly': isGeneralPractice ? 'Poli Umum' : 'Kardiologi',
        'doctor': isGeneralPractice ? 'Dr. Ahmad' : 'Dr. Fauzi',
        'date': body['appointment_date'],
        'schedule': isGeneralPractice ? '09:00' : '08:00',
        'complaint': body['initial_complaint'],
        'consultation_type': body['consultation_type'] ?? 'In-Person',
        'queue_number': 'A-001',
        'status': 'PENDING',
        'registration_status': 'PENDING',
      };
      appointments.insert(0, created);
      return _json(201, {'data': created});
    }

    return _json(404, {'message': 'Rute pengujian tidak ditemukan.'});
  }

  static const _session = {
    'token': 'mobile-access-token',
    'token_type': 'Bearer',
    'user': {'id': '7', 'email': 'budi@example.test'},
    'patient': {'id': '12', 'name': 'Budi Santoso'},
  };

  static const _patient = {
    'id': '12',
    'medical_record_number': 'RM-00000012',
    'name': 'Budi Santoso',
    'birth_date': '1990-01-01',
    'gender': 'Laki-laki',
    'phone': '081234567890',
    'relationship': 'Diri sendiri',
    'is_authorized': true,
  };

  static http.Response _json(int statusCode, Object body) => http.Response(
    jsonEncode(body),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}

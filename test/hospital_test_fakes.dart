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

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;

    if (request.url.path.endsWith('/auth/login') && request.method == 'POST') {
      if (body['password'] != 'correct-password') {
        return _json(422, {
          'message': 'Email atau password salah.',
          'errors': {
            'email': ['Email atau password salah.'],
          },
        });
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
        'visits': <Object>[],
        'reports': <Object>[],
        'bills': <Object>[],
        'notifications': <Object>[],
        'currently_serving': <String, String>{},
        'pending_access_requests': <Object>[],
      });
    }
    if (request.url.path.endsWith('/schedules')) {
      return _json(200, {
        'data': [
          {
            'id': '11',
            'department': 'Penyakit Dalam',
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
      final created = {
        'id': '33',
        'patient_id': body['patient_id'].toString(),
        'patient_name': 'Budi Santoso',
        'poly': 'Penyakit Dalam',
        'doctor': 'Dr. Ahmad',
        'date': body['appointment_date'],
        'schedule': '09:00',
        'complaint': body['initial_complaint'],
        'queue_number': 'A-001',
        'status': 'PENDING',
        'registration_status': 'PENDING',
      };
      appointments.insert(0, created);
      return _json(201, created);
    }
    if (request.url.path.contains('/appointments/') &&
        request.url.path.endsWith('/cancel')) {
      appointments.first['status'] = 'CANCELLED';
      appointments.first['registration_status'] = 'CANCELLED';
      return _json(200, {'message': 'Pendaftaran berhasil dibatalkan.'});
    }
    if (request.url.path.endsWith('/patient-access-requests')) {
      return _json(202, {'message': 'Menunggu verifikasi.'});
    }

    return _json(404, {'message': 'Rute pengujian tidak ditemukan.'});
  }

  static const _session = {
    'user': {'id': '7', 'email': 'budi@example.test'},
    'patient': {
      'id': '12',
      'medical_record_number': 'RM-00000012',
      'nik': '3174010101900001',
      'name': 'Budi Santoso',
      'birth_date': '1990-01-01',
      'gender': 'Laki-laki',
      'address': 'Jakarta',
      'phone': '081234567890',
      'relationship': 'Diri sendiri',
      'is_authorized': true,
      'owner_account': '',
    },
    'token': '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    'token_type': 'Bearer',
    'expires_at': '2027-01-01T00:00:00+00:00',
  };

  static const _patient = {
    'id': '12',
    'medical_record_number': 'RM-00000012',
    'nik': '3174010101900001',
    'name': 'Budi Santoso',
    'birth_date': '1990-01-01',
    'gender': 'Laki-laki',
    'address': 'Jakarta',
    'phone': '081234567890',
    'relationship': 'Diri sendiri',
    'is_authorized': true,
    'owner_account': '',
  };

  static http.Response _json(int statusCode, Object body) => http.Response(
    jsonEncode(body),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}

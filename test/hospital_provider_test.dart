import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_kesehatan/services/hospital_api_client.dart';

import 'hospital_test_fakes.dart';

void main() {
  group('HospitalProvider shared API', () {
    test(
      'login loads the patient portal from the shared portal endpoint',
      () async {
        final fixture = HospitalApiFixture();

        final error = await fixture.provider.login(
          ' BUDI@example.test ',
          'correct-password',
        );

        expect(error, isNull);
        expect(fixture.tokenStore.token, 'mobile-access-token');
        expect(fixture.provider.currentEmail, 'budi@example.test');
        expect(fixture.provider.patients.single.name, 'Budi Santoso');
        expect(fixture.provider.visits, hasLength(2));
        expect(
          fixture.provider.visits.last.diagnosis,
          'Infeksi saluran pernapasan',
        );
        expect(fixture.provider.visits.first.source, 'nursing');
        expect(fixture.provider.visits.first.doctor, 'Perawat');
        expect(fixture.provider.visits.first.condition, 'Membaik');
        expect(
          fixture.provider.visits.first.vitalSigns,
          contains('Tekanan darah 120/80 mmHg'),
        );
        expect(fixture.provider.reports.single.title, 'Ringkasan pemeriksaan');
        expect(fixture.requests.first.headers['authorization'], isNull);
        expect(fixture.requests[1].url.path, '/api/v1/portal');
        expect(
          fixture.requests.any(
            (request) => request.url.path == '/api/v1/patients',
          ),
          isFalse,
        );
        expect(
          fixture.requests[1].headers['authorization'],
          'Bearer ${fixture.tokenStore.token}',
        );
      },
    );

    test(
      'server validation errors are shown instead of a local demo login',
      () async {
        final fixture = HospitalApiFixture();

        final error = await fixture.provider.login(
          'budi@example.test',
          'wrong-password',
        );

        expect(error, 'Email atau password salah.');
        expect(fixture.provider.isLoggedIn, isFalse);
        expect(fixture.tokenStore.token, isNull);
      },
    );

    test(
      'registration creates an account and signs in with its API token',
      () async {
        final fixture = HospitalApiFixture();

        final error = await fixture.provider.registerAccount(
          name: 'Rina Pratama',
          nik: '3174050505950005',
          phone: '081299990005',
          email: 'rina@example.test',
          password: 'aman1234',
          passwordConfirmation: 'aman1234',
          birthDate: '1995-05-05',
          gender: 'P',
          address: 'Jakarta',
        );

        expect(error, isNull);
        expect(fixture.tokenStore.token, 'mobile-access-token');
        expect(fixture.provider.isLoggedIn, isTrue);
        final request = fixture.requests.first;
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.url.path, '/api/v1/auth/register');
        expect(payload['password_confirmation'], 'aman1234');
        expect(payload['birth_date'], '1995-05-05');
        expect(payload['gender'], 'P');
        expect(payload['device_name'], 'SIMRS Sehat');
      },
    );

    test(
      'booking uses server schedules and refreshes the shared queue',
      () async {
        final fixture = HospitalApiFixture();
        await fixture.provider.login('budi@example.test', 'correct-password');
        final schedules = await fixture.provider.schedulesForDate('2026-11-02');

        final generalPractice = schedules.singleWhere(
          (schedule) => schedule.department == 'Poli Umum',
        );
        expect(generalPractice.doctor, 'Dr. Ahmad');
        expect(generalPractice.remainingQuota, 4);
        final appointment = await fixture.provider.createAppointment(
          patientId: '12',
          scheduleId: generalPractice.id,
          date: '2026-11-02',
          complaint: 'Kontrol',
          consultationType: 'Teleconsultation',
        );

        expect(appointment.queueNumber, 'A-001');
        expect(appointment.poly, 'Poli Umum');
        expect(fixture.provider.appointments.single.status, 'PENDING');
        final booking = fixture.requests
            .where(
              (request) =>
                  request.url.path.endsWith('/appointments') &&
                  request.method == 'POST',
            )
            .single;
        expect(jsonDecode(booking.body)['doctor_schedule_id'], 11);
        expect(
          jsonDecode(booking.body)['consultation_type'],
          'Teleconsultation',
        );
      },
    );

    test('logout revokes local credentials and clears patient data', () async {
      final fixture = HospitalApiFixture();
      await fixture.provider.login('budi@example.test', 'correct-password');

      await fixture.provider.logout();

      expect(fixture.provider.isLoggedIn, isFalse);
      expect(fixture.provider.patients, isEmpty);
      expect(fixture.tokenStore.token, isNull);
    });

    test('missing API configuration fails explicitly', () async {
      final client = HospitalApiClient(
        baseUrl: '',
        tokenStore: MemoryTokenStore(),
      );

      await expectLater(
        client.post(
          '/auth/login',
          authenticated: false,
          body: {'email': 'a@example.test', 'password': 'secret'},
        ),
        throwsA(isA<HospitalApiException>()),
      );
    });

    test('Android debug builds default to the forwarded local API', () {
      final previousTargetPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        expect(
          HospitalApiClient.configuredBaseUrl,
          'http://127.0.0.1:8000/api/v1',
        );
      } finally {
        debugDefaultTargetPlatformOverride = previousTargetPlatform;
      }
    });
  });
}

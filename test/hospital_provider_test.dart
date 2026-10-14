import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_kesehatan/services/hospital_api_client.dart';

import 'hospital_test_fakes.dart';

void main() {
  group('HospitalProvider shared API', () {
    test('login stores the server token and loads only authorized portal data',
        () async {
      final fixture = HospitalApiFixture();

      final error =
          await fixture.provider.login(' BUDI@example.test ', 'correct-password');

      expect(error, isNull);
      expect(fixture.tokenStore.token, hasLength(64));
      expect(fixture.provider.currentEmail, 'budi@example.test');
      expect(fixture.provider.patients.single.name, 'Budi Santoso');
      expect(
        fixture.requests.first.headers['authorization'],
        isNull,
      );
      expect(
        fixture.requests.last.headers['authorization'],
        'Bearer ${fixture.tokenStore.token}',
      );
    });

    test('server validation errors are shown instead of a local demo login',
        () async {
      final fixture = HospitalApiFixture();

      final error =
          await fixture.provider.login('budi@example.test', 'wrong-password');

      expect(error, 'Email atau password salah.');
      expect(fixture.provider.isLoggedIn, isFalse);
      expect(fixture.tokenStore.token, isNull);
    });

    test('registration sends profile data and confirmed password to the API',
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
      final request = fixture.requests.first;
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(request.url.path, '/api/v1/auth/register');
      expect(payload['password_confirmation'], 'aman1234');
      expect(payload['birth_date'], '1995-05-05');
      expect(payload['gender'], 'P');
    });

    test('booking uses server schedules and refreshes the shared queue',
        () async {
      final fixture = HospitalApiFixture();
      await fixture.provider.login('budi@example.test', 'correct-password');
      final schedules =
          await fixture.provider.schedulesForDate('2026-11-02');

      expect(schedules.single.doctor, 'Dr. Ahmad');
      final appointment = await fixture.provider.createAppointment(
        patientId: '12',
        scheduleId: schedules.single.id,
        date: '2026-11-02',
        complaint: 'Kontrol',
      );

      expect(appointment.queueNumber, 'A-001');
      expect(fixture.provider.appointments.single.status, 'PENDING');
      final booking = fixture.requests
          .where((request) => request.url.path.endsWith('/appointments'))
          .single;
      expect(jsonDecode(booking.body)['doctor_schedule_id'], 11);
    });

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
  });
}

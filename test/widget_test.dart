import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sim_kesehatan/main.dart';
import 'package:sim_kesehatan/providers/hospital_provider.dart';

import 'hospital_test_fakes.dart';

void main() {
  Future<void> loginAsPatient(WidgetTester tester) async {
    final fixture = HospitalApiFixture();
    await tester.pumpWidget(
      ChangeNotifierProvider<HospitalProvider>.value(
        value: fixture.provider..initialize(),
        child: const HospitalApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'budi@example.test',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'correct-password',
    );
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
  }

  testWidgets('login displays data returned from the shared web backend', (
    WidgetTester tester,
  ) async {
    await loginAsPatient(tester);

    expect(find.text('Halo, Budi'), findsOneWidget);
    expect(find.text('Pasien saya'), findsWidgets);
    expect(find.text('Belum ada pendaftaran berobat.'), findsNothing);
  });

  testWidgets('patient books against a server schedule and queue', (
    WidgetTester tester,
  ) async {
    await loginAsPatient(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -450));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daftar berobat').first);
    await tester.pumpAndSettle();

    expect(find.text('Buat pendaftaran'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).last,
      'Pemeriksaan rutin',
    );
    await tester.tap(find.text('Konfirmasi pendaftaran di server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konfirmasi'));
    await tester.pumpAndSettle();

    expect(find.text('A-001'), findsOneWidget);
    expect(find.text('Penyakit Dalam · Dr. Ahmad'), findsOneWidget);
  });

  testWidgets('family access requests are shown as pending verification', (
    WidgetTester tester,
  ) async {
    await loginAsPatient(tester);

    await tester.tap(find.text('Pasien').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah pasien'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Ahmad Santoso');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '3174030303150003',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '081200000003');
    await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Sehat No. 3');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pilih tanggal lahir'));
    await tester.tap(find.text('Pilih tanggal lahir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(
      find.textContaining('Permintaan dikirim. Pasien akan muncul'),
      findsOneWidget,
    );
  });
}

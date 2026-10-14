class Patient {
  final String id;
  final String medicalRecordNumber;
  final String nik;
  final String name;
  final String birthDate;
  final String gender;
  final String address;
  final String phone;
  final String relationship;
  final bool isAuthorized;
  final String ownerAccount;

  const Patient({
    required this.id,
    required this.nik,
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.address,
    this.medicalRecordNumber = '',
    this.phone = '',
    this.relationship = 'Diri sendiri',
    this.isAuthorized = true,
    this.ownerAccount = '',
  });
}

class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String poly;
  final String doctor;
  final String date;
  final String schedule;
  final String complaint;
  final String queueNumber;
  final String status;
  final String registrationStatus;

  const Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.poly,
    required this.doctor,
    required this.date,
    required this.queueNumber,
    required this.status,
    this.schedule = '08:00',
    this.complaint = '',
    this.registrationStatus = 'CONFIRMED',
  });
}

class DoctorSchedule {
  final String id;
  final String department;
  final String doctor;
  final String startTime;
  final String endTime;
  final int remainingQuota;

  const DoctorSchedule({
    required this.id,
    required this.department,
    required this.doctor,
    required this.startTime,
    required this.endTime,
    required this.remainingQuota,
  });

  factory DoctorSchedule.fromJson(Map<String, dynamic> json) {
    return DoctorSchedule(
      id: json['id'] as String,
      department: json['department'] as String,
      doctor: json['doctor'] as String,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      remainingQuota: json['remaining_quota'] as int,
    );
  }
}

class PatientAccessRequest {
  final String id;
  final String patientName;
  final String relationship;

  const PatientAccessRequest({
    required this.id,
    required this.patientName,
    required this.relationship,
  });

  factory PatientAccessRequest.fromJson(Map<String, dynamic> json) =>
      PatientAccessRequest(
        id: json['id'].toString(),
        patientName: json['patient_name'] as String,
        relationship: json['relationship'] as String,
      );
}

class MedicalVisit {
  final String id;
  final String patientId;
  final String date;
  final String poly;
  final String doctor;
  final String complaint;
  final String diagnosis;
  final String treatment;

  const MedicalVisit({
    required this.id,
    required this.patientId,
    required this.date,
    required this.poly,
    required this.doctor,
    required this.complaint,
    required this.diagnosis,
    required this.treatment,
  });
}

class PatientReport {
  final String id;
  final String patientId;
  final String date;
  final String title;
  final String content;

  const PatientReport({
    required this.id,
    required this.patientId,
    required this.date,
    required this.title,
    required this.content,
  });
}

class Bill {
  final String id;
  final String patientId;
  final String patientName;
  final String date;
  final double totalAmount;
  final String status;
  final List<BillItem> items;

  const Bill({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.totalAmount,
    required this.status,
    required this.items,
    this.date = '',
  });
}

class BillItem {
  final String name;
  final double price;

  const BillItem({required this.name, required this.price});
}

class HospitalNotification {
  final String id;
  final String title;
  final String message;
  final String date;
  final bool isRead;
  final String ownerAccount;

  const HospitalNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.date,
    this.isRead = false,
    this.ownerAccount = '',
  });
}

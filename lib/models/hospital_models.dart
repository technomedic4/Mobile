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
  final String consultationType;

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
    this.consultationType = 'In-Person',
  });
}

class Teleconsultation {
  final Appointment appointment;

  const Teleconsultation(this.appointment);
}

class TeleconsultationMessage {
  final String id;
  final String senderName;
  final String senderRole;
  final String message;
  final DateTime? sentAt;
  final bool isMine;

  const TeleconsultationMessage({
    required this.id,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.sentAt,
    required this.isMine,
  });
}

class PaymentSubmission {
  final String id;
  final double amount;
  final String method;
  final String status;
  final String? reviewNote;

  const PaymentSubmission({
    required this.id,
    required this.amount,
    required this.method,
    required this.status,
    required this.reviewNote,
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
      id: json['id'].toString(),
      department: json['department'] as String,
      doctor: json['doctor'] as String,
      startTime: (json['start_time'] as String).substring(0, 5),
      endTime: (json['end_time'] as String).substring(0, 5),
      remainingQuota: (json['remaining_quota'] as num).toInt(),
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
  final String source;
  final String? condition;
  final List<String> vitalSigns;

  const MedicalVisit({
    required this.id,
    required this.patientId,
    required this.date,
    required this.poly,
    required this.doctor,
    required this.complaint,
    required this.diagnosis,
    required this.treatment,
    this.source = 'doctor',
    this.condition,
    this.vitalSigns = const [],
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
  final String billNumber;
  final double amountPaid;
  final double balanceDue;
  final List<PaymentSubmission> paymentSubmissions;

  const Bill({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.totalAmount,
    required this.status,
    required this.items,
    this.date = '',
    this.billNumber = '',
    this.amountPaid = 0,
    this.balanceDue = 0,
    this.paymentSubmissions = const [],
  });
}

class BillItem {
  final String name;
  final double price;
  final int quantity;

  const BillItem({
    required this.name,
    required this.price,
    this.quantity = 1,
  });
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

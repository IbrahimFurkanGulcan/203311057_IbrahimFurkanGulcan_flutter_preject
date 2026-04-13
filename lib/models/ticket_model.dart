class TicketModel {
  final String id;
  final String pnrCode; // Rezervasyon Kodu (Örn: A8F3K9)
  final String userId; 
  final String flightId;
  final String passengerName;  
  final String passengerTcNo;  
  final String contactEmail; // İletişim E-postası
  final String contactPhone; // İletişim Telefonu
  final String seatClass; // economy, business
  final String status;
  final String passengerSex; 
  final String? seatNumber; 

  TicketModel({
    required this.id,
    required this.pnrCode,
    required this.userId,
    required this.flightId,
    required this.passengerName,
    required this.passengerTcNo,
    required this.contactEmail,
    required this.contactPhone,
    required this.passengerSex,
    this.seatClass = 'economy',
    this.status = 'booked',
    this.seatNumber,
  });

  factory TicketModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TicketModel(
      id: documentId,
      pnrCode: map['pnrCode'] ?? '',
      userId: map['userId'] ?? '',
      flightId: map['flightId'] ?? '',
      passengerName: map['passengerName'] ?? '',
      passengerTcNo: map['passengerTcNo'] ?? '',
      contactEmail: map['contactEmail'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      passengerSex: map['passengerSex'] ?? '',
      seatClass: map['seatClass'] ?? 'economy',
      status: map['status'] ?? 'booked',
      seatNumber: map['seatNumber'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pnrCode': pnrCode,
      'userId': userId,
      'flightId': flightId,
      'passengerName': passengerName,
      'passengerTcNo': passengerTcNo,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'passengerSex': passengerSex,
      'seatClass': seatClass,
      'status': status,
      'seatNumber': seatNumber,
    };
  }
}
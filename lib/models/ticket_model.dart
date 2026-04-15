import 'package:cloud_firestore/cloud_firestore.dart';

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
  final DateTime createdAt; // Satın Alma Tarihi
  final DateTime date;
  final String flightNumber; 
  final String origin;
  final String destination;
  final DateTime arrivalTime;
  final String terminal;

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
    required this.createdAt,
    required this.date,
    required this.flightNumber, 
    required this.origin,       
    required this.destination,  
    required this.arrivalTime,  
    required this.terminal,
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
      flightNumber: map['flightNumber'] ?? '',       
      origin: map['origin'] ?? '',                   
      destination: map['destination'] ?? '',        
      arrivalTime: (map['arrivalTime'] as Timestamp).toDate(), 
      terminal: map['terminal'] ?? '',               
      passengerName: map['passengerName'] ?? '',
      passengerTcNo: map['passengerTcNo'] ?? '',
      contactEmail: map['contactEmail'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      passengerSex: map['passengerSex'] ?? '',
      seatClass: map['seatClass'] ?? 'economy',
      date: (map['date'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),      
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
      'createdAt': Timestamp.fromDate(createdAt),
      'date': Timestamp.fromDate(date),
      'flightNumber': flightNumber,       
      'origin': origin,                   
      'destination': destination,         
      'arrivalTime': Timestamp.fromDate(arrivalTime), 
      'terminal': terminal,               
    };
  }
}
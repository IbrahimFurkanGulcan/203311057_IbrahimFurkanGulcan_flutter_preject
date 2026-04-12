import 'package:cloud_firestore/cloud_firestore.dart';

class LogModel {
  final String id;
  final String userId; // İşlemi yapan kişinin ID'si
  final String action; // Ne yaptığı (Örn: "IST-ESB uçuşu için bilet aldı")
  final DateTime timestamp;

  LogModel({
    required this.id,
    required this.userId,
    required this.action,
    required this.timestamp,
  });

  factory LogModel.fromMap(Map<String, dynamic> map, String documentId) {
    return LogModel(
      id: documentId,
      userId: map['userId'] ?? '',
      action: map['action'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'action': action,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class FlightModel {
  final String id;
  final String flightNumber; // Uçuş No (Örn: TK-777)
  final String origin;
  final String destination;
  final DateTime date;
  final double price;
  final int totalSeats;
  final int availableSeats;
  final String status; // scheduled, delayed, cancelled
  final String? gate;  // Uçağa biniş kapısı

  FlightModel({
    required this.id,
    required this.flightNumber,
    required this.origin,
    required this.destination,
    required this.date,
    required this.price,
    required this.totalSeats,
    required this.availableSeats,
    this.status = 'scheduled',
    this.gate,
  });

  factory FlightModel.fromMap(Map<String, dynamic> map, String documentId) {
    return FlightModel(
      id: documentId,
      flightNumber: map['flightNumber'] ?? '',
      origin: map['origin'] ?? '',
      destination: map['destination'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      price: (map['price'] ?? 0.0).toDouble(),
      totalSeats: map['totalSeats'] ?? 0,
      availableSeats: map['availableSeats'] ?? 0,
      status: map['status'] ?? 'scheduled',
      gate: map['gate'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'flightNumber': flightNumber,
      'origin': origin,
      'destination': destination,
      'date': Timestamp.fromDate(date),
      'price': price,
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'status': status,
      'gate': gate,
    };
  }
}
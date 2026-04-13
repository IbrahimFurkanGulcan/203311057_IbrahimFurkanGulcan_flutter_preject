import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/flight_model.dart';

class FlightService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Yeni Uçuş Ekleme (Admin kullanacak)
  Future<String?> addFlight(FlightModel flight) async {
    try {
      // 'flights' adında bir koleksiyona uçuşu kaydediyoruz.
      // doc() içini boş bırakırsak Firebase otomatik olarak eşsiz bir ID (flightId) üretir.
      DocumentReference docRef = _firestore.collection('flights').doc();
      
      // Oluşan bu ID'yi modelimizin içine de koyup öyle kaydediyoruz
      FlightModel flightWithId = FlightModel(
        id: docRef.id,
        flightNumber: flight.flightNumber,
        origin: flight.origin,
        destination: flight.destination,
        date: flight.date,
        price: flight.price,
        totalSeats: flight.totalSeats,
        availableSeats: flight.totalSeats, // Başlangıçta boş koltuk = toplam koltuk
        status: flight.status,
        gate: flight.gate,
      );

      await docRef.set(flightWithId.toMap());
      return "success";
    } catch (e) {
      return "Uçuş eklenirken hata oluştu: $e";
    }
  }

  // 2. Tüm Uçuşları Çekme (Hem Yolcu hem Admin kullanacak)
  // Stream kullanıyoruz, böylece bir bilet satıldığında boş koltuk sayısı ekranda anında güncellenir!
  Stream<List<FlightModel>> getAllFlights() {
    return _firestore
        .collection('flights')
        .orderBy('date') // Tarihe göre sıralı gelsin
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => FlightModel.fromMap(doc.data(), doc.id)).toList();
    });
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/flight_model.dart';

class FlightService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Yeni Uçuş Ekleme (Admin kullanacak)
  Future<String?> addFlight(FlightModel flight) async {
    try {
      // --- ÇAKIŞMA KONTROLÜ BAŞLANGICI ---
      // Önce o rotadaki uçuşları çekiyoruz
      QuerySnapshot existingFlights = await _firestore
          .collection('flights')
          .where('origin', isEqualTo: flight.origin)
          .where('destination', isEqualTo: flight.destination)
          .get();

      // Çekilen uçuşların tarihlerini tek tek kontrol ediyoruz
      for (var doc in existingFlights.docs) {
        DateTime existingDate = (doc['date'] as Timestamp).toDate();
        
        // Eğer Yıl, Ay, Gün, Saat ve Dakika BİREBİR aynıysa eklemeyi reddet!
        if (existingDate.year == flight.date.year &&
            existingDate.month == flight.date.month &&
            existingDate.day == flight.date.day &&
            existingDate.hour == flight.date.hour &&
            existingDate.minute == flight.date.minute) {
          return "HATA: Bu rota için ${flight.date.hour}:${flight.date.minute.toString().padLeft(2, '0')} saatinde zaten bir uçuş kayıtlı!";
        }
      }
      // --- ÇAKIŞMA KONTROLÜ BİTİŞİ ---

      // Çakışma yoksa normal kayıt işlemine devam et
      DocumentReference docRef = _firestore.collection('flights').doc();
      
      FlightModel flightWithId = FlightModel(
        id: docRef.id,
        flightNumber: flight.flightNumber,
        origin: flight.origin,
        destination: flight.destination,
        date: flight.date,
        price: flight.price,
        totalSeats: flight.totalSeats,
        availableSeats: flight.totalSeats,
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

  // 3. Uçuş Arama Fonksiyonu (Yolcu kullanacak)
  Future<List<FlightModel>> searchFlights({
    required String origin,
    required String destination,
    required DateTime date,
    required int passengerCount,
    bool isFlexible = false, // YENİ: Esnek tarih seçeneği
  }) async {
    QuerySnapshot snapshot = await _firestore
        .collection('flights')
        .where('origin', isEqualTo: origin)
        .where('destination', isEqualTo: destination)
        .get();

    List<FlightModel> results = snapshot.docs
        .map((doc) => FlightModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    return results.where((flight) {
      // Eğer esnek seçildiyse tarih kontrolünü atla, sadece gelecekteki uçuşları göster
      bool dateMatch = isFlexible 
          ? flight.date.isAfter(DateTime.now())
          : (flight.date.year == date.year && flight.date.month == date.month && flight.date.day == date.day);
      
      bool hasEnoughSeats = flight.availableSeats >= passengerCount;
      return dateMatch && hasEnoughSeats && flight.status == 'scheduled';
    }).toList();
  }
}
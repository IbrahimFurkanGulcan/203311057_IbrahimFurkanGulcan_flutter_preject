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
        arrivalTime: flight.arrivalTime, 
        terminal: flight.terminal,
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

  // --- FAZ 2: ADMİN RÖTAR VE İPTAL İŞLEMLERİ ---

  // 1. Uçuşu Erteleme (Rötar)
  Future<String> delayFlight(String flightId, Duration delay) async {
    try {
      DocumentReference flightRef = _firestore.collection('flights').doc(flightId);
      
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot flightSnap = await transaction.get(flightRef);
        if (!flightSnap.exists) throw Exception("Uçuş bulunamadı.");

        DateTime oldDate = (flightSnap['date'] as Timestamp).toDate();
        DateTime oldArrival = (flightSnap['arrivalTime'] as Timestamp).toDate();

        // Uçuş statüsünü ve saatlerini güncelle
        transaction.update(flightRef, {
          'status': 'delayed',
          'date': Timestamp.fromDate(oldDate.add(delay)),
          'arrivalTime': Timestamp.fromDate(oldArrival.add(delay)),
        });
        
        // (İleride buraya bildirim gönderme kodu eklenecek)
      });
      return "success";
    } catch (e) {
      return "Rötar işlemi başarısız: $e";
    }
  }

  // 2. Havayolu Tarafından Toplu İptal (Batch Refund)
  Future<String> cancelFlightByAdmin(String flightId) async {
    try {
      // Batch işlemi: Birden fazla belgeyi aynı anda güvenle günceller (Maksimum 500 işlem)
      WriteBatch batch = _firestore.batch();
      DocumentReference flightRef = _firestore.collection('flights').doc(flightId);
      
      // 1. Uçuşu iptal et
      batch.update(flightRef, {'status': 'cancelled'});

      // 2. Bu uçuşa ait tüm biletleri bul
      QuerySnapshot ticketsSnap = await _firestore.collection('tickets').where('flightId', isEqualTo: flightId).get();

      // Biletleri iptal et ve kullanıcı bakiyelerini iade etmek için kullanıcıları grupla
      Map<String, double> refunds = {}; 
      
      for (var doc in ticketsSnap.docs) {
        // Biletin statüsünü iptal yap
        batch.update(doc.reference, {'status': 'cancelled'});
        
        String userId = doc['userId'];
        String seatClass = doc['seatClass'];
        
        // Bu uçuşun güncel fiyatını (veya biletteki fiyatı) iade için hesapla (Basitlik için sabit çarpan)
        // Gerçekte bilet modeline "ödenen miktar" eklemek en doğrusudur.
        double price = 1000.0; // Şimdilik varsayılan iade bedeli (Sistemine göre dinamik çekilebilir)
        double refund = seatClass == 'business' ? price * 2.5 : price;
        
        refunds[userId] = (refunds[userId] ?? 0.0) + refund;
      }

      // 3. Kullanıcıların cüzdanlarına paraları iade et
      for (String userId in refunds.keys) {
        DocumentReference userRef = _firestore.collection('users').doc(userId);
        batch.update(userRef, {'walletBalance': FieldValue.increment(refunds[userId]!)});
      }

      await batch.commit(); // Tüm işlemleri tek seferde veritabanına yaz
      return "success";
    } catch (e) {
      return "İptal işlemi başarısız: $e";
    }
  }
}
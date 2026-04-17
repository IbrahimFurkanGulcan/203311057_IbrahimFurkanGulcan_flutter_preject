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

  // 1. Uçuşu Erteleme (Transaction yerine daha güvenli olan Batch'e geçtik)
  Future<String> delayFlight(String flightId, Duration delay) async {
    try {
      DocumentReference flightRef = _firestore.collection('flights').doc(flightId);
      DocumentSnapshot flightSnap = await flightRef.get();
      
      if (!flightSnap.exists) return "Uçuş bulunamadı.";

      // Mevcut verileri çekiyoruz
      DateTime oldDate = (flightSnap['date'] as Timestamp).toDate();
      // arrivalTime null ise bugünü al (hata almamak için koruma)
      DateTime oldArrival = (flightSnap.data() as Map).containsKey('arrivalTime') 
          ? (flightSnap['arrivalTime'] as Timestamp).toDate() 
          : oldDate.add(const Duration(hours: 2));

      String flightNo = flightSnap['flightNumber'] ?? "Bilinmiyor";

      // Uçuşun yolcularını bul
      QuerySnapshot tickets = await _firestore.collection('tickets')
          .where('flightId', isEqualTo: flightId)
          .where('status', whereIn: ['booked', 'checked_in']).get();

      WriteBatch batch = _firestore.batch();

      // Uçuşu güncelle
      batch.update(flightRef, {
        'status': 'delayed',
        'date': Timestamp.fromDate(oldDate.add(delay)),
        'arrivalTime': Timestamp.fromDate(oldArrival.add(delay)),
      });

      // Her yolcuya BİLDİRİM gönder
      for (var doc in tickets.docs) {
        DocumentReference notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'userId': doc['userId'],
          'title': '✈️ Uçuş Rötarı: $flightNo',
          'message': 'Uçuşunuz ${delay.inHours} saat ertelenmiştir. Yeni saat: ${oldDate.add(delay).hour}:${oldDate.add(delay).minute}',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      await batch.commit();
      return "success";
    } catch (e) {
      return "Rötar işlemi başarısız: $e";
    }
  }

  // 2. Havayolu Tarafından Toplu İptal (İade ve Bildirim Entegre Edildi)
  Future<String> cancelFlightByAdmin(String flightId) async {
    try {
      DocumentReference flightRef = _firestore.collection('flights').doc(flightId);
      DocumentSnapshot flightSnap = await flightRef.get();
      
      if (!flightSnap.exists) return "Uçuş bulunamadı.";
      
      double flightPrice = (flightSnap.data() as Map<String, dynamic>)['price'] ?? 0.0;
      String flightNo = flightSnap['flightNumber'] ?? "";

      QuerySnapshot ticketsSnap = await _firestore.collection('tickets')
          .where('flightId', isEqualTo: flightId)
          .where('status', isNotEqualTo: 'cancelled').get();

      WriteBatch batch = _firestore.batch();

      // 1. Uçuşu iptal et
      batch.update(flightRef, {'status': 'cancelled'});

      for (var doc in ticketsSnap.docs) {
        String userId = doc['userId'];
        String seatClass = doc['seatClass'] ?? 'economy';
        double refund = seatClass == 'business' ? flightPrice * 2.5 : flightPrice;

        // 2. Bileti iptal et
        batch.update(doc.reference, {'status': 'cancelled'});

        // 3. Para İadesi (Increment kullanarak bakiye hatasını önlüyoruz)
        DocumentReference userRef = _firestore.collection('users').doc(userId);
        batch.update(userRef, {'walletBalance': FieldValue.increment(refund)});

        // 4. Bildirim Gönder
        DocumentReference notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'userId': userId,
          'title': '❌ Uçuş İptal Edildi: $flightNo',
          'message': 'Uçuşunuz iptal olmuştur. $refund TL iadeniz cüzdanınıza yüklendi.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      await batch.commit();
      return "success";
    } catch (e) {
      return "İptal işlemi başarısız: $e";
    }
  }
}
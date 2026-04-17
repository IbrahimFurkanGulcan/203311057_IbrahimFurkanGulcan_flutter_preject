import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/flight_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    bool isFlexible = false, // Esnek tarih seçeneği
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
          : (flight.date.year == date.year && 
             flight.date.month == date.month && 
             flight.date.day == date.day && 
             flight.date.isAfter(DateTime.now()));
      
      bool hasEnoughSeats = flight.availableSeats >= passengerCount;
      bool statusMatch = flight.status == 'scheduled' || flight.status == 'Rötarlı';
      return dateMatch && hasEnoughSeats && statusMatch;
    }).toList();
  }

  // --- DİNAMİK ROTA HARİTASI ÇEKME ---
  Future<Map<String, List<String>>> getAvailableRoutes() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('flights').get();
      Map<String, Set<String>> routesMap = {}; // Kalkış -> [Varışlar]

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String origin = data['origin'] ?? '';
        String dest = data['destination'] ?? '';

        if (origin.isNotEmpty && dest.isNotEmpty) {
          if (!routesMap.containsKey(origin)) {
            routesMap[origin] = {};
          }
          routesMap[origin]!.add(dest);
        }
      }

      Map<String, List<String>> finalRoutes = {};
      routesMap.forEach((key, value) {
        List<String> dests = value.toList();
        dests.sort();
        finalRoutes[key] = dests;
      });

      return finalRoutes;
    } catch (e) {
      return {};
    }
  }

  // --- FAZ 2: ADMİN RÖTAR VE İPTAL İŞLEMLERİ ---

  // --- ADMİN: UÇUŞA RÖTAR EKLEME ---
  Future<String> delayFlight(String flightId, Duration delay) async {
    try {
      WriteBatch batch = _firestore.batch();

      // 1. Uçuşu bul
      DocumentReference flightRef = _firestore.collection('flights').doc(flightId);
      DocumentSnapshot flightDoc = await flightRef.get();

      if (!flightDoc.exists) return "Uçuş bulunamadı.";

      DateTime oldDate = (flightDoc['date'] as Timestamp).toDate();
      DateTime oldArrival = (flightDoc['arrivalTime'] as Timestamp).toDate();

      DateTime newDate = oldDate.add(delay);
      DateTime newArrival = oldArrival.add(delay);

      // Uçuşun saatini güncelle
      batch.update(flightRef, {
        'date': newDate,
        'arrivalTime': newArrival,
        'status': 'Rötarlı', // İsteğe bağlı, durumu Rötarlı yapabilirsin
      });

      // 2. Bu uçuşa ait tüm biletleri bul ve saatlerini güncelle
      QuerySnapshot ticketsSnapshot = await _firestore.collection('tickets').where('flightId', isEqualTo: flightId).get();

      // Aynı kişiye 5 bilet aldıysa 5 bildirim gitmesin diye benzersiz kullanıcı ID'lerini topluyoruz
      Set<String> affectedUserIds = {};

      for (var doc in ticketsSnapshot.docs) {
        batch.update(doc.reference, {
          'date': newDate,
          'arrivalTime': newArrival,
        });
        affectedUserIds.add(doc['userId']);
      }

      // 3. Kullanıcılara arka planda "Zil" bildirimi oluştur
      for (String uId in affectedUserIds) {
        DocumentReference notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'id': notifRef.id,
          'userId': uId,
          'title': 'Uçuşunuzda Rötar!',
          'message': '${flightDoc['flightNumber']} sefer sayılı uçuşunuza ${delay.inHours} saat rötar eklenmiştir. Yeni kalkış saati: ${newDate.hour.toString().padLeft(2, '0')}:${newDate.minute.toString().padLeft(2, '0')}',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      String adminId = FirebaseAuth.instance.currentUser?.uid ?? 'Bilinmeyen Admin';
      DocumentReference logRef = _firestore.collection('logs').doc();
      batch.set(logRef, {
        'userId': adminId,
        'action': '${flightDoc['flightNumber']} sefer sayılı uçuşa ${delay.inHours} saat rötar eklendi.',
        'timestamp': FieldValue.serverTimestamp(),
      });


      // Tüm işlemleri tek seferde çalıştır
      await batch.commit();
      return "success";
    } catch (e) {
      return "Rötar eklenirken hata: $e";
    }
  }

  // --- ADMİN: UÇUŞ İPTALİ VE OTOMATİK İADE SİSTEMİ ---
  Future<String> cancelFlightByAdmin(String flightId) async {
    try {
      WriteBatch batch = _firestore.batch();

      // 1. Uçuşun statüsünü iptal et
      DocumentReference flightRef = _firestore.collection('flights').doc(flightId);
      DocumentSnapshot flightDoc = await flightRef.get();

      if (!flightDoc.exists) return "Uçuş bulunamadı.";

      batch.update(flightRef, {
        'status': 'cancelled',
      });

      // 2. İlgili tüm biletleri bul
      QuerySnapshot ticketsSnapshot = await _firestore.collection('tickets').where('flightId', isEqualTo: flightId).get();

      // Kullanıcılara ne kadar iade yapılacağını hesaplayacağımız liste (KullanıcıID : Toplam İade)
      Map<String, double> refundsByUser = {};

      for (var doc in ticketsSnapshot.docs) {
        // Bileti veritabanında İptal Edildi olarak işaretle
        batch.update(doc.reference, {
          'status': 'cancelled',
        });

        // Bilet fiyatını al
        var data = doc.data() as Map<String, dynamic>;
        double price = data['price'] != null ? double.tryParse(data['price'].toString()) ?? 0.0 : 0.0;
        String uId = doc['userId'];

        // Kişinin iade sepetine parayı ekle
        if (refundsByUser.containsKey(uId)) {
          refundsByUser[uId] = refundsByUser[uId]! + price;
        } else {
          refundsByUser[uId] = price;
        }
      }

      // 3. Para iadelerini yap ve Bildirimleri gönder
      for (String uId in refundsByUser.keys) {
        double refundAmount = refundsByUser[uId]!;

        // Kullanıcının cüzdanına parayı KESİN VE GÜVENLİ olarak ekle
        DocumentReference userRef = _firestore.collection('users').doc(uId);
        batch.update(userRef, {
          'walletBalance': FieldValue.increment(refundAmount)
        });

        // Bildirim oluştur
        DocumentReference notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'id': notifRef.id,
          'userId': uId,
          'title': '⚠️ Uçuş İptali ve İade',
          'message': '${flightDoc['flightNumber']} sefer sayılı uçuşunuz iptal edilmiştir. Biletleriniz için toplam $refundAmount TL cüzdanınıza iade edildi.',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }


      String adminId = FirebaseAuth.instance.currentUser?.uid ?? 'Bilinmeyen Admin';
      DocumentReference logRef = _firestore.collection('logs').doc();
      batch.set(logRef, {
        'userId': adminId,
        'action': '${flightDoc['flightNumber']} sefer sayılı uçuş iptal edildi ve bilet ücretleri iade edildi.',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Tüm işlemleri tek seferde ateşle!
      await batch.commit();
      return "success";
    } catch (e) {
      return "İptal işleminde hata: $e";
    }
  }

  
}
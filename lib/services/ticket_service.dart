import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ucak_bileti_rezervasyon_ve_check_in_sistemi/models/flight_model.dart';
import '../models/ticket_model.dart';
import 'dart:math';

class TicketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Güvenli Satın Alma İşlemi (Transaction) - GİDİŞ/DÖNÜŞ DESTEKLİ (Düzeltilmiş Versiyon)
  Future<String> buyTickets({
    required String userId,
    required List<TicketModel> tickets, 
    required double totalPrice, required String flightId,
  }) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(userId);

      // Biletlerdeki farklı uçuşları ve kaç koltuk istendiğini tespit et
      Map<String, int> flightSeatCounts = {};
      for (var t in tickets) {
        flightSeatCounts[t.flightId] = (flightSeatCounts[t.flightId] ?? 0) + 1;
      }

      await _firestore.runTransaction((transaction) async {
        // =======================================================
        // 1. AŞAMA: SADECE OKUMA (READ) İŞLEMLERİ 
        // (Firebase kuralı: Tüm okumalar yazmalardan önce yapılmalıdır)
        // =======================================================
        
        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) throw Exception("Kullanıcı bulunamadı.");
        double currentBalance = (userSnapshot.data() as Map<String, dynamic>)['walletBalance'] ?? 0.0;

        if (currentBalance < totalPrice) throw Exception("Cüzdan bakiyeniz yetersiz.");

        // İlgili tüm uçuşların mevcut kapasitelerini okuyup hafızaya (Map) alalım
        Map<String, int> availableSeatsMap = {};
        Map<String, DocumentReference> flightRefs = {};

        for (String fId in flightSeatCounts.keys) {
          DocumentReference flightRef = _firestore.collection('flights').doc(fId);
          DocumentSnapshot flightSnap = await transaction.get(flightRef);
          
          if (!flightSnap.exists) throw Exception("Uçuşlardan biri bulunamadı.");
          int availableSeats = (flightSnap.data() as Map<String, dynamic>)['availableSeats'] ?? 0;
          int requestedSeats = flightSeatCounts[fId]!;

          if (availableSeats < requestedSeats) throw Exception("Üzgünüz, uçuşların birinde yeterli koltuk kalmadı.");
          
          availableSeatsMap[fId] = availableSeats; // Koltuk sayısını kaydet
          flightRefs[fId] = flightRef;             // Referansı kaydet
        }

        // =======================================================
        // 2. AŞAMA: SADECE YAZMA (WRITE) İŞLEMLERİ
        // =======================================================
        
        // 1. Parayı düş
        transaction.update(userRef, {'walletBalance': currentBalance - totalPrice});

        // 2. Uçuş kapasitelerini düş
        for (String fId in flightSeatCounts.keys) {
          transaction.update(flightRefs[fId]!, {
            'availableSeats': availableSeatsMap[fId]! - flightSeatCounts[fId]!
          });
        }

        // 3. Biletleri veritabanına ekle
        for (var ticket in tickets) {
          DocumentReference newTicketRef = _firestore.collection('tickets').doc();
          TicketModel ticketWithId = TicketModel(
            id: newTicketRef.id, pnrCode: _generatePNR(), userId: ticket.userId,
            flightId: ticket.flightId, passengerName: ticket.passengerName, passengerTcNo: ticket.passengerTcNo,
            contactEmail: ticket.contactEmail, contactPhone: ticket.contactPhone, passengerSex: ticket.passengerSex,
            seatClass: ticket.seatClass, status: 'booked', createdAt: DateTime.now(), date: ticket.date,
            flightNumber: ticket.flightNumber, origin: ticket.origin, destination: ticket.destination,
            arrivalTime: ticket.arrivalTime, terminal: ticket.terminal,
          );
          transaction.set(newTicketRef, ticketWithId.toMap());
        }

        // 4. Log Kaydı
        DocumentReference logRef = _firestore.collection('logs').doc();
        transaction.set(logRef, {
          'userId': userId, 'action': '${tickets.length} adet bilet alındı. Tutar: $totalPrice', 'timestamp': FieldValue.serverTimestamp(),
        });
      });

      return "success";
    } catch (e) {
      return e.toString().replaceAll("Exception: ", "");
    }
  }

  //Kullanıcının Biletlerini Gerçek Zamanlı Getirme (Stream)
  Stream<List<TicketModel>> getUserTicketsStream(String userId) {
    return _firestore
        .collection('tickets')
        .where('userId', isEqualTo: userId)
        // Tarihe göre yakın uçuşlar en üstte görünsün
        .orderBy('date', descending: false) 
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TicketModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Güvenli Bilet İptal İşlemi (Transaction)
  Future<String> cancelTicket({
    required String ticketId,
    required String flightId,
    required String userId,
    required String seatClass,
  }) async {
    try {
      DocumentReference ticketRef = _firestore.collection('tickets').doc(ticketId);
      DocumentReference flightRef = _firestore.collection('flights').doc(flightId);
      DocumentReference userRef = _firestore.collection('users').doc(userId);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot ticketSnap = await transaction.get(ticketRef);
        DocumentSnapshot flightSnap = await transaction.get(flightRef);
        DocumentSnapshot userSnap = await transaction.get(userRef);

        if (!ticketSnap.exists || !flightSnap.exists || !userSnap.exists) {
          throw Exception("Kayıtlar bulunamadı, iptal işlemi durduruldu.");
        }

        // Uçuş verilerinden iade edilecek tutarı hesapla
        double basePrice = (flightSnap.data() as Map<String, dynamic>)['price'] ?? 0.0;
        double refundAmount = seatClass == 'business' ? basePrice * 2.5 : basePrice;

        // Kullanıcı bakiyesini ve Uçuş koltuğunu oku
        double currentBalance = (userSnap.data() as Map<String, dynamic>)['walletBalance'] ?? 0.0;
        int availableSeats = (flightSnap.data() as Map<String, dynamic>)['availableSeats'] ?? 0;

        // YAZMA İŞLEMLERİ 
        // 1. Cüzdana parayı iade et
        transaction.update(userRef, {'walletBalance': currentBalance + refundAmount});
        // 2. Koltuğu uçağa geri ver (+1)
        transaction.update(flightRef, {'availableSeats': availableSeats + 1});
        // 3. Bilet statüsünü iptal olarak değiştir
        transaction.update(ticketRef, {'status': 'cancelled'});

        // Log kaydı oluştur
        DocumentReference logRef = _firestore.collection('logs').doc();
        transaction.set(logRef, {
          'userId': userId,
          'action': 'Bilet İptali (PNR: ${(ticketSnap.data() as Map)['pnrCode']}). İade: $refundAmount TL',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      return "success";
    } catch (e) {
      return e.toString().replaceAll("Exception: ", "");
    }
  }

  // Yardımcı Fonksiyon: 6 haneli rastgele PNR kodu üretir
  String _generatePNR() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // Uçuşa ait DOLU koltukları gerçek zamanlı dinler (Biri koltuğu seçerse ekranda anında kırmızı olur)
  Stream<List<String>> getTakenSeatsStream(String flightId) {
    return _firestore
        .collection('tickets')
        .where('flightId', isEqualTo: flightId)
        .where('status', isEqualTo: 'checked_in')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['seatNumber'] as String?)
            .where((seat) => seat != null)
            .cast<String>()
            .toList());
  }

  // Check-in İşlemini Veritabanına Kaydetme (Çakışma Kontrollü Transaction)
  Future<String> performCheckIn({
    required String ticketId,
    required String seatNumber,
    required String flightId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        // Kritik Kontrol: Acaba bu koltuk saliseler önce başkası tarafından kapıldı mı?
        QuerySnapshot existingTickets = await _firestore
            .collection('tickets')
            .where('flightId', isEqualTo: flightId)
            .where('seatNumber', isEqualTo: seatNumber)
            .where('status', isEqualTo: 'checked_in')
            .get();

        if (existingTickets.docs.isNotEmpty) {
          throw Exception("Maalesef bu koltuk az önce başka bir yolcu tarafından seçildi.");
        }

        // Boşsa bileti güncelle
        DocumentReference ticketRef = _firestore.collection('tickets').doc(ticketId);
        transaction.update(ticketRef, {
          'status': 'checked_in',
          'seatNumber': seatNumber,
        });

        // Log Kaydı
        DocumentReference logRef = _firestore.collection('logs').doc();
        transaction.set(logRef, {
          'userId': FirebaseAuth.instance.currentUser?.uid ?? 'Bilinmiyor',
          'action': 'Check-in Yapıldı. Bilet: $ticketId, Koltuk: $seatNumber',
          'timestamp': FieldValue.serverTimestamp(),
        });

        return "success";
      });
    } catch (e) {
      return e.toString().replaceAll("Exception: ", "");
    }
  }
  
  // 3. Güvenli Uçuş Değiştirme İşlemi (Multi-Transaction)
  Future<String> changeTicket({
    required TicketModel oldTicket,
    required FlightModel newFlight,
    required double priceDifference, // Pozitifse ödeme yapacak, negatifse iade alacak
  }) async {
    try {
      DocumentReference oldFlightRef = _firestore.collection('flights').doc(oldTicket.flightId);
      DocumentReference newFlightRef = _firestore.collection('flights').doc(newFlight.id);
      DocumentReference userRef = _firestore.collection('users').doc(oldTicket.userId);
      DocumentReference ticketRef = _firestore.collection('tickets').doc(oldTicket.id);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot userSnap = await transaction.get(userRef);
        DocumentSnapshot newFlightSnap = await transaction.get(newFlightRef);
        DocumentSnapshot oldFlightSnap = await transaction.get(oldFlightRef);

        double currentBalance = (userSnap.data() as Map<String, dynamic>)['walletBalance'] ?? 0.0;
        int newFlightSeats = (newFlightSnap.data() as Map<String, dynamic>)['availableSeats'] ?? 0;
        int oldFlightSeats = (oldFlightSnap.data() as Map<String, dynamic>)['availableSeats'] ?? 0;

        // Kontroller
        if (priceDifference > 0 && currentBalance < priceDifference) {
          throw Exception("Cüzdan bakiyeniz fiyat farkını ödemek için yetersiz.");
        }
        if (newFlightSeats <= 0) {
          throw Exception("Seçilen yeni uçuşta boş koltuk kalmadı.");
        }

        // 1. Cüzdan Güncelleme (Fark pozitifse düş, negatifse ekle)
        transaction.update(userRef, {'walletBalance': currentBalance - priceDifference});

        // 2. Koltuk Sayıları Güncelleme (Senin hatırlattığın kritik nokta!)
        transaction.update(oldFlightRef, {'availableSeats': oldFlightSeats + 1}); // Eski uçuşa koltuk iade
        transaction.update(newFlightRef, {'availableSeats': newFlightSeats - 1}); // Yeni uçuştan koltuk düş

        // 3. Bileti Yeni Bilgilerle Güncelle
        transaction.update(ticketRef, {
          'flightId': newFlight.id,
          'flightNumber': newFlight.flightNumber,
          'date': Timestamp.fromDate(newFlight.date),
          'arrivalTime': Timestamp.fromDate(newFlight.arrivalTime),
          'terminal': newFlight.terminal,
          'status': 'booked', // Eğer check-in yapılmışsa bile sıfırlanır
          'seatNumber': null, // Yeni uçuş için tekrar check-in yapmalı
        });

        // Log
        DocumentReference logRef = _firestore.collection('logs').doc();
        transaction.set(logRef, {
          'userId': oldTicket.userId,
          'action': 'Uçuş Değiştirildi. Eski: ${oldTicket.flightNumber}, Yeni: ${newFlight.flightNumber}. Fark: $priceDifference TL',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      return "success";
    } catch (e) {
      return e.toString().replaceAll("Exception: ", "");
    }
  }
}
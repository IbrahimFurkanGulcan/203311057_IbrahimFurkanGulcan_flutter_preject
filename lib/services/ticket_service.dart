import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ticket_model.dart';
import 'dart:math';

class TicketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Güvenli Satın Alma İşlemi (Transaction)
  Future<String> buyTickets({
    required String userId,
    required String flightId,
    required List<TicketModel> tickets, // Kaç kişi uçuyorsa o kadar bilet
    required double totalPrice,
  }) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(userId);
      DocumentReference flightRef = _firestore.collection('flights').doc(flightId);

      // runTransaction: Tüm işlemler hatasız biterse veritabanına yazar, biri patlarsa hepsini geri alır (Rollback)
      await _firestore.runTransaction((transaction) async {
        // 1. Oku: Uçuş ve Kullanıcı verilerini anlık olarak oku
        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        DocumentSnapshot flightSnapshot = await transaction.get(flightRef);

        if (!userSnapshot.exists || !flightSnapshot.exists) {
          throw Exception("Kullanıcı veya uçuş bulunamadı.");
        }

        double currentBalance = (userSnapshot.data() as Map<String, dynamic>)['walletBalance'] ?? 0.0;
        int availableSeats = (flightSnapshot.data() as Map<String, dynamic>)['availableSeats'] ?? 0;

        // 2. Kontrol Et: Para ve Koltuk yetiyor mu?
        if (currentBalance < totalPrice) {
          throw Exception("Cüzdan bakiyeniz yetersiz.");
        }
        if (availableSeats < tickets.length) {
          throw Exception("Üzgünüz, uçakta yeterli boş koltuk kalmadı.");
        }

        // 3. Yaz: Parayı düş, koltuğu azalt
        transaction.update(userRef, {'walletBalance': currentBalance - totalPrice});
        transaction.update(flightRef, {'availableSeats': availableSeats - tickets.length});

        // 4. Yaz: Biletleri ve Log kaydını oluştur
        for (var ticket in tickets) {
          DocumentReference newTicketRef = _firestore.collection('tickets').doc();
          
          // Rastgele PNR kodu üret
          String pnr = _generatePNR();
          
          TicketModel ticketWithId = TicketModel(
            id: newTicketRef.id,
            pnrCode: pnr,
            userId: ticket.userId,
            flightId: ticket.flightId,
            passengerName: ticket.passengerName,
            passengerTcNo: ticket.passengerTcNo,
            contactEmail: ticket.contactEmail,
            contactPhone: ticket.contactPhone,
            passengerSex: ticket.passengerSex,
            seatClass: ticket.seatClass,
            status: 'booked',
            createdAt: DateTime.now(), 
            date: ticket.date,
            flightNumber: ticket.flightNumber,
            origin: ticket.origin,
            destination: ticket.destination,
            arrivalTime: ticket.arrivalTime,
            terminal: ticket.terminal,
          );

          transaction.set(newTicketRef, ticketWithId.toMap());
        }

        // Hocanın istediği log kaydı
        DocumentReference logRef = _firestore.collection('logs').doc();
        transaction.set(logRef, {
          'userId': userId,
          'action': '${tickets.length} adet bilet satın alındı. Uçuş: $flightId',
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
}
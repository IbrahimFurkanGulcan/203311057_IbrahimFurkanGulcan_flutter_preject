import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ucak_bileti_rezervasyon_ve_check_in_sistemi/models/flight_model.dart';
import 'package:ucak_bileti_rezervasyon_ve_check_in_sistemi/models/ticket_model.dart';
import 'package:ucak_bileti_rezervasyon_ve_check_in_sistemi/services/ticket_service.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  late FirebaseFirestore firestore;
  late TicketService ticketService;

  // Test Verileri (Başkalarıyla karışmasın diye özel ID'ler kullanıyoruz)
  final String testUserId = 'TEST_USER_999';
  final String flightA_Id = 'TEST_FLIGHT_A';
  final String flightB_Id = 'TEST_FLIGHT_B';

  // Testler başlamadan ÖNCE 1 KERE ÇALIŞIR: Firebase'i başlatır
  setUpAll(() async {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(); // Gerçek Firebase'e bağlan
    firestore = FirebaseFirestore.instance;
    ticketService = TicketService(); // Artık gerçek servisi kullanıyoruz
  });

  // Her testten ÖNCE çalışır: Veritabanına test verilerini yükler
  setUp(() async {
    await firestore.collection('users').doc(testUserId).set({
      'walletBalance': 10000.0,
      'email': 'test@test.com',
    });

    await firestore.collection('flights').doc(flightA_Id).set({
      'availableSeats': 100,
      'price': 1000.0,
      'status': 'scheduled',
      'origin': 'IST',
      'destination': 'ANK',
      'date': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
      'arrivalTime': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1, hours: 2))),
    });

    await firestore.collection('flights').doc(flightB_Id).set({
      'availableSeats': 100,
      'price': 1200.0,
      'status': 'scheduled',
      'origin': 'IST',
      'destination': 'ANK',
      'date': Timestamp.fromDate(DateTime.now().add(const Duration(days: 2))),
      'arrivalTime': Timestamp.fromDate(DateTime.now().add(const Duration(days: 2, hours: 2))),
    });

  });


  // Her testten SONRA çalışır: Gerçek veritabanını kirletmemek için her şeyi SİLER!
  tearDown(() async {
    await firestore.collection('users').doc(testUserId).delete();
    await firestore.collection('flights').doc(flightA_Id).delete();
    await firestore.collection('flights').doc(flightB_Id).delete();
    
    // Kesilen test biletlerini bul ve sil
    var tickets = await firestore.collection('tickets').where('userId', isEqualTo: testUserId).get();
    for (var doc in tickets.docs) {
      await doc.reference.delete();
    }
  });

  group('GERÇEK FIREBASE - Uçak Bileti UAT Testleri', () {
    
    test('Senaryo 1: Yetersiz bakiye durumunda bilet alımı reddedilmeli', () async {
      String result = await ticketService.buyTickets(
        userId: testUserId,
        flightId: flightA_Id,
        tickets: [_createMockTicket(testUserId, flightA_Id)],
        totalPrice: 15000.0, 
      );
      expect(result, contains("yetersiz")); 
      var user = await firestore.collection('users').doc(testUserId).get();
      expect(user['walletBalance'], 10000.0); 
    });

    test('Senaryo 2: Başarılı bilet alımı cüzdandan düşmeli ve koltuğu azaltmalı', () async {
      String result = await ticketService.buyTickets(
        userId: testUserId,
        flightId: flightA_Id,
        tickets: [_createMockTicket(testUserId, flightA_Id)], 
        totalPrice: 1000.0,
      );
      expect(result, "success");
      var user = await firestore.collection('users').doc(testUserId).get();
      expect(user['walletBalance'], 9000.0); 
      var flight = await firestore.collection('flights').doc(flightA_Id).get();
      expect(flight['availableSeats'], 99); 
    });

    test('Senaryo 3: Check-in kapasiteyi DÜŞÜRMEZ, sadece koltuk no atar', () async {
      await ticketService.buyTickets(
        userId: testUserId, flightId: flightA_Id, totalPrice: 1000.0,
        tickets: [_createMockTicket(testUserId, flightA_Id)], 
      );
      var ticketDocs = await firestore.collection('tickets').where('userId', isEqualTo: testUserId).get();
      String ticketId = ticketDocs.docs.first.id;

      String result = await ticketService.performCheckIn(
        ticketId: ticketId, seatNumber: '14C', flightId: flightA_Id
      );
      expect(result, "success");
      var updatedTicket = await firestore.collection('tickets').doc(ticketId).get();
      expect(updatedTicket['status'], 'checked_in');
      expect(updatedTicket['seatNumber'], '14C');
      var flight = await firestore.collection('flights').doc(flightA_Id).get();
      expect(flight['availableSeats'], 99); 
    });

    test('Senaryo 4: İptal edilen bilet parayı iade eder ve koltuğu uçağa geri verir', () async {
      await ticketService.buyTickets(
        userId: testUserId, flightId: flightA_Id, totalPrice: 1000.0,
        tickets: [_createMockTicket(testUserId, flightA_Id)], 
      );
      var ticketDocs = await firestore.collection('tickets').where('userId', isEqualTo: testUserId).get();
      String ticketId = ticketDocs.docs.first.id;

      await ticketService.cancelTicket(
        ticketId: ticketId, flightId: flightA_Id, userId: testUserId, seatClass: 'economy'
      );
      var user = await firestore.collection('users').doc(testUserId).get();
      expect(user['walletBalance'], 10000.0);
      var flight = await firestore.collection('flights').doc(flightA_Id).get();
      expect(flight['availableSeats'], 100);
      var cancelledTicket = await firestore.collection('tickets').doc(ticketId).get();
      expect(cancelledTicket['status'], 'cancelled');
    });

    test('Senaryo 5: Uçuş Değiştirildiğinde eski koltuk iade edilir, yenisi düşer, fiyat farkı alınır', () async {
      await ticketService.buyTickets(
        userId: testUserId, flightId: flightA_Id, totalPrice: 1000.0,
        tickets: [_createMockTicket(testUserId, flightA_Id)], 
      );
      var ticketDocs = await firestore.collection('tickets').where('userId', isEqualTo: testUserId).get();
      var oldTicket = TicketModel.fromMap(ticketDocs.docs.first.data(), ticketDocs.docs.first.id);

      var newFlightDoc = await firestore.collection('flights').doc(flightB_Id).get();
      var newFlight = FlightModel.fromMap(newFlightDoc.data()!, newFlightDoc.id);

      String result = await ticketService.changeTicket(
        oldTicket: oldTicket, newFlight: newFlight, priceDifference: 200.0
      );
      expect(result, "success");

      var user = await firestore.collection('users').doc(testUserId).get();
      expect(user['walletBalance'], 8800.0); // 10.000 - 1000 - 200

      var flightA = await firestore.collection('flights').doc(flightA_Id).get();
      expect(flightA['availableSeats'], 100); // Eski uçuşa koltuk iade edildi

      var flightB = await firestore.collection('flights').doc(flightB_Id).get();
      expect(flightB['availableSeats'], 99); // Yeni uçuştan koltuk alındı
    });
  });
}

TicketModel _createMockTicket(String userId, String flightId) {
  return TicketModel(
    id: '', pnrCode: 'TEST', userId: userId, flightId: flightId,
    flightNumber: 'TK-TEST', origin: 'IST', destination: 'ANK',
    arrivalTime: DateTime.now(), terminal: '1', passengerName: 'Test',
    passengerTcNo: '123', contactEmail: '', contactPhone: '',
    passengerSex: 'Erkek', createdAt: DateTime.now(), date: DateTime.now(), seatClass: 'economy'
  );
}
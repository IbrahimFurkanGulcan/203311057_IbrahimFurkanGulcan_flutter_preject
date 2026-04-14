import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/flight_model.dart';

class DummyDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> generateMockFlights() async {
    try {
      // Yurt içi ve Yurt dışı ayrımı
      List<String> domestic = ['İstanbul', 'Ankara', 'İzmir', 'Antalya'];
      List<String> international = ['Paris', 'New York', 'Londra', 'Dubai'];
      List<String> allAirports = [...domestic, ...international];

      Random random = Random();
      WriteBatch batch = _firestore.batch();
      int operationCount = 0; // YENİ: Batch sınırını takip edecek sayaç

      // Önümüzdeki 15 gün boyunca veri üretebiliriz artık sınırımız yok!
      for (int day = 1; day <= 15; day++) { 
        for (int i = 0; i < allAirports.length; i++) {
          for (int j = 0; j < allAirports.length; j++) {
            if (i == j) continue;

            String origin = allAirports[i];
            String destination = allAirports[j];

            // Rota yurt içi mi kontrol et
            bool isDomesticRoute = domestic.contains(origin) && domestic.contains(destination);
            
            // Yurt içiyse günde 3 uçuş, değilse 1 uçuş
            int flightsPerDay = isDomesticRoute ? 3 : 1;

            for (int k = 0; k < flightsPerDay; k++) {
              DateTime flightDate = DateTime.now().add(Duration(days: day)).copyWith(
                    // Yurt içiyse 08:00, 14:00, 20:00 gibi dağıt. Yurt dışıysa rastgele bir saat ver.
                    hour: flightsPerDay == 3 ? 8 + (k * 6) : random.nextInt(14) + 8, 
                    minute: random.nextInt(60),
                  );

              DocumentReference docRef = _firestore.collection('flights').doc();
              FlightModel dummyFlight = FlightModel(
                id: docRef.id,
                flightNumber: 'TK-${random.nextInt(8999) + 1000}',
                origin: origin,
                destination: destination,
                date: flightDate,
                // Yurt dışı biletleri daha pahalı olsun
                price: isDomesticRoute 
                    ? (random.nextDouble() * 1500 + 1000).roundToDouble() 
                    : (random.nextDouble() * 5000 + 3000).roundToDouble(),
                totalSeats: 150,
                availableSeats: 150,
                status: 'scheduled',
                gate: '${random.nextInt(50) + 1}${['A', 'B', 'C'][random.nextInt(3)]}',
              );

              batch.set(docRef, dummyFlight.toMap());
              operationCount++;

              // YENİ: BATCH SINIRI KONTROLÜ (500'e yaklaşınca gönder, yeni paket aç)
              if (operationCount >= 450) {
                await batch.commit();
                batch = _firestore.batch(); // Paketi sıfırla
                operationCount = 0; // Sayacı sıfırla
              }
            }
          }
        }
      }

      // Döngü bittiğinde pakette kalan son uçuşları da gönder
      if (operationCount > 0) {
        await batch.commit();
      }

      return "success";
    } catch (e) {
      return "Hata: $e";
    }
  }
}
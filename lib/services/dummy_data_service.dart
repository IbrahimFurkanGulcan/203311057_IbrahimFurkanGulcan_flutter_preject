import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/flight_model.dart';

class DummyDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> generateMockFlights() async {
    try {
      // Gerçekçi Havalimanı ve Terminal Sözlüğü (Her Şehre Özel)
      final Map<String, Map<String, List<String>>> cityAirports = {
        'İstanbul': {
          'İstanbul Havalimanı (IST)': ['İç Hatlar - T1', 'Dış Hatlar - T1'],
          'Sabiha Gökçen (SAW)': ['İç Hatlar', 'Dış Hatlar']
        },
        'Ankara': {
          'Esenboğa (ESB)': ['İç Hatlar', 'Dış Hatlar'],
          'Etimesgut (ETI)': ['Ana Terminal'] // Sistemin kuralları gereği eklendi
        },
        'İzmir': {
          'Adnan Menderes (ADB)': ['İç Hatlar', 'Dış Hatlar'],
          'Çiğli (IGL)': ['Terminal 1'] // Sistemin kuralları gereği eklendi
        },
        'Antalya': {
          'Antalya Hvl. (AYT)': ['Terminal 1', 'Terminal 2', 'İç Hatlar'],
          'Gazipaşa (GZP)': ['Ana Terminal']
        },
        'Paris': {
          'Charles de Gaulle (CDG)': ['Terminal 1', 'Terminal 2E', 'Terminal 3'],
          'Orly (ORY)': ['Terminal 1', 'Terminal 2', 'Terminal 3', 'Terminal 4']
        },
        'New York': {
          'JFK': ['Terminal 1', 'Terminal 4', 'Terminal 5', 'Terminal 8'],
          'Newark (EWR)': ['Terminal A', 'Terminal B', 'Terminal C']
        },
        'Londra': {
          'Heathrow (LHR)': ['Terminal 2', 'Terminal 3', 'Terminal 4', 'Terminal 5'],
          'Gatwick (LGW)': ['North Terminal', 'South Terminal'],
          'Stansted (STN)': ['Main Terminal']
        },
        'Dubai': {
          'Dubai Intl (DXB)': ['Terminal 1', 'Terminal 2', 'Terminal 3'],
          'Al Maktoum (DWC)': ['Ana Terminal']
        }
      };

      List<String> domestic = ['İstanbul', 'Ankara', 'İzmir', 'Antalya'];
      List<String> allCities = cityAirports.keys.toList();

      Random random = Random();
      WriteBatch batch = _firestore.batch();
      int operationCount = 0; 

      for (int day = 1; day <= 15; day++) { 
        for (int i = 0; i < allCities.length; i++) {
          for (int j = 0; j < allCities.length; j++) {
            if (i == j) continue;

            String originCity = allCities[i];
            String destinationCity = allCities[j];
            bool isDomesticRoute = domestic.contains(originCity) && domestic.contains(destinationCity);
            int flightsPerDay = isDomesticRoute ? 3 : 1;

            // Şehre ait rastgele bir havalimanı ve o havalimanına ait terminali seçiyoruz
            List<String> originAirportsList = cityAirports[originCity]!.keys.toList();
            String selectedOriginAirport = originAirportsList[random.nextInt(originAirportsList.length)];
            
            List<String> terminalsList = cityAirports[originCity]![selectedOriginAirport]!;
            String selectedTerminal = terminalsList[random.nextInt(terminalsList.length)];

            for (int k = 0; k < flightsPerDay; k++) {
              DateTime flightDate = DateTime.now().add(Duration(days: day)).copyWith(
                    hour: flightsPerDay == 3 ? 8 + (k * 6) : random.nextInt(14) + 8, 
                    minute: random.nextInt(60),
                  );
              
              // TUTARLI VARIŞ SAATİ ALGORİTMASI
              int baseDuration = _getBaseDuration(originCity, destinationCity);
              // Hava durumu/Rüzgar etkisi: -5 dakika erken varabilir veya +10 dakika rötar yapabilir
              int weatherEffect = random.nextInt(16) - 5; 
              int flightDurationMinutes = baseDuration + weatherEffect;
              
              DateTime arrivalTime = flightDate.add(Duration(minutes: flightDurationMinutes));
              DocumentReference docRef = _firestore.collection('flights').doc();
              FlightModel dummyFlight = FlightModel(
                id: docRef.id,
                flightNumber: 'TK-${random.nextInt(8999) + 1000}',
                origin: originCity,           // Arama motoru için şehir adı (İstanbul)
                destination: destinationCity, // Arama motoru için şehir adı (Londra)
                date: flightDate,
                arrivalTime: arrivalTime,
                // Havalimanı adını ve Terminali birleştirerek yazıyoruz!
                terminal: '$selectedOriginAirport - $selectedTerminal', 
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

              if (operationCount >= 450) {
                await batch.commit();
                batch = _firestore.batch(); 
                operationCount = 0; 
              }
            }
          }
        }
      }

      if (operationCount > 0) {
        await batch.commit();
      }

      return "success";
    } catch (e) {
      return "Hata: $e";
    }
  }

  // Rotalara göre tutarlı baz uçuş süreleri (Dakika cinsinden)
  int _getBaseDuration(String origin, String destination) {
    // Önemli rotalar için gerçekçi süreler (İki yönlü de ortalama aynıdır)
    if ((origin == 'İstanbul' && destination == 'Ankara') || (origin == 'Ankara' && destination == 'İstanbul')) return 65;
    if ((origin == 'İstanbul' && destination == 'İzmir') || (origin == 'İzmir' && destination == 'İstanbul')) return 70;
    if ((origin == 'İstanbul' && destination == 'Antalya') || (origin == 'Antalya' && destination == 'İstanbul')) return 85;
    if ((origin == 'Ankara' && destination == 'İzmir') || (origin == 'İzmir' && destination == 'Ankara')) return 80;
    
    // Yurt dışı uçuşları
    if (origin == 'New York' || destination == 'New York') return 660; // ~11 saat
    if (origin == 'Dubai' || destination == 'Dubai') return 270; // ~4.5 saat
    if (origin == 'Londra' || destination == 'Londra') return 240; // ~4 saat
    if (origin == 'Paris' || destination == 'Paris') return 210; // ~3.5 saat

    // Tanımlanmamış rastgele bir yurt içi rotası denk gelirse standart 75 dakika ver
    return 75; 
  }
}
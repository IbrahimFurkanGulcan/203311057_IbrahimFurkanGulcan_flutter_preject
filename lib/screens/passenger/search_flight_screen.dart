import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/flight_model.dart';
import '../../models/ticket_model.dart';
import '../../services/flight_service.dart';
import '../../services/ticket_service.dart';

class SearchFlightScreen extends StatefulWidget {
  const SearchFlightScreen({super.key});

  @override
  State<SearchFlightScreen> createState() => _SearchFlightScreenState();
}

class _SearchFlightScreenState extends State<SearchFlightScreen> {
  // Arama Formu Kontrolcüleri
  String _selectedOrigin = 'İstanbul';
  String _selectedDestination = 'Ankara';
  DateTime _selectedDate = DateTime.now();
  int _passengerCount = 1;

  // Havalimanı Listesi (Test verilerimizdeki lokasyonlar)
  final List<String> _airports = [
    'İstanbul',
    'Ankara',
    'İzmir',
    'Antalya',
    'Paris',
    'New York',
    'Londra',
    'Dubai',
  ];

  bool _isSearching = false;
  List<FlightModel> _searchResults = [];

  // Tarih Seçici
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() { _selectedDate = picked; });
    }
  }

  // Uçuşları Ara
  void _searchFlights({bool isFlexible = false}) async {
    if (_selectedOrigin == _selectedDestination) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kalkış ve Varış noktası aynı olamaz!')));
      return;
    }

    setState(() { _isSearching = true; });

    List<FlightModel> results = await FlightService().searchFlights(
      origin: _selectedOrigin,
      destination: _selectedDestination,
      date: _selectedDate,
      passengerCount: _passengerCount,
      isFlexible: isFlexible, // Burayı ekledik
    );

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  // Ödeme ve Biletleme Penceresi (BottomSheet)
  void _showBookingModal(FlightModel flight) {
    double totalPrice = flight.price * _passengerCount;
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Uçuş Özeti ve Ödeme', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Text('Uçuş: ${flight.flightNumber} (${flight.origin} -> ${flight.destination})', style: const TextStyle(fontSize: 16)),
                  Text('Tarih: ${flight.date.day}/${flight.date.month}/${flight.date.year}', style: const TextStyle(fontSize: 16)),
                  Text('Yolcu Sayısı: $_passengerCount Kişi', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  Text('Ödenecek Toplam Tutar: $totalPrice TL', style: const TextStyle(fontSize: 20, color: Colors.blue, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  isProcessing
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () async {
                            setModalState(() { isProcessing = true; });

                            // 1. Kullanıcıyı getir
                            User? currentUser = FirebaseAuth.instance.currentUser;
                            if (currentUser == null) return;

                            // 2. Bilet modellerini hazırla (Kaç kişiyse o kadar bilet)
                            List<TicketModel> newTickets = [];
                            for (int i = 0; i < _passengerCount; i++) {
                              newTickets.add(TicketModel(
                                id: '', pnrCode: '', // Servis dolduracak
                                userId: currentUser.uid,
                                flightId: flight.id,
                                passengerName: 'Yolcu ${i + 1}', // Gerçek projede formdan alınır
                                passengerTcNo: '11111111111', 
                                contactEmail: currentUser.email ?? '',
                                contactPhone: '05000000000',
                                passengerSex: 'Belirtilmedi',
                              ));
                            }

                            // 3. Transaction'ı (Satın Almayı) Başlat!
                            String result = await TicketService().buyTickets(
                              userId: currentUser.uid,
                              flightId: flight.id,
                              tickets: newTickets,
                              totalPrice: totalPrice,
                            );

                            setModalState(() { isProcessing = false; });

                            if (!context.mounted) return;
                            Navigator.pop(context); // Modalı kapat

                            if (result == "success") {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Biletiniz başarıyla alındı! 🎉'), backgroundColor: Colors.green),
                              );
                              // Uçuşları yenile (kapasite düştüğünü görmek için)
                              _searchFlights();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Hata: $result'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          child: const Text('Cüzdan ile Öde ve Bileti Kes', style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ARAMA FORMU (Üst Kısım)
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedOrigin,
                      decoration: const InputDecoration(labelText: 'Nereden', border: OutlineInputBorder()),
                      // Liste elemanlarını basitçe Text'e çeviriyoruz
                      items: _airports.map((ap) => DropdownMenuItem(value: ap, child: Text(ap))).toList(),
                      onChanged: (val) => setState(() => _selectedOrigin = val!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedDestination,
                      decoration: const InputDecoration(labelText: 'Nereye', border: OutlineInputBorder()),
                      // Liste elemanlarını basitçe Text'e çeviriyoruz
                      items: _airports.map((ap) => DropdownMenuItem(value: ap, child: Text(ap))).toList(),
                      onChanged: (val) => setState(() => _selectedDestination = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _passengerCount,
                      decoration: const InputDecoration(labelText: 'Kişi', border: OutlineInputBorder()),
                      items: [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n Yolcu'))).toList(),
                      onChanged: (val) => setState(() => _passengerCount = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _searchFlights(isFlexible: false),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue),
                      child: const Text('Uçuş Bul', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _searchFlights(isFlexible: true),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      child: const Text('Tüm Tarihler'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ARAMA SONUÇLARI LİSTESİ (Alt Kısım)
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? const Center(child: Text('Bu kriterlere uygun uçuş bulunamadı.\n(Lütfen Test tarihlerini deneyin)'))
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        FlightModel flight = _searchResults[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: const Icon(Icons.flight, color: Colors.blue, size: 40),
                            title: Text('${flight.flightNumber} | ${flight.date.hour}:${flight.date.minute.toString().padLeft(2, '0')}'),
                            subtitle: Text('Boş Koltuk: ${flight.availableSeats}'),
                            trailing: Text('${flight.price} TL', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                            onTap: () => _showBookingModal(flight),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
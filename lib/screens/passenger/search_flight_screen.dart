import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/flight_model.dart';
import '../../models/ticket_model.dart';
import '../../services/flight_service.dart';
import '../../services/ticket_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

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

  UserModel? _userProfile;

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

  final GlobalKey<FormState> _modalFormKey = GlobalKey<FormState>();

  bool _isSearching = false;
  List<FlightModel> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile(); // Sayfa açılırken profili yükle
  }

  // Giriş yapan kişinin verilerini bir kez çekip hafızaya alıyoruz
  Future<void> _loadUserProfile() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userProfile = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        });
      }
    }
  }

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

  // Ödeme ve Dinamik Yolcu Bilgileri Penceresi (BottomSheet)
  void _showBookingModal(FlightModel flight) {
    double basePrice = flight.price;
    bool isProcessing = false;

    // Her yolcu için ayrı form kontrolcüleri ve durum değişkenleri oluşturuyoruz
    
    List<TextEditingController> nameControllers = List.generate(_passengerCount, (i) {
      String initialName = (i == 0 && _userProfile != null) ? _userProfile!.fullName : "";
      return TextEditingController(text: initialName);
    });

    List<TextEditingController> phoneControllers = List.generate(_passengerCount, (i) {
      String initialPhone = (i == 0 && _userProfile != null) ? (_userProfile!.phoneNumber ?? "") : "";
      return TextEditingController(text: initialPhone);
    });

    List<TextEditingController> tcControllers = List.generate(_passengerCount, (i) => TextEditingController());
    List<String> seatClasses = List.generate(_passengerCount, (i) => 'economy');
    List<String> passengerSexes = List.generate(_passengerCount, (i) => 'Belirtilmedi');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Ekranı tam kaplayabilmesi için
      backgroundColor: Colors.transparent, // Arka planı şeffaf yapıp kendimiz şekillendireceğiz
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            
            // Toplam fiyatı, seçilen koltuk sınıflarına göre dinamik hesaplayan fonksiyon
            double calculateTotalPrice() {
              double total = 0;
              for (String seatClass in seatClasses) {
                total += seatClass == 'business' ? basePrice * 2.5 : basePrice; // Business 2.5 katı
              }
              return total;
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.90, // Ekranın %90'ını kaplasın (klavye için alan)
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, // Klavye açılınca ekranı yukarı iter
                left: 20, right: 20, top: 20,
              ),
              child: Form(
                key: _modalFormKey,
                child: Column(
                  children: [
                    Text('${flight.origin} ➔ ${flight.destination} | Uçuş: ${flight.flightNumber}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    
                    // YOLCU BİLGİ FORMLARI LİSTESİ (Kişi sayısı kadar döner)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _passengerCount,
                        itemBuilder: (context, index) {
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${index + 1}. Yolcu Bilgileri', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: nameControllers[index],
                                    decoration: const InputDecoration(labelText: 'Ad Soyad', isDense: true, border: OutlineInputBorder()),
                                    validator: (v) => v!.isEmpty ? 'Zorunlu' : null,
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: tcControllers[index],
                                    keyboardType: TextInputType.number,
                                    maxLength: 11,
                                    decoration: const InputDecoration(labelText: 'TC Kimlik No', isDense: true, border: OutlineInputBorder(), counterText: ""),
                                    validator: (v) => v!.length != 11 ? '11 Haneli Olmalı' : null,
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: phoneControllers[index],
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(labelText: 'Telefon No', isDense: true, border: OutlineInputBorder()),
                                    validator: (v) => v!.isEmpty ? 'Zorunlu' : null,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: passengerSexes[index],
                                          decoration: const InputDecoration(labelText: 'Cinsiyet', isDense: true, border: OutlineInputBorder()),
                                          items: ['Belirtilmedi', 'Erkek', 'Kadın'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                          onChanged: (val) => setModalState(() => passengerSexes[index] = val!),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: seatClasses[index],
                                          decoration: const InputDecoration(labelText: 'Koltuk Sınıfı', isDense: true, border: OutlineInputBorder()),
                                          items: const [
                                            DropdownMenuItem(value: 'economy', child: Text('Economy')),
                                            DropdownMenuItem(value: 'business', child: Text('Business')),
                                          ],
                                          onChanged: (val) {
                                            // Seçim değiştiğinde toplam fiyatın da değişmesi için setModalState yapıyoruz
                                            setModalState(() { seatClasses[index] = val!; });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // ALT KISIM: TOPLAM FİYAT VE ÖDEME BUTONU
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          Text('Ödenecek Toplam Tutar: ${calculateTotalPrice()} TL', 
                              style: const TextStyle(fontSize: 20, color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          isProcessing
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                    backgroundColor: Colors.green,
                                  ),
                                  onPressed: () async {
                                    // Eğer formda boş yer varsa veya TC 11 hane değilse durdur
                                    if (!_modalFormKey.currentState!.validate()) return;
                                    
                                    setModalState(() { isProcessing = true; });

                                    User? currentUser = FirebaseAuth.instance.currentUser;
                                    if (currentUser == null) return;

                                    List<TicketModel> newTickets = [];
                                    // Formdan gelen gerçek verileri Modellere aktarıyoruz
                                    for (int i = 0; i < _passengerCount; i++) {
                                      newTickets.add(TicketModel(
                                        id: '', pnrCode: '', 
                                        userId: currentUser.uid,
                                        flightId: flight.id,
                                        passengerName: nameControllers[i].text.trim().toUpperCase(),
                                        passengerTcNo: tcControllers[i].text.trim(), 
                                        contactEmail: currentUser.email ?? '', // Bileti alan kişinin maili eklendi
                                        contactPhone: phoneControllers[i].text.trim(),
                                        passengerSex: passengerSexes[i],
                                        seatClass: seatClasses[i],
                                      ));
                                    }

                                    // Transaction işlemi
                                    String result = await TicketService().buyTickets(
                                      userId: currentUser.uid,
                                      flightId: flight.id,
                                      tickets: newTickets,
                                      totalPrice: calculateTotalPrice(),
                                    );

                                    setModalState(() { isProcessing = false; });

                                    if (!context.mounted) return;
                                    Navigator.pop(context); // Paneli kapat

                                    if (result == "success") {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Biletler başarıyla alındı! 🎉'), backgroundColor: Colors.green),
                                      );
                                      // Arka plandaki uçuş listesini kapasite değiştiği için yenile
                                      _searchFlights(isFlexible: true); 
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Hata: $result'), backgroundColor: Colors.red),
                                      );
                                    }
                                  },
                                  child: const Text('Cüzdan ile Öde ve Bileti Kes', style: TextStyle(fontSize: 18, color: Colors.white)),
                                ),
                        ],
                      ),
                    )
                  ],
                ),
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
                        
                        // Koltuk sayısına göre dinamik uyarı yazısı
                        Widget seatInfo = flight.availableSeats <= 10
                            ? Text('🔥 Son ${flight.availableSeats} Koltuk!', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                            : Text('Boş Koltuk: ${flight.availableSeats}', style: const TextStyle(color: Colors.grey));

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: const Icon(Icons.flight, color: Colors.blue, size: 40),
                            title: Text('${flight.flightNumber} | ${flight.date.hour.toString().padLeft(2, '0')}:${flight.date.minute.toString().padLeft(2, '0')}'),
                            subtitle: seatInfo, 
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
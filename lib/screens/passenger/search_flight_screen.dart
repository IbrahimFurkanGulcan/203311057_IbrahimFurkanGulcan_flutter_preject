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
  bool _isRoundTrip = false; // Çift yön mü?
  DateTime? _returnDate;     // Dönüş tarihi
  FlightModel? _selectedOutboundFlight; // Seçilen ilk uçuş (Sepet)
  bool _isAdmin = false;
  UserModel? _userProfile;

  // Havalimanı Listesi (Test verilerimizdeki lokasyonlar)
  final List<String> _airports = [                             //admin kendi uçuş eklerse burda nasıl görüntüleyecek
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
          _isAdmin = (doc.data() as Map<String, dynamic>)['role'] == 'admin';
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

    // Set state ONCE before the async call
    setState(() { _isSearching = true; });

    // The potentially heavy API call
    List<FlightModel> results = await FlightService().searchFlights(
      origin: _selectedOrigin,
      destination: _selectedDestination,
      date: _selectedDate,
      passengerCount: _passengerCount,
      isFlexible: isFlexible,
    );

    // Guard against the widget being unmounted during the await
    if (!mounted) return;

    // Set state ONCE after the async call
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  
  // Ödeme ve Dinamik Yolcu Bilgileri Penceresi (BottomSheet) - GİDİŞ/DÖNÜŞ DESTEKLİ
  void _showBookingModal(FlightModel currentFlight) {
    // Eğer Gidiş-Dönüş seçildiyse; elimizde bir ilk uçuş (outbound) ve şu an tıklanan uçuş (return) var demektir.
    FlightModel? outboundFlight = _selectedOutboundFlight;
    bool isRoundTripBooking = _isRoundTrip && outboundFlight != null;

    // Fiyat hesaplaması: Tek yönse tek fiyat, çift yönse iki uçuşun toplam baz fiyatı
    double basePrice = isRoundTripBooking 
        ? outboundFlight.price + currentFlight.price 
        : currentFlight.price;
        
    bool isProcessing = false;

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
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            
            double calculateTotalPrice() {
              double total = 0;
              for (String seatClass in seatClasses) {
                total += seatClass == 'business' ? basePrice * 2.5 : basePrice; 
              }
              return total;
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: Form(
                key: _modalFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BAŞLIK BÖLÜMÜ (Tek mi Çift Yön mü?)
                    if (isRoundTripBooking) ...[
                      const Text('✈️ GİDİŞ:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      Text('${outboundFlight.origin} ➔ ${outboundFlight.destination} | Uçuş: ${outboundFlight.flightNumber}', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 5),
                      const Text('🛬 DÖNÜŞ:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      Text('${currentFlight.origin} ➔ ${currentFlight.destination} | Uçuş: ${currentFlight.flightNumber}', style: const TextStyle(fontSize: 16)),
                    ] else ...[
                      Text('${currentFlight.origin} ➔ ${currentFlight.destination} | Uçuş: ${currentFlight.flightNumber}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                    const Divider(),
                    
                    // YOLCU BİLGİ FORMLARI LİSTESİ
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
                                    if (!_modalFormKey.currentState!.validate()) return;
                                    setModalState(() { isProcessing = true; });

                                    User? currentUser = FirebaseAuth.instance.currentUser;
                                    if (currentUser == null) return;

                                    List<TicketModel> newTickets = [];
                                    
                                    // Yardımcı fonksiyon: Bilet modelini oluşturur
                                    void addTicketToList(FlightModel flight, int index) {

                                      double calculatedTicketPrice = seatClasses[index] == 'business' 
                                                                    ? flight.price * 2.5 
                                                                    : flight.price;

                                      newTickets.add(TicketModel(
                                        id: '', pnrCode: '', userId: currentUser.uid, flightId: flight.id,
                                        passengerName: nameControllers[index].text.trim().toUpperCase(),
                                        passengerTcNo: tcControllers[index].text.trim(), 
                                        contactEmail: currentUser.email ?? '', contactPhone: phoneControllers[index].text.trim(),
                                        passengerSex: passengerSexes[index], seatClass: seatClasses[index], 
                                        createdAt: DateTime.now(), date: flight.date, flightNumber: flight.flightNumber,
                                        origin: flight.origin, destination: flight.destination,
                                        arrivalTime: flight.arrivalTime, terminal: flight.terminal ?? 'Belirtilmedi', price: calculatedTicketPrice,
                                      ));
                                    }

                                    // Her yolcu için biletleri oluştur (Gidiş-Dönüş ise her yolcuya 2 bilet kesilir)
                                    for (int i = 0; i < _passengerCount; i++) {
                                      if (isRoundTripBooking) {
                                        addTicketToList(outboundFlight, i); // Gidiş bileti
                                        addTicketToList(currentFlight, i);   // Dönüş bileti
                                      } else {
                                        addTicketToList(currentFlight, i);   // Sadece tek yön bileti
                                      }
                                    }

                                    // Yeni Transaction sistemine biletleri gönder
                                    String result = await TicketService().buyTickets(
                                      userId: currentUser.uid,
                                      tickets: newTickets,
                                      totalPrice: calculateTotalPrice(), flightId: '',
                                    );

                                    setModalState(() { isProcessing = false; });

                                    if (!context.mounted) return;
                                    Navigator.pop(context); // Paneli kapat

                                    if (result == "success") {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Biletler başarıyla alındı! 🎉'), backgroundColor: Colors.green),
                                      );
                                      // İşlem bittiğinde sepeti sıfırla ve listeyi yenile
                                      setState(() { _selectedOutboundFlight = null; });
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

  
  // --- ADMİN İŞLEMLERİ ---
  void _showDelayDialog(FlightModel flight) {
    int delayHours = 2;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog( // DEĞİŞTİ: context yerine dialogContext yazdık
        title: Text('${flight.flightNumber} Rötar Ekle'),
        content: DropdownButtonFormField<int>(
          initialValue: delayHours,
          decoration: const InputDecoration(labelText: 'Erteleme Süresi'),
          items: [1, 2, 3, 4, 5, 12, 24].map((h) => DropdownMenuItem(value: h, child: Text('$h Saat'))).toList(),
          onChanged: (val) => delayHours = val!,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')), // DEĞİŞTİ
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              // 1. Önce Dialogu kendi context'i ile güvenle kapat
              Navigator.pop(dialogContext); 
              
              // 2. Artık Ana Ekranın (State) context'indeyiz, güvenle SnackBar gösterebiliriz
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İşleniyor...')));
              
              String res = await FlightService().delayFlight(flight.id, Duration(hours: delayHours));
              
              // 3. Bekleme sonrası Ana Ekran hala açık mı kontrolü (Hata engelleyici)
              if (!mounted) return; 
              
              if (res == "success") {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rötar eklendi ve yolculara bildirildi!'), backgroundColor: Colors.green));
                _searchFlights(isFlexible: true); 
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res), backgroundColor: Colors.red));
              }
            },
            child: const Text('Rötarı Onayla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(FlightModel flight) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog( // DEĞİŞTİ: context yerine dialogContext yazdık
        title: const Text('⚠️ Uçuşu İptal Et'),
        content: const Text('Bu uçuş iptal edilecek, tüm biletler geçersiz sayılacak ve ücretler yolculara iade edilecek.\n\nEmin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')), // DEĞİŞTİ
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext); // Dialogu kendi context'i ile kapat
              
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İptal işlemi başlatıldı, lütfen bekleyin...')));
              
              String res = await FlightService().cancelFlightByAdmin(flight.id);
              
              if (!mounted) return; // Ana Ekran kontrolü
              
              if (res == "success") {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uçuş İptal Edildi ve İadeler Yapıldı!'), backgroundColor: Colors.green));
                _searchFlights(isFlexible: true); 
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res), backgroundColor: Colors.red));
              }
            },
            child: const Text('İptal Et', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
              // YENİ: Tek Yön / Gidiş-Dönüş Switch'i
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RadioMenuButton<bool>(
                    value: false,
                    groupValue: _isRoundTrip,
                    onChanged: (val) => setState(() { _isRoundTrip = val!; _returnDate = null; }),
                    child: const Text("Tek Yön"),
                  ),
                  const SizedBox(width: 20),
                  RadioMenuButton<bool>(
                    value: true,
                    groupValue: _isRoundTrip,
                    onChanged: (val) => setState(() { _isRoundTrip = val!; _returnDate = DateTime.now().add(const Duration(days: 1)); }),
                    child: const Text("Gidiş-Dönüş"),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // TARİH VE KİŞİ SEÇİMİ
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.flight_takeoff),
                      label: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                    ),
                  ),
                  const SizedBox(width: 5),
                  if (_isRoundTrip) // Sadece gidiş-dönüşse görünür
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade100),
                        onPressed: () async {
                           final DateTime? picked = await showDatePicker(context: context, initialDate: _returnDate!, firstDate: _selectedDate, lastDate: DateTime.now().add(const Duration(days: 60)));
                           if (picked != null) setState(() { _returnDate = picked; });
                        },
                        icon: const Icon(Icons.flight_land, color: Colors.blue),
                        label: Text('${_returnDate?.day}/${_returnDate?.month}/${_returnDate?.year}', style: const TextStyle(color: Colors.blue)),
                      ),
                    ),
                  const SizedBox(width: 5),
                  Expanded(
                    // Kişi seçimi dropdown'ı (Eski kodun aynısı)
                    child: DropdownButtonFormField<int>(
                      initialValue: _passengerCount,
                      decoration: const InputDecoration(labelText: 'Kişi', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
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
                            title: Text('${flight.flightNumber} | ${flight.origin} ➔ ${flight.destination}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('${flight.date.hour.toString().padLeft(2, '0')}:${flight.date.minute.toString().padLeft(2, '0')} Kalkış ➔ ${flight.arrivalTime.hour.toString().padLeft(2, '0')}:${flight.arrivalTime.minute.toString().padLeft(2, '0')} Varış', 
                                     style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                Text('Terminal: ${flight.terminal ?? "Belirtilmedi"}', style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                                const SizedBox(height: 4),
                                seatInfo, 
                              ],
                            ),
                            // YENİ ADMİN MENÜLÜ FİYAT KISMI
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${flight.price} TL', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                                if (_isAdmin)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.red),
                                    onSelected: (value) {
                                      if (value == 'delay') _showDelayDialog(flight);
                                      if (value == 'cancel') _showCancelDialog(flight);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'delay', child: Text('⏳ Rötar Ekle')),
                                      const PopupMenuItem(value: 'cancel', child: Text('❌ Uçuşu İptal Et', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                              ],
                            ),
                            // SİLİNEN TIKLAMA FONKSİYONU BURAYA GERİ GELDİ
                            onTap: () {
                              if (_isRoundTrip && _selectedOutboundFlight == null) {
                                setState(() {
                                  _selectedOutboundFlight = flight;
                                  _isSearching = true;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gidiş uçuşu seçildi! Şimdi dönüş uçuşunu seçin.'), backgroundColor: Colors.orange));
                                
                                FlightService().searchFlights(
                                  origin: _selectedDestination, destination: _selectedOrigin,
                                  date: _returnDate!, passengerCount: _passengerCount, isFlexible: false
                                ).then((results) {
                                  if (mounted) setState(() { _searchResults = results; _isSearching = false; });
                                });
                              } else {                                
                                _showBookingModal(flight);
                              }
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
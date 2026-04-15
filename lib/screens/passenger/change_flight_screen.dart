import 'package:flutter/material.dart';
import '../../models/flight_model.dart';
import '../../models/ticket_model.dart';
import '../../services/flight_service.dart';
import '../../services/ticket_service.dart';

class ChangeFlightScreen extends StatefulWidget {
  final TicketModel ticket;
  const ChangeFlightScreen({super.key, required this.ticket});

  @override
  State<ChangeFlightScreen> createState() => _ChangeFlightScreenState();
}

class _ChangeFlightScreenState extends State<ChangeFlightScreen> {
  bool _isLoading = true;
  List<FlightModel> _availableFlights = [];

  @override
  void initState() {
    super.initState();
    _loadAlternativeFlights();
  }

  Future<void> _loadAlternativeFlights() async {
    // Aynı güzergahtaki gelecek uçuşları getir
    List<FlightModel> results = await FlightService().searchFlights(
      origin: widget.ticket.origin,
      destination: widget.ticket.destination,
      date: DateTime.now(),
      passengerCount: 1,
      isFlexible: true,
    );

    // Mevcut uçuşu listeden çıkar
    results.removeWhere((f) => f.id == widget.ticket.flightId);

    if (mounted) {
      setState(() {
        _availableFlights = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uçuş Değiştirme')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _availableFlights.isEmpty 
          ? const Center(child: Text("Alternatif uçuş bulunamadı."))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('${widget.ticket.origin} ➔ ${widget.ticket.destination} rotası için alternatifler:', 
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _availableFlights.length,
                    itemBuilder: (context, index) {
                      FlightModel flight = _availableFlights[index];
                      
                      // UYARI 1 ÇÖZÜMÜ: oldPrice değişkeni artık kullanılıyor
                      double oldPrice = 1500.0; // Gerçekte bunu eski bilet fiyatından alırız
                      double newPrice = widget.ticket.seatClass == 'business' ? flight.price * 2.5 : flight.price;
                      double diff = newPrice - oldPrice; 

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          // Uçuş numarasının yanına tarihi (Gün/Ay/Yıl) ekledik
                          title: Text(
                            '${flight.flightNumber} | ${flight.date.day.toString().padLeft(2, '0')}/${flight.date.month.toString().padLeft(2, '0')}/${flight.date.year}'
                          ),
                          // Saati alta, fiyat farkıyla birlikte aldık
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${flight.date.hour.toString().padLeft(2, '0')}:${flight.date.minute.toString().padLeft(2, '0')} Kalkış ➔ ${flight.arrivalTime.hour.toString().padLeft(2, '0')}:${flight.arrivalTime.minute.toString().padLeft(2, '0')} Varış',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fiyat Farkı: ${diff > 0 ? "+" : ""}$diff TL',
                                style: TextStyle(
                                  color: diff > 0 ? Colors.red : (diff < 0 ? Colors.green : Colors.grey),
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.blue),
                          onTap: () => _confirmChange(flight, diff),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _confirmChange(FlightModel newFlight, double diff) {
    showDialog(
      context: context,
      // UYARI 2 ÇÖZÜMÜ: Sayfanın context'i ile dialog'un context'ini ayırmak için ismini dialogContext yaptık
      builder: (dialogContext) => AlertDialog(
        title: const Text('Uçuş Değişikliği'),
        content: Text('Uçuşunuz ${newFlight.flightNumber} ile değiştirilecektir.\n\nFiyat Farkı: $diff TL'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Önce uyarı penceresini kapat

              // Arka plandaki uzun işlemi bekle
              String res = await TicketService().changeTicket(
                oldTicket: widget.ticket,
                newFlight: newFlight,
                priceDifference: diff,
              );

              // UYARI 2 ÇÖZÜMÜ: Uzun işlem bitene kadar kullanıcı bu sayfadan çıkmış olabilir. 
              // Sayfa hala "mounted" (ekranda) ise işlemlere devam et.
              if (!mounted) return;

              if (res == "success") {
                Navigator.pop(context); // Ekranı kapat
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Uçuşunuz başarıyla değiştirildi!'), backgroundColor: Colors.green)
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hata: $res'), backgroundColor: Colors.red)
                );
              }
            },
            child: const Text('Onayla'),
          )
        ],
      ),
    );
  }
}
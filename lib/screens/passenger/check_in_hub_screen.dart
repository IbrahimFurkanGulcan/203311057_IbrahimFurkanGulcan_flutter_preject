import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/ticket_model.dart';
import '../../services/ticket_service.dart';
import 'check_in_screen.dart'; 

class CheckInHubScreen extends StatefulWidget {
  const CheckInHubScreen({super.key});

  @override
  State<CheckInHubScreen> createState() => _CheckInHubScreenState();
}

class _CheckInHubScreenState extends State<CheckInHubScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  // PERFORMANS ÇÖZÜMÜ: Stream'i hafızaya alıyoruz (Jank/Kilitlenme Koruması)
  late Stream<List<TicketModel>> _ticketsStream;

  @override
  void initState() {
    super.initState();
    // Sayfa ilk yüklendiğinde Firebase bağlantısını kurar, bir daha koparmaz.
    if (currentUserId != null) {
      _ticketsStream = TicketService().getUserTicketsStream(currentUserId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) return const Center(child: Text("Lütfen giriş yapın."));

    return StreamBuilder<List<TicketModel>>(
      // BURASI ÖNEMLİ: Hafızaya aldığımız stream'i dinliyor!
      stream: _ticketsStream, 
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return _buildEmptyState();

        DateTime now = DateTime.now();
        List<TicketModel> availableForCheckIn = snapshot.data!.where((ticket) {
          int hoursLeft = ticket.date.difference(now).inHours;
          return ticket.status == 'booked' && hoursLeft <= 24 && hoursLeft >= 1;
        }).toList();

        if (availableForCheckIn.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: availableForCheckIn.length,
          itemBuilder: (context, index) {
            TicketModel ticket = availableForCheckIn[index];
            int hoursLeft = ticket.date.difference(now).inHours;

            return Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.blue, width: 1)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Online Check-in Açık', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        Text('Son $hoursLeft Saat', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.flight_takeoff, color: Colors.blue, size: 40),
                      title: Text('${ticket.origin} ➔ ${ticket.destination}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      subtitle: Text('Yolcu: ${ticket.passengerName}\nUçuş: ${ticket.flightNumber}'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                        backgroundColor: Colors.blue,
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => CheckInScreen(ticket: ticket)));
                      },
                      icon: const Icon(Icons.event_seat, color: Colors.white),
                      label: const Text('Koltuk Seç ve Check-in Yap', style: TextStyle(color: Colors.white, fontSize: 16)),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.airplane_ticket_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            const Text('Şu an Check-in yapılacak bir uçuşunuz bulunmuyor.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.black54)),
            const SizedBox(height: 10),
            const Text('Online Check-in işlemleri uçuşunuza 24 saat kala açılır ve 1 saat kala kapanır.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
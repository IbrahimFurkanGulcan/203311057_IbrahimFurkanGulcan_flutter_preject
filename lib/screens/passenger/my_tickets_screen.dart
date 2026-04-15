import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/ticket_model.dart';
import '../../services/ticket_service.dart';
import 'check_in_screen.dart';
import 'change_flight_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Bilet Detay Paneli ve İşlem Butonları
  void _showTicketDetails(BuildContext context, TicketModel ticket) {
    // 1. Zaman Kurallarını Hesapla
    DateTime now = DateTime.now();
    Duration timeDifference = ticket.date.difference(now);
    int hoursLeft = timeDifference.inHours;

    bool isPast = timeDifference.isNegative; // Uçuş geçmişte mi?
    bool isCancelled = ticket.status == 'cancelled';
    bool isCheckedIn = ticket.status == 'checked_in';

    // Kurallarımız (Senin belirlediğin senaryolar)
    bool canCancel = !isPast && !isCancelled && !isCheckedIn && hoursLeft >= 24;
    bool canChange = !isPast && !isCancelled && !isCheckedIn && hoursLeft >= 48;
    bool canCheckIn = !isPast && !isCancelled && !isCheckedIn && hoursLeft <= 24 && hoursLeft >= 1;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PNR: ${ticket.pnrCode}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  _buildStatusBadge(ticket),
                ],
              ),
              const Divider(height: 30),
              Text('Yolcu: ${ticket.passengerName} (${ticket.passengerTcNo})', style: const TextStyle(fontSize: 16)),
              Text('Sınıf: ${ticket.seatClass.toUpperCase()}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              if (!isPast && !isCancelled)
                Text('Uçuşa Kalan Süre: $hoursLeft Saat', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
              
              const SizedBox(height: 30),
              
              // İŞLEM BUTONLARI (Kurallara göre görünür)
              if (canCheckIn)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Önce alt paneli kapat
                    // Gerçek sayfaya yönlendir
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CheckInScreen(ticket: ticket)));
                  },
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: const Text('Check-in Yap', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue),
                ),
                
              if (canChange) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Önce alt paneli kapat
                    // Gerçek Uçuş Değiştirme sayfasına yönlendir
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => ChangeFlightScreen(ticket: ticket))
                    );
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Uçuşu Değiştir'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                ),
              ],

              if (canCancel) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context); // Paneli Kapat
                    _showCancelConfirmDialog(ticket); // Onay penceresi aç
                  },
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  label: const Text('Bileti İptal Et', style: TextStyle(color: Colors.red)),
                  style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                ),
              ],

              if (!canCancel && !canChange && !canCheckIn && !isCancelled && !isPast && !isCheckedIn)
                const Center(
                  child: Text('Check-in işlemleri uçuşa son 24 saat kala açılacaktır.', 
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                )
            ],
          ),
        );
      },
    );
  }

  // İptal Onay Penceresi
  void _showCancelConfirmDialog(TicketModel ticket) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bilet İptali'),
        content: const Text('Biletinizi iptal etmek istediğinize emin misiniz? Bilet tutarı cüzdanınıza iade edilecektir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              // İptal İşlemini Başlat (Backend)
              String result = await TicketService().cancelTicket(
                ticketId: ticket.id,
                flightId: ticket.flightId,
                userId: ticket.userId,
                seatClass: ticket.seatClass,
              );

              if (!context.mounted) return;
              if (result == "success") {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bilet iptal edildi ve ücret iade edildi.'), backgroundColor: Colors.green));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $result'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Evet, İptal Et', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Durum Bildirici Rozet (Badge) Tasarımı
  Widget _buildStatusBadge(TicketModel ticket) {
    Color bgColor = Colors.blue;
    String text = 'Aktif';

    if (ticket.status == 'cancelled') {
      bgColor = Colors.red;
      text = 'İptal Edildi';
    } else if (ticket.status == 'checked_in') {
      bgColor = Colors.green;
      text = 'Check-in Yapıldı';
    } else if (ticket.date.isBefore(DateTime.now())) {
      bgColor = Colors.grey;
      text = 'Uçuş Gerçekleşti';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.1), // withValues ve alpha kullanıldı
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: bgColor)
      ),
      child: Text(text, style: TextStyle(color: bgColor, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) return const Center(child: Text("Lütfen giriş yapın."));

    return StreamBuilder<List<TicketModel>>(
      // Gerçek zamanlı okuma (Bilet iptal edilince anında sayfa güncellenir)
      stream: TicketService().getUserTicketsStream(currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text("Bir hata oluştu: ${snapshot.error}"));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Henüz bir biletiniz bulunmuyor."));

        List<TicketModel> tickets = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            TicketModel ticket = tickets[index];

            return GestureDetector(
              onTap: () => _showTicketDetails(context, ticket),
              child: Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(ticket.flightNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          _buildStatusBadge(ticket),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ticket.origin, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text('${ticket.date.hour.toString().padLeft(2, '0')}:${ticket.date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 16, color: Colors.blue)),
                            ],
                          ),
                          const Icon(Icons.flight_takeoff, color: Colors.blue, size: 30),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(ticket.destination, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text('${ticket.arrivalTime.hour.toString().padLeft(2, '0')}:${ticket.arrivalTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 16, color: Colors.blue)),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Yolcu: ${ticket.passengerName}', style: const TextStyle(color: Colors.black87)),
                          Text('Sınıf: ${ticket.seatClass.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
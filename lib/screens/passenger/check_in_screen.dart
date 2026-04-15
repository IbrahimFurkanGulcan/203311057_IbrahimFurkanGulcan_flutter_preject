import 'package:flutter/material.dart';
import '../../models/ticket_model.dart';
import '../../services/ticket_service.dart';

class CheckInScreen extends StatefulWidget {
  final TicketModel ticket;

  const CheckInScreen({super.key, required this.ticket});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  String? _selectedSeat;
  bool _isProcessing = false;
  late Stream<List<String>> _takenSeatsStream;

  @override
  void initState() {
    super.initState();
    _takenSeatsStream = TicketService().getTakenSeatsStream(widget.ticket.flightId);
  }

  // Koltuk Kutucuğu Tasarımı
  Widget _buildSeat(String seatCode, List<String> takenSeats, {bool isBusiness = false}) {
    bool isTaken = takenSeats.contains(seatCode);
    bool isSelected = _selectedSeat == seatCode;
    // Bilet sınıfı Ekonomi ise ve koltuk Business ise seçimi engelle veya tam tersi
    bool isClassMismatch = (widget.ticket.seatClass == 'economy' && isBusiness) || 
                           (widget.ticket.seatClass == 'business' && !isBusiness);

    Color seatColor = Colors.grey.shade300; // Boş
    Color textColor = Colors.black87;

    if (isTaken || isClassMismatch) {
      seatColor = isClassMismatch ? Colors.grey.shade200 : Colors.red.shade400;
      textColor = isClassMismatch ? Colors.grey.shade400 : Colors.white;
    } else if (isSelected) {
      seatColor = Colors.blue;
      textColor = Colors.white;
    }

    return GestureDetector(
      onTap: () {
        if (isTaken || isClassMismatch) return; // Dolu veya yanlış sınıfsa tıklanamaz
        setState(() { _selectedSeat = seatCode; });
      },
      child: Container(
        width: isBusiness ? 50 : 40,
        height: isBusiness ? 50 : 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: seatColor,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.blue.shade900, width: 2) : null,
        ),
        child: Text(seatCode, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: isBusiness ? 16 : 14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in & Koltuk Seçimi')),
      body: StreamBuilder<List<String>>(
        // ESKİ KOD: stream: TicketService().getTakenSeatsStream(widget.ticket.flightId),
        // YENİ KOD: Artık hafızadaki (cache) stream'i dinliyor, her tıklamada baştan yüklenmiyor!
        stream: _takenSeatsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          List<String> takenSeats = snapshot.data ?? [];

          return AbsorbPointer(
            absorbing: _isProcessing,
            child: Column(
              children: [
              // Uçak Burnu ve Bilgiler
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem(Colors.grey.shade300, 'Boş'),
                    _buildLegendItem(Colors.blue, 'Seçilen'),
                    _buildLegendItem(Colors.red.shade400, 'Dolu'),
                    _buildLegendItem(Colors.grey.shade200, 'Diğer Sınıf'),
                  ],
                ),
              ),
              
              // Koltuk Haritası (Uçak Gövdesi)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  children: [
                    const Icon(Icons.flight_takeoff, size: 60, color: Colors.grey),
                    const SizedBox(height: 20),
                    
                    // BUSINESS CLASS (Sıra 1-5, Düzen: 2-2)
                    Container(padding: const EdgeInsets.all(8), color: Colors.amber.withValues(alpha: 0.2), child: const Center(child: Text('BUSINESS CLASS', style: TextStyle(fontWeight: FontWeight.bold)))),
                    const SizedBox(height: 10),
                    for (int row = 1; row <= 5; row++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSeat('${row}A', takenSeats, isBusiness: true),
                            const SizedBox(width: 8),
                            _buildSeat('${row}B', takenSeats, isBusiness: true),
                            SizedBox(width: 40, child: Center(child: Text('$row', style: const TextStyle(fontWeight: FontWeight.bold)))), // Koridor Numarası
                            _buildSeat('${row}C', takenSeats, isBusiness: true),
                            const SizedBox(width: 8),
                            _buildSeat('${row}D', takenSeats, isBusiness: true),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 20),

                    // ECONOMY CLASS (Sıra 6-27, Düzen: 3-3)
                    Container(padding: const EdgeInsets.all(8), color: Colors.blue.withValues(alpha: 0.1), child: const Center(child: Text('ECONOMY CLASS', style: TextStyle(fontWeight: FontWeight.bold)))),
                    const SizedBox(height: 10),
                    for (int row = 6; row <= 27; row++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSeat('${row}A', takenSeats),
                            const SizedBox(width: 4),
                            _buildSeat('${row}B', takenSeats),
                            const SizedBox(width: 4),
                            _buildSeat('${row}C', takenSeats),
                            SizedBox(width: 30, child: Center(child: Text('$row', style: const TextStyle(fontWeight: FontWeight.bold)))), // Koridor Numarası
                            _buildSeat('${row}D', takenSeats),
                            const SizedBox(width: 4),
                            _buildSeat('${row}E', takenSeats),
                            const SizedBox(width: 4),
                            _buildSeat('${row}F', takenSeats),
                          ],
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // Alt Onay Çubuğu
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, -3))]),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Seçilen Koltuk', style: TextStyle(color: Colors.grey)),
                          Text(_selectedSeat ?? 'Seçilmedi', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                      onPressed: (_selectedSeat == null || _isProcessing) ? null : () async {
                        setState(() { _isProcessing = true; });
                        
                        String result = await TicketService().performCheckIn(
                          ticketId: widget.ticket.id, 
                          seatNumber: _selectedSeat!, 
                          flightId: widget.ticket.flightId
                        );

                        if (!context.mounted) return;
                        setState(() { _isProcessing = false; });

                        if (result == "success") {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in Başarılı! İyi Uçuşlar.'), backgroundColor: Colors.green));
                          Navigator.pop(context); // Sayfayı kapat, biletlerim ekranına dön
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $result'), backgroundColor: Colors.red));
                        }
                      },
                      child: _isProcessing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                        : const Text('Check-in Tamamla', style: TextStyle(color: Colors.white, fontSize: 16)),
                    )
                  ],
                ),
              )
            ],
            )
          );
        }
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
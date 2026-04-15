import 'package:flutter/material.dart';
import '../../models/flight_model.dart';
import '../../services/flight_service.dart';

class AddFlightScreen extends StatefulWidget {
  const AddFlightScreen({super.key});

  @override
  State<AddFlightScreen> createState() => _AddFlightScreenState();
}

class _AddFlightScreenState extends State<AddFlightScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Text Controller'ları
  final _flightNoController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _priceController = TextEditingController();
  final _seatsController = TextEditingController();
  final _gateController = TextEditingController();
  final _durationController = TextEditingController(); 
  final _terminalController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  // Tarih Seçici
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() { _selectedDate = picked; });
    }
  }

  // Saat Seçici
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() { _selectedTime = picked; });
    }
  }

  // Uçuşu Kaydetme
  Future<void> _saveFlight() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen tarih ve saat seçiniz.')),
        );
        return;
      }

      setState(() { _isLoading = true; });

      // Seçilen Tarih ve Saati tek bir DateTime nesnesinde birleştiriyoruz
      final DateTime finalDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      int durationMinutes = int.tryParse(_durationController.text.trim()) ?? 60; // Boşsa 60 dk say
      DateTime calculatedArrival = finalDateTime.add(Duration(minutes: durationMinutes));

      // Modelimizi oluşturuyoruz (id boş, çünkü Firebase kendisi doc id verecek)
      FlightModel newFlight = FlightModel(
        id: '', 
        flightNumber: _flightNoController.text.trim().toUpperCase(),
        origin: _originController.text.trim().toUpperCase(),
        destination: _destinationController.text.trim().toUpperCase(),
        date: finalDateTime,
        price: double.parse(_priceController.text.trim()),
        totalSeats: int.parse(_seatsController.text.trim()),
        availableSeats: int.parse(_seatsController.text.trim()), // Başlangıçta hepsi boş
        gate: _gateController.text.trim().toUpperCase(), 
        arrivalTime: calculatedArrival, // HESAPLANAN VARIŞ SAATİ
        terminal: _terminalController.text.trim(),
      );

      // Servisi çağırıp veritabanına yazıyoruz
      String? result = await FlightService().addFlight(newFlight);

      if (!mounted) return; // Öğrendiğimiz hayat kurtaran taktik!
      
      setState(() { _isLoading = false; });

      if (result == "success") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uçuş başarıyla eklendi!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // İşlem bitince Ana Sayfaya dön
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result ?? 'Bir hata oluştu'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Uçuş Ekle')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _flightNoController,
                  decoration: const InputDecoration(labelText: 'Uçuş No (Örn: TK-777)', border: OutlineInputBorder()),
                  validator: (value) => value!.isEmpty ? 'Boş bırakılamaz' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _originController,
                        decoration: const InputDecoration(labelText: 'Kalkış (Örn: IST)', border: OutlineInputBorder()),
                        validator: (value) => value!.isEmpty ? 'Zorunlu' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _destinationController,
                        decoration: const InputDecoration(labelText: 'Varış (Örn: ESB)', border: OutlineInputBorder()),
                        validator: (value) => value!.isEmpty ? 'Zorunlu' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Fiyat (TL)', border: OutlineInputBorder()),
                        validator: (value) => value!.isEmpty ? 'Zorunlu' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _seatsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Kapasite', border: OutlineInputBorder()),
                        validator: (value) => value!.isEmpty ? 'Zorunlu' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _gateController,
                  decoration: const InputDecoration(labelText: 'Kapı No (Opsiyonel)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Uçuş Süresi (Dk)', border: OutlineInputBorder()),
                        validator: (value) => value!.isEmpty ? 'Zorunlu' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _terminalController,
                        decoration: const InputDecoration(labelText: 'Terminal (Örn: SAW - İç Hatlar)', border: OutlineInputBorder()),
                        validator: (value) => value!.isEmpty ? 'Zorunlu' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Tarih ve Saat Seçim Butonları
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_selectedDate == null 
                          ? 'Tarih Seç' 
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(_selectedTime == null 
                          ? 'Saat Seç' 
                          : _selectedTime!.format(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _saveFlight,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Uçuşu Kaydet', style: TextStyle(fontSize: 18)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
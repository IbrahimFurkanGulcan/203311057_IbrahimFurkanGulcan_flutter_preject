class UserModel {
  final String uid;
  final String email;
  final String firstName; 
  final String lastName;         
  final String? phoneNumber;
  final String role; // "admin" veya "passenger"

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.role = 'passenger', // Varsayılan olarak herkes yolcu kaydedilir
  });

  // Firebase'den gelen veriyi Dart nesnesine çevirir
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      role: map['role'] ?? 'passenger',
      phoneNumber: map['phoneNumber'],
    );
  }

  // Dart nesnesini Firebase'e yazılacak formata çevirir
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'phoneNumber': phoneNumber,
    };
  }

  // Tam ismi kolayca almak için
  String get fullName => '$firstName $lastName';
}
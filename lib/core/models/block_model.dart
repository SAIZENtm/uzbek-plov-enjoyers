import 'package:cloud_firestore/cloud_firestore.dart';

class BlockModel {
  final String id; // Например: 'A', 'B', 'C', 'D', 'E', 'F'
  final String name;
  final String address;
  final int totalFloors;
  final int totalApartments;
  final String status; // 'active', 'construction', etc.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BlockModel({
    required this.id,
    required this.name,
    required this.address,
    required this.totalFloors,
    required this.totalApartments,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory BlockModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BlockModel(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      totalFloors: data['totalFloors'] ?? 0,
      totalApartments: data['totalApartments'] ?? 0,
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'totalFloors': totalFloors,
      'totalApartments': totalApartments,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
} 
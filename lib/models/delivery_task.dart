class DeliveryTask {
  const DeliveryTask({
    required this.id,
    required this.address,
    required this.status,
    this.scheduledAt,
    this.proofCode,
    this.proofPhotoUrl,
  });

  final String id;
  final String address;
  final String status;
  final DateTime? scheduledAt;
  final String? proofCode;
  final String? proofPhotoUrl;

  DeliveryTask copyWith({
    String? id,
    String? address,
    String? status,
    DateTime? scheduledAt,
    String? proofCode,
    String? proofPhotoUrl,
  }) {
    return DeliveryTask(
      id: id ?? this.id,
      address: address ?? this.address,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      proofCode: proofCode ?? this.proofCode,
      proofPhotoUrl: proofPhotoUrl ?? this.proofPhotoUrl,
    );
  }

  factory DeliveryTask.fromJson(Map<String, dynamic> json) {
    return DeliveryTask(
      id: json['id']?.toString() ?? '',
      address: json['address']?.toString() ?? 'Unknown address',
      status: json['status']?.toString() ?? 'pending',
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.tryParse(json['scheduledAt'].toString())
          : null,
      proofCode: json['proofCode']?.toString(),
      proofPhotoUrl: json['proofPhotoUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'status': status,
      if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
      if (proofCode != null && proofCode!.isNotEmpty) 'proofCode': proofCode,
      if (proofPhotoUrl != null && proofPhotoUrl!.isNotEmpty)
        'proofPhotoUrl': proofPhotoUrl,
    };
  }

  static List<DeliveryTask> sampleTasks() {
    return const [
      DeliveryTask(
        id: 'ORD-1024',
        address: '15 Harbour Road, Central Logistics Hub',
        status: 'pending',
      ),
      DeliveryTask(
        id: 'ORD-1025',
        address: '88 Airport Freightway, Hangar C',
        status: 'in-transit',
      ),
      DeliveryTask(
        id: 'ORD-1026',
        address: '22 Warehouse Lane, Kowloon Bay',
        status: 'delayed',
      ),
    ];
  }
}

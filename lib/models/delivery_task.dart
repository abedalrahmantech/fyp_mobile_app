class DeliveryTask {
  const DeliveryTask({
    required this.id,
    required this.address,
    required this.status,
    this.scheduledAt,
    this.priority = 0,
    this.proofCode,
    this.proofPhotoUrl,
  });

  final String id;
  final String address;
  final String status;
  final DateTime? scheduledAt;
  final int priority;
  final String? proofCode;
  final String? proofPhotoUrl;

  DeliveryTask copyWith({
    String? id,
    String? address,
    String? status,
    DateTime? scheduledAt,
    int? priority,
    String? proofCode,
    String? proofPhotoUrl,
  }) {
    return DeliveryTask(
      id: id ?? this.id,
      address: address ?? this.address,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      priority: priority ?? this.priority,
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
          : (json['scheduled_start'] != null
              ? DateTime.tryParse(json['scheduled_start'].toString())
              : null),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      proofCode:
          json['proofCode']?.toString() ?? json['proof_code']?.toString(),
      proofPhotoUrl: json['proofPhotoUrl']?.toString() ??
          json['proof_photo_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'status': status,
      if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
      'priority': priority,
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

class DeviceInfo {
  final String id;
  final String model;
  final String androidVersion;
  final String manufacturer;
  final bool isEmulator;
  final bool isAuthorized;
  final String status;

  DeviceInfo({
    required this.id,
    this.model = '',
    this.androidVersion = '',
    this.manufacturer = '',
    this.isEmulator = false,
    this.isAuthorized = true,
    this.status = 'device',
  });

  factory DeviceInfo.fromId(String id, String status) {
    bool isEmulator = id.contains('emulator') || id.startsWith('emulator-');
    bool isAuthorized = status == 'device';

    return DeviceInfo(
      id: id,
      isEmulator: isEmulator,
      isAuthorized: isAuthorized,
      status: status,
    );
  }

  DeviceInfo copyWith({
    String? model,
    String? androidVersion,
    String? manufacturer,
  }) {
    return DeviceInfo(
      id: this.id,
      model: model ?? this.model,
      androidVersion: androidVersion ?? this.androidVersion,
      manufacturer: manufacturer ?? this.manufacturer,
      isEmulator: this.isEmulator,
      isAuthorized: this.isAuthorized,
      status: this.status,
    );
  }

  String get displayName {
    if (model.isNotEmpty) {
      return '$model ($id)';
    } else {
      return id;
    }
  }

  Map<String, String> toMap() {
    return {
      'id': id,
      'model': model,
      'androidVersion': androidVersion,
      'manufacturer': manufacturer,
      'isEmulator': isEmulator.toString(),
      'isAuthorized': isAuthorized.toString(),
      'status': status,
    };
  }

  @override
  String toString() {
    return 'DeviceInfo{id: $id, model: $model, androidVersion: $androidVersion, status: $status}';
  }
}

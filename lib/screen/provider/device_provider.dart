import 'dart:async';
import 'dart:io';

import 'package:adb_test/model/adb_error.dart';
import 'package:adb_test/model/device_info.dart';
import 'package:adb_test/utils/adb_service.dart';
import 'package:flutter/material.dart';

class DeviceProvider with ChangeNotifier {
  final AdbService _adbService = AdbService();

  List<DeviceInfo> _devices = [];
  DeviceInfo? _selectedDevice;
  bool _isLoading = false;
  AdbError? _lastError;
  Timer? _refreshTimer;

  // 게터
  List<DeviceInfo> get devices => _devices;
  DeviceInfo? get selectedDevice => _selectedDevice;
  bool get isLoading => _isLoading;
  AdbError? get lastError => _lastError;
  bool get hasDevices => _devices.isNotEmpty;

  DeviceProvider() {
    refreshDevices();
    // 30초마다 자동으로 디바이스 목록 새로고침
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      refreshDevices();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshDevices() async {
    _setLoading(true);
    _lastError = null;

    try {
      List<String> deviceIds = await _adbService.getDevices();
      List<DeviceInfo> newDevices = [];

      for (String id in deviceIds) {
        // 기본 디바이스 정보 생성
        DeviceInfo deviceInfo = DeviceInfo.fromId(id, 'device');

        // 기기 상세 정보 가져오기 (비동기로 처리)
        try {
          Map<String, dynamic> props = await _getDeviceProperties(id);
          deviceInfo = deviceInfo.copyWith(
            model: props['model'] ?? '',
            androidVersion: props['androidVersion'] ?? '',
            manufacturer: props['manufacturer'] ?? '',
          );
        } catch (e) {
          // 상세 정보 가져오기 실패해도 기본 정보는 추가
          print('디바이스 상세 정보 가져오기 실패: $e');
        }

        newDevices.add(deviceInfo);
      }

      _devices = newDevices;

      // 선택된 디바이스가 없거나 목록에서 사라진 경우 첫 번째 디바이스 선택
      if (_selectedDevice == null ||
          !_devices.any((d) => d.id == _selectedDevice!.id)) {
        _selectedDevice = _devices.isNotEmpty ? _devices.first : null;
      }

      notifyListeners();
    } catch (e) {
      _lastError = AdbError.fromException(e);
      print('디바이스 목록 새로고침 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> _getDeviceProperties(String deviceId) async {
    Map<String, dynamic> props = {};

    try {
      ProcessResult result =
          await Process.run('adb', ['-s', deviceId, 'shell', 'getprop']);

      String output = result.stdout as String;
      List<String> lines = output.split('\n');

      for (String line in lines) {
        if (line.contains('[ro.product.model]')) {
          props['model'] = _extractPropertyValue(line);
        } else if (line.contains('[ro.build.version.release]')) {
          props['androidVersion'] = _extractPropertyValue(line);
        } else if (line.contains('[ro.product.manufacturer]')) {
          props['manufacturer'] = _extractPropertyValue(line);
        }
      }
    } catch (e) {
      print('디바이스 속성 가져오기 실패: $e');
    }

    return props;
  }

  String _extractPropertyValue(String propLine) {
    // [prop]: [value] 형식에서 value 추출
    RegExp regex = RegExp(r'\[(.*?)\]: \[(.*?)\]');
    Match? match = regex.firstMatch(propLine);
    return match?.group(2) ?? '';
  }

  void selectDevice(DeviceInfo device) {
    _selectedDevice = device;
    notifyListeners();
  }

  void selectDeviceById(String id) {
    final device = _devices.firstWhere(
      (d) => d.id == id,
      orElse: () => _devices.isNotEmpty ? _devices.first : null!,
    );

    if (device != null) {
      _selectedDevice = device;
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

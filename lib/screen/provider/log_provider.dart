import 'dart:async';
import 'dart:io';

import 'package:adb_test/model/adb_error.dart';
import 'package:adb_test/model/device_info.dart';
import 'package:adb_test/utils/adb_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
  fatal,
}

class LogEntry {
  final DateTime timestamp;
  final String tag;
  final String message;
  final LogLevel level;

  LogEntry({
    required this.timestamp,
    required this.tag,
    required this.message,
    required this.level,
  });

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  Color get levelColor {
    switch (level) {
      case LogLevel.verbose:
        return Colors.grey;
      case LogLevel.debug:
        return Colors.blue;
      case LogLevel.info:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.fatal:
        return Colors.purple;
    }
  }
}

class LogProvider with ChangeNotifier {
  final AdbService _adbService = AdbService();

  List<LogEntry> _logs = [];
  List<FlSpot> _videoFrameData = [];
  List<FlSpot> _audioFrameData = [];

  String _filterText = '';
  bool _isMonitoring = false;
  Set<LogLevel> _enabledLevels = Set.from(LogLevel.values);

  DeviceInfo? _currentDevice;
  StreamSubscription? _logSubscription;
  AdbError? _lastError;

  // 게터
  List<LogEntry> get logs => _getFilteredLogs();
  List<FlSpot> get videoFrameData => _videoFrameData;
  List<FlSpot> get audioFrameData => _audioFrameData;
  bool get isMonitoring => _isMonitoring;
  String get filterText => _filterText;
  Set<LogLevel> get enabledLevels => _enabledLevels;
  AdbError? get lastError => _lastError;

  // 로그 필터링
  List<LogEntry> _getFilteredLogs() {
    if (_filterText.isEmpty &&
        _enabledLevels.length == LogLevel.values.length) {
      return _logs;
    }

    return _logs.where((log) {
      bool levelMatch = _enabledLevels.contains(log.level);
      bool textMatch = _filterText.isEmpty ||
          log.tag.toLowerCase().contains(_filterText.toLowerCase()) ||
          log.message.toLowerCase().contains(_filterText.toLowerCase());

      return levelMatch && textMatch;
    }).toList();
  }

  // 로그 수집 시작
  Future<void> startMonitoring(DeviceInfo device) async {
    if (_isMonitoring) {
      stopMonitoring();
    }

    _currentDevice = device;
    _lastError = null;

    try {
      final stream = _adbService.startLogcat(device.id);

      _logSubscription = stream.listen((log) {
        parseLog(log);
      }, onError: (error) {
        _lastError = AdbError.fromException(error);
        notifyListeners();
      }, onDone: () {
        _isMonitoring = false;
        notifyListeners();
      });

      _isMonitoring = true;
      notifyListeners();
    } catch (e) {
      _lastError = AdbError.fromException(e);
      _isMonitoring = false;
      notifyListeners();
    }
  }

  // 로그 수집 중지
  void stopMonitoring() {
    _logSubscription?.cancel();
    _isMonitoring = false;
    notifyListeners();
  }

  // 필터 설정
  void setFilter(String filter) {
    _filterText = filter;
    notifyListeners();
  }

  // 로그 레벨 필터 토글
  void toggleLevel(LogLevel level) {
    if (_enabledLevels.contains(level)) {
      _enabledLevels.remove(level);
    } else {
      _enabledLevels.add(level);
    }
    notifyListeners();
  }

  // 로그 파싱
  void parseLog(String log) {
    // 로그 형식 파싱 (Android logcat)
    try {
      // 간단한 로그캣 형식 파싱 예시
      RegExp logPattern = RegExp(r'([A-Z])\/([^:]+):\s+(.+)');
      Match? match = logPattern.firstMatch(log);

      if (match != null && match.groupCount >= 3) {
        final levelChar = match.group(1);
        final tag = match.group(2) ?? 'Unknown';
        final message = match.group(3) ?? '';

        LogLevel level = _parseLogLevel(levelChar);

        _logs.add(LogEntry(
          timestamp: DateTime.now(),
          tag: tag,
          message: message,
          level: level,
        ));

        // 최대 1000개의 로그만 유지
        if (_logs.length > 1000) {
          _logs.removeAt(0);
        }

        // 비디오 프레임 데이터 파싱
        if (log.contains("onSendVideo data")) {
          _extractVideoData(log);
        }

        // 오디오 프레임 데이터 파싱
        if (log.contains("onSendAudio data")) {
          _extractAudioData(log);
        }

        notifyListeners();
      }
    } catch (e) {
      print('로그 파싱 오류: $e');
    }
  }

  LogLevel _parseLogLevel(String? levelChar) {
    switch (levelChar) {
      case 'V':
        return LogLevel.verbose;
      case 'D':
        return LogLevel.debug;
      case 'I':
        return LogLevel.info;
      case 'W':
        return LogLevel.warning;
      case 'E':
        return LogLevel.error;
      case 'F':
        return LogLevel.fatal;
      default:
        return LogLevel.info;
    }
  }

  void _extractVideoData(String log) {
    try {
      final RegExp frameRegex = RegExp(r'onSendVideo data (\d+)');
      final match = frameRegex.firstMatch(log);
      if (match != null) {
        final frameCount = int.parse(match.group(1) ?? '0');
        updateVideoFrameData(frameCount);
      }
    } catch (e) {
      print('비디오 데이터 추출 오류: $e');
    }
  }

  void _extractAudioData(String log) {
    try {
      final RegExp frameRegex = RegExp(r'onSendAudio data (\d+)');
      final match = frameRegex.firstMatch(log);
      if (match != null) {
        final frameCount = int.parse(match.group(1) ?? '0');
        updateAudioFrameData(frameCount);
      }
    } catch (e) {
      print('오디오 데이터 추출 오류: $e');
    }
  }

  void updateVideoFrameData(int frameCount) {
    _videoFrameData
        .add(FlSpot(_videoFrameData.length.toDouble(), frameCount.toDouble()));

    // 최대 100개 데이터 포인트 유지
    if (_videoFrameData.length > 100) {
      _videoFrameData.removeAt(0);
    }

    notifyListeners();
  }

  void updateAudioFrameData(int frameCount) {
    _audioFrameData
        .add(FlSpot(_audioFrameData.length.toDouble(), frameCount.toDouble()));

    // 최대 100개 데이터 포인트 유지
    if (_audioFrameData.length > 100) {
      _audioFrameData.removeAt(0);
    }

    notifyListeners();
  }

  // 로그 저장
  Future<String?> saveLogsToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fileName =
          'logs_${now.year}${now.month}${now.day}_${now.hour}${now.minute}.txt';
      final file = File('${directory.path}/$fileName');

      final buffer = StringBuffer();
      for (final log in _logs) {
        buffer.writeln(
            '[${log.formattedTime}] ${log.level.toString().split('.').last} - ${log.tag}: ${log.message}');
      }

      await file.writeAsString(buffer.toString());
      return file.path;
    } catch (e) {
      print('로그 저장 오류: $e');
      return null;
    }
  }

  // 로그 초기화
  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

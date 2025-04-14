import 'dart:async';
import 'dart:convert';
import 'dart:io';

class AdbService {
  static final AdbService _instance = AdbService._internal();
  String? _adbPath;

  factory AdbService() {
    return _instance;
  }

  AdbService._internal() {
    _initAdbPath();
  }

  Future<void> _initAdbPath() async {
    // 환경 변수에서 ADB 경로를 찾거나 기본 경로를 시도
    if (Platform.isWindows) {
      _adbPath = 'adb.exe';
      // 로컬 경로 시도 (애플리케이션과 함께 배포된 ADB)
      final appDir = Directory.current.path;
      final localAdb = '$appDir\\adb\\adb.exe';
      if (await File(localAdb).exists()) {
        _adbPath = localAdb;
      }
    } else {
      _adbPath = 'adb';
    }
  }

  Future<ProcessResult> _runAdbCommand(List<String> args) async {
    if (_adbPath == null) {
      await _initAdbPath();
    }
    return await Process.run(_adbPath!, args);
  }

  // 연결된 디바이스 목록 가져오기
  Future<List<String>> getDevices() async {
    try {
      ProcessResult result = await _runAdbCommand(['devices']);
      String output = result.stdout as String;

      List<String> devices = [];
      List<String> lines = output.split('\n');

      // 첫 번째 줄은 "List of devices attached"이므로 건너뜀
      for (int i = 1; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isNotEmpty && line.contains('\t')) {
          List<String> parts = line.split('\t');
          if (parts.length > 1 && parts[1] == 'device') {
            devices.add(parts[0]);
          }
        }
      }

      return devices;
    } catch (e) {
      print('ADB 디바이스 목록 조회 오류: $e');
      return [];
    }
  }

  // 배터리 정보 가져오기
  Future<Map<String, dynamic>> getBatteryInfo(String deviceId) async {
    try {
      ProcessResult result =
          await _runAdbCommand(['-s', deviceId, 'shell', 'dumpsys', 'battery']);
      String output = result.stdout as String;

      // 정규식으로 필요한 정보 추출
      RegExp levelRegex = RegExp(r'level: (\d+)');
      RegExp tempRegex = RegExp(r'temperature: (\d+)');
      RegExp voltageRegex = RegExp(r'voltage: (\d+)');
      RegExp statusRegex = RegExp(r'status: (\d+)');

      int level = int.parse(levelRegex.firstMatch(output)?.group(1) ?? '0');
      int temp = int.parse(tempRegex.firstMatch(output)?.group(1) ?? '0');
      int voltage = int.parse(voltageRegex.firstMatch(output)?.group(1) ?? '0');
      int status = int.parse(statusRegex.firstMatch(output)?.group(1) ?? '0');

      return {
        'level': level,
        'temperature': temp / 10.0, // 온도는 10으로 나눈 값이 실제 온도
        'voltage': voltage / 1000.0, // 전압은 1000으로 나눈 값이 실제 전압(V)
        'status': _getBatteryStatusString(status),
      };
    } catch (e) {
      print('배터리 정보 조회 오류: $e');
      return {
        'level': 0,
        'temperature': 0.0,
        'voltage': 0.0,
        'status': 'unknown',
      };
    }
  }

  // 앱별 배터리 사용량 통계 가져오기
  Future<List<Map<String, dynamic>>> getBatteryStats(String deviceId) async {
    try {
      // 먼저 배터리 통계 리셋 (선택사항)
      // await Process.run('adb', ['-s', deviceId, 'shell', 'dumpsys', 'batterystats', '--reset']);

      // 배터리 사용량 통계 가져오기
      ProcessResult result = await _runAdbCommand(
          ['-s', deviceId, 'shell', 'dumpsys', 'batterystats']);
      String output = result.stdout as String;

      // 실행 중인 앱 목록 가져오기
      ProcessResult appsResult = await _runAdbCommand(
          ['-s', deviceId, 'shell', 'pm', 'list', 'packages', '-3']);
      String appsOutput = appsResult.stdout as String;

      // 앱 목록 파싱
      List<String> appPackages = [];
      for (String line in appsOutput.split('\n')) {
        if (line.startsWith('package:')) {
          appPackages.add(line.substring(8).trim());
        }
      }

      // 배터리 통계 파싱
      List<Map<String, dynamic>> batteryStats = [];

      // 앱별 배터리 사용량 수동 파싱
      List<String> lines = output.split('\n');
      bool inEstimatedPowerSection = false;

      for (int i = 0; i < lines.length; i++) {
        String line = lines[i];

        // 예상 전력 사용량 섹션 찾기
        if (line.contains('Estimated power use')) {
          inEstimatedPowerSection = true;
          continue;
        }

        if (inEstimatedPowerSection) {
          // 앱 패키지명 찾기
          for (String pkg in appPackages) {
            if (line.contains(pkg)) {
              // 배터리 사용량 추출
              RegExp usageRegex = RegExp(r'(\d+\.?\d*) mAh');
              Match? usageMatch = usageRegex.firstMatch(line);
              double usage = 0.0;

              if (usageMatch != null) {
                usage = double.parse(usageMatch.group(1) ?? '0');
              }

              // 앱 이름 가져오기
              String appName = await _getAppName(deviceId, pkg);

              batteryStats.add({
                'package': pkg,
                'name': appName,
                'usage': usage,
                'details': line.trim(),
              });

              break;
            }
          }
        }
      }

      // 사용량 기준으로 정렬
      batteryStats.sort(
          (a, b) => (b['usage'] as double).compareTo(a['usage'] as double));

      return batteryStats;
    } catch (e) {
      print('배터리 통계 조회 오류: $e');
      return [];
    }
  }

  // 앱 이름 가져오기
  Future<String> _getAppName(String deviceId, String packageName) async {
    try {
      ProcessResult result = await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'pm',
        'list',
        'packages',
        '-f',
        packageName
      ]);
      String output = result.stdout as String;

      // 앱 이름 추출 (패키지 경로에서 마지막 부분)
      if (output.contains('=')) {
        List<String> parts = output.split('=');
        String path = parts[0].substring(8); // 'package:' 제거

        // 경로에서 앱 이름 추출 (보통 .apk 파일 이름)
        List<String> pathParts = path.split('/');
        String apkName = pathParts.last;

        // .apk 확장자 제거
        if (apkName.endsWith('.apk')) {
          apkName = apkName.substring(0, apkName.length - 4);
        }

        return apkName;
      }

      return packageName; // 이름을 가져올 수 없으면 패키지명 반환
    } catch (e) {
      return packageName;
    }
  }

  // 실시간 배터리 드레인 모니터링 시작
  Future<Map<String, dynamic>> getBatteryDrainRate(String deviceId) async {
    try {
      // 현재 배터리 레벨과 시간 기록
      Map<String, dynamic> batteryInfo = await getBatteryInfo(deviceId);
      int startLevel = batteryInfo['level'] as int;
      DateTime startTime = DateTime.now();

      // 5초 대기 (짧은 시간이지만 테스트용)
      await Future.delayed(Duration(seconds: 5));

      // 새 배터리 레벨 확인
      batteryInfo = await getBatteryInfo(deviceId);
      int endLevel = batteryInfo['level'] as int;
      DateTime endTime = DateTime.now();

      // 시간 차이 계산 (시간 단위)
      double hoursDiff =
          endTime.difference(startTime).inMilliseconds / (1000 * 60 * 60);

      // 레벨 차이
      int levelDiff = startLevel - endLevel;

      // 드레인 속도 계산 (% / 시간)
      double drainRate = 0;
      if (hoursDiff > 0) {
        drainRate = levelDiff / hoursDiff;
      }

      // 예상 배터리 지속 시간 (시간)
      double estimatedHours = 0;
      if (drainRate > 0) {
        estimatedHours = endLevel / drainRate;
      }

      return {
        'currentLevel': endLevel,
        'drainRate': drainRate.toStringAsFixed(2), // % / 시간
        'estimatedHours': estimatedHours.toStringAsFixed(1), // 예상 지속 시간
        'temperatureCelsius': batteryInfo['temperature'], // 현재 온도
      };
    } catch (e) {
      print('배터리 드레인 속도 계산 오류: $e');
      return {
        'currentLevel': 0,
        'drainRate': '0.00',
        'estimatedHours': '0.0',
        'temperatureCelsius': 0.0,
      };
    }
  }

  // 메모리 정보 가져오기
  Future<Map<String, dynamic>> getMemoryInfo(String deviceId) async {
    try {
      ProcessResult result =
          await _runAdbCommand(['-s', deviceId, 'shell', 'dumpsys', 'meminfo']);
      String output = result.stdout as String;

      RegExp totalRegex = RegExp(r'Total RAM: ([\d,]+)K');
      RegExp freeRegex = RegExp(r'Free RAM: ([\d,]+)K');
      RegExp usedRegex = RegExp(r'Used RAM: ([\d,]+)K');

      String totalStr = totalRegex.firstMatch(output)?.group(1) ?? '0';
      String freeStr = freeRegex.firstMatch(output)?.group(1) ?? '0';
      String usedStr = usedRegex.firstMatch(output)?.group(1) ?? '0';

      // 쉼표 제거 후 숫자 변환
      int total = int.parse(totalStr.replaceAll(',', ''));
      int free = int.parse(freeStr.replaceAll(',', ''));
      int used = int.parse(usedStr.replaceAll(',', ''));

      return {
        'total': total,
        'free': free,
        'used': used,
        'usagePercent': (used / total * 100).toStringAsFixed(2),
      };
    } catch (e) {
      print('메모리 정보 조회 오류: $e');
      return {
        'total': 0,
        'free': 0,
        'used': 0,
        'usagePercent': '0.00',
      };
    }
  }

  // CPU 정보 가져오기
  Future<Map<String, dynamic>> getCpuInfo(String deviceId) async {
    try {
      ProcessResult result =
          await _runAdbCommand(['-s', deviceId, 'shell', 'dumpsys', 'cpuinfo']);
      String output = result.stdout as String;

      List<String> lines = output.split('\n');
      Map<String, dynamic> cpuInfo = {};

      for (String line in lines) {
        if (line.contains('%')) {
          List<String> parts = line.trim().split(' ');
          if (parts.length >= 2) {
            String processName = parts.last;
            String usage = parts.where((part) => part.contains('%')).first;
            cpuInfo[processName] = usage;
          }
        }
      }

      return {
        'processes': cpuInfo,
        'totalUsage': _calculateTotalCpuUsage(cpuInfo),
      };
    } catch (e) {
      print('CPU 정보 조회 오류: $e');
      return {
        'processes': {},
        'totalUsage': '0%',
      };
    }
  }

  // 로그캣 스트림 시작
  Stream<String> startLogcat(String deviceId, {List<String>? filters}) {
    StreamController<String> logStreamController = StreamController<String>();

    try {
      List<String> args = ['-s', deviceId, 'logcat'];
      if (filters != null && filters.isNotEmpty) {
        args.addAll(filters);
      }

      Process.start('adb', args).then((process) {
        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          logStreamController.add(line);
        });

        process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((error) {
          logStreamController.addError('로그캣 오류: $error');
        });

        // 컨트롤러가 닫히면 프로세스도 종료
        logStreamController.onCancel = () {
          process.kill();
        };
      });
    } catch (e) {
      logStreamController.addError('로그캣 시작 오류: $e');
      logStreamController.close();
    }

    return logStreamController.stream;
  }

  // 디바이스 제어 명령
  Future<bool> executeDeviceCommand(String deviceId, String command) async {
    try {
      List<String> args = ['-s', deviceId];
      args.addAll(command.split(' '));

      ProcessResult result = await _runAdbCommand(args);
      return result.exitCode == 0;
    } catch (e) {
      print('디바이스 명령 실행 오류: $e');
      return false;
    }
  }

  // 배터리 상태 문자열 변환
  String _getBatteryStatusString(int status) {
    switch (status) {
      case 1:
        return '알 수 없음';
      case 2:
        return '충전 중';
      case 3:
        return '방전 중';
      case 4:
        return '충전되지 않음';
      case 5:
        return '완전 충전됨';
      default:
        return '알 수 없음';
    }
  }

  // CPU 사용량 총합 계산
  String _calculateTotalCpuUsage(Map<String, dynamic> processesUsage) {
    double total = 0;
    for (String usage in processesUsage.values) {
      total += double.parse(usage.replaceAll('%', ''));
    }
    return '${total.toStringAsFixed(1)}%';
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class AdbLogCollector {
  final StreamController<String> _logStreamController =
      StreamController<String>();

  Stream<String> get logStream => _logStreamController.stream;

  void startLogCollection() async {
    try {
      // ADB 로그캣 명령어 실행
      Process process = await Process.start('adb', ['logcat']);

      // 로그 출력 읽기
      process.stdout.transform(utf8.decoder).listen((data) {
        _logStreamController.add(data);
      });

      // 오류 출력 읽기
      process.stderr.transform(utf8.decoder).listen((data) {
        _logStreamController.addError(data);
      });
    } catch (e) {
      _logStreamController.addError('Failed to start ADB logcat: $e');
    }
  }

  void dispose() {
    _logStreamController.close();
  }
}

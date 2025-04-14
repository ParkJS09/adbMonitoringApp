enum AdbErrorType {
  deviceNotFound,
  commandFailed,
  connectionFailed,
  permissionDenied,
  invalidArgument,
  unknown
}

class AdbError {
  final AdbErrorType type;
  final String message;
  final String? details;
  final dynamic originalError;

  AdbError({
    required this.type,
    required this.message,
    this.details,
    this.originalError,
  });

  factory AdbError.fromException(dynamic error) {
    if (error is String) {
      if (error.contains('device not found') ||
          error.contains('no devices/emulators found')) {
        return AdbError(
          type: AdbErrorType.deviceNotFound,
          message: '디바이스를 찾을 수 없습니다',
          details: error,
          originalError: error,
        );
      } else if (error.contains('permission')) {
        return AdbError(
          type: AdbErrorType.permissionDenied,
          message: 'ADB 실행 권한이 없습니다',
          details: error,
          originalError: error,
        );
      }
    }

    return AdbError(
      type: AdbErrorType.unknown,
      message: '알 수 없는 ADB 오류가 발생했습니다',
      details: error.toString(),
      originalError: error,
    );
  }

  String get userFriendlyMessage {
    switch (type) {
      case AdbErrorType.deviceNotFound:
        return '연결된 Android 기기를 찾을 수 없습니다. USB 케이블을 확인하고 USB 디버깅이 활성화되어 있는지 확인하세요.';
      case AdbErrorType.commandFailed:
        return 'ADB 명령 실행에 실패했습니다. 자세한 정보: $details';
      case AdbErrorType.connectionFailed:
        return 'Android 기기와의 연결에 실패했습니다. USB 연결과 디버깅 설정을 확인하세요.';
      case AdbErrorType.permissionDenied:
        return 'ADB 실행 권한이 없습니다. 관리자 권한으로 실행하거나 권한 설정을 확인하세요.';
      case AdbErrorType.invalidArgument:
        return '잘못된 명령어 인수가 전달되었습니다. 명령어를 확인하세요.';
      case AdbErrorType.unknown:
      default:
        return '알 수 없는 오류가 발생했습니다. 자세한 정보: $details';
    }
  }
}

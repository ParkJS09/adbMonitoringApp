import 'package:adb_test/model/adb_error.dart';
import 'package:adb_test/model/device_info.dart';
import 'package:adb_test/screen/provider/device_provider.dart';
import 'package:adb_test/utils/adb_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DeviceControlScreen extends StatefulWidget {
  @override
  _DeviceControlScreenState createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  final AdbService _adbService = AdbService();
  bool _isProcessing = false;
  String _statusMessage = '';
  bool _isError = false;

  Future<void> _executeCommand(String title, String command) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = '$title 실행 중...';
      _isError = false;
    });

    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final selectedDevice = deviceProvider.selectedDevice;

    if (selectedDevice == null) {
      setState(() {
        _isProcessing = false;
        _statusMessage = '선택된 디바이스가 없습니다';
        _isError = true;
      });
      return;
    }

    try {
      bool success =
          await _adbService.executeDeviceCommand(selectedDevice.id, command);

      setState(() {
        _isProcessing = false;
        if (success) {
          _statusMessage = '$title 성공';
          _isError = false;
        } else {
          _statusMessage = '$title 실패';
          _isError = true;
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = '오류: $e';
        _isError = true;
      });
    }
  }

  Widget _buildDeviceInfoCard(DeviceInfo device) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '디바이스 정보',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow(
                '모델명', device.model.isNotEmpty ? device.model : '알 수 없음'),
            _buildInfoRow(
                '제조사',
                device.manufacturer.isNotEmpty
                    ? device.manufacturer
                    : '알 수 없음'),
            _buildInfoRow(
                'Android 버전',
                device.androidVersion.isNotEmpty
                    ? device.androidVersion
                    : '알 수 없음'),
            _buildInfoRow('디바이스 ID', device.id),
            _buildInfoRow('에뮬레이터', device.isEmulator ? '예' : '아니오'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandButtons() {
    final commands = [
      {
        'title': '스크린샷 촬영',
        'icon': Icons.photo_camera,
        'command': 'shell screencap -p /sdcard/screenshot.png',
        'description': '디바이스 화면 캡처 후 내부 저장소에 저장',
      },
      {
        'title': '화면 녹화 시작',
        'icon': Icons.videocam,
        'command': 'shell screenrecord /sdcard/recording.mp4',
        'description': '화면 녹화를 시작합니다(최대 3분)',
      },
      {
        'title': '디바이스 리부팅',
        'icon': Icons.restart_alt,
        'command': 'reboot',
        'description': '디바이스를 재부팅합니다',
        'dangerous': true,
      },
      {
        'title': '앱 목록 가져오기',
        'icon': Icons.apps,
        'command': 'shell pm list packages',
        'description': '설치된 앱 목록을 표시합니다',
      },
      {
        'title': '백 버튼 누르기',
        'icon': Icons.arrow_back,
        'command': 'shell input keyevent 4',
        'description': '백 버튼을 누릅니다',
      },
      {
        'title': '홈 버튼 누르기',
        'icon': Icons.home,
        'command': 'shell input keyevent 3',
        'description': '홈 버튼을 누릅니다',
      },
    ];

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '디바이스 제어',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: commands.length,
              itemBuilder: (context, index) {
                final command = commands[index];
                final bool isDangerous = command['dangerous'] == true;

                return ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          if (isDangerous) {
                            _showConfirmationDialog(
                              command['title'] as String,
                              command['command'] as String,
                              command['description'] as String,
                            );
                          } else {
                            _executeCommand(
                              command['title'] as String,
                              command['command'] as String,
                            );
                          }
                        },
                  icon: Icon(command['icon'] as IconData),
                  label: Text(command['title'] as String),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDangerous ? Colors.red : null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showConfirmationDialog(
      String title, String command, String description) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('정말 $title 작업을 실행하시겠습니까?'),
                SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('실행'),
              onPressed: () {
                Navigator.of(context).pop();
                _executeCommand(title, command);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('디바이스 제어'),
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, deviceProvider, child) {
          final selectedDevice = deviceProvider.selectedDevice;

          if (selectedDevice == null) {
            return Center(
              child: Text('선택된 디바이스가 없습니다. 디바이스를 선택하세요.'),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // 디바이스 정보
                _buildDeviceInfoCard(selectedDevice),

                // 디바이스 제어 버튼
                _buildCommandButtons(),

                // 상태 메시지
                if (_statusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        if (_isProcessing)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            _isError ? Icons.error : Icons.check_circle,
                            color: _isError ? Colors.red : Colors.green,
                          ),
                        SizedBox(width: 8),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _isError ? Colors.red : null,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

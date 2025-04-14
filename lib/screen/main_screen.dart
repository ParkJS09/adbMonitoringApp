import 'package:adb_test/model/device_info.dart';
import 'package:adb_test/screen/battery_monitor_screen.dart';
import 'package:adb_test/screen/battery_usage_screen.dart';
import 'package:adb_test/screen/device_control_screen.dart';
import 'package:adb_test/screen/memory_info_screen.dart';
import 'package:adb_test/screen/provider/device_provider.dart';
import 'package:adb_test/screen/streaming_monitor_screen.dart';
import 'package:adb_test/widget/device_selector_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADB 테스트 도구'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<DeviceProvider>().refreshDevices();
            },
            tooltip: '디바이스 목록 새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 디바이스 선택 위젯
          DeviceSelectorWidget(),

          // 메인 콘텐츠
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Consumer<DeviceProvider>(
                builder: (context, deviceProvider, child) {
                  if (deviceProvider.isLoading) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (deviceProvider.lastError != null) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          SizedBox(height: 16),
                          Text(
                            deviceProvider.lastError!.userFriendlyMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => deviceProvider.refreshDevices(),
                            child: Text('다시 시도'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!deviceProvider.hasDevices) {
                    return _buildNoDevicesView();
                  }

                  return _buildFeatureGrid(
                      context, deviceProvider.selectedDevice);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDevicesView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smartphone_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '연결된 Android 디바이스가 없습니다',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'USB 케이블이 연결되어 있고 USB 디버깅이 활성화되어 있는지 확인하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context, DeviceInfo? selectedDevice) {
    final features = [
      {
        'title': '배터리 모니터링',
        'icon': Icons.battery_full,
        'description': '디바이스 배터리 상태와 온도를 실시간으로 모니터링합니다.',
        'screen': BattryInfoScreen(),
      },
      {
        'title': '배터리 사용량 분석',
        'icon': Icons.battery_saver,
        'description': '앱별 배터리 사용량과 소모 패턴을 분석합니다.',
        'screen': BatteryUsageScreen(),
      },
      {
        'title': '메모리 정보',
        'icon': Icons.memory,
        'description': '메모리 사용량과 프로세스 정보를 확인합니다.',
        'screen': MemoryInfoScreen(),
      },
      {
        'title': '디바이스 제어',
        'icon': Icons.phone_android,
        'description': '스크린샷, 리부팅 등 디바이스 제어 기능을 제공합니다.',
        'screen': DeviceControlScreen(),
      },
      {
        'title': '로그 모니터링',
        'icon': Icons.analytics,
        'description': '실시간 로그캣 내용을 확인하고 필터링합니다.',
        'screen': LogScreen(),
      },
    ];

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return _buildFeatureCard(
          context,
          feature['title'] as String,
          feature['description'] as String,
          feature['icon'] as IconData,
          feature['screen'] as Widget,
          selectedDevice,
        );
      },
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Widget screen,
    DeviceInfo? selectedDevice,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selectedDevice == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => screen),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Theme.of(context).primaryColor),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Expanded(
                child: Text(
                  description,
                  style: TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ),
              if (selectedDevice == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '디바이스를 선택하세요',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

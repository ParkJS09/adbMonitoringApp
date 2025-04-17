import 'dart:async';

import 'package:adb_test/model/adb_error.dart';
import 'package:adb_test/screen/provider/device_provider.dart';
import 'package:adb_test/utils/adb_service.dart';
import 'package:adb_test/widget/control_panel_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BatteryUsageScreen extends StatefulWidget {
  @override
  _BatteryUsageScreenState createState() => _BatteryUsageScreenState();
}

class _BatteryUsageScreenState extends State<BatteryUsageScreen> {
  final AdbService _adbService = AdbService();
  List<Map<String, dynamic>> _batteryStats = [];
  Map<String, dynamic> _drainRate = {};
  bool _isLoading = false;
  bool _isAnalyzing = false;
  bool _isDrainRateLoading = false;
  AdbError? _lastError;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _fetchBatteryUsage();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> _fetchBatteryUsage() async {
    if (!_mounted) return;

    setState(() {
      _isLoading = true;
      _lastError = null;
    });

    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final selectedDevice = deviceProvider.selectedDevice;

    if (selectedDevice == null) {
      setState(() {
        _lastError = AdbError(
          type: AdbErrorType.deviceNotFound,
          message: '선택된 디바이스가 없습니다',
        );
        _isLoading = false;
      });
      return;
    }

    try {
      final stats = await _adbService.getBatteryStats(selectedDevice.id);

      if (_mounted) {
        setState(() {
          _batteryStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (_mounted) {
        setState(() {
          _lastError = AdbError.fromException(e);
          _isLoading = false;
        });
      }
      print('배터리 사용량 가져오기 오류: $e');
    }
  }

  Future<void> _analyzeDrainRate() async {
    if (!_mounted) return;

    setState(() {
      _isDrainRateLoading = true;
      _lastError = null;
    });

    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final selectedDevice = deviceProvider.selectedDevice;

    if (selectedDevice == null) {
      setState(() {
        _lastError = AdbError(
          type: AdbErrorType.deviceNotFound,
          message: '선택된 디바이스가 없습니다',
        );
        _isDrainRateLoading = false;
      });
      return;
    }

    try {
      final drainRateData =
          await _adbService.getBatteryDrainRate(selectedDevice.id);
      drainRateData['analysisTime'] = DateTime.now();

      if (_mounted) {
        setState(() {
          _drainRate = drainRateData;
          _isAnalyzing = true;
          _isDrainRateLoading = false;
        });
      }
    } catch (e) {
      if (_mounted) {
        setState(() {
          _lastError = AdbError.fromException(e);
          _isDrainRateLoading = false;
        });
      }
      print('배터리 드레인 속도 분석 오류: $e');
    }
  }

  Widget _buildBatteryUsageList() {
    if (_batteryStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.battery_unknown, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '배터리 사용량 데이터가 없습니다',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '배터리 사용량을 분석하려면 새로고침 버튼을 눌러주세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _batteryStats.length,
      itemBuilder: (context, index) {
        final app = _batteryStats[index];
        final usage = app['usage'] as double;
        final package = app['package'] as String;
        final name = app['name'] as String;

        // 배터리 사용량에 따른 색상 결정
        Color usageColor = Colors.green;
        if (usage > 10) {
          usageColor = Colors.red;
        } else if (usage > 5) {
          usageColor = Colors.orange;
        } else if (usage > 2) {
          usageColor = Colors.amber;
        }

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: usageColor.withOpacity(0.2),
              child: Icon(Icons.battery_alert, color: usageColor),
            ),
            title: Text(
              name.isNotEmpty ? name : package,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(package),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${usage.toStringAsFixed(2)} mAh',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: usageColor,
                  ),
                ),
                Text(
                  '배터리 사용량',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrainRateCard() {
    if (_drainRate.isEmpty || !_isAnalyzing) {
      return SizedBox.shrink();
    }

    final currentLevel = _drainRate['currentLevel'] as int;
    final drainRate = _drainRate['drainRate'] as String;
    final estimatedHours = _drainRate['estimatedHours'] as String;
    final temperature = _drainRate['temperatureCelsius'] as double;
    final analysisTime = _drainRate['analysisTime'] as DateTime;

    // 시간 형식화
    final timeStr =
        '${analysisTime.hour.toString().padLeft(2, '0')}:${analysisTime.minute.toString().padLeft(2, '0')}:${analysisTime.second.toString().padLeft(2, '0')}';

    // 배터리 드레인 속도에 따른 색상 결정
    Color drainColor = Colors.green;
    if (double.parse(drainRate) > 20) {
      drainColor = Colors.red;
    } else if (double.parse(drainRate) > 10) {
      drainColor = Colors.orange;
    } else if (double.parse(drainRate) > 5) {
      drainColor = Colors.amber;
    }

    // 온도에 따른 색상 결정
    Color tempColor = Colors.green;
    if (temperature > 40) {
      tempColor = Colors.red;
    } else if (temperature > 35) {
      tempColor = Colors.orange;
    }

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '배터리 소모 분석',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.timer, size: 14, color: Colors.blue[700]),
                    SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700]),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAnalysisInfoItem(
                  icon: Icons.battery_full,
                  value: '$currentLevel%',
                  label: '현재 배터리',
                  color: Colors.blue,
                ),
                _buildAnalysisInfoItem(
                  icon: Icons.speed,
                  value: '$drainRate%/h',
                  label: '소모 속도',
                  color: drainColor,
                ),
                _buildAnalysisInfoItem(
                  icon: Icons.access_time,
                  value: '$estimatedHours시간',
                  label: '예상 지속 시간',
                  color: Colors.purple,
                ),
                _buildAnalysisInfoItem(
                  icon: Icons.device_thermostat,
                  value: '${temperature.toStringAsFixed(1)}°C',
                  label: '배터리 온도',
                  color: tempColor,
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Text(
              '배터리 소모가 큰 앱을 종료하거나 권한을 제한하세요',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisInfoItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('배터리 사용량 분석'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchBatteryUsage,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 드레인 속도 분석 버튼
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: _isDrainRateLoading ? null : _analyzeDrainRate,
                    icon: Icon(Icons.analytics),
                    label: Text('실시간 배터리 소모 분석'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                ),

                // 드레인 속도 로딩 표시
                if (_isDrainRateLoading)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('배터리 소모 분석 중...'),
                      ],
                    ),
                  ),

                // 드레인 속도 카드
                _buildDrainRateCard(),

                // 오류 메시지
                if (_lastError != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _lastError!.userFriendlyMessage,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),

                // 앱별 배터리 사용량 목록
                Expanded(child: _buildBatteryUsageList()),
              ],
            ),
    );
  }
}

import 'dart:async';

import 'package:adb_test/model/adb_error.dart';
import 'package:adb_test/screen/provider/device_provider.dart';
import 'package:adb_test/utils/adb_service.dart';
import 'package:adb_test/widget/control_panel_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

class MemoryInfoScreen extends StatefulWidget {
  @override
  _MemoryInfoScreenState createState() => _MemoryInfoScreenState();
}

class _MemoryInfoScreenState extends State<MemoryInfoScreen> {
  final AdbService _adbService = AdbService();
  Map<String, dynamic> _memoryInfo = {};
  List<FlSpot> _memoryData = [];
  Timer? _timer;
  bool _isMonitoring = false;
  bool _isLoading = false;
  bool _mounted = true;
  AdbError? _lastError;
  int _dataPointCount = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _mounted = false;
    _stopMonitoring();
    super.dispose();
  }

  Future<void> _fetchMemoryInfo() async {
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
      final memoryInfo = await _adbService.getMemoryInfo(selectedDevice.id);

      if (_mounted) {
        setState(() {
          _memoryInfo = memoryInfo;
          _isLoading = false;

          // 메모리 사용률 차트 데이터 추가
          double usagePercent =
              double.parse(memoryInfo['usagePercent'] as String);
          _memoryData.add(FlSpot(_dataPointCount.toDouble(), usagePercent));
          _dataPointCount++;

          // 최대 30개 데이터 포인트만 유지
          if (_memoryData.length > 30) {
            _memoryData.removeAt(0);
          }
        });
      }
    } catch (e) {
      if (_mounted) {
        setState(() {
          _lastError = AdbError.fromException(e);
          _isLoading = false;
        });
      }
      print('메모리 정보 가져오기 오류: $e');
    }
  }

  void _startMonitoring() {
    _fetchMemoryInfo(); // 초기 데이터 가져오기
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchMemoryInfo();
    });

    setState(() {
      _isMonitoring = true;
    });
  }

  void _stopMonitoring() {
    _timer?.cancel();
    setState(() {
      _isMonitoring = false;
    });
  }

  void _clearData() {
    setState(() {
      _memoryData.clear();
      _dataPointCount = 0;
    });
  }

  Widget _buildMemoryUsageCard() {
    if (_memoryInfo.isEmpty) {
      return Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('메모리 정보가 없습니다. 모니터링을 시작하세요.'),
          ),
        ),
      );
    }

    int totalMB = (_memoryInfo['total'] as int) ~/ 1024;
    int usedMB = (_memoryInfo['used'] as int) ~/ 1024;
    int freeMB = (_memoryInfo['free'] as int) ~/ 1024;
    String usagePercent = _memoryInfo['usagePercent'] as String;

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '메모리 사용 현황',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            LinearProgressIndicator(
              value: double.parse(usagePercent) / 100,
              backgroundColor: Colors.grey[200],
              minHeight: 10,
              valueColor: AlwaysStoppedAnimation<Color>(
                double.parse(usagePercent) > 80
                    ? Colors.red
                    : double.parse(usagePercent) > 60
                        ? Colors.orange
                        : Colors.green,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('사용량: $usagePercent%'),
                Text('${usedMB}MB / ${totalMB}MB'),
              ],
            ),
            Divider(height: 32),
            _buildMemoryInfoRow('총 메모리', '$totalMB MB'),
            _buildMemoryInfoRow('사용 중인 메모리', '$usedMB MB'),
            _buildMemoryInfoRow('사용 가능한 메모리', '$freeMB MB'),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryInfoRow(String label, String value) {
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

  Widget _buildMemoryChart() {
    if (_memoryData.isEmpty) {
      return SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '메모리 사용량 추이',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}%');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _memoryData,
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('메모리 정보'),
      ),
      body: _isLoading && _memoryInfo.isEmpty
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // 제어 패널
                  ControlPanel(
                    onStart: _startMonitoring,
                    onStop: _stopMonitoring,
                    onClear: _clearData,
                    isActive: _isMonitoring,
                  ),

                  // 오류 메시지
                  if (_lastError != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _lastError!.userFriendlyMessage,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),

                  // 메모리 사용량 카드
                  _buildMemoryUsageCard(),

                  // 메모리 차트
                  _buildMemoryChart(),

                  SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

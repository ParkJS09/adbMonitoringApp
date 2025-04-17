import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:adb_test/model/adb_error.dart';
import 'package:adb_test/model/battry_info.dart';
import 'package:adb_test/screen/provider/device_provider.dart';
import 'package:adb_test/utils/adb_service.dart';
import 'package:adb_test/widget/battery_chart_widget.dart';
import 'package:adb_test/widget/control_panel_widget.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class BattryInfoScreen extends StatefulWidget {
  @override
  _BattryInfoScreenState createState() => _BattryInfoScreenState();
}

class _BattryInfoScreenState extends State<BattryInfoScreen> {
  final AdbService _adbService = AdbService();
  List<BatteryInfo> data = [];
  BatteryInfo? firstData; // 최초 측정 데이터 저장
  Timer? timer;
  bool _isMonitoring = false;
  bool _isSaving = false;
  bool _mounted = true;
  AdbError? _lastError;
  GlobalKey _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _mounted = false;
    stopMonitoring();
    super.dispose();
  }

  Future<void> fetchData() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final selectedDevice = deviceProvider.selectedDevice;

    if (selectedDevice == null) {
      setState(() {
        _lastError = AdbError(
          type: AdbErrorType.deviceNotFound,
          message: '선택된 디바이스가 없습니다',
        );
      });
      return;
    }

    try {
      Map<String, dynamic> batteryInfo =
          await _adbService.getBatteryInfo(selectedDevice.id);

      final batteryInfoData = BatteryInfo(
        DateTime.now(),
        batteryInfo['level'] as int,
        batteryInfo['temperature'] as double,
      );

      if (_mounted) {
        setState(() {
          // 첫번째 데이터라면 firstData에 저장
          if (data.isEmpty) {
            firstData = batteryInfoData;
          }
          data.add(batteryInfoData);
          _lastError = null;
        });
      }
    } catch (e) {
      if (_mounted) {
        setState(() {
          _lastError = AdbError.fromException(e);
        });
      }
      print('배터리 정보 가져오기 오류: $e');
    }
  }

  void startMonitoring() {
    fetchData(); // 초기 데이터 가져오기
    timer = Timer.periodic(const Duration(minutes: 1), (Timer t) async {
      await fetchData();
    });

    setState(() {
      _isMonitoring = true;
    });
  }

  void stopMonitoring() {
    timer?.cancel();
    setState(() {
      _isMonitoring = false;
    });
  }

  void clearData() {
    setState(() {
      data.clear();
      firstData = null;
    });
  }

  List<FlSpot> getLevelSpots() {
    return data
        .map((info) => FlSpot(
            info.time.millisecondsSinceEpoch.toDouble(), info.level.toDouble()))
        .toList();
  }

  List<FlSpot> getTemperatureSpots() {
    return data
        .map((info) => FlSpot(
            info.time.millisecondsSinceEpoch.toDouble(), info.temperature))
        .toList();
  }

  String formatDateTime(DateTime dateTime) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}';
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Color(0xff68737d),
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    Widget text = Container();
    if (data.isNotEmpty) {
      if (value == data.first.time.millisecondsSinceEpoch.toDouble() ||
          value == data.last.time.millisecondsSinceEpoch.toDouble()) {
        final DateTime date =
            DateTime.fromMillisecondsSinceEpoch(value.toInt());
        text = Text(formatDateTime(date), style: style);
      }
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: text,
    );
  }

  Future<void> captureChart() async {
    setState(() {
      _isSaving = true;
    });

    try {
      RenderRepaintBoundary boundary =
          _chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = (await getApplicationDocumentsDirectory()).path;
      final now = DateTime.now();
      final fileName =
          'battery_chart_${now.year}${now.month}${now.day}_${now.hour}${now.minute}.png';
      final imgFile = File('$directory/$fileName');
      await imgFile.writeAsBytes(pngBytes);

      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('차트가 저장되었습니다: ${imgFile.path}'),
            action: SnackBarAction(
              label: '확인',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('차트 저장 실패: $e')),
        );
      }
      print('차트 캡처 오류: $e');
    } finally {
      if (_mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('배터리 모니터링'),
        actions: [
          // 차트 저장 버튼
          IconButton(
            icon: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.save),
            onPressed: _isSaving ? null : captureChart,
            tooltip: '차트 저장',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 배터리 정보 요약
            if (data.isNotEmpty) _buildBatteryInfoSummary(),

            // 배터리 상태 카드 비교 (최초 상태와 현재 상태)
            if (data.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text('최초 상태',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.grey[700])),
                            SizedBox(height: 4),
                            BatteryStatusCard(
                              batteryLevel: firstData?.level.toDouble() ??
                                  data.first.level.toDouble(),
                              temperature: firstData?.temperature ??
                                  data.first.temperature,
                              measureTime: firstData?.time ?? data.first.time,
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text('현재 상태',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.grey[700])),
                            SizedBox(height: 4),
                            BatteryStatusCard(
                              batteryLevel: data.last.level.toDouble(),
                              temperature: data.last.temperature,
                              measureTime: data.last.time,
                            ),
                          ],
                        ),
                      ],
                    ),

                    // 상태 변화량 표시
                    if (data.length > 1)
                      _buildStateChangeInfo(firstData ?? data.first, data.last),
                  ],
                ),
              ),

            // 모니터링 제어 패널
            ControlPanel(
              onStart: startMonitoring,
              onStop: stopMonitoring,
              onClear: clearData,
              isActive: _isMonitoring,
            ),

            // 오류 메시지
            if (_lastError != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _lastError!.userFriendlyMessage,
                  style: TextStyle(color: Colors.red),
                ),
              ),

            // 차트 섹션
            Container(
              padding: EdgeInsets.all(8.0),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 4.0),
                    child: Text(
                      '배터리 및 온도 추이',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Row(
                      children: [
                        _buildLegendItem(Colors.blue, '배터리 레벨 (%)'),
                        SizedBox(width: 16),
                        _buildLegendItem(Colors.red, '온도 (°C)'),
                      ],
                    ),
                  ),
                  // 터치 안내 문구 추가
                  if (!data.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.touch_app,
                              size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            '차트를 터치하여 자세한 정보를 확인하세요',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  data.isEmpty
                      ? Container(
                          height: 300,
                          child: _buildEmptyView(),
                        )
                      : Container(
                          height: 400, // 차트 높이 증가
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              // 데이터 포인트 개수에 따라 차트 너비 동적 설정
                              width: max(
                                MediaQuery.of(context).size.width,
                                data.length * 20.0, // 데이터 포인트당 너비 20으로 설정
                              ),
                              child: RepaintBoundary(
                                key: _chartKey,
                                child: BatteryChart(
                                  data: data,
                                  getLevelSpots: getLevelSpots,
                                  getTemperatureSpots: getTemperatureSpots,
                                  bottomTitleWidgets: bottomTitleWidgets,
                                ),
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),

            // 추가 여백
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.battery_alert,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '배터리 모니터링을 시작하세요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '모니터링 버튼을 눌러 실시간 배터리 정보 수집을 시작합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryInfoSummary() {
    if (data.isEmpty) return SizedBox.shrink();

    final latest = data.last;
    String batteryStatus = '알 수 없음';
    IconData batteryIcon = Icons.battery_unknown;
    Color batteryColor = Colors.grey;

    // 배터리 상태 아이콘 및 색상 결정
    if (latest.level > 80) {
      batteryStatus = '충분함';
      batteryIcon = Icons.battery_full;
      batteryColor = Colors.green;
    } else if (latest.level > 50) {
      batteryStatus = '양호함';
      batteryIcon = Icons.battery_std;
      batteryColor = Colors.blue;
    } else if (latest.level > 20) {
      batteryStatus = '부족함';
      batteryIcon = Icons.battery_alert;
      batteryColor = Colors.orange;
    } else {
      batteryStatus = '매우 부족함';
      batteryIcon = Icons.battery_alert;
      batteryColor = Colors.red;
    }

    // 온도 상태
    String tempStatus = '정상';
    Color tempColor = Colors.green;
    if (latest.temperature > 40) {
      tempStatus = '매우 높음';
      tempColor = Colors.red;
    } else if (latest.temperature > 35) {
      tempStatus = '높음';
      tempColor = Colors.orange;
    }

    // 측정 시간 형식화
    final timeStr =
        '${latest.time.hour.toString().padLeft(2, '0')}:${latest.time.minute.toString().padLeft(2, '0')}:${latest.time.second.toString().padLeft(2, '0')}';

    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(batteryIcon, color: batteryColor, size: 32),
                    SizedBox(height: 4),
                    Text('${latest.level}%',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(batteryStatus,
                        style: TextStyle(color: batteryColor, fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.thermostat, color: tempColor, size: 32),
                    SizedBox(height: 4),
                    Text('${latest.temperature.toStringAsFixed(1)}°C',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(tempStatus,
                        style: TextStyle(color: tempColor, fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.access_time, size: 32),
                    SizedBox(height: 4),
                    Text('${data.length}회',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('수집 횟수', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer, size: 16, color: Colors.blue[700]),
                SizedBox(width: 4),
                Text('최근 측정 시간: $timeStr',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 상태 변화량을 보여주는 위젯
  Widget _buildStateChangeInfo(BatteryInfo first, BatteryInfo last) {
    // 배터리 변화량
    final batteryChange = last.level - first.level;
    final tempChange = last.temperature - first.temperature;

    // 시간 차이
    final timeDiffInMinutes = last.time.difference(first.time).inMinutes;

    // 변화량에 따른 색상
    Color batteryChangeColor = Colors.grey;
    if (batteryChange < 0) {
      batteryChangeColor = Colors.red;
    } else if (batteryChange > 0) {
      batteryChangeColor = Colors.green;
    }

    Color tempChangeColor = Colors.grey;
    if (tempChange > 0) {
      tempChangeColor = Colors.red;
    } else if (tempChange < 0) {
      tempChangeColor = Colors.green;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(
                '변화량 (${timeDiffInMinutes}분)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildChangeItem(
                    label: '배터리',
                    changeValue: batteryChange.toDouble(),
                    unit: '%',
                    color: batteryChangeColor,
                    icon: batteryChange < 0
                        ? Icons.arrow_downward
                        : batteryChange > 0
                            ? Icons.arrow_upward
                            : Icons.remove,
                  ),
                  _buildChangeItem(
                    label: '온도',
                    changeValue: tempChange,
                    unit: '°C',
                    color: tempChangeColor,
                    icon: tempChange > 0
                        ? Icons.arrow_upward
                        : tempChange < 0
                            ? Icons.arrow_downward
                            : Icons.remove,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangeItem({
    required String label,
    required double changeValue,
    required String unit,
    required Color color,
    required IconData icon,
  }) {
    final absChange = changeValue.abs();
    final sign = changeValue > 0
        ? '+'
        : changeValue < 0
            ? '-'
            : '';

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            SizedBox(width: 4),
            Text(
              '$sign${absChange.toStringAsFixed(1)}$unit',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 4,
          color: color,
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

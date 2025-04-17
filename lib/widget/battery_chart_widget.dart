import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../model/battry_info.dart';

// 배터리 상태와 온도의 간단한 카드 위젯
class BatteryStatusCard extends StatelessWidget {
  final double batteryLevel;
  final double temperature;
  final DateTime measureTime;

  const BatteryStatusCard({
    Key? key,
    required this.batteryLevel,
    required this.temperature,
    required this.measureTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 시간 포맷팅
    final timeStr =
        '${measureTime.hour.toString().padLeft(2, '0')}:${measureTime.minute.toString().padLeft(2, '0')}:${measureTime.second.toString().padLeft(2, '0')}';

    // 배터리 상태에 따른 색상
    Color batteryColor = Colors.blue;
    if (batteryLevel < 20) {
      batteryColor = Colors.red;
    } else if (batteryLevel < 50) {
      batteryColor = Colors.orange;
    }

    // 온도에 따른 색상
    Color tempColor = Colors.green;
    if (temperature > 40) {
      tempColor = Colors.red;
    } else if (temperature > 35) {
      tempColor = Colors.orange;
    }

    return Card(
      color: Color(0xFF5A6378),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${batteryLevel.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: batteryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2),
            Text(
              '배터리',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${temperature.toStringAsFixed(1)}°C',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: tempColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2),
            Text(
              '온도',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.white70),
                SizedBox(width: 4),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class BatteryChart extends StatelessWidget {
  final List<BatteryInfo> data;
  final List<FlSpot> Function() getLevelSpots;
  final List<FlSpot> Function() getTemperatureSpots;
  final Widget Function(double, TitleMeta) bottomTitleWidgets;

  BatteryChart({
    required this.data,
    required this.getLevelSpots,
    required this.getTemperatureSpots,
    required this.bottomTitleWidgets,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 16.0,
        horizontal: 4.0,
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (value) => Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final spotIndex = touchedSpot.spotIndex;
                  if (spotIndex >= data.length) return null;

                  final dataPoint = data[spotIndex];
                  final dateTime = dataPoint.time;
                  final formattedTime =
                      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';

                  final String label;
                  if (touchedSpot.barIndex == 0) {
                    label = '배터리: ${touchedSpot.y.toStringAsFixed(1)}%';
                  } else {
                    label = '온도: ${touchedSpot.y.toStringAsFixed(1)}°C';
                  }

                  return LineTooltipItem(
                    '시간: $formattedTime\n$label',
                    TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: getLevelSpots(),
              isCurved: true,
              barWidth: 3,
              color: Colors.blue,
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  if (index % 5 == 0) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Colors.blue,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  }
                  return FlDotCirclePainter(
                    radius: 0, // 대부분의 점은 보이지 않게 설정
                    color: Colors.transparent,
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  );
                },
              ),
            ),
            LineChartBarData(
              spots: getTemperatureSpots(),
              isCurved: true,
              barWidth: 3,
              color: Colors.red,
              belowBarData: BarAreaData(
                show: true,
                color: Colors.red.withOpacity(0.1),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  if (index % 5 == 0) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Colors.red,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  }
                  return FlDotCirclePainter(
                    radius: 0, // 대부분의 점은 보이지 않게 설정
                    color: Colors.transparent,
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  );
                },
              ),
            ),
          ],
          titlesData: FlTitlesData(
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (data.isNotEmpty &&
                        data.length > 1 &&
                        (data.last.time.millisecondsSinceEpoch -
                                data.first.time.millisecondsSinceEpoch) >
                            0)
                    ? (data.last.time.millisecondsSinceEpoch -
                                data.first.time.millisecondsSinceEpoch)
                            .toDouble() /
                        4
                    : 1000 * 60 * 60.0, // 기본값: 1시간
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  // 간단하게 인덱스 위치만 표시하여 시간축 혼란 방지
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8.0,
                    child: Text(
                      '', // 시간 표시 제거
                      style: TextStyle(
                        color: Color(0xff68737d),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 10,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: Color(0xff68737d),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: Color(0xff68737d),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 20,
            verticalInterval: (data.isNotEmpty &&
                    data.length > 1 &&
                    (data.last.time.millisecondsSinceEpoch -
                            data.first.time.millisecondsSinceEpoch) >
                        0)
                ? (data.last.time.millisecondsSinceEpoch -
                            data.first.time.millisecondsSinceEpoch)
                        .toDouble() /
                    4
                : 1000 * 60 * 60.0, // 기본값: 1시간
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.3),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.3),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Colors.grey.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

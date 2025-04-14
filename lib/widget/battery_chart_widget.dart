import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../model/battry_info.dart';

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
          lineBarsData: [
            LineChartBarData(
              spots: getLevelSpots(),
              isCurved: true,
              barWidth: 2,
              color: Colors.blue,
              belowBarData: BarAreaData(show: false),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  if (index % 10 == 0) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Colors.red,
                      strokeWidth: 2,
                      strokeColor: Colors.black,
                    );
                  }
                  return FlDotCirclePainter(
                    radius: 2,
                    color: Colors.blue,
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  );
                },
              ),
            ),
            LineChartBarData(
              spots: getTemperatureSpots(),
              isCurved: true,
              barWidth: 2,
              color: Colors.red,
              belowBarData: BarAreaData(show: false),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  if (index % 10 == 0) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Colors.red,
                      strokeWidth: 2,
                      strokeColor: Colors.black,
                    );
                  }
                  return FlDotCirclePainter(
                    radius: 2,
                    color: Colors.red,
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  );
                },
              ),
            ),
          ],
          titlesData: FlTitlesData(
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
                interval: (data.isNotEmpty &&
                        (data.last.time.millisecondsSinceEpoch -
                                data.first.time.millisecondsSinceEpoch) !=
                            0)
                    ? (data.last.time.millisecondsSinceEpoch.toDouble() -
                            data.first.time.millisecondsSinceEpoch.toDouble()) /
                        4
                    : 1,
                getTitlesWidget: (value, meta) {
                  if (data.isNotEmpty) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      final isExclamation = index % 10 == 0;
                      return Text(
                        isExclamation
                            ? '!'
                            : '${data[index].time.hour}:${data[index].time.minute}',
                        style: TextStyle(
                          color: Color(0xff68737d),
                          fontWeight: FontWeight.bold,
                          fontSize: isExclamation ? 14 : 10,
                        ),
                      );
                    }
                  }
                  return const SizedBox();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (data.isNotEmpty &&
                        (data.last.time.millisecondsSinceEpoch -
                                data.first.time.millisecondsSinceEpoch) !=
                            0)
                    ? (data.last.time.millisecondsSinceEpoch.toDouble() -
                            data.first.time.millisecondsSinceEpoch.toDouble()) /
                        4
                    : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < data.length) {
                    final isSpecialTick = index % 10 == 0;
                    return Text(
                      isSpecialTick
                          ? '!'
                          : '${data[index].time.hour}:${data[index].time.minute}',
                      style: TextStyle(
                        color: isSpecialTick ? Colors.red : Color(0xff68737d),
                        fontWeight:
                            isSpecialTick ? FontWeight.bold : FontWeight.normal,
                        fontSize: isSpecialTick ? 14 : 10,
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
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
          gridData: FlGridData(show: false),
        ),
      ),
    );
  }
}

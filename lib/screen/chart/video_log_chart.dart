import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class VideoLogChart extends StatelessWidget {
  final List<FlSpot> videoFrameData;
  final List<FlSpot> audioFrameData;

  VideoLogChart({
    required this.videoFrameData,
    required this.audioFrameData,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: videoFrameData,
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
          ),
          LineChartBarData(
            spots: audioFrameData,
            isCurved: true,
            color: Colors.red,
            barWidth: 2,
          ),
        ],
      ),
    );
  }
}

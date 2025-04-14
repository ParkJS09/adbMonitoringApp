import 'package:adb_test/model/adb_error.dart';
import 'package:adb_test/screen/chart/video_log_chart.dart';
import 'package:adb_test/screen/provider/device_provider.dart';
import 'package:adb_test/screen/provider/log_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LogScreen extends StatefulWidget {
  @override
  _LogScreenState createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TextEditingController _filterController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 화면이 빌드된 후 로그 수집을 시작합니다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLogging();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _startLogging() {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final logProvider = Provider.of<LogProvider>(context, listen: false);

    final selectedDevice = deviceProvider.selectedDevice;
    if (selectedDevice != null && !logProvider.isMonitoring) {
      logProvider.startMonitoring(selectedDevice);
    }
  }

  Future<void> _saveLogsToFile() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final logProvider = Provider.of<LogProvider>(context, listen: false);
      final filePath = await logProvider.saveLogsToFile();

      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그가 저장되었습니다: $filePath'),
            action: SnackBarAction(
              label: '확인',
              onPressed: () {},
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그 저장에 실패했습니다')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildLogLevelFilter() {
    return Consumer<LogProvider>(
      builder: (context, logProvider, child) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: LogLevel.values.map((level) {
              final isEnabled = logProvider.enabledLevels.contains(level);
              final levelName = level.toString().split('.').last.toUpperCase();
              final color = LogEntry(
                timestamp: DateTime.now(),
                tag: '',
                message: '',
                level: level,
              ).levelColor;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: FilterChip(
                  selected: isEnabled,
                  label: Text(levelName),
                  onSelected: (selected) {
                    logProvider.toggleLevel(level);
                  },
                  selectedColor: color.withOpacity(0.3),
                  labelStyle: TextStyle(
                    color: isEnabled ? color : Colors.grey,
                    fontWeight: isEnabled ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildLogList() {
    return Consumer<LogProvider>(
      builder: (context, logProvider, child) {
        final logs = logProvider.logs;

        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.list_alt, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  '수집된 로그가 없습니다',
                  style: TextStyle(fontSize: 16),
                ),
                if (!logProvider.isMonitoring)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ElevatedButton(
                      onPressed: _startLogging,
                      child: Text('로그 수집 시작'),
                    ),
                  ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[logs.length - 1 - index]; // 최신 로그를 위에 표시

            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    child: Text(
                      log.formattedTime,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Container(
                    width: 20,
                    child: Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: log.levelColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.tag,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          log.message,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChartView() {
    return Consumer<LogProvider>(
      builder: (context, logProvider, child) {
        return VideoLogChart(
          videoFrameData: logProvider.videoFrameData,
          audioFrameData: logProvider.audioFrameData,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('로그 모니터링'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.list), text: '로그'),
            Tab(icon: Icon(Icons.show_chart), text: '차트'),
          ],
        ),
        actions: [
          Consumer<LogProvider>(
            builder: (context, logProvider, child) {
              return IconButton(
                icon: Icon(
                    logProvider.isMonitoring ? Icons.pause : Icons.play_arrow),
                tooltip: logProvider.isMonitoring ? '로그 수집 중지' : '로그 수집 시작',
                onPressed: () {
                  if (logProvider.isMonitoring) {
                    logProvider.stopMonitoring();
                  } else {
                    _startLogging();
                  }
                },
              );
            },
          ),
          IconButton(
            icon: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)))
                : Icon(Icons.save),
            tooltip: '로그 저장',
            onPressed: _isSaving ? null : _saveLogsToFile,
          ),
          Consumer<LogProvider>(
            builder: (context, logProvider, child) {
              return IconButton(
                icon: Icon(Icons.delete),
                tooltip: '로그 초기화',
                onPressed: logProvider.clearLogs,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 필터 UI
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _filterController,
              decoration: InputDecoration(
                hintText: '로그 필터링...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              onChanged: (value) {
                Provider.of<LogProvider>(context, listen: false)
                    .setFilter(value);
              },
            ),
          ),

          // 로그 레벨 필터 칩
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildLogLevelFilter(),
          ),

          // 오류 메시지
          Consumer<LogProvider>(
            builder: (context, logProvider, child) {
              if (logProvider.lastError != null) {
                return Container(
                  color: Colors.red.withOpacity(0.1),
                  padding: EdgeInsets.all(8),
                  width: double.infinity,
                  child: Text(
                    logProvider.lastError!.userFriendlyMessage,
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),

          // 탭 컨텐츠
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLogList(),
                _buildChartView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

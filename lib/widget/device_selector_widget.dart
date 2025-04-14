import 'package:adb_test/model/device_info.dart';
import 'package:adb_test/screen/provider/device_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DeviceSelectorWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Consumer<DeviceProvider>(
        builder: (context, deviceProvider, child) {
          return Row(
            children: [
              Icon(Icons.smartphone, size: 20),
              SizedBox(width: 8),
              Text('디바이스:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Expanded(
                child: _buildDeviceDropdown(context, deviceProvider),
              ),
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  size: 20,
                  color: deviceProvider.isLoading ? Colors.grey : null,
                ),
                onPressed: deviceProvider.isLoading
                    ? null
                    : () => deviceProvider.refreshDevices(),
                tooltip: '디바이스 목록 새로고침',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeviceDropdown(BuildContext context, DeviceProvider provider) {
    if (provider.isLoading) {
      return Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          SizedBox(width: 8),
          Text('디바이스 목록 로딩 중...'),
        ],
      );
    }

    if (provider.lastError != null) {
      return Text(
        '오류: ${provider.lastError!.message}',
        style: TextStyle(color: Colors.red),
      );
    }

    if (provider.devices.isEmpty) {
      return Text('연결된 디바이스 없음', style: TextStyle(fontStyle: FontStyle.italic));
    }

    return DropdownButton<String>(
      value: provider.selectedDevice?.id,
      isExpanded: true,
      underline: Container(),
      icon: const Icon(Icons.arrow_drop_down),
      elevation: 16,
      onChanged: (String? newValue) {
        if (newValue != null) {
          provider.selectDeviceById(newValue);
        }
      },
      items:
          provider.devices.map<DropdownMenuItem<String>>((DeviceInfo device) {
        return DropdownMenuItem<String>(
          value: device.id,
          child: Text(
            device.model.isNotEmpty
                ? '${device.model} (${device.id})'
                : device.id,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }
}

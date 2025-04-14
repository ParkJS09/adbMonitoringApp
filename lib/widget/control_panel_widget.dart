import 'package:flutter/material.dart';

class ControlPanel extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onClear;
  final bool isActive;

  const ControlPanel({
    Key? key,
    required this.onStart,
    required this.onStop,
    required this.onClear,
    this.isActive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              context,
              isActive ? '모니터링 중지' : '모니터링 시작',
              isActive ? Icons.stop : Icons.play_arrow,
              isActive ? onStop : onStart,
              isActive ? Colors.red : Colors.green,
            ),
            _buildControlButton(
              context,
              '데이터 초기화',
              Icons.delete,
              onClear,
              Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(BuildContext context, String label, IconData icon,
      VoidCallback onPressed, Color color) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
      ),
    );
  }
}

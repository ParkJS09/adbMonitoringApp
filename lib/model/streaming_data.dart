class StreamingData {
  final int videoBitrate;
  final int videoFps;
  final double videoPacketLoss;
  final int audioBitrate;
  final double audioLevel;
  final double audioPacketLoss;
  final double cpuUsage;
  final double memoryUsage;

  StreamingData({
    required this.videoBitrate,
    required this.videoFps,
    required this.videoPacketLoss,
    required this.audioBitrate,
    required this.audioLevel,
    required this.audioPacketLoss,
    required this.cpuUsage,
    required this.memoryUsage,
  });
}

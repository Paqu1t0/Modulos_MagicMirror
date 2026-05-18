class MirrorStatus {
  final bool isOnline;
  final bool wifiStrong;
  final bool isPowered;
  final bool isSynced;
  final int activeWidgets;
  final int savedPresets;

  const MirrorStatus({
    required this.isOnline,
    required this.wifiStrong,
    required this.isPowered,
    required this.isSynced,
    required this.activeWidgets,
    required this.savedPresets,
  });

  factory MirrorStatus.fromJson(Map<String, dynamic> json) {
    return MirrorStatus(
      isOnline: json['online'] as bool? ?? false,
      wifiStrong: json['wifi'] as bool? ?? false,
      isPowered: json['powered'] as bool? ?? false,
      isSynced: json['synced'] as bool? ?? false,
      activeWidgets: json['activeWidgets'] as int? ?? 0,
      savedPresets: json['savedPresets'] as int? ?? 0,
    );
  }

  static MirrorStatus get demo => const MirrorStatus(
        isOnline: true,
        wifiStrong: true,
        isPowered: true,
        isSynced: true,
        activeWidgets: 12,
        savedPresets: 4,
      );

  static MirrorStatus get offline => const MirrorStatus(
        isOnline: false,
        wifiStrong: false,
        isPowered: false,
        isSynced: false,
        activeWidgets: 0,
        savedPresets: 0,
      );
}

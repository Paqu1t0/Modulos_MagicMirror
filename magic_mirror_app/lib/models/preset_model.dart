import 'package:flutter/material.dart';

class PresetModel {
  final String id;
  final String name;
  final String description;
  final int widgetCount;
  final String iconName;
  final Map<int, Map<String, String>>? layout;
  bool isActive;

  PresetModel({
    required this.id,
    required this.name,
    required this.description,
    required this.widgetCount,
    required this.iconName,
    this.layout,
    this.isActive = false,
  });

  IconData get icon {
    switch (iconName) {
      case 'sunny':
      case 'morning':
        return Icons.wb_sunny;
      case 'cloudy':
      case 'afternoon':
        return Icons.wb_cloudy;
      case 'night':
        return Icons.nightlight_round;
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'music':
        return Icons.music_note;
      case 'photo':
        return Icons.photo;
      default:
        return Icons.dashboard;
    }
  }

  factory PresetModel.fromJson(Map<String, dynamic> json) {
    Map<int, Map<String, String>>? parsedLayout;
    if (json['layout'] != null) {
      try {
        final rawLayout = json['layout'] as Map<String, dynamic>;
        parsedLayout = rawLayout.map((key, value) {
          final pageNum = int.tryParse(key) ?? 1;
          final posMap = Map<String, dynamic>.from(value as Map);
          return MapEntry(
            pageNum,
            posMap.map((k, v) => MapEntry(k, v.toString())),
          );
        });
      } catch (_) {}
    }

    return PresetModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      widgetCount: json['widgetCount'] as int? ?? 0,
      iconName: json['iconName'] as String? ?? 'dashboard',
      layout: parsedLayout,
      isActive: json['active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'widgetCount': widgetCount,
        'iconName': iconName,
        'layout': layout?.map((k, v) => MapEntry(k.toString(), v)),
        'active': isActive,
      };
}

final List<PresetModel> defaultPresets = [
  PresetModel(
    id: 'morning',
    name: 'Morning Routine',
    description: 'Weather, calendar, and news for your morning',
    widgetCount: 5,
    iconName: 'sunny',
    isActive: true,
    layout: {
      1: {'Top Left': 'clock', 'Top Right': 'weather', 'Bottom Center': 'news'},
      2: {'Center': 'calendar'},
      3: {'Bottom Right': 'photos'},
    },
  ),
  PresetModel(
    id: 'afternoon',
    name: 'Afternoon Mode',
    description: 'Relaxed layout with photos and music',
    widgetCount: 5,
    iconName: 'cloudy',
    isActive: false,
    layout: {
      1: {'Top Left': 'clock', 'Top Center': 'music', 'Bottom Center': 'news'},
      2: {'Center': 'photos'},
      3: {'Bottom Right': 'fitness'},
    },
  ),
  PresetModel(
    id: 'night',
    name: 'Night Time',
    description: 'Minimal display with clock and ambient info',
    widgetCount: 2,
    iconName: 'night',
    isActive: false,
    layout: {
      1: {'Top Center': 'clock'},
      2: {'Center': 'weather'},
      3: {},
    },
  ),
];

final List<PresetModel> demoPresets = defaultPresets;

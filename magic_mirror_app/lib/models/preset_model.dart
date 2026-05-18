import 'package:flutter/material.dart';

class PresetModel {
  final String id;
  final String name;
  final String description;
  final int widgetCount;
  final IconData icon;
  bool isActive;

  PresetModel({
    required this.id,
    required this.name,
    required this.description,
    required this.widgetCount,
    required this.icon,
    this.isActive = false,
  });

  factory PresetModel.fromJson(Map<String, dynamic> json) {
    return PresetModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      widgetCount: json['widgetCount'] as int? ?? 0,
      icon: Icons.dashboard,
      isActive: json['active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'widgetCount': widgetCount,
        'active': isActive,
      };
}

final List<PresetModel> demoPresets = [
  PresetModel(
    id: 'morning',
    name: 'Morning Routine',
    description: 'Weather, calendar, and news for your morning',
    widgetCount: 8,
    icon: Icons.wb_sunny,
    isActive: true,
  ),
  PresetModel(
    id: 'weekend',
    name: 'Weekend Mode',
    description: 'Relaxed layout with photos and music',
    widgetCount: 5,
    icon: Icons.home,
    isActive: false,
  ),
  PresetModel(
    id: 'work',
    name: 'Work Focus',
    description: 'Calendar, email, and productivity widgets',
    widgetCount: 6,
    icon: Icons.work,
    isActive: false,
  ),
  PresetModel(
    id: 'night',
    name: 'Night Time',
    description: 'Minimal display with clock and ambient info',
    widgetCount: 3,
    icon: Icons.nightlight_round,
    isActive: false,
  ),
];

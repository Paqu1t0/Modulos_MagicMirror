import 'package:flutter/material.dart';

class WidgetModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final IconData icon;
  final String? author;
  final String? repoUrl;
  final int stars;
  bool isInstalled;
  String? position;

  WidgetModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    this.author,
    this.repoUrl,
    this.stars = 0,
    this.isInstalled = false,
    this.position,
  });

  /// Parse response from the local MagicMirror MMM-Remote-Control API.
  factory WidgetModel.fromJson(Map<String, dynamic> json) {
    return WidgetModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      icon: Icons.widgets,
      isInstalled: json['installed'] as bool? ?? false,
      position: json['position'] as String?,
    );
  }

  /// Parse response from the public magicmirror.builders catalogue API.
  factory WidgetModel.fromCatalogueJson(Map<String, dynamic> json) {
    final name = (json['name'] as String? ?? 'Unknown').replaceAll('MMM-', '');
    final category = _mapCategory(json['categories'] as List<dynamic>?);
    return WidgetModel(
      id: json['name'] as String? ?? name,
      name: name,
      description: json['description'] as String? ?? '',
      category: category,
      icon: _iconForCategory(category),
      author: json['author'] as String?,
      repoUrl: json['url'] as String?,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      isInstalled: false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'installed': isInstalled,
        'position': position,
      };

  static String _mapCategory(List<dynamic>? cats) {
    if (cats == null || cats.isEmpty) return 'General';
    final first = cats.first.toString().toLowerCase();
    if (first.contains('weather')) return 'Lifestyle';
    if (first.contains('clock') || first.contains('time')) return 'Utilities';
    if (first.contains('news') || first.contains('rss')) return 'News';
    if (first.contains('calendar')) return 'Productivity';
    if (first.contains('music') || first.contains('media')) return 'Entertainment';
    if (first.contains('health') || first.contains('fit')) return 'Health';
    if (first.contains('sensor') || first.contains('iot')) return 'IoT';
    return 'General';
  }

  static IconData _iconForCategory(String category) {
    switch (category) {
      case 'Lifestyle':     return Icons.cloud;
      case 'Utilities':    return Icons.access_time;
      case 'News':         return Icons.newspaper;
      case 'Productivity': return Icons.calendar_today;
      case 'Entertainment':return Icons.music_note;
      case 'Health':       return Icons.fitness_center;
      case 'IoT':          return Icons.sensors;
      default:             return Icons.widgets;
    }
  }
}

final List<WidgetModel> demoWidgets = [
  WidgetModel(
    id: 'weather',
    name: 'Weather',
    description: 'Real-time weather updates with 5-day forecast and current conditions',
    category: 'Lifestyle',
    icon: Icons.cloud,
    isInstalled: false,
  ),
  WidgetModel(
    id: 'calendar',
    name: 'Calendar',
    description: 'Sync your events from Google Calendar, Outlook,...',
    category: 'Productivity',
    icon: Icons.calendar_today,
    isInstalled: true,
  ),
  WidgetModel(
    id: 'news',
    name: 'News Feed',
    description: 'Latest headlines from your favorite news sources and...',
    category: 'News',
    icon: Icons.newspaper,
    isInstalled: false,
  ),
  WidgetModel(
    id: 'clock',
    name: 'Clock',
    description: 'Customizable clock with timezone support and...',
    category: 'Utilities',
    icon: Icons.access_time,
    isInstalled: true,
  ),
  WidgetModel(
    id: 'music',
    name: 'Music Player',
    description: 'Control Spotify, Apple Music, or local music playback',
    category: 'Entertainment',
    icon: Icons.music_note,
    isInstalled: false,
  ),
  WidgetModel(
    id: 'fitness',
    name: 'Fitness Tracker',
    description: 'Daily steps, calories, and workout summary from yo...',
    category: 'Health',
    icon: Icons.fitness_center,
    isInstalled: false,
  ),
  WidgetModel(
    id: 'email',
    name: 'Email Inbox',
    description: 'Quick view of unread emails and notifications',
    category: 'Productivity',
    icon: Icons.email,
    isInstalled: false,
  ),
  WidgetModel(
    id: 'photos',
    name: 'Photo Frame',
    description: 'Slideshow of your favorite photos from Google Photo...',
    category: 'Lifestyle',
    icon: Icons.photo,
    isInstalled: false,
  ),
];

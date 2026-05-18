import 'package:flutter/material.dart';

class WidgetModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final IconData icon;
  bool isInstalled;
  String? position;

  WidgetModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    this.isInstalled = false,
    this.position,
  });

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'installed': isInstalled,
        'position': position,
      };
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

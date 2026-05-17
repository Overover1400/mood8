import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'insight_type.dart';

part 'insight.g.dart';

@HiveType(typeId: 12)
class Insight extends HiveObject {
  Insight({
    required this.id,
    required this.type,
    required this.title,
    required this.confidence,
    required this.effectSize,
    required this.sampleSize,
    required this.discoveredAt,
    this.description,
    this.relatedHabitId,
    this.relatedIdentity,
    this.actionable = false,
    this.actionText,
    this.aiExplanation,
    this.dismissed = false,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  InsightType type;

  @HiveField(2)
  String title;

  @HiveField(3)
  String? description;

  @HiveField(4)
  double confidence;

  @HiveField(5)
  double effectSize;

  @HiveField(6)
  int sampleSize;

  @HiveField(7)
  String? relatedHabitId;

  @HiveField(8)
  String? relatedIdentity;

  @HiveField(9)
  bool actionable;

  @HiveField(10)
  String? actionText;

  @HiveField(11)
  String? aiExplanation;

  @HiveField(12)
  DateTime discoveredAt;

  @HiveField(13)
  bool dismissed;

  String get confidenceLabel {
    final c = confidence.abs();
    if (c >= 0.7) return 'very strong';
    if (c >= 0.5) return 'strong';
    if (c >= 0.3) return 'moderate';
    return 'weak';
  }

  IconData get icon => type.icon;
  Color get color => type.color;
}

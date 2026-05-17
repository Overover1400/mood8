import 'package:hive/hive.dart';

import 'routine_category.dart';

part 'routine_item.g.dart';

@HiveType(typeId: 1)
class RoutineItem extends HiveObject {
  RoutineItem({
    required this.id,
    required this.title,
    required this.time,
    required this.durationMinutes,
    required this.category,
    required this.meta,
    this.isCompleted = false,
    this.completedAt,
    this.sortOrder = 0,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime time;

  @HiveField(3)
  int durationMinutes;

  @HiveField(4)
  RoutineCategory category;

  @HiveField(5)
  String meta;

  @HiveField(6)
  bool isCompleted;

  @HiveField(7)
  DateTime? completedAt;

  @HiveField(8)
  int sortOrder;
}

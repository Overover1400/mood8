import 'package:hive/hive.dart';

part 'reflection.g.dart';

@HiveType(typeId: 6)
class Reflection extends HiveObject {
  Reflection({
    required this.id,
    required this.date,
    required this.reflection,
    required this.generatedAt,
    this.suggestion,
    this.identityScores,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String reflection;

  @HiveField(3)
  String? suggestion;

  @HiveField(4)
  DateTime generatedAt;

  @HiveField(5)
  Map<String, double>? identityScores;
}

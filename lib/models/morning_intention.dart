import 'package:hive/hive.dart';

part 'morning_intention.g.dart';

@HiveType(typeId: 15)
class MorningIntention extends HiveObject {
  MorningIntention({
    required this.id,
    required this.date,
    required this.text,
    required this.createdAt,
    this.wasSkipped = false,
    this.updatedAt,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String text;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  bool wasSkipped;

  @HiveField(5)
  DateTime? updatedAt;
}

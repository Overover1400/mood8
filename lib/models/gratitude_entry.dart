import 'package:hive/hive.dart';

part 'gratitude_entry.g.dart';

@HiveType(typeId: 16)
class GratitudeEntry extends HiveObject {
  GratitudeEntry({
    required this.id,
    required this.date,
    required List<String> items,
    required this.createdAt,
  }) : items = _normalize(items);

  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  /// Up to 3 strings the user is grateful for today.
  @HiveField(2)
  List<String> items;

  @HiveField(3)
  DateTime createdAt;

  bool get isEmpty => items.every((s) => s.trim().isEmpty);

  /// Returns the non-empty items (trimmed). Always ≤ 3.
  List<String> get nonEmptyItems =>
      items.where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();

  static List<String> _normalize(List<String> raw) {
    final cleaned = <String>[
      for (final s in raw.take(3)) s.trim(),
    ];
    while (cleaned.length < 3) {
      cleaned.add('');
    }
    return cleaned;
  }
}

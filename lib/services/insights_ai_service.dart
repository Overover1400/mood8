import 'package:flutter/foundation.dart';

import '../models/daily_data.dart';
import '../models/insight.dart';
import 'ai_service.dart';
import 'insights_repository.dart';

class InsightsAiService {
  InsightsAiService({AiService? ai, InsightsRepository? repo})
      : _ai = ai ?? AiService(),
        _repo = repo ?? InsightsRepository();

  final AiService _ai;
  final InsightsRepository _repo;

  Future<String> enhanceInsight(Insight insight) async {
    if (insight.aiExplanation != null && insight.aiExplanation!.isNotEmpty) {
      return insight.aiExplanation!;
    }
    try {
      final text = await _ai.explainInsight(
        title: insight.title,
        description: insight.description,
      );
      if (text.isNotEmpty) {
        insight.aiExplanation = text;
        await _repo.saveInsight(insight);
      }
      return text;
    } catch (e) {
      debugPrint('InsightsAiService.enhanceInsight failed: $e');
      rethrow;
    }
  }

  Future<String> explainWhy(Insight insight) => enhanceInsight(insight);

  Future<String> suggestNextAction(Insight insight) async {
    try {
      return await _ai.explainInsight(
        title: 'Next action for: ${insight.title}',
        description:
            'Suggest exactly one concrete next action in one sentence. '
            'Pattern: ${insight.description ?? insight.title}',
      );
    } catch (e) {
      debugPrint('InsightsAiService.suggestNextAction failed: $e');
      rethrow;
    }
  }

  Future<String> generateNarrative(
    List<Insight> insights, {
    DailyData? context,
  }) async {
    if (insights.isEmpty) {
      return 'No clear patterns yet — keep tracking and Mood8 will surface them as soon as the signal is there.';
    }
    final top = insights.take(5);
    final bullets = top
        .map((i) =>
            '- ${i.title} (${i.confidenceLabel}, n=${i.sampleSize})')
        .join('\n');
    try {
      return await _ai.weeklyNarrative(
        summary: 'Patterns found this week:\n$bullets',
        context: context,
      );
    } catch (e) {
      debugPrint('InsightsAiService.generateNarrative failed: $e');
      rethrow;
    }
  }

  void close() => _ai.close();
}

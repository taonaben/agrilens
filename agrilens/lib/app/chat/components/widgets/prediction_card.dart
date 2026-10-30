import 'package:agrilens/app/chat/components/utils/chat_text_formatters.dart';
import 'package:agrilens/app/chat/models/prediction.dart';
import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class PredictionCard extends StatelessWidget {
  const PredictionCard({super.key, required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final isHealthy = prediction.condition == 'healthy';
    final conditionName = titleCaseFromSnake(prediction.condition);
    final cropName = titleCaseFromSnake(prediction.crop);

    final summary = switch (prediction.decisionState) {
      DecisionState.possibleMatch => (
        headline: 'Possible match: $cropName • $conditionName',
        details:
            isHealthy
                ? 'No supported condition was recognised in this photo. '
                    'This does not guarantee the plant is healthy.'
                : 'Model confidence: ${(prediction.calibratedScore * 100).toStringAsFixed(1)}%. '
                    'This is a support signal, not a confirmed diagnosis.',
      ),
      DecisionState.uncertain || DecisionState.unsupportedOrUnclear => (
        headline: 'Uncertain result',
        details:
            prediction.failureReason ??
            'The image evidence was not strong enough for a confident match. '
                'Try a clear, well-lit photo showing the pest or crop symptoms.',
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: AppColors.primaryDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.headline,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onPrimary,
            ),
          ),
          const Gap(AppConstants.gapSmall),
          Text(
            summary.details,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.onPrimary.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

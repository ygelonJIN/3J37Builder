import 'package:flutter/material.dart';
import '../data/services/dataset_loader.dart';
import '../theme/app_tokens.dart';

class TakeoverPanel extends StatelessWidget {
  const TakeoverPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final loader = DatasetLoader();
    final takeovers = loader.takeovers;
    

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Takeover Abilities', style: AppTokens.cardTitleStyle),
        const SizedBox(height: 4),
        Text(
          '29 abilities (24 published + 5 internal). Attribute codes are unresolved enum values.',
          style: AppTokens.caption,
        ),
        const SizedBox(height: 12),
        ...takeovers.map((t) {
          final hasReqs = t.hasRequirements;
          // We can't fully resolve requirements since the attribute enum is different,
          // but we show what we have
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTokens.surfaceAlt,
              border: Border.all(color: AppTokens.cardBorder, width: 0.5),
              borderRadius: BorderRadius.circular(AppTokens.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasReqs ? Icons.shield : Icons.shield_outlined,
                      size: 14,
                      color: hasReqs ? AppTokens.primary : AppTokens.keyOff,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ability ${t.abilityCode}',
                      style: AppTokens.body.copyWith(
                        color: hasReqs ? AppTokens.textPrimary : AppTokens.keyOff,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    if (!hasReqs)
                      Text('No requirements', style: AppTokens.caption.copyWith(fontSize: 10)),
                  ],
                ),
                if (hasReqs) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: t.requirements.map((r) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTokens.surface,
                          border: Border.all(color: AppTokens.chipBorder, width: 0.5),
                          borderRadius: BorderRadius.circular(AppTokens.radius),
                        ),
                        child: Text(
                          'Attr ${r.attributeCode} ≥ ${r.minimum}',
                          style: AppTokens.caption.copyWith(fontSize: 10),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

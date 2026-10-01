import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../api/api_models.dart';
import '../content/app.g.dart';
import '../design_system/design_system.dart';

String formatStorageBytes(int bytes, String locale) {
  final (unit, divisor) = bytes >= 1000000000
      ? ('GB', 1000000000)
      : bytes >= 1000000
      ? ('MB', 1000000)
      : bytes >= 1000
      ? ('KB', 1000)
      : ('B', 1);
  return '${NumberFormat('0.#', locale).format(bytes / divisor)} $unit';
}

class StorageUsage extends StatelessWidget {
  const StorageUsage({super.key, required this.storage});
  final ApiStorage? storage;

  @override
  Widget build(BuildContext context) {
    final copy = AppContent.of(context).v6.storage;
    final c = CameoTheme.colorsOf(context);
    final locale = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    final quota = storage;
    String bytes(int value) => formatStorageBytes(value, locale);
    return Padding(
      padding: const EdgeInsets.all(CameoSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CameoSpace.s8,
        children: [
          CameoText(
            quota == null
                ? copy.title
                : quota.quotaBytes == null
                ? copy.unlimited
                : fillTemplate(
                    quota.isPro ? copy.proCapacity : copy.freeCapacity,
                    {'amount': bytes(quota.quotaBytes!)},
                  ),
            style: CameoTextStyles.bodyLgStrong,
            color: c.foregroundNeutralBase,
            maxLines: 1,
          ),
          CameoText(
            quota == null
                ? copy.unavailable
                : fillTemplate(copy.usage, {
                    'used': bytes(quota.usedBytes),
                    'limit': quota.quotaBytes == null
                        ? copy.unlimited
                        : bytes(quota.quotaBytes!),
                  }),
            key: const ValueKey('storage.usage'),
            style: CameoTextStyles.bodyMd,
            color: c.foregroundNeutralMuted,
            maxLines: 1,
          ),
          if (quota != null && quota.quotaBytes != null) ...[
            Semantics(
              label: fillTemplate(copy.usage, {
                'used': bytes(quota.usedBytes),
                'limit': quota.quotaBytes == null
                    ? copy.unlimited
                    : bytes(quota.quotaBytes!),
              }),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(CameoRadius.full),
                child: SizedBox(
                  key: const ValueKey('storage.progress'),
                  height: CameoSpace.s4,
                  child: ColoredBox(
                    color: c.backgroundFillNeutralBase,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: quota.progress,
                        child: ColoredBox(
                          color: quota.isFull
                              ? c.systemRed
                              : c.foregroundNeutralBase,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (quota.isFull)
              CameoText(
                copy.full,
                style: CameoTextStyles.bodySm,
                color: c.systemRed,
                maxLines: 1,
              ),
          ],
        ],
      ),
    );
  }
}

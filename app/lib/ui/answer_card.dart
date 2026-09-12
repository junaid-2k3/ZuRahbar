import 'package:flutter/material.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';

/// Route badges are colour-coded by service type (UI-5.4.1) so a rider can
/// tell an express from a feeder at a glance.
const _serviceTypeColors = {
  'express': Colors.deepOrange,
  'super_express': Colors.red,
  'standard': Colors.blue,
  'direct': Colors.teal,
};

class AnswerCard extends StatelessWidget {
  final String replyText;
  final JourneyPlan? plan;
  final bool isOffline;

  const AnswerCard({
    super.key,
    required this.replyText,
    this.plan,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(replyText),
            if (plan != null && plan!.found) ..._planDetails(context, theme, muted),
            if (plan != null && !plan!.found && plan!.warnings.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final warning in plan!.warnings) Text(warning, style: muted),
            ],
            if (isOffline) ...[
              const SizedBox(height: 6),
              Text(
                'Answered on-device — routes and fares are exact, wording is not AI-written.',
                style: muted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _planDetails(BuildContext context, ThemeData theme, TextStyle? muted) {
    final journey = plan!;
    return [
      const Divider(height: 20),
      for (final leg in journey.legs) _legRow(theme, leg),
      if (journey.legs.length > 1) ...[
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.swap_horiz, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Change at ${journey.legs.skip(1).map((leg) => leg.boardStation).join(', ')}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 8),
      Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          _stat(theme, Icons.payments_outlined, 'Rs. ${journey.fare?.totalPkr ?? '—'}'),
          _stat(theme, Icons.schedule, '${journey.totalTimeMin.round()} min'),
          if (_frequency(journey) != null)
            _stat(theme, Icons.directions_bus_filled_outlined, _frequency(journey)!),
        ],
      ),
      if (journey.serviceAvailable == false) ...[
        const SizedBox(height: 6),
        Text('Outside published service hours right now. ${_publishedHours(journey)}',
            style: muted),
      ],
      if (journey.fare?.isEstimate ?? false) ...[
        const SizedBox(height: 6),
        Text('Fare is an estimate — distances are interpolated.', style: muted),
      ],
    ];
  }

  Widget _legRow(ThemeData theme, Leg leg) {
    final color = _serviceTypeColors[leg.serviceType] ?? Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              border: Border.all(color: color.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              leg.routeId,
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${leg.boardStation} → ${leg.alightStation}'),
                Text(
                  '${leg.stopCount} ${leg.stopCount == 1 ? 'stop' : 'stops'} · '
                  '${leg.rideTimeMin.round()} min'
                  '${leg.platform != null ? ' · platform ${leg.platform}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(ThemeData theme, IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.bodyMedium),
        ],
      );

  /// The hours each leg's route actually runs, so an off-hours answer says when
  /// to come back rather than just "closed" (FR-9.3).
  String _publishedHours(JourneyPlan journey) {
    final windows = [
      for (final leg in journey.legs)
        if (leg.firstBus != null && leg.lastBus != null)
          '${leg.routeId} runs ${leg.firstBus}–${leg.lastBus}',
    ];
    return windows.isEmpty ? '' : '${windows.join('; ')}.';
  }

  /// Bus frequency on the first leg (FR-6.2), when the dataset publishes one.
  String? _frequency(JourneyPlan journey) {
    if (journey.legs.isEmpty) return null;
    final low = journey.legs.first.headwayMinLow;
    if (low == null) return null;
    final high = journey.legs.first.headwayMinHigh;
    return high == null || high == low ? 'every ~$low min' : 'every $low–$high min';
  }
}

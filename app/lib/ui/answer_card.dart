import 'package:flutter/material.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';

const _serviceTypeColors = {
  'express': Colors.deepOrange,
  'super_express': Colors.red,
  'standard': Colors.blue,
  'direct': Colors.teal,
};

class AnswerCard extends StatelessWidget {
  final String replyText;
  final JourneyPlan? plan;

  const AnswerCard({super.key, required this.replyText, this.plan});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(replyText),
            if (plan != null && plan!.found) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: plan!.legs
                    .map((leg) => Chip(
                          label: Text(leg.routeId),
                          backgroundColor:
                              (_serviceTypeColors[leg.serviceType] ?? Colors.grey).withOpacity(0.2),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 4),
              Text('Fare: Rs. ${plan!.fare?.totalPkr ?? '—'} · '
                  '${plan!.totalTimeMin.toStringAsFixed(0)} min'),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ReadingHistoryChartWidget extends StatelessWidget {
  final String meterType;
  final List<dynamic> readings;

  const ReadingHistoryChartWidget({
    super.key,
    required this.meterType,
    required this.readings,
  });

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Center(
        child: Text('No history data available'),
      );
    }

    final List<FlSpot> spots = readings.asMap().entries.map((entry) {
      // Try both 'value' and 'reading' fields for compatibility
      final reading = entry.value['value'] ?? entry.value['reading'];
      final value = reading != null ? double.tryParse(reading.toString()) ?? 0.0 : 0.0;
      return FlSpot(entry.key.toDouble(), value);
    }).toList();

    return AspectRatio(
      aspectRatio: 2,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.shade300),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Theme.of(context).primaryColor,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withValues(red: 0, green: 0, blue: 0, alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

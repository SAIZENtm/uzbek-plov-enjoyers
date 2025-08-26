import 'package:flutter/material.dart';

import 'reading_history_chart_widget.dart';

class MeterReadingCardWidget extends StatelessWidget {
  final String meterType;
  final String currentReading;
  final String lastReading;
  final String lastReadingDate;
  final List<dynamic> readings;
  final VoidCallback onSubmit;
  final String meterName;
  final String unit;
  final String lastDate;
  final IconData icon;
  final Color color;
  final TextEditingController controller;
  final bool isValid;
  final String? capturedPhoto;
  final Function(String) onReadingChanged;
  final Function(String) onPhotoCapture;
  final List<Map<String, dynamic>> historyData;

  const MeterReadingCardWidget({
    super.key,
    required this.meterType,
    required this.currentReading,
    required this.lastReading,
    required this.lastReadingDate,
    required this.readings,
    required this.onSubmit,
    required this.meterName,
    required this.unit,
    required this.lastDate,
    required this.icon,
    required this.color,
    required this.controller,
    required this.isValid,
    this.capturedPhoto,
    required this.onReadingChanged,
    required this.onPhotoCapture,
    required this.historyData,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  meterName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Icon(
                  icon,
                  color: color.withAlpha(204),
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Last Reading: $lastReading $unit',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Date: $lastDate',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Current Reading',
                suffixText: unit,
                errorText: !isValid ? 'Invalid reading' : null,
              ),
              onChanged: onReadingChanged,
            ),
            const SizedBox(height: 16),
            if (capturedPhoto != null)
              Image.network(
                capturedPhoto!,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => onPhotoCapture(''),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Photo'),
            ),
            const SizedBox(height: 16),
            ReadingHistoryChartWidget(
              meterType: meterType,
              readings: readings,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isValid ? onSubmit : null,
                child: const Text('Submit Reading'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

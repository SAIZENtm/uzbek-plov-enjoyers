
import '../../core/app_export.dart';
import 'package:go_router/go_router.dart';
import './widgets/meter_reading_card_widget.dart';
import './widgets/submission_status_widget.dart';

class UtilityReadingsScreen extends StatefulWidget {
  const UtilityReadingsScreen({super.key});

  @override
  State<UtilityReadingsScreen> createState() => _UtilityReadingsScreenState();
}

class _UtilityReadingsScreenState extends State<UtilityReadingsScreen> {
  final Map<String, TextEditingController> _controllers = {
    'electricity': TextEditingController(),
    'gas': TextEditingController(),
    'water': TextEditingController(),
  };

  final Map<String, String?> _capturedPhotos = {
    'electricity': null,
    'gas': null,
    'water': null,
  };

  final Map<String, bool> _isValidReading = {
    'electricity': false,
    'gas': false,
    'water': false,
  };

  bool _isSubmitting = false;
  final DateTime _submissionDeadline =
      DateTime.now().add(const Duration(days: 5));

  // Mock data for meter readings
  final List<Map<String, dynamic>> _meterData = [
    {
      "type": "electricity",
      "name": "Электричество",
      "unit": "кВт·ч",
      "lastReading": "1245.67",
      "lastDate": "15.11.2024",
      "icon": Icons.flash_on,
      "color": const Color(0xFFF39C12),
      "history": [
        {"month": "Июн", "value": 1180.5},
        {"month": "Июл", "value": 1195.2},
        {"month": "Авг", "value": 1210.8},
        {"month": "Сен", "value": 1225.4},
        {"month": "Окт", "value": 1240.1},
        {"month": "Ноя", "value": 1245.67},
      ]
    },
    {
      "type": "gas",
      "name": "Газ",
      "unit": "м³",
      "lastReading": "892.34",
      "lastDate": "15.11.2024",
      "icon": Icons.local_fire_department,
      "color": const Color(0xFF3498DB),
      "history": [
        {"month": "Июн", "value": 850.2},
        {"month": "Июл", "value": 860.5},
        {"month": "Авг", "value": 870.8},
        {"month": "Сен", "value": 881.1},
        {"month": "Окт", "value": 886.7},
        {"month": "Ноя", "value": 892.34},
      ]
    },
    {
      "type": "water",
      "name": "Вода",
      "unit": "м³",
      "lastReading": "156.89",
      "lastDate": "15.11.2024",
      "icon": Icons.water_drop,
      "color": const Color(0xFF27AE60),
      "history": [
        {"month": "Июн", "value": 145.2},
        {"month": "Июл", "value": 148.5},
        {"month": "Авг", "value": 151.3},
        {"month": "Сен", "value": 153.8},
        {"month": "Окт", "value": 155.4},
        {"month": "Ноя", "value": 156.89},
      ]
    },
  ];

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _validateReading(String type, String value) {
    if (value.isEmpty) {
      setState(() {
        _isValidReading[type] = false;
      });
      return;
    }

    // Remove any whitespace and replace commas with dots
    final cleanValue = value.trim().replaceAll(',', '.');
    
    final double? newReading = double.tryParse(cleanValue);
    if (newReading == null) {
      setState(() {
        _isValidReading[type] = false;
      });
      _showValidationDialog(type, 'Пожалуйста, введите корректное числовое значение');
      return;
    }

    // Validate reading is not negative
    if (newReading < 0) {
      _showValidationDialog(type, 'Показание не может быть отрицательным');
      setState(() {
        _isValidReading[type] = false;
      });
      return;
    }

    final meterInfo = _meterData.firstWhere(
      (meter) => meter['type'] == type,
      orElse: () => throw Exception('Счетчик не найден'),
    );
    
    final double lastReading = double.parse(meterInfo['lastReading']);

    // Validate reading is not less than last reading
    if (newReading < lastReading) {
      _showValidationDialog(
          type, 'Новое показание не может быть меньше предыдущего');
      setState(() {
        _isValidReading[type] = false;
      });
      return;
    }

    // Check for unusual increases
    final double difference = newReading - lastReading;
    final double averageMonthlyUsage = _calculateAverageUsage(type);

    // Add maximum threshold check
    final double maxThreshold = averageMonthlyUsage * 3;
    if (difference > maxThreshold) {
      _showUnusualIncreaseDialog(type, difference, averageMonthlyUsage);
      setState(() {
        _isValidReading[type] = false;
      });
      return;
    }

    // Check for suspiciously small readings
    if (difference < averageMonthlyUsage * 0.1 && difference > 0) {
      _showValidationDialog(
          type, 'Показание подозрительно низкое. Пожалуйста, проверьте введенное значение');
      setState(() {
        _isValidReading[type] = false;
      });
      return;
    }

    setState(() {
      _isValidReading[type] = true;
    });
  }

  double _calculateAverageUsage(String type) {
    final meterInfo = _meterData.firstWhere((meter) => meter['type'] == type);
    final List<dynamic> history = meterInfo['history'];

    if (history.length < 2) return 0;

    double totalUsage = 0;
    for (int i = 1; i < history.length; i++) {
      totalUsage += (history[i]['value'] - history[i - 1]['value']);
    }

    return totalUsage / (history.length - 1);
  }

  void _showValidationDialog(String type, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ошибка ввода'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showUnusualIncreaseDialog(
      String type, double difference, double average) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Необычное увеличение'),
        content: Text(
          'Потребление увеличилось на ${difference.toStringAsFixed(2)} единиц, '
          'что превышает средний месячный расход (${average.toStringAsFixed(2)}). '
          'Подтвердите правильность показания.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isValidReading[type] = false;
              });
            },
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isValidReading[type] = true;
              });
            },
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
  }

  void _onPhotoCapture(String type, String? photoPath) {
    setState(() {
      _capturedPhotos[type] = photoPath;
    });
  }

  bool get _canSubmit {
    return _isValidReading.values.every((isValid) => isValid) && !_isSubmitting;
  }

  Future<void> _submitAllReadings() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      _showSuccessDialog();
    } catch (e) {
      _showErrorDialog('Ошибка при отправке показаний. Попробуйте позже.');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showSuccessDialog() {
    final totalEstimatedBill = _calculateEstimatedBill();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            CustomIconWidget(
              iconName: 'check_circle',
              color: AppTheme.successLight,
              size: 24,
            ),
            SizedBox(width: 8),
            Text('Показания отправлены'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ваши показания успешно переданы в управляющую компанию.'),
            const SizedBox(height: 16),
            Text(
              'Предварительная сумма к оплате:',
              style: AppTheme.lightTheme.textTheme.titleSmall,
            ),
            Text(
              '${totalEstimatedBill.toStringAsFixed(0)} сум',
              style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                color: AppTheme.primaryLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/payment-screen');
            },
            child: const Text('Перейти к оплате'),
          ),
        ],
      ),
    );
  }

  double _calculateEstimatedBill() {
    double total = 0;

    for (final meter in _meterData) {
      final type = meter['type'];
      final controller = _controllers[type];
      if (controller?.text.isNotEmpty == true) {
        final newReading = double.tryParse(controller?.text ?? '') ?? 0;
        final lastReading = double.parse(meter['lastReading']);
        final usage = newReading - lastReading;

        // Mock tariffs
        final tariffs = {
          'electricity': 825.0, // per kWh
          'gas': 1250.0, // per m³
          'water': 3500.0, // per m³
        };

        total += usage * (tariffs[type] ?? 0);
      }
    }

    return total;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            CustomIconWidget(
              iconName: 'error',
              color: AppTheme.errorLight,
              size: 24,
            ),
            SizedBox(width: 8),
            Text('Ошибка'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatTimeRemaining() {
    final now = DateTime.now();
    final difference = _submissionDeadline.difference(now);

    if (difference.isNegative) {
      return 'Срок истек';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    if (days > 0) {
      return '$days ${_getDaysText(days)} $hours ${_getHoursText(hours)}';
    } else if (hours > 0) {
      return '$hours ${_getHoursText(hours)} $minutes ${_getMinutesText(minutes)}';
    } else {
      return '$minutes ${_getMinutesText(minutes)}';
    }
  }

  String _getDaysText(int days) {
    if (days % 10 == 1 && days % 100 != 11) {
      return 'день';
    } else if (days % 10 >= 2 && days % 10 <= 4 && (days % 100 < 10 || days % 100 >= 20)) {
      return 'дня';
    } else {
      return 'дней';
    }
  }

  String _getHoursText(int hours) {
    if (hours % 10 == 1 && hours % 100 != 11) {
      return 'час';
    } else if (hours % 10 >= 2 && hours % 10 <= 4 && (hours % 100 < 10 || hours % 100 >= 20)) {
      return 'часа';
    } else {
      return 'часов';
    }
  }

  String _getMinutesText(int minutes) {
    if (minutes % 10 == 1 && minutes % 100 != 11) {
      return 'минута';
    } else if (minutes % 10 >= 2 && minutes % 10 <= 4 && (minutes % 100 < 10 || minutes % 100 >= 20)) {
      return 'минуты';
    } else {
      return 'минут';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Показания счетчиков'),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: AppTheme.lightTheme.colorScheme.onSurface,
            size: 24,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Справка'),
                  content: const Text(
                    'Подавайте показания до 20 числа каждого месяца. '
                    'Сфотографируйте счетчик для подтверждения показаний. '
                    'При необычных показаниях система запросит подтверждение.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Понятно'),
                    ),
                  ],
                ),
              );
            },
            icon: CustomIconWidget(
              iconName: 'help_outline',
              color: AppTheme.lightTheme.colorScheme.onSurface,
              size: 24,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Submission Status
            SubmissionStatusWidget(
              deadline: _submissionDeadline,
              timeRemaining: _formatTimeRemaining(),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Текущие показания',
                      style: AppTheme.lightTheme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),

                    // Meter Cards
                    ...(_meterData.map((meter) {
                      final type = meter['type'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: MeterReadingCardWidget(
                          meterType: type,
                          currentReading: meter['lastReading'],
                          lastReading: meter['lastReading'],
                          lastReadingDate: meter['lastDate'],
                          readings: meter['history'] as List,
                          onSubmit: () => _validateReading(type, meter['lastReading']),
                          meterName: meter['name'],
                          unit: meter['unit'],
                          lastDate: meter['lastDate'],
                          icon: meter['icon'],
                          color: meter['color'],
                          controller: _controllers[type] ?? TextEditingController(),
                          isValid: _isValidReading[type] ?? false,
                          capturedPhoto: _capturedPhotos[type],
                          onReadingChanged: (value) =>
                              _validateReading(type, value),
                          onPhotoCapture: (photoPath) =>
                              _onPhotoCapture(type, photoPath),
                          historyData: (meter['history'] as List)
                              .cast<Map<String, dynamic>>(),
                        ),
                      );
                    }).toList()),

                    const SizedBox(height: 80), // Space for fixed button
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Fixed Submit Button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.scaffoldBackgroundColor,
          boxShadow: const [
            BoxShadow(
              color: AppTheme.shadowLight,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submitAllReadings : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSubmit
                    ? AppTheme.primaryLight
                    : AppTheme.textDisabledLight,
                foregroundColor: Colors.white,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomIconWidget(
                          iconName: 'send',
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Отправить все показания',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

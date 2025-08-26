import 'package:go_router/go_router.dart';

import '../../core/app_export.dart';
import '../../core/di/service_locator.dart';
import './widgets/stepper/step1_request_type_widget.dart';
import './widgets/stepper/step2_photo_widget.dart';
import './widgets/stepper/step3_contact_method_widget.dart';
import './widgets/stepper/step4_priority_widget.dart';
import './widgets/stepper/step5_datetime_widget.dart';
import '../../widgets/blue_button.dart';

class ServiceRequestStepperScreen extends StatefulWidget {
  final String? initialRequestType;
  
  const ServiceRequestStepperScreen({
    super.key,
    this.initialRequestType,
  });

  @override
  State<ServiceRequestStepperScreen> createState() => _ServiceRequestStepperScreenState();
}

class _ServiceRequestStepperScreenState extends State<ServiceRequestStepperScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  // Form data
  String? _selectedRequestType;
  String _description = '';
  List<String> _attachedPhotos = [];
  String _selectedContactMethod = 'phone';
  String _selectedPriority = 'Low';
  DateTime? _selectedDateTime;

  // Stepper state
  int _currentStep = 0;
  bool _isLoading = false;

  // Request types data
  final List<Map<String, dynamic>> _requestTypes = [
    {'value': 'plumbing', 'label': 'Сантехника', 'icon': 'plumbing'},
    {'value': 'electrical', 'label': 'Электрика', 'icon': 'electrical_services'},
    {'value': 'cleaning', 'label': 'Уборка', 'icon': 'cleaning_services'},
    {'value': 'other', 'label': 'Прочее', 'icon': 'build'},
  ];

  final List<Map<String, dynamic>> _priorityOptions = [
    {'value': 'Low', 'label': 'Низкий', 'color': const Color(0xFF27AE60), 'emoji': '🟢'},
    {'value': 'Medium', 'label': 'Средний', 'color': const Color(0xFFF39C12), 'emoji': '🟡'},
    {'value': 'High', 'label': 'Высокий', 'color': const Color(0xFFE74C3C), 'emoji': '🔴'},
    {'value': 'Emergency', 'label': 'Экстренный', 'color': const Color(0xFF8E44AD), 'emoji': '🟣'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDraftData();
    _descriptionController.addListener(_onDescriptionChanged);
    
    // Set initial request type if provided
    if (widget.initialRequestType != null && 
        _requestTypes.any((type) => type['value'] == widget.initialRequestType)) {
      _selectedRequestType = widget.initialRequestType;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _onDescriptionChanged() {
    setState(() {
      _description = _descriptionController.text;
    });
  }

  Future<void> _loadDraftData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final draftRequestType = prefs.getString('stepper_draft_request_type');
      _selectedRequestType = draftRequestType != null && 
          _requestTypes.any((type) => type['value'] == draftRequestType) 
          ? draftRequestType 
          : null;
          
      _descriptionController.text = prefs.getString('stepper_draft_description') ?? '';
      
      final draftPriority = prefs.getString('stepper_draft_priority') ?? 'Low';
      _selectedPriority = _priorityOptions.any((option) => option['value'] == draftPriority) 
          ? draftPriority 
          : 'Low';
          
      final draftContactMethod = prefs.getString('stepper_draft_contact_method') ?? 'phone';
      _selectedContactMethod = ['phone', 'notification'].contains(draftContactMethod) 
          ? draftContactMethod 
          : 'phone';
          
      final dateString = prefs.getString('stepper_draft_date_time');
      if (dateString != null) {
        _selectedDateTime = DateTime.tryParse(dateString);
      }
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('stepper_draft_request_type', _selectedRequestType ?? '');
    await prefs.setString('stepper_draft_description', _descriptionController.text);
    await prefs.setString('stepper_draft_priority', _selectedPriority);
    await prefs.setString('stepper_draft_contact_method', _selectedContactMethod);
    if (_selectedDateTime != null) {
      await prefs.setString('stepper_draft_date_time', _selectedDateTime!.toIso8601String());
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('stepper_draft_request_type');
    await prefs.remove('stepper_draft_description');
    await prefs.remove('stepper_draft_priority');
    await prefs.remove('stepper_draft_contact_method');
    await prefs.remove('stepper_draft_date_time');
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0: // Step 1: Request type and description
        return _selectedRequestType != null && _description.trim().isNotEmpty;
      case 1: // Step 2: Photo (optional)
        return true;
      case 2: // Step 3: Contact method
        return _selectedContactMethod.isNotEmpty;
      case 3: // Step 4: Priority
        return _selectedPriority.isNotEmpty;
      case 4: // Step 5: DateTime
        return _selectedDateTime != null;
      default:
        return false;
    }
  }

  bool _canSubmit() {
    return _selectedRequestType != null &&
           _description.trim().isNotEmpty &&
           _selectedContactMethod.isNotEmpty &&
           _selectedPriority.isNotEmpty &&
           _selectedDateTime != null;
  }

  void _nextStep() {
    if (_canProceedToNextStep()) {
      setState(() {
        _currentStep++;
      });
      _saveDraft();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _goToStep(int step) {
    if (step >= 0 && step <= 4) {
      setState(() {
        _currentStep = step;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_canSubmit()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, заполните все обязательные поля'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Получаем сервисы
      late final ServiceRequestService serviceRequestService;
      late final AuthService authService;
      
      try {
        serviceRequestService = GetIt.instance<ServiceRequestService>();
        authService = GetIt.instance<AuthService>();
      } catch (e) {
        throw Exception('Ошибка инициализации сервисов. Перезапустите приложение.');
      }
      
      // Проверяем статус авторизации
      if (!authService.isAuthenticated) {
        throw Exception('Пользователь не авторизован. Войдите в систему.');
      }
      
      // Дополнительная отладочная информация
      getIt<LoggingService>().debug('Debug: isAuthenticated = ${authService.isAuthenticated}');
      getIt<LoggingService>().debug('Debug: userData = ${authService.userData}');
      getIt<LoggingService>().debug('Debug: verifiedApartment = ${authService.verifiedApartment}');
      getIt<LoggingService>().debug('Debug: userApartments = ${authService.userApartments}');
      
      // Получаем данные пользователя
      final userData = authService.userData;
      final apartmentData = authService.verifiedApartment;
      final userApartments = authService.userApartments;
      
      // Проверяем валидность формы
      if (_selectedRequestType == null || _selectedRequestType!.isEmpty) {
        throw Exception('Выберите тип заявки.');
      }
      
      if (_selectedDateTime == null) {
        throw Exception('Выберите предпочтительное время обслуживания.');
      }
      
      if (_description.trim().isEmpty) {
        throw Exception('Введите описание проблемы.');
      }
      
      // Проверяем что выбранные значения существуют в списках
      if (!_requestTypes.any((type) => type['value'] == _selectedRequestType)) {
        throw Exception('Недействительный тип заявки. Выберите из предложенных вариантов.');
      }
      
      if (!_priorityOptions.any((option) => option['value'] == _selectedPriority)) {
        throw Exception('Недействительный приоритет. Выберите из предложенных вариантов.');
      }
      
      // Расширенная проверка данных
      if (apartmentData == null) {
        // Пытаемся использовать первую квартиру из списка
        if (userApartments != null && userApartments.isNotEmpty) {
          final firstApartment = userApartments.first;
          
          // Отправляем запрос используя первую квартиру
          final requestId = await serviceRequestService.createServiceRequest(
            category: _selectedRequestType!,
            description: _description.trim(),
            apartmentNumber: firstApartment.apartmentNumber,
            blockName: firstApartment.blockId,
            priority: _selectedPriority,
            contactMethod: _selectedContactMethod,
            preferredTime: _selectedDateTime!,
            photos: _attachedPhotos,
            additionalData: {
              'requestSource': 'mobile_app',
              'userPhone': userData?['phone'] ?? firstApartment.phone ?? '',
              'userName': userData?['full_name'] ?? firstApartment.fullName ?? '',
            },
          );

          await _clearDraft();

          if (mounted) {
            _showSuccessDialog(requestId);
          }
          return;
        }
        
        // Если нет вообще никаких данных квартир
        throw Exception('Не удалось получить данные квартиры. Попробуйте войти в систему заново.');
      }
      
      // Проверяем базовые данные
      if (apartmentData.apartmentNumber.isEmpty || apartmentData.blockId.isEmpty) {
        throw Exception('Неполные данные квартиры. Попробуйте войти в систему заново.');
      }
      
      // Отправляем запрос в Firebase и на внешний сайт
      final requestId = await serviceRequestService.createServiceRequest(
        category: _selectedRequestType!,
        description: _description.trim(),
        apartmentNumber: apartmentData.apartmentNumber,
        blockName: apartmentData.blockId,
        priority: _selectedPriority,
        contactMethod: _selectedContactMethod,
        preferredTime: _selectedDateTime!,
        photos: _attachedPhotos,
        additionalData: {
          'requestSource': 'mobile_app',
          'userPhone': userData?['phone'] ?? apartmentData.phone ?? '',
          'userName': userData?['full_name'] ?? apartmentData.fullName ?? '',
        },
      );

      await _clearDraft();

      if (mounted) {
        _showSuccessDialog(requestId);
      }
    } catch (e) {
      getIt<LoggingService>().error('Error submitting request: $e');
      if (mounted) {
        // Более подробные сообщения об ошибках
        String errorMessage = 'Не удалось отправить заявку. Попробуйте еще раз.';
        
        final errorString = e.toString();
        
        if (errorString.contains('квартиры')) {
          errorMessage = 'Не удалось получить данные квартиры. Попробуйте войти в систему заново.';
        } else if (errorString.contains('авторизован')) {
          errorMessage = 'Пользователь не авторизован. Войдите в систему.';
        } else if (errorString.contains('сервисов')) {
          errorMessage = 'Ошибка инициализации сервисов. Перезапустите приложение.';
        } else if (errorString.contains('тип заявки')) {
          errorMessage = 'Выберите тип заявки.';
        } else if (errorString.contains('время обслуживания')) {
          errorMessage = 'Выберите предпочтительное время обслуживания.';
        } else if (errorString.contains('описание')) {
          errorMessage = 'Введите описание проблемы.';
        } else if (errorString.contains('Firebase')) {
          errorMessage = 'Проблема с подключением к серверу. Проверьте интернет-соединение.';
        } else if (errorString.contains('network')) {
          errorMessage = 'Проблема с сетью. Проверьте подключение к интернету.';
        } else if (errorString.contains('свободное место')) {
          errorMessage = 'Не хватает места на устройстве. Освободите место и попробуйте снова.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorLight,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog(String requestId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Заявка отправлена',
                style: AppTheme.lightTheme.textTheme.titleLarge,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ваша заявка на обслуживание успешно отправлена.',
                style: AppTheme.lightTheme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.lightTheme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.lightTheme.dividerColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Номер заявки',
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${requestId.substring(0, 8)}',
                      style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Вы получите уведомление о статусе заявки через приложение.',
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Закрыть диалог
                // Безопасная навигация назад к услугам
                context.go('/services');
              },
              child: const Text('Закрыть'),
            ),
            BlueButton(
              text: 'Мои заявки',
              onPressed: () {
                Navigator.of(context).pop(); // Закрыть диалог
                // Безопасная навигация к заявкам
                context.go('/services/my-requests');
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая заявка'),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: Stepper(
                currentStep: _currentStep,
                onStepTapped: _goToStep,
                onStepContinue: _currentStep == 4 ? null : _nextStep,
                onStepCancel: _currentStep > 0 ? _previousStep : null,
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            if (_currentStep > 0)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: details.onStepCancel,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Назад'),
                                ),
                              ),
                            if (_currentStep > 0) const SizedBox(width: 16),
                            Expanded(
                              child: _currentStep == 4
                                  ? BlueButton(
                                      text: 'Отправить заявку',
                                      onPressed: _canSubmit() && !_isLoading ? _submitRequest : null,
                                      isLoading: _isLoading,
                                    )
                                  : BlueButton(
                                      text: 'Далее',
                                      onPressed: _canProceedToNextStep() ? details.onStepContinue : null,
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                steps: [
                  // Step 1: Request type and description
                  Step(
                    title: const Text('Тип заявки и описание'),
                    subtitle: const Text('Выберите тип и опишите проблему'),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                    content: Step1RequestTypeWidget(
                      requestTypes: _requestTypes,
                      selectedRequestType: _selectedRequestType,
                      descriptionController: _descriptionController,
                      onRequestTypeChanged: (type) {
                        setState(() {
                          _selectedRequestType = type;
                        });
                      },
                    ),
                  ),
                  
                  // Step 2: Photo attachment
                  Step(
                    title: const Text('Фото'),
                    subtitle: const Text('Добавьте фотографии (необязательно)'),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                    content: Step2PhotoWidget(
                      attachedPhotos: _attachedPhotos,
                      onPhotosChanged: (photos) {
                        setState(() {
                          _attachedPhotos = photos;
                        });
                      },
                    ),
                  ),
                  
                  // Step 3: Contact method
                  Step(
                    title: const Text('Способ связи'),
                    subtitle: const Text('Выберите предпочтительный способ связи'),
                    isActive: _currentStep >= 2,
                    state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                    content: Step3ContactMethodWidget(
                      selectedContactMethod: _selectedContactMethod,
                      onContactMethodChanged: (method) {
                        setState(() {
                          _selectedContactMethod = method;
                        });
                      },
                    ),
                  ),
                  
                  // Step 4: Priority
                  Step(
                    title: const Text('Приоритет'),
                    subtitle: const Text('Выберите приоритет выполнения'),
                    isActive: _currentStep >= 3,
                    state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                    content: Step4PriorityWidget(
                      priorityOptions: _priorityOptions,
                      selectedPriority: _selectedPriority,
                      onPriorityChanged: (priority) {
                        setState(() {
                          _selectedPriority = priority;
                        });
                      },
                    ),
                  ),
                  
                  // Step 5: Date and time
                  Step(
                    title: const Text('Время обслуживания'),
                    subtitle: const Text('Выберите предпочтительное время'),
                    isActive: _currentStep >= 4,
                    state: StepState.indexed,
                    content: Step5DateTimeWidget(
                      selectedDateTime: _selectedDateTime,
                      onDateTimeChanged: (dateTime) {
                        setState(() {
                          _selectedDateTime = dateTime;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
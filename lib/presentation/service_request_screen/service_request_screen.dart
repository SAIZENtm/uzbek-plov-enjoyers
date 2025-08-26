// Removed fluttertoast dependency; using SnackBar for error messages
import 'package:go_router/go_router.dart';

import '../../core/app_export.dart';
import '../../core/di/service_locator.dart';
import './widgets/contact_method_widget.dart';
import './widgets/date_time_picker_widget.dart';
import './widgets/photo_attachment_widget.dart';
import './widgets/priority_selector_widget.dart';
import './widgets/request_type_dropdown_widget.dart';
import '../../widgets/blue_button.dart';
import '../../widgets/blue_text_field.dart';

class ServiceRequestScreen extends StatefulWidget {
  final String? initialRequestType;
  
  const ServiceRequestScreen({
    super.key,
    this.initialRequestType,
  });

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String? _selectedRequestType;
  String _selectedPriority = 'Low';
  String _selectedContactMethod = 'phone';
  DateTime? _selectedDateTime;
  List<String> _attachedPhotos = [];

  bool _isLoading = false;
  bool _isFormValid = false;

  // Mock data for request types
  final List<Map<String, dynamic>> _requestTypes = [
    {'value': 'plumbing', 'label': 'Сантехника', 'icon': 'plumbing'},
    {
      'value': 'electrical',
      'label': 'Электричество',
      'icon': 'electrical_services'
    },
    {'value': 'hvac', 'label': 'Отопление/Кондиционирование', 'icon': 'ac_unit'},
    {'value': 'general', 'label': 'Общее обслуживание', 'icon': 'build'},
  ];

  final List<Map<String, dynamic>> _priorityOptions = [
    {'value': 'Low', 'label': 'Низкий', 'color': const Color(0xFF27AE60)},
    {'value': 'Medium', 'label': 'Средний', 'color': const Color(0xFFF39C12)},
    {'value': 'High', 'label': 'Высокий', 'color': const Color(0xFFE74C3C)},
    {'value': 'Emergency', 'label': 'Экстренный', 'color': const Color(0xFF8E44AD)},
  ];

  @override
  void initState() {
    super.initState();
    _loadDraftData();
    _descriptionController.addListener(_validateForm);
    
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



  Future<void> _loadDraftData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final draftRequestType = prefs.getString('draft_request_type');
      // Проверяем, что сохраненный тип запроса существует в списке
      _selectedRequestType = draftRequestType != null && 
          _requestTypes.any((type) => type['value'] == draftRequestType) 
          ? draftRequestType 
          : null;
          
      _descriptionController.text = prefs.getString('draft_description') ?? '';
      
      final draftPriority = prefs.getString('draft_priority') ?? 'Low';
      // Проверяем, что сохраненный приоритет существует в списке
      _selectedPriority = _priorityOptions.any((option) => option['value'] == draftPriority) 
          ? draftPriority 
          : 'Low';
          
      final draftContactMethod = prefs.getString('draft_contact_method') ?? 'phone';
      // Проверяем, что сохраненный способ связи корректный
      _selectedContactMethod = ['phone', 'notification'].contains(draftContactMethod) 
          ? draftContactMethod 
          : 'phone';
      final dateString = prefs.getString('draft_date_time');
      if (dateString != null) {
        _selectedDateTime = DateTime.tryParse(dateString);
      }
    });
    _validateForm();
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('draft_request_type', _selectedRequestType ?? '');
    await prefs.setString('draft_description', _descriptionController.text);
    await prefs.setString('draft_priority', _selectedPriority);
    await prefs.setString('draft_contact_method', _selectedContactMethod);
    if (_selectedDateTime != null) {
      await prefs.setString(
          'draft_date_time', _selectedDateTime!.toIso8601String());
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('draft_request_type');
    await prefs.remove('draft_description');
    await prefs.remove('draft_priority');
    await prefs.remove('draft_contact_method');
    await prefs.remove('draft_date_time');
  }

  void _validateForm() {
    final isValid = _selectedRequestType != null &&
        _descriptionController.text.trim().isNotEmpty &&
        _selectedDateTime != null;

    if (isValid != _isFormValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || !_isFormValid) {
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
      
      // Дополнительная отладочная информация (можно удалить в production)
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
      
      if (_descriptionController.text.trim().isEmpty) {
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
            description: _descriptionController.text.trim(),
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
        description: _descriptionController.text.trim(),
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
              const CustomIconWidget(
                iconName: 'check_circle',
                color: AppTheme.successLight,
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
                      'ID заявки: $requestId',
                      style: AppTheme.lightTheme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ожидаемое время ответа: 24-48 часов',
                      style: AppTheme.lightTheme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                context.go('/services'); // Navigate back to services screen
              },
              child: const Text('ОК'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Новая заявка'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: AppTheme.lightTheme.colorScheme.onSurface,
            size: 24,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isFormValid && !_isLoading ? _submitRequest : null,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.lightTheme.colorScheme.primary,
                        ),
                      ),
                    )
                  : Text(
                      'Отправить',
                      style: TextStyle(
                        color: _isFormValid
                            ? AppTheme.lightTheme.colorScheme.primary
                            : AppTheme.lightTheme.colorScheme.onSurface
                                .withValues(alpha: 0.38),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
                Text(
                  'Тип заявки *',
                  style: AppTheme.lightTheme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                RequestTypeDropdownWidget(
                  requestTypes: _requestTypes,
                  selectedType: _selectedRequestType,
                  onChanged: (value) {
                    setState(() {
                      _selectedRequestType = value;
                    });
                    _validateForm();
                    _saveDraft();
                  },
                ),
                const SizedBox(height: 24),

                Text(
                  'Описание *',
                  style: AppTheme.lightTheme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                BlueTextField(
                  controller: _descriptionController,
                  hintText: 'Пожалуйста, опишите проблему подробно...',
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Пожалуйста, предоставьте описание';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_descriptionController.text.length}/500',
                    style: AppTheme.lightTheme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Приоритет',
                  style: AppTheme.lightTheme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                PrioritySelectorWidget(
                  priorityOptions: _priorityOptions,
                  selectedPriority: _selectedPriority,
                  onChanged: (value) {
                    setState(() {
                      _selectedPriority = value;
                    });
                    _saveDraft();
                  },
                ),
                const SizedBox(height: 24),

                Text(
                  'Фотографии (необязательно)',
                  style: AppTheme.lightTheme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                PhotoAttachmentWidget(
                  attachedPhotos: _attachedPhotos,
                  onPhotosChanged: (photos) {
                    setState(() {
                      _attachedPhotos = photos;
                    });
                  },
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightTheme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'info',
                        color: AppTheme.lightTheme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Номер квартиры и блок определяются автоматически на основе вашего аккаунта',
                          style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Предпочтительный способ связи',
                  style: AppTheme.lightTheme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ContactMethodWidget(
                  selectedMethod: _selectedContactMethod,
                  onChanged: (value) {
                    setState(() {
                      _selectedContactMethod = value;
                    });
                    _saveDraft();
                  },
                ),
                const SizedBox(height: 24),

                Text(
                  'Предпочтительное время обслуживания *',
                  style: AppTheme.lightTheme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                DateTimePickerWidget(
                  selectedDateTime: _selectedDateTime,
                  onChanged: (dateTime) {
                    setState(() {
                      _selectedDateTime = dateTime;
                    });
                    _validateForm();
                    _saveDraft();
                  },
                ),
                const SizedBox(height: 32),

                BlueButton(
                  text: _isLoading ? 'Отправка...' : 'Отправить заявку',
                  isLoading: _isLoading,
                  onPressed: _isFormValid && !_isLoading ? _submitRequest : null,
                ),
                const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_export.dart';

class ServiceRequestsListScreen extends StatefulWidget {
  final String? initialRequestId;
  
  const ServiceRequestsListScreen({
    super.key,
    this.initialRequestId,
  });

  @override
  State<ServiceRequestsListScreen> createState() => _ServiceRequestsListScreenState();
}

class _ServiceRequestsListScreenState extends State<ServiceRequestsListScreen> {
  late final AuthService _authService;
  late final LoggingService _loggingService;
  late final ServiceRequestService _serviceRequestService;
  
  bool _isLoading = true;
  List<ServiceRequest> _requests = [];
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _authService = GetIt.instance<AuthService>();
    _loggingService = GetIt.instance<LoggingService>();
    _serviceRequestService = GetIt.instance<ServiceRequestService>();
    _loadRequests();
  }
  
  Future<void> _loadRequests() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      final requests = await _serviceRequestService.getServiceRequests();
      
      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
        
        // Если указан начальный ID заявки, открываем её детали
        if (widget.initialRequestId != null && _requests.isNotEmpty) {
          final request = _requests.firstWhere(
            (r) => r.id == widget.initialRequestId,
            orElse: () => _requests.first,
          );
          
          // Конвертируем в Map для _showRequestDetails
          final requestData = request.toJson();
          
          // Небольшая задержка для корректного отображения
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _showRequestDetails(context, requestData);
            }
          });
        }
      }
    } catch (e) {
      _loggingService.error('Failed to load service requests', e);
      if (mounted) {
        setState(() {
          _error = 'Ошибка загрузки заявок: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return const Color(0xFF27AE60);
      case 'medium':
        return const Color(0xFFF39C12);
      case 'high':
        return const Color(0xFFE74C3C);
      case 'emergency':
        return const Color(0xFF8E44AD);
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'В ожидании';
      case 'in-progress':
      case 'inProgress':
        return 'В работе';
      case 'completed':
        return 'Завершено';
      case 'cancelled':
        return 'Отменено';
      case 'rejected':
        return 'Отклонено';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in-progress':
      case 'inProgress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'plumbing':
        return 'Сантехника';
      case 'electrical':
        return 'Электричество';
      case 'hvac':
        return 'Отопление/Кондиционирование';
      case 'general':
        return 'Общее обслуживание';
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.userData;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Мои заявки')),
        body: const Center(
          child: Text('Пользователь не авторизован'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Мои заявки'),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              // If we can't pop (no navigation history), go to dashboard
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/service-request');
        },
        backgroundColor: AppTheme.lightTheme.colorScheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadRequests,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    
    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'У вас пока нет заявок',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[index];
        final hasAdminResponse = request.additionalData['adminResponse'] != null && 
                              request.additionalData['adminResponse'].toString().trim().isNotEmpty;
        
        // Преобразуем ServiceRequest в Map для совместимости с существующим кодом
        final data = {
          'id': request.id,
          'requestType': request.category,
          'description': request.description,
          'priority': request.priority,
          'status': request.status.toString().split('.').last,
          'apartmentNumber': request.apartmentNumber,
          'block': request.block,
          'createdAt': request.createdAt,
          'adminResponse': request.additionalData['adminResponse'],
        };
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: hasAdminResponse ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: hasAdminResponse 
                ? BorderSide(color: AppTheme.lightTheme.colorScheme.primary, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: () => _showRequestDetails(context, data),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getCategoryName(data['requestType'] ?? 'unknown'),
                          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(data['priority'] ?? 'Low').withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          data['priority'] ?? 'Low',
                          style: TextStyle(
                            color: _getPriorityColor(data['priority'] ?? 'Low'),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['description'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.lightTheme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ID: ${request.id.substring(0, 8)}',
                        style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(data['status'] ?? 'pending').withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getStatusText(data['status'] ?? 'pending'),
                          style: TextStyle(
                            color: _getStatusColor(data['status'] ?? 'pending'),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasAdminResponse) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings,
                                size: 16,
                                color: AppTheme.lightTheme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ответ администратора:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.lightTheme.colorScheme.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['adminResponse'],
                            style: AppTheme.lightTheme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRequestDetails(BuildContext context, Map<String, dynamic> data) {
    final requestId = data['id'] ?? 'unknown';
    final hasAdminResponse = data['adminResponse'] != null && 
                           data['adminResponse'].toString().trim().isNotEmpty;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Заявка #${requestId.substring(0, 8)}',
                      style: AppTheme.lightTheme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    _buildDetailRow('Тип заявки', _getCategoryName(data['requestType'] ?? 'unknown')),
                    _buildDetailRow('Приоритет', data['priority'] ?? 'Low'),
                    _buildDetailRow('Статус', _getStatusText(data['status'] ?? 'pending')),
                    _buildDetailRow('Квартира', '${data['apartmentNumber']} (Блок ${data['block']})'),
                    _buildDetailRow('Дата создания', _formatDate(data['createdAt'])),
                    const SizedBox(height: 16),
                    Text(
                      'Описание:',
                      style: AppTheme.lightTheme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['description'] ?? '',
                      style: AppTheme.lightTheme.textTheme.bodyMedium,
                    ),
                    if (hasAdminResponse) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.lightTheme.colorScheme.primary,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.admin_panel_settings,
                                  color: AppTheme.lightTheme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ответ администратора',
                                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                                    color: AppTheme.lightTheme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              data['adminResponse'],
                              style: AppTheme.lightTheme.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    try {
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return 'Неизвестно';
      }
      
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Неизвестно';
    }
  }
} 
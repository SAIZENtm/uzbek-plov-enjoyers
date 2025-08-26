import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_export.dart';
import 'widgets/request_card.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late final AuthService _authService;
  late final LoggingService _loggingService;
  late final ServiceRequestService _serviceRequestService;
  
  bool _isLoading = true;
  List<ServiceRequest> _allRequests = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _authService = GetIt.instance<AuthService>();
    _loggingService = GetIt.instance<LoggingService>();
    _serviceRequestService = GetIt.instance<ServiceRequestService>();
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          _allRequests = requests;
          _isLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    final user = _authService.userData;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Мои заявки'),
        ),
        body: const Center(
          child: Text('Пользователь не авторизован'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(
          'Мои заявки',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/services');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.lightGray,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppTheme.newportPrimary,
              indicatorWeight: 3,
              labelColor: AppTheme.newportPrimary,
              unselectedLabelColor: AppTheme.mediumGray,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              tabs: const [
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('Черновики'),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('В ожидании'),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('В процессе'),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('Завершённые'),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('Отклонённые'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.mediumGray,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppTheme.mediumGray,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadRequests,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDraftsTab(),
                  _buildPendingTab(),
                  _buildInProgressTab(),
                  _buildCompletedTab(),
                  _buildRejectedTab(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/services/new-request'),
        backgroundColor: AppTheme.newportPrimary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDraftsTab() {
    // В текущей архитектуре нет черновиков, но оставляем для будущего расширения
    final draftRequests = _allRequests.where((request) => 
      false // Пока нет логики черновиков
    ).toList();

    return _buildRequestsList(draftRequests, 'черновиков');
  }

  Widget _buildPendingTab() {
    final pendingRequests = _allRequests.where((request) => 
      request.status == RequestStatus.pending && 
      !_hasAdminResponse(request) // Заявки с ответом админа НЕ показываем в ожидании
    ).toList();

    return _buildRequestsList(pendingRequests, 'заявок в ожидании');
  }

  Widget _buildInProgressTab() {
    final inProgressRequests = _allRequests.where((request) => 
      request.status == RequestStatus.inProgress || 
      _hasAdminResponse(request) // Заявки с ответом админа автоматически в процессе
    ).toList();

    return _buildRequestsList(inProgressRequests, 'заявок в процессе');
  }

  Widget _buildCompletedTab() {
    final completedRequests = _allRequests.where((request) => 
      request.status == RequestStatus.completed
    ).toList();

    return _buildRequestsList(completedRequests, 'завершённых заявок');
  }

  Widget _buildRejectedTab() {
    final rejectedRequests = _allRequests.where((request) => 
      request.status == RequestStatus.rejected || request.status == RequestStatus.cancelled
    ).toList();

    return _buildRequestsList(rejectedRequests, 'отклонённых заявок');
  }

  Widget _buildRequestsList(List<ServiceRequest> requests, String emptyMessage) {
    if (requests.isEmpty) {
      return _buildEmptyState(emptyMessage);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.builder(
        key: ValueKey(requests.length),
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 200 + (index * 50)),
            curve: Curves.easeOutCubic,
            child: RequestCard(
              request: requests[index],
              onTap: () => _onRequestTap(requests[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.lightGray,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: AppTheme.neutralGray,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 40,
              color: AppTheme.mediumGray,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Нет $message',
            style: const TextStyle(
              color: AppTheme.mediumGray,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Здесь будут отображаться ваши заявки',
            style: TextStyle(
              color: AppTheme.mediumGray,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _onRequestTap(ServiceRequest request) {
    final hasAdminResponse = request.additionalData['adminResponse'] != null && 
                           request.additionalData['adminResponse'].toString().trim().isNotEmpty;
    
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
                      'Заявка #${request.id.substring(0, 8)}',
                      style: AppTheme.lightTheme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    _buildDetailRow('Тип заявки', _getCategoryName(request.category)),
                    _buildDetailRow('Приоритет', request.priority),
                    _buildDetailRow('Статус', _getStatusText(request.status.toString().split('.').last)),
                    _buildDetailRow('Квартира', '${request.apartmentNumber} (Блок ${request.block})'),
                    _buildDetailRow('Дата создания', _formatDetailDate(request.createdAt)),
                    const SizedBox(height: 16),
                    Text(
                      'Описание:',
                      style: AppTheme.lightTheme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request.description,
                      style: AppTheme.lightTheme.textTheme.bodyMedium,
                    ),
                    if (request.photos.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Фотографии:',
                        style: AppTheme.lightTheme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildPhotoGallery(request.photos),
                    ],
                    if (hasAdminResponse) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.newportPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.newportPrimary,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.admin_panel_settings,
                                  color: AppTheme.newportPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ответ администратора',
                                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                                    color: AppTheme.newportPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              request.additionalData['adminResponse'].toString(),
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

  String _formatDetailDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getCategoryName(String category) {
    switch (category.toLowerCase()) {
      case 'plumbing':
        return 'Сантехника';
      case 'electrical':
        return 'Электричество';
      case 'hvac':
        return 'Отопление/Кондиционирование';
      case 'general':
        return 'Общее обслуживание';
      case 'cleaning':
        return 'Уборка';
      case 'maintenance':
        return 'Обслуживание';
      default:
        return category;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'В ожидании';
      case 'inprogress':
      case 'in-progress':
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



  Widget _buildPhotoGallery(List<String> photos) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.only(right: index < photos.length - 1 ? 12 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: photos[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey[400],
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Проверяет, есть ли ответ администратора в заявке
  bool _hasAdminResponse(ServiceRequest request) {
    // Проверяем наличие adminResponse в additionalData
    final adminResponse = request.additionalData['adminResponse'];
    
    if (adminResponse == null) return false;
    
    // Проверяем, что ответ не пустой
    if (adminResponse is String) {
      return adminResponse.trim().isNotEmpty;
    }
    
    if (adminResponse is Map) {
      final message = adminResponse['message'] ?? adminResponse['response'];
      if (message is String) {
        return message.trim().isNotEmpty;
      }
    }
    
    return false;
  }
}

// Используем существующие модели из ServiceRequestService 
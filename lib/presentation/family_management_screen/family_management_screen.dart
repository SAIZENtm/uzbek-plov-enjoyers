import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_export.dart';
import '../../core/models/family_member_model.dart';
import '../../core/models/family_request_model.dart';
import '../../widgets/card_container.dart';

import '../../core/di/service_locator.dart';
import '../../core/models/invitation_model.dart';
import 'widgets/family_member_card.dart';
import 'widgets/family_request_card.dart';

class FamilyManagementScreen extends StatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<FamilyMemberModel> _familyMembers = [];
  List<FamilyRequestModel> _familyRequests = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _setupListeners();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setupListeners() {
    // Слушаем изменения в семейных запросах
    final familyRequestService = getIt<FamilyRequestService>();
    familyRequestService.requestsStream.listen((requests) {
      if (mounted) {
        setState(() {
          _familyRequests = requests;
        });
      }
    });
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final authService = Provider.of<AuthService>(context, listen: false);
      final apartment = authService.verifiedApartment;
      
      if (apartment != null) {
        final familyRequestService = getIt<FamilyRequestService>();
        
        // Загружаем членов семьи
        final members = await familyRequestService.getFamilyMembers(apartment.id);
        
        // Загружаем семейные запросы
        List<FamilyRequestModel> requests = [];
        try {
          // Сначала пробуем по apartmentId
          requests = await familyRequestService.getFamilyRequestsForApartment(apartment.id);
          
          // Если не найдено, пробуем по адресу
          if (requests.isEmpty) {
            requests = await familyRequestService.getFamilyRequestsByAddress(
              apartment.blockId,
              apartment.apartmentNumber,
            );
          }
        } catch (e) {
          getIt<LoggingService>().error('Failed to load family requests', e);
        }
        
        setState(() {
          _familyMembers = members;
          _familyRequests = requests;
        });
        
        getIt<LoggingService>().info('Loaded ${members.length} family members and ${requests.length} requests');
      }
    } catch (e) {
      getIt<LoggingService>().error('Failed to load family data', e);
      _showErrorMessage('Не удалось загрузить данные семьи');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeFamilyMember(FamilyMemberModel member) async {
    final confirmed = await _showConfirmationDialog(
      'Удалить члена семьи',
      'Вы уверены, что хотите удалить ${member.name} из семьи?\n\nЭто действие нельзя отменить.',
    );

    if (!confirmed) return;

    // Capture context before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apartment = authService.verifiedApartment;
      
      if (apartment == null || member.memberId == null) return;

      final familyRequestService = getIt<FamilyRequestService>();
      final success = await familyRequestService.removeFamilyMember(
        apartmentId: apartment.id,
        memberId: member.memberId!,
      );

      if (success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Член семьи удален'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Перезагружаем данные
        _loadData();
      } else {
        _showErrorMessage('Не удалось удалить члена семьи');
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Ошибка при удалении члена семьи'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Управление семьей'),
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
        foregroundColor: AppTheme.charcoal,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.newportPrimary,
          unselectedLabelColor: AppTheme.mediumGray,
          indicatorColor: AppTheme.newportPrimary,
          tabs: [
            Tab(
              text: 'Члены семьи (${_familyMembers.length})',
              icon: const Icon(Icons.people),
            ),
            Tab(
              text: 'Запросы (${_familyRequests.length})',
              icon: const Icon(Icons.notification_important),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFamilyMembersTab(),
                _buildRequestsTab(),
              ],
            ),
    );
  }

  Widget _buildFamilyMembersTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFamilyMembersHeader(),
            const SizedBox(height: 24),
            if (_familyMembers.isEmpty)
              _buildEmptyFamilyState()
            else
              _buildFamilyMembersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyMembersHeader() {
    return CardContainer(
      child: Column(
        children: [
          const Icon(
            Icons.family_restroom,
            size: 48,
            color: AppTheme.newportPrimary,
          ),
          const SizedBox(height: 16),
          Text(
            'Члены вашей семьи',
            style: AppTheme.typography.headlineMedium.copyWith(
              color: AppTheme.charcoal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Управляйте составом семьи. Максимум 10 членов.',
            style: AppTheme.typography.bodyMedium.copyWith(
              color: AppTheme.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Добавлено',
                  '${_familyMembers.length}',
                  Icons.people,
                  AppTheme.newportPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Доступно',
                  '${10 - _familyMembers.length}',
                  Icons.person_add,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showInviteDialog,
                  icon: const Icon(Icons.link),
                  label: const Text('Быстрое приглашение'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.newportPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/profile/invites'),
                  icon: const Icon(Icons.manage_accounts),
                  label: const Text('Управление инвайтами'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.colors.pureWhite,
                    foregroundColor: AppTheme.newportPrimary,
                    side: const BorderSide(color: AppTheme.newportPrimary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTheme.typography.bodyMedium.copyWith(
              fontSize: 12,
              color: AppTheme.mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFamilyState() {
    return CardContainer(
      child: Column(
        children: [
          const Icon(
            Icons.people_outline,
            size: 64,
            color: AppTheme.mediumGray,
          ),
          const SizedBox(height: 16),
          Text(
            'Нет членов семьи',
            style: AppTheme.typography.headlineMedium.copyWith(
              color: AppTheme.mediumGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Члены семьи появятся здесь после подтверждения их запросов.',
            style: AppTheme.typography.bodyMedium.copyWith(
              color: AppTheme.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyMembersList() {
    return Column(
      children: _familyMembers.map((member) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FamilyMemberCard(
            member: member,
            onRemove: () => _removeFamilyMember(member),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRequestsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRequestsHeader(),
            const SizedBox(height: 24),
            if (_familyRequests.isEmpty)
              _buildEmptyRequestsState()
            else
              _buildRequestsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsHeader() {
    return CardContainer(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.newportPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notification_important,
              color: AppTheme.newportPrimary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Запросы в семью',
                  style: AppTheme.typography.headlineMedium.copyWith(
                    fontSize: 18,
                    color: AppTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Новые запросы на присоединение к вашей семье',
                  style: AppTheme.typography.bodyMedium.copyWith(
                    color: AppTheme.mediumGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRequestsState() {
    return CardContainer(
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            'Нет новых запросов',
            style: AppTheme.typography.headlineMedium.copyWith(
              color: AppTheme.mediumGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'У вас нет ожидающих запросов на присоединение к семье.',
            style: AppTheme.typography.bodyMedium.copyWith(
              color: AppTheme.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return Column(
      children: _familyRequests.map((request) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FamilyRequestCard(
            request: request,
            onRequestHandled: _loadData,
          ),
        );
      }).toList(),
    );
  }

  /// Show dialog to create family invitation
  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (context) => _InviteCreationDialog(
        onInviteCreated: (invitation) {
          _showInviteSuccessDialog(invitation);
        },
      ),
    );
  }

  /// Show success dialog with invite link
  void _showInviteSuccessDialog(InvitationModel invitation) {
    final inviteUrl = invitation.generateShareableLink();
    final shareText = 'Привет! 👋\n\n'
        'Владелец квартиры ${invitation.blockId} ${invitation.apartmentNumber} '
        'приглашает вас присоединиться к семье в приложении Newport Resident.\n\n'
        '🔗 Ссылка для регистрации:\n'
        '${invitation.generateShareableLink()}\n\n'
        '⏰ Ссылка действительна до ${_formatDateTime(invitation.expiresAt)}\n'
        '👥 Максимум использований: ${invitation.maxUses}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Приглашение создано'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ссылка-приглашение готова к отправке:',
              style: AppTheme.typography.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                inviteUrl,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '⏰ Действительна до: ${_formatDateTime(invitation.expiresAt)}',
              style: AppTheme.typography.bodySmall.copyWith(
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: shareText));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Текст приглашения скопирован'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Копировать'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                // Import share_plus package if not already imported
                // await Share.share(shareText);
                await Clipboard.setData(ClipboardData(text: shareText));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ссылка скопирована - отправьте её через мессенджер'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.share),
            label: const Text('Поделиться'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Dialog for creating family invitations
class _InviteCreationDialog extends StatefulWidget {
  final Function(InvitationModel) onInviteCreated;

  const _InviteCreationDialog({
    required this.onInviteCreated,
  });

  @override
  State<_InviteCreationDialog> createState() => _InviteCreationDialogState();
}

class _InviteCreationDialogState extends State<_InviteCreationDialog> {
  bool _isLoading = false;
  String? _error;
  bool _selectAllApartments = true;
  final Set<String> _selectedApartments = {};

  @override
  void initState() {
    super.initState();
    _loadUserApartments();
  }

  void _loadUserApartments() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userApartments = authService.userApartments ?? [];
    
    if (userApartments.isNotEmpty) {
      // Pre-select all apartments
      for (final apartment in userApartments) {
        _selectedApartments.add(apartment.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userApartments = authService.userApartments ?? [];

    return AlertDialog(
      title: const Text('🔗 Создать приглашение'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Выберите квартиры для доступа:',
              style: AppTheme.typography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            if (userApartments.isEmpty)
              const Text('У вас нет доступных квартир')
            else ...[
              // Select all toggle
              CheckboxListTile(
                title: const Text('Все квартиры'),
                subtitle: Text('${userApartments.length} квартир'),
                value: _selectAllApartments,
                onChanged: (value) {
                  setState(() {
                    _selectAllApartments = value ?? false;
                    if (_selectAllApartments) {
                      _selectedApartments.clear();
                      for (final apartment in userApartments) {
                        _selectedApartments.add(apartment.id);
                      }
                    } else {
                      _selectedApartments.clear();
                    }
                  });
                },
                dense: true,
              ),
              const Divider(),
              
              // Individual apartment selection
              if (userApartments.length > 1)
                ...userApartments.map((apartment) {
                  return CheckboxListTile(
                    title: Text('${apartment.blockId}-${apartment.apartmentNumber}'),
                    subtitle: Text(apartment.fullName ?? 'Квартира'),
                    value: _selectedApartments.contains(apartment.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedApartments.add(apartment.id);
                        } else {
                          _selectedApartments.remove(apartment.id);
                        }
                        
                        _selectAllApartments = _selectedApartments.length == userApartments.length;
                      });
                    },
                    dense: true,
                  );
                }),
            ],
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Информация о приглашении:',
                        style: AppTheme.typography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Ссылка действительна 1 час\n'
                    '• Одноразовое использование\n'
                    '• Полный доступ к выбранным квартирам\n'
                    '• SMS-подтверждение обязательно',
                    style: AppTheme.typography.bodySmall.copyWith(
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTheme.typography.bodySmall.copyWith(
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _isLoading || _selectedApartments.isEmpty ? null : _createInvitation,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Создать'),
        ),
      ],
    );
  }

  Future<void> _createInvitation() async {
    if (_selectedApartments.isEmpty) {
      setState(() {
        _error = 'Выберите хотя бы одну квартиру';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userApartments = authService.userApartments ?? [];
      final selectedApartment = userApartments.firstWhere(
        (apt) => apt.id == _selectedApartments.first,
        orElse: () => userApartments.first,
      );

      final inviteService = getIt<InviteService>();
      final invitation = await inviteService.createFamilyInvite(
        apartmentId: selectedApartment.id,
        blockId: selectedApartment.blockId,
        apartmentNumber: selectedApartment.apartmentNumber,
        ownerName: authService.userData?['fullName'] ?? 'Владелец',
        ownerPhone: authService.userData?['phone'] ?? '',
        ownerPassport: authService.userData?['passport_number'],
      );

      if (invitation != null) {
        if (mounted) {
          Navigator.pop(context);
          widget.onInviteCreated(invitation);
        }
      } else {
        setState(() {
          _error = 'Не удалось создать приглашение';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
} 

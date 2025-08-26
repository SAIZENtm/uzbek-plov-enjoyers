import '../core/app_export.dart';

/// Premium offline status indicator with real-time sync information
class OfflineStatusIndicator extends StatefulWidget {
  final bool showDetails;
  final VoidCallback? onTap;

  const OfflineStatusIndicator({
    super.key,
    this.showDetails = false,
    this.onTap,
  });

  @override
  State<OfflineStatusIndicator> createState() => _OfflineStatusIndicatorState();
}

class _OfflineStatusIndicatorState extends State<OfflineStatusIndicator>
    with TickerProviderStateMixin {
  late final OfflineService _offlineService;
  late final AnimationController _pulseController;
  late final AnimationController _progressController;
  late final Animation<double> _pulseAnimation;
  
  bool _isOnline = true;
  SyncQueueStatus? _queueStatus;
  List<ConflictData> _conflicts = [];

  @override
  void initState() {
    super.initState();
    _offlineService = GetIt.instance<OfflineService>();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _initializeStatus();
    _setupListeners();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _initializeStatus() async {
    _isOnline = await _offlineService.isOnline();
    _queueStatus = _offlineService.queueStatus;
    _conflicts = await _offlineService.getConflicts();
    
    if (mounted) setState(() {});
    
    if (!_isOnline || _queueStatus!.pendingCount > 0) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _setupListeners() {
    _offlineService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _queueStatus = _offlineService.queueStatus;
        });
        
        switch (status.state) {
          case SyncState.syncing:
            _progressController.forward();
            break;
          case SyncState.completed:
            _progressController.reverse();
            _pulseController.stop();
            break;
          case SyncState.error:
            _progressController.reverse();
            _pulseController.repeat(reverse: true);
            break;
          default:
            break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline && (_queueStatus?.pendingCount ?? 0) == 0 && _conflicts.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onTap ?? _showOfflineDetails,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.showDetails ? 16 : 12,
                vertical: widget.showDetails ? 12 : 8,
              ),
              decoration: BoxDecoration(
                color: _getStatusColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(widget.showDetails ? 16 : 20),
                border: Border.all(
                  color: _getStatusColor().withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Icon(
                        _getStatusIcon(),
                        color: _getStatusColor(),
                        size: widget.showDetails ? 20 : 16,
                      ),
                      if (_queueStatus?.isSyncing == true)
                        Positioned.fill(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(_getStatusColor()),
                          ),
                        ),
                    ],
                  ),
                  
                  if (widget.showDetails) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getStatusText(),
                            style: AppTheme.typography.bodyMedium.copyWith(
                              color: _getStatusColor(),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_getSubtitleText().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _getSubtitleText(),
                              style: AppTheme.typography.bodySmall.copyWith(
                                color: _getStatusColor().withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if ((_queueStatus?.pendingCount ?? 0) > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_queueStatus!.pendingCount}',
                        style: AppTheme.typography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor() {
    if (!_isOnline) return Colors.red.shade600;
    if (_conflicts.isNotEmpty) return Colors.orange.shade600;
    if ((_queueStatus?.pendingCount ?? 0) > 0) return Colors.blue.shade600;
    return Colors.green.shade600;
  }

  IconData _getStatusIcon() {
    if (!_isOnline) return Icons.cloud_off_rounded;
    if (_conflicts.isNotEmpty) return Icons.warning_rounded;
    if ((_queueStatus?.pendingCount ?? 0) > 0) return Icons.cloud_sync_rounded;
    return Icons.cloud_done_rounded;
  }

  String _getStatusText() {
    if (!_isOnline) return 'Офлайн режим';
    if (_conflicts.isNotEmpty) return 'Конфликт данных';
    if (_queueStatus?.isSyncing == true) return 'Синхронизация...';
    if ((_queueStatus?.pendingCount ?? 0) > 0) return 'Ожидает синхронизации';
    return 'Синхронизировано';
  }

  String _getSubtitleText() {
    if (!_isOnline) return 'Данные сохраняются локально';
    if (_conflicts.isNotEmpty) return '${_conflicts.length} конфликтов';
    if ((_queueStatus?.pendingCount ?? 0) > 0) return '${_queueStatus!.pendingCount} действий';
    return '';
  }

  void _showOfflineDetails() {
    HapticFeedback.lightImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _OfflineDetailsSheet(
        offlineService: _offlineService,
        isOnline: _isOnline,
        queueStatus: _queueStatus,
        conflicts: _conflicts,
      ),
    );
  }
}

/// Detailed offline status sheet
class _OfflineDetailsSheet extends StatefulWidget {
  final OfflineService offlineService;
  final bool isOnline;
  final SyncQueueStatus? queueStatus;
  final List<ConflictData> conflicts;

  const _OfflineDetailsSheet({
    required this.offlineService,
    required this.isOnline,
    required this.queueStatus,
    required this.conflicts,
  });

  @override
  State<_OfflineDetailsSheet> createState() => _OfflineDetailsSheetState();
}

class _OfflineDetailsSheetState extends State<_OfflineDetailsSheet> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.colors.lightGray,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Header
                  Row(
                    children: [
                      Icon(
                        widget.isOnline ? Icons.cloud_rounded : Icons.cloud_off_rounded,
                        color: widget.isOnline ? Colors.green : Colors.red,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isOnline ? 'Подключено к интернету' : 'Офлайн режим',
                              style: AppTheme.typography.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.isOnline 
                                  ? 'Данные синхронизируются автоматически'
                                  : 'Данные сохраняются локально',
                              style: AppTheme.typography.bodyMedium.copyWith(
                                color: AppTheme.colors.darkGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Sync Queue Status
                  if ((widget.queueStatus?.pendingCount ?? 0) > 0) ...[
                    _buildSectionHeader('Очередь синхронизации'),
                    const SizedBox(height: 16),
                    _buildSyncQueueCard(),
                    const SizedBox(height: 24),
                  ],
                  
                  // Conflicts
                  if (widget.conflicts.isNotEmpty) ...[
                    _buildSectionHeader('Конфликты данных'),
                    const SizedBox(height: 16),
                    ...widget.conflicts.map((conflict) => _buildConflictCard(conflict)),
                    const SizedBox(height: 24),
                  ],
                  
                  // Actions
                  _buildSectionHeader('Действия'),
                  const SizedBox(height: 16),
                  
                  if (widget.isOnline) ...[
                    _buildActionButton(
                      icon: Icons.sync_rounded,
                      title: 'Принудительная синхронизация',
                      subtitle: 'Синхронизировать все данные сейчас',
                      onTap: _forcSync,
                      loading: _isSyncing,
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  _buildActionButton(
                    icon: Icons.delete_outline_rounded,
                    title: 'Очистить кеш',
                    subtitle: 'Удалить все локальные данные',
                    onTap: _clearCache,
                    destructive: true,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Last sync info
                  FutureBuilder<DateTime?>(
                    future: widget.offlineService.getLastSyncTimestamp(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        final lastSync = snapshot.data!;
                        final difference = DateTime.now().difference(lastSync);
                        
                        String timeText;
                        if (difference.inMinutes < 1) {
                          timeText = 'только что';
                        } else if (difference.inHours < 1) {
                          timeText = '${difference.inMinutes} мин. назад';
                        } else if (difference.inDays < 1) {
                          timeText = '${difference.inHours} ч. назад';
                        } else {
                          timeText = '${difference.inDays} дн. назад';
                        }
                        
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.colors.lightGray.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                color: AppTheme.colors.mediumGray,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Последняя синхронизация: $timeText',
                                style: AppTheme.typography.bodySmall.copyWith(
                                  color: AppTheme.colors.darkGray,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTheme.typography.titleMedium.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.colors.charcoal,
      ),
    );
  }

  Widget _buildSyncQueueCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.queue_rounded,
            color: Colors.blue.shade600,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.queueStatus!.pendingCount} действий в очереди',
                  style: AppTheme.typography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                Text(
                  widget.queueStatus!.isSyncing 
                      ? 'Синхронизация в процессе...'
                      : 'Будут синхронизированы при подключении',
                  style: AppTheme.typography.bodySmall.copyWith(
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (widget.queueStatus!.isSyncing)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConflictCard(ConflictData conflict) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Colors.orange.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getActionTypeDisplayName(conflict.action.type),
                  style: AppTheme.typography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            conflict.conflictReason,
            style: AppTheme.typography.bodySmall.copyWith(
              color: Colors.orange.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildConflictButton(
                'Использовать локальные данные',
                () => _resolveConflict(conflict.id, ConflictResolution.useLocal),
              ),
              const SizedBox(width: 8),
              _buildConflictButton(
                'Пропустить',
                () => _resolveConflict(conflict.id, ConflictResolution.skip),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConflictButton(String label, VoidCallback onPressed) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.orange.shade300),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Text(
          label,
          style: AppTheme.typography.bodySmall.copyWith(
            color: Colors.orange.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool loading = false,
    bool destructive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: destructive 
              ? Colors.red.shade200
              : AppTheme.colors.lightGray,
        ),
      ),
      child: ListTile(
        onTap: loading ? null : onTap,
        leading: loading 
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                icon,
                color: destructive 
                    ? Colors.red.shade600
                    : AppTheme.primaryColor,
              ),
        title: Text(
          title,
          style: AppTheme.typography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: destructive 
                ? Colors.red.shade700
                : AppTheme.colors.charcoal,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTheme.typography.bodySmall.copyWith(
            color: destructive 
                ? Colors.red.shade500
                : AppTheme.colors.darkGray,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: AppTheme.colors.mediumGray,
        ),
      ),
    );
  }

  String _getActionTypeDisplayName(OfflineActionType type) {
    switch (type) {
      case OfflineActionType.createServiceRequest:
        return 'Создание заявки';
      case OfflineActionType.updateUtilityReading:
        return 'Показания счетчиков';
      case OfflineActionType.createFeedback:
        return 'Отзыв';
      case OfflineActionType.updateProfile:
        return 'Обновление профиля';
      case OfflineActionType.markNewsAsRead:
        return 'Прочтение новости';
    }
  }

  void _forcSync() async {
    if (_isSyncing) return;
    
    setState(() => _isSyncing = true);
    HapticFeedback.lightImpact();
    
    try {
      await widget.offlineService.forceSync();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Синхронизация завершена'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка синхронизации: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _clearCache() async {
    HapticFeedback.mediumImpact();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить кеш?'),
        content: const Text(
          'Это действие удалит все локальные данные. '
          'Несинхронизированные изменения будут потеряны.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.offlineService.clearOfflineData();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Кеш очищен'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _resolveConflict(String conflictId, ConflictResolution resolution) async {
    HapticFeedback.lightImpact();
    
    await widget.offlineService.resolveConflict(conflictId, resolution);
    
    if (mounted) {
      setState(() {
        widget.conflicts.removeWhere((c) => c.id == conflictId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Конфликт разрешен'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
} 
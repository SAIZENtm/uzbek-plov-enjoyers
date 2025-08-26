import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_export.dart';
import '../../core/di/service_locator.dart';
import '../../core/models/invitation_model.dart';
import '../../widgets/frosted_glass_card.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  List<InvitationModel> _invites = [];
  bool _isLoading = true;
  late final InviteService _inviteService;

  @override
  void initState() {
    super.initState();
    _inviteService = getIt<InviteService>();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    setState(() => _isLoading = true);
    
    try {
      final invites = await _inviteService.getUserInvites();
      setState(() {
        _invites = invites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки инвайтов: $e')),
        );
      }
    }
  }

  Future<void> _createNewInvite() async {
    final authService = getIt<AuthService>();
    final currentApartment = authService.verifiedApartment;
    
    if (currentApartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите квартиру')),
      );
      return;
    }

    try {
      final invite = await _inviteService.createFamilyInvite(
        apartmentId: currentApartment.id,
        blockId: currentApartment.blockId,
        apartmentNumber: currentApartment.apartmentNumber,
        ownerName: authService.userData?['fullName'] ?? 'Владелец',
        ownerPhone: authService.userData?['phone'] ?? '',
        ownerPassport: authService.userData?['passport_number'],
        customMessage: null,
        maxUses: 5,
        validityDuration: const Duration(days: 7),
      );

      if (invite != null) {
        await _loadInvites();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Инвайт создан успешно!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания инвайта: $e')),
        );
      }
    }
  }

  Future<void> _shareInvite(InvitationModel invite) async {
    try {
      final message = 'Привет! 👋\n\n'
          'Владелец квартиры ${invite.blockId} ${invite.apartmentNumber} '
          'приглашает вас присоединиться к семье в приложении Newport Resident.\n\n'
          '🔗 Ссылка для регистрации:\n'
          '${invite.inviteLink}\n\n'
          '⏰ Ссылка действительна до ${_formatDate(invite.expiresAt)}\n'
          '👥 Максимум использований: ${invite.maxUses}';

      await Share.share(
        message,
        subject: 'Приглашение в семью Newport Resident',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e')),
        );
      }
    }
  }

  Future<void> _cancelInvite(InvitationModel invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить инвайт?'),
        content: Text('Инвайт ${invite.shortCode} будет отменен. Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Отменить инвайт'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _inviteService.cancelInvite(invite.id);
        await _loadInvites();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Инвайт отменен')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка отмены инвайта: $e')),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      appBar: AppBar(
        backgroundColor: AppTheme.colors.pureWhite,
        elevation: 0,
        surfaceTintColor: AppTheme.colors.pureWhite,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.colors.charcoal),
          onPressed: () => context.go('/profile/family'),
        ),
        title: Text(
          'Инвайты семьи',
          style: AppTheme.typography.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.colors.charcoal,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.colors.charcoal),
            onPressed: _loadInvites,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _invites.isEmpty
                    ? _buildEmptyState()
                    : _buildInvitesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewInvite,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.colors.pureWhite,
        icon: const Icon(Icons.add),
        label: const Text('Создать инвайт'),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Приглашения семьи',
            style: AppTheme.typography.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.colors.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Создавайте ссылки для приглашения членов семьи в вашу квартиру',
            style: AppTheme.typography.bodyMedium.copyWith(
              color: AppTheme.colors.darkGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.colors.lightGray,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.share,
                size: 64,
                color: AppTheme.colors.mediumGray,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Нет активных инвайтов',
              style: AppTheme.typography.headlineSmall.copyWith(
                color: AppTheme.colors.darkGray,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Создайте инвайт, чтобы пригласить\nчленов семьи в вашу квартиру',
              style: AppTheme.typography.bodyMedium.copyWith(
                color: AppTheme.colors.mediumGray,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _invites.length,
      itemBuilder: (context, index) {
        final invite = _invites[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _InviteCard(
            invite: invite,
            onShare: () => _shareInvite(invite),
            onCancel: () => _cancelInvite(invite),
          ),
        );
      },
    );
  }
}

class _InviteCard extends StatelessWidget {
  final InvitationModel invite;
  final VoidCallback onShare;
  final VoidCallback onCancel;

  const _InviteCard({
    required this.invite,
    required this.onShare,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = DateTime.now().isAfter(invite.expiresAt);
    final isUsedUp = invite.currentUses >= invite.maxUses;

    return FrostedGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.secondaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      invite.shortCode,
                      style: AppTheme.typography.titleMedium.copyWith(
                        color: AppTheme.colors.pureWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Квартира ${invite.apartmentNumber}',
                        style: AppTheme.typography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.colors.charcoal,
                        ),
                      ),
                      Text(
                        'Блок ${invite.blockId}',
                        style: AppTheme.typography.bodyMedium.copyWith(
                          color: AppTheme.colors.darkGray,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isExpired || isUsedUp)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isExpired ? 'Истек' : 'Использован',
                      style: AppTheme.typography.bodySmall.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatItem(
                  Icons.people,
                  '${invite.currentUses}/${invite.maxUses}',
                  'Использований',
                ),
                const SizedBox(width: 24),
                _buildStatItem(
                  Icons.access_time,
                  _formatDate(invite.expiresAt),
                  'Действует до',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: invite.canBeUsed ? onShare : null,
                    icon: const Icon(Icons.share),
                    label: const Text('Поделиться'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: invite.canBeUsed ? onCancel : null,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Отменить'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.colors.mediumGray),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTheme.typography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.colors.charcoal,
              ),
            ),
            Text(
              label,
              style: AppTheme.typography.bodySmall.copyWith(
                color: AppTheme.colors.mediumGray,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
  }
} 
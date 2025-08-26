import 'package:intl/intl.dart';

import '../../../core/app_export.dart';
import '../../../core/models/family_member_model.dart';
import '../../../widgets/card_container.dart';

class FamilyMemberCard extends StatelessWidget {
  final FamilyMemberModel member;
  final VoidCallback onRemove;

  const FamilyMemberCard({
    super.key,
    required this.member,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMemberInfo(),
              ),
              _buildActionButton(context),
            ],
          ),
          const SizedBox(height: 16),
          _buildMemberDetails(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.newportPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Icon(
        _getRoleIcon(),
        color: AppTheme.newportPrimary,
        size: 28,
      ),
    );
  }

  IconData _getRoleIcon() {
    switch (member.role) {
      case 'mother':
        return Icons.woman;
      case 'father':
        return Icons.man;
      case 'son':
        return Icons.boy;
      case 'daughter':
        return Icons.girl;
      case 'grandmother':
      case 'grandfather':
        return Icons.elderly;
      default:
        return Icons.person;
    }
  }

  Widget _buildMemberInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          member.name,
          style: AppTheme.typography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.newportPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            member.roleDisplayName,
            style: AppTheme.typography.bodyMedium.copyWith(
              fontSize: 12,
              color: AppTheme.newportPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: AppTheme.mediumGray,
      ),
      onSelected: (value) {
        if (value == 'remove') {
          onRemove();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'remove',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Удалить',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightGray.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (member.phone != null) ...[
            _buildDetailRow(
              Icons.phone,
              'Телефон',
              member.phone!,
            ),
            const SizedBox(height: 12),
          ],
          _buildDetailRow(
            Icons.access_time,
            'Дата присоединения',
            DateFormat('dd.MM.yyyy').format(member.createdAt),
          ),
          if (member.approvedAt != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.check_circle,
              'Подтверждено',
              DateFormat('dd.MM.yyyy HH:mm').format(member.approvedAt!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.mediumGray,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTheme.typography.bodyMedium.copyWith(
            fontSize: 12,
            color: AppTheme.mediumGray,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: AppTheme.typography.bodyMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.charcoal,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
} 

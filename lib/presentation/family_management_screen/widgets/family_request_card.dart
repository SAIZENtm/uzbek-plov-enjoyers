import 'package:intl/intl.dart';

import '../../../core/app_export.dart';
import '../../../core/models/family_request_model.dart';
import '../../../core/models/family_member_model.dart';
import '../../../widgets/card_container.dart';
import '../../family_request_screen/widgets/family_request_notification_dialog.dart';

class FamilyRequestCard extends StatelessWidget {
  final FamilyRequestModel request;
  final VoidCallback? onRequestHandled;

  const FamilyRequestCard({
    super.key,
    required this.request,
    this.onRequestHandled,
  });

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRequestHeader(),
          const SizedBox(height: 16),
          _buildRequestInfo(),
          const SizedBox(height: 16),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildRequestHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getStatusColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getStatusIcon(),
            color: _getStatusColor(),
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.name,
                style: AppTheme.typography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.newportPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      FamilyMemberModel.roles[request.role] ?? request.role,
                      style: AppTheme.typography.bodyMedium.copyWith(
                        fontSize: 12,
                        color: AppTheme.newportPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      request.statusDisplayName,
                      style: AppTheme.typography.bodyMedium.copyWith(
                        fontSize: 12,
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightGray.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.apartment,
            'Квартира',
            request.fullAddress,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.phone,
            'Телефон заявителя',
            request.applicantPhone ?? 'Не указан',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.access_time,
            'Дата запроса',
            DateFormat('dd.MM.yyyy HH:mm').format(request.createdAt),
          ),
          if (request.respondedAt != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.check_circle,
              'Дата ответа',
              DateFormat('dd.MM.yyyy HH:mm').format(request.respondedAt!),
            ),
          ],
          if (request.rejectionReason != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.info_outline,
              'Причина отклонения',
              request.rejectionReason!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(width: 8),
        Expanded(
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

  Widget _buildActionButtons(BuildContext context) {
    if (!request.isPending) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getStatusColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              _getStatusIcon(),
              color: _getStatusColor(),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              request.statusDisplayName,
              style: AppTheme.typography.bodyMedium.copyWith(
                color: _getStatusColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showRequestDialog(context),
            icon: const Icon(Icons.visibility),
            label: const Text('Рассмотреть'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.newportPrimary,
              side: const BorderSide(color: AppTheme.newportPrimary),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _showRequestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FamilyRequestNotificationDialog(
        request: request,
        onRequestHandled: onRequestHandled,
      ),
    );
  }

  Color _getStatusColor() {
    switch (request.status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return AppTheme.mediumGray;
    }
  }

  IconData _getStatusIcon() {
    switch (request.status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }
} 

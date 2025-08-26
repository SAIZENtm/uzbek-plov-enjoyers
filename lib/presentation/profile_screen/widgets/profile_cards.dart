import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_export.dart';
import '../../../core/models/resident_profile_model.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../widgets/card_container.dart';

/// Base profile card widget
class ProfileCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ProfileCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      margin: EdgeInsets.only(bottom: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 20,
              ),
              SizedBox(width: 3.w),
              Text(
                title,
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: 2.h),
          child,
        ],
      ),
    );
  }
}

/// Contact information card
class ContactCard extends StatelessWidget {
  const ContactCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        final profile = provider.profile;
        if (profile == null) return const SizedBox.shrink();

        return ProfileCard(
          title: 'Контакты',
          icon: Icons.contact_phone,
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditContactDialog(context, profile),
            tooltip: 'Редактировать',
          ),
          child: Column(
            children: [
              _ContactTile(
                icon: Icons.phone,
                label: 'Телефон',
                value: profile.phone,
                onTap: () => _launchPhone(profile.phone),
              ),
              if (profile.email != null) ...[
                SizedBox(height: 1.h),
                _ContactTile(
                  icon: Icons.email,
                  label: 'Email',
                  value: profile.email!,
                  onTap: () => _launchEmail(profile.email!),
                ),
              ],
              if (profile.telegram != null) ...[
                SizedBox(height: 1.h),
                _ContactTile(
                  icon: Icons.telegram,
                  label: 'Telegram',
                  value: profile.telegram!,
                  onTap: () => _launchTelegram(profile.telegram!),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showEditContactDialog(BuildContext context, ResidentProfile profile) {
    showDialog(
      context: context,
      builder: (context) => _ContactEditDialog(profile: profile),
    );
  }

  void _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchTelegram(String telegram) async {
    final username = telegram.startsWith('@') ? telegram.substring(1) : telegram;
    final uri = Uri.parse('https://t.me/$username');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

/// Contact tile widget
class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 2.w),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 3.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: AppTheme.lightTheme.textTheme.bodyMedium,
                ),
              ],
            ),
            const Spacer(),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// Housing information card
class HousingCard extends StatelessWidget {
  const HousingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        final profile = provider.profile;
        if (profile == null) return const SizedBox.shrink();

        return ProfileCard(
          title: 'Жильё',
          icon: Icons.home,
          child: Column(
            children: [
              _HousingInfoRow(
                label: 'Тип собственности',
                value: profile.roleDisplay,
                icon: _getRoleIcon(profile.role),
              ),
              SizedBox(height: 1.h),
              _HousingInfoRow(
                label: 'Квартира',
                value: profile.apartmentDisplay,
                icon: Icons.apartment,
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/payment'),
                      icon: const Icon(Icons.payment),
                      label: const Text('Оплатить коммуналку'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.lightTheme.colorScheme.primary,
                        foregroundColor: AppTheme.lightTheme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  IconButton(
                    onPressed: () => _showGuestQR(context, profile),
                    icon: const Icon(Icons.qr_code),
                    tooltip: 'QR для гостя',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getRoleIcon(ResidentRole role) {
    switch (role) {
      case ResidentRole.owner:
        return Icons.verified_user;
      case ResidentRole.renter:
        return Icons.person;
      case ResidentRole.guest:
        return Icons.person_outline;
      case ResidentRole.familyFull:
        return Icons.family_restroom;
    }
  }

  void _showGuestQR(BuildContext context, ResidentProfile profile) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _GuestQRSheet(profile: profile),
    );
  }
}

/// Housing info row widget
class _HousingInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HousingInfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: 3.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Notifications settings card
class NotificationsCard extends StatelessWidget {
  const NotificationsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        final prefs = provider.notificationPrefs;
        
        return ProfileCard(
          title: 'Уведомления',
          icon: Icons.notifications,
          child: Column(
            children: [
              _NotificationSwitch(
                title: 'Критические новости',
                subtitle: 'Важные уведомления о ЖКХ',
                icon: Icons.priority_high,
                value: prefs.critical,
                onChanged: (value) => provider.toggleNotificationChannel('critical', value),
              ),
              _NotificationSwitch(
                title: 'Общие новости',
                subtitle: 'Новости сообщества',
                icon: Icons.info,
                value: prefs.general,
                onChanged: (value) => provider.toggleNotificationChannel('general', value),
              ),
              _NotificationSwitch(
                title: 'Сервисные уведомления',
                subtitle: 'Статусы заявок и услуг',
                icon: Icons.build,
                value: prefs.service,
                onChanged: (value) => provider.toggleNotificationChannel('service', value),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Notification switch widget
class _NotificationSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationSwitch({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      secondary: Icon(icon),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.lightTheme.colorScheme.primary,
    );
  }
}

/// History card showing recent service requests
class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      title: 'История',
      icon: Icons.history,
      trailing: TextButton(
        onPressed: () => context.go('/service-requests'),
        child: const Text('Показать все'),
      ),
      child: const Column(
        children: [
          // Mock data - in real app, this would come from ServiceRequestProvider
          _HistoryItem(
            title: 'Ремонт лифта',
            date: 'Сегодня',
            status: 'pending',
          ),
          _HistoryItem(
            title: 'Замена лампочки',
            date: 'Вчера',
            status: 'done',
          ),
          _HistoryItem(
            title: 'Проблема с водой',
            date: '2 дня назад',
            status: 'done',
          ),
        ],
      ),
    );
  }
}

/// History item widget
class _HistoryItem extends StatelessWidget {
  final String title;
  final String date;
  final String status;

  const _HistoryItem({
    required this.title,
    required this.date,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.lightTheme.textTheme.bodyMedium,
                ),
                Text(
                  date,
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(status: status),
        ],
      ),
    );
  }
}

/// Status chip widget
class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, text) = _getStatusInfo(status);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: color.withAlpha(153), // 0.6 opacity
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, String) _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return (Colors.orange, 'В работе');
      case 'done':
        return (Colors.green, 'Готово');
      case 'cancelled':
        return (Colors.red, 'Отменено');
      default:
        return (Colors.grey, 'Неизвестно');
    }
  }
}

/// App settings card
class AppSettingsCard extends StatelessWidget {
  const AppSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      title: 'Настройки приложения',
      icon: Icons.settings,
      child: Column(
        children: [
          _SettingsDropdown(
            title: 'Язык',
            value: 'Русский',
            items: const ['Русский', 'O\'zbek', 'English'],
            onChanged: (value) {
              // TODO: Implement language change
            },
          ),
          SizedBox(height: 1.h),
          _SettingsRadioGroup(
            title: 'Тема',
            value: 'Светлая',
            items: const ['Светлая', 'Тёмная', 'Системная'],
            onChanged: (value) {
              // TODO: Implement theme change
            },
          ),
          SizedBox(height: 2.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(Icons.logout),
              label: const Text('Выход из аккаунта'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.lightTheme.colorScheme.error,
                side: BorderSide(color: AppTheme.lightTheme.colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход из аккаунта'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement logout
              context.go('/auth');
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}

/// Settings dropdown widget
class _SettingsDropdown extends StatelessWidget {
  final String title;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _SettingsDropdown({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppTheme.lightTheme.textTheme.bodyMedium,
        ),
        const Spacer(),
        DropdownButton<String>(
          value: value,
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item),
          )).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Settings radio group widget
class _SettingsRadioGroup extends StatelessWidget {
  final String title;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _SettingsRadioGroup({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.lightTheme.textTheme.bodyMedium,
        ),
        ...items.map((item) => RadioListTile<String>(
          title: Text(item),
          value: item,
          groupValue: value,
          onChanged: onChanged,
          dense: true,
        )),
      ],
    );
  }
}

/// Contact edit dialog
class _ContactEditDialog extends StatefulWidget {
  final ResidentProfile profile;

  const _ContactEditDialog({required this.profile});

  @override
  State<_ContactEditDialog> createState() => _ContactEditDialogState();
}

class _ContactEditDialogState extends State<_ContactEditDialog> {
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _telegramController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.profile.phone);
    _emailController = TextEditingController(text: widget.profile.email ?? '');
    _telegramController = TextEditingController(text: widget.profile.telegram ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _telegramController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Редактировать контакты'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Телефон',
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: 1.h),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 1.h),
          TextField(
            controller: _telegramController,
            decoration: const InputDecoration(
              labelText: 'Telegram',
              prefixIcon: Icon(Icons.telegram),
              hintText: '@username',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _saveChanges,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  void _saveChanges() {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    provider.updateContactInfo(
      phone: _phoneController.text,
      email: _emailController.text.isEmpty ? null : _emailController.text,
      telegram: _telegramController.text.isEmpty ? null : _telegramController.text,
    );
    Navigator.pop(context);
  }
}

/// Guest QR code bottom sheet
class _GuestQRSheet extends StatelessWidget {
  final ResidentProfile profile;

  const _GuestQRSheet({required this.profile});

  @override
  Widget build(BuildContext context) {
    final qrData = 'GUEST_ACCESS:${profile.blockId}:${profile.apartmentNumber}:${profile.uid}';
    
    return Container(
      padding: EdgeInsets.all(6.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12.w,
            height: 0.5.h,
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'QR-код для гостя',
            style: AppTheme.lightTheme.textTheme.titleLarge,
          ),
          SizedBox(height: 1.h),
          Text(
            'Покажите этот код охране для прохода гостя',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 3.h),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(77), // 0.3 opacity
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 60.w,
              backgroundColor: Colors.white,
              gapless: false,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppTheme.lightTheme.colorScheme.primary,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppTheme.lightTheme.colorScheme.primary,
              ),
              embeddedImage: const AssetImage('assets/images/img_app_logo.svg'),
              embeddedImageStyle: QrEmbeddedImageStyle(
                size: Size(10.w, 10.w),
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Покажите этот QR-код охране для пропуска гостя',
            textAlign: TextAlign.center,
            style: AppTheme.lightTheme.textTheme.bodyMedium,
          ),
          SizedBox(height: 1.h),
          Text(
            'Действителен до конца дня',
            textAlign: TextAlign.center,
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurface.withAlpha(153), // 0.6 opacity
            ),
          ),
        ],
      ),
    );
  }
} 
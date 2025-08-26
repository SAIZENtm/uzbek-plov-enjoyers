import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;

import '../../core/app_export.dart';
import '../../core/models/resident_profile_model.dart';
import '../../core/providers/profile_provider.dart';
import '../../widgets/custom_error_widget.dart';
import 'widgets/profile_cards.dart';
import 'widgets/profile_edit_sheet.dart';

class ResidentProfileScreen extends StatefulWidget {
  const ResidentProfileScreen({super.key});

  @override
  State<ResidentProfileScreen> createState() => _ResidentProfileScreenState();
}

class _ResidentProfileScreenState extends State<ResidentProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Load profile data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: Consumer<ProfileProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return CustomErrorWidget(
              message: provider.error!,
              onRetry: () => provider.loadProfile(),
            );
          }

          if (!provider.hasProfile) {
            return const Center(
              child: Text('Профиль не найден'),
            );
          }

          return _buildProfileContent(provider.profile!);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditSheet(context),
        tooltip: 'Редактировать',
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildProfileContent(ResidentProfile profile) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
            expandedHeight: 35.h,
            floating: false,
            pinned: true,
            title: innerBoxIsScrolled ? const Text('Профиль') : null,
            backgroundColor: AppTheme.lightTheme.colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroHeader(profile),
            ),
          ),
        ];
      },
      body: _buildProfileBody(profile),
    );
  }

  Widget _buildHeroHeader(ResidentProfile profile) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.lightTheme.colorScheme.primary,
            AppTheme.lightTheme.colorScheme.primary.withAlpha(204), // 0.8 opacity
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background image (mock block photo)
          const Positioned.fill(
            child: CustomImageWidget(
              imageUrl: 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?q=80&w=2940&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(77), // 0.3 opacity
                    Colors.black.withAlpha(179), // 0.7 opacity
                  ],
                ),
              ),
            ),
          ),
          // Profile content
          Positioned(
            bottom: 8.h,
            left: 6.w,
            right: 6.w,
            child: Column(
              children: [
                _buildAvatar(profile),
                SizedBox(height: 2.h),
                _buildProfileInfo(profile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ResidentProfile profile) {
    return Hero(
      tag: 'avatar',
      child: badges.Badge(
        showBadge: true,
        badgeContent: Icon(
          _getStatusIcon(profile.role),
          size: 12,
          color: Colors.white,
        ),
        badgeStyle: badges.BadgeStyle(
          badgeColor: _getStatusColor(profile.role),
          elevation: 4,
        ),
        position: badges.BadgePosition.bottomEnd(bottom: 8, end: 8),
        child: Container(
          width: 22.w, // 88dp equivalent
          height: 22.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(77), // 0.3 opacity
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: profile.avatarUrl != null
                ? CustomImageWidget(
                    imageUrl: profile.avatarUrl!,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: AppTheme.lightTheme.colorScheme.surface,
                    child: Icon(
                      Icons.person,
                      size: 12.w,
                      color: AppTheme.lightTheme.colorScheme.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfo(ResidentProfile profile) {
    return Column(
      children: [
        Text(
          profile.displayName,
          style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: Colors.black.withAlpha(128), // 0.5 opacity
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        SizedBox(height: 0.5.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on,
              size: 16,
              color: Colors.white.withAlpha(230), // 0.9 opacity
            ),
            SizedBox(width: 1.w),
            Text(
              profile.apartmentDisplay,
              style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withAlpha(230), // 0.9 opacity
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black.withAlpha(128), // 0.5 opacity
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
          decoration: BoxDecoration(
            color: _getStatusColor(profile.role).withAlpha(230), // 0.9 opacity
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _getStatusText(profile.role),
            style: AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileBody(ResidentProfile profile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        children: [
          if (profile.hasNotifications) _buildNotificationBanner(profile),
          const ContactCard(),
          const HousingCard(),
          const NotificationsCard(),
          const HistoryCard(),
          const AppSettingsCard(),
          SizedBox(height: 10.h), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildNotificationBanner(ResidentProfile profile) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.error.withAlpha(77), // 0.3 opacity
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning,
            color: AppTheme.lightTheme.colorScheme.error,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Требует внимания',
                  style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (profile.hasUnpaidBills)
                  Text(
                    'Есть неоплаченные счета',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.onErrorContainer,
                    ),
                  ),
                if (profile.hasOpenRequests)
                  Text(
                    'Есть открытые заявки',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.onErrorContainer,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ProfileEditSheet(),
    );
  }

  // Helper methods for status styling
  IconData _getStatusIcon(ResidentRole role) {
    switch (role) {
      case ResidentRole.owner:
        return Icons.verified;
      case ResidentRole.renter:
        return Icons.person;
      case ResidentRole.guest:
        return Icons.person_outline;
      case ResidentRole.familyFull:
        return Icons.family_restroom;
    }
  }

  Color _getStatusColor(ResidentRole role) {
    switch (role) {
      case ResidentRole.owner:
        return Colors.green;
      case ResidentRole.renter:
        return Colors.blue;
      case ResidentRole.guest:
        return Colors.orange;
      case ResidentRole.familyFull:
        return Colors.purple;
    }
  }

  String _getStatusText(ResidentRole role) {
    switch (role) {
      case ResidentRole.owner:
        return 'Собственник';
      case ResidentRole.renter:
        return 'Арендатор';
      case ResidentRole.guest:
        return 'Гость';
      case ResidentRole.familyFull:
        return 'Член семьи';
    }
  }
} 
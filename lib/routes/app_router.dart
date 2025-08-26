import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';

import '../core/services/auth_service.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/authentication_screen/authentication_screen.dart';
import '../presentation/dashboard_screen/dashboard_screen.dart';
import '../presentation/news_screen/news_list_screen.dart';
import '../presentation/news_screen/news_detail_screen.dart';
import '../presentation/service_request_screen/service_request_stepper_screen.dart';
import '../presentation/service_requests_list_screen/service_requests_list_screen.dart';
import '../presentation/services_screen/services_screen.dart';
import '../presentation/notifications_screen/notifications_screen.dart';
import '../presentation/profile_screen/profile_screen.dart';
import '../presentation/profile_screen/resident_profile_screen.dart';
import '../presentation/payment_screen/payment_screen.dart';
import '../presentation/utility_readings_screen/utility_readings_screen.dart';
import '../presentation/apartments_list_screen/apartments_list_screen.dart';
import '../presentation/community_screen/community_screen.dart';
import '../presentation/family_request_screen/family_request_screen.dart';
import '../presentation/phone_registration_screen/phone_registration_screen.dart';
import '../presentation/family_management_screen/family_management_screen.dart';
import '../presentation/invite_accept_screen/invite_accept_screen.dart';
import '../presentation/invite_screen/invite_screen.dart';
import '../presentation/my_requests_screen/my_requests_screen.dart';
import '../presentation/smart_home_screen/smart_home_screen.dart';
import '../widgets/premium_main_shell.dart';

/// Enhanced App Router with go_router for modern navigation
class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  /// Main router configuration
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    debugLogDiagnostics: true,
    
    // Route guards
    redirect: (context, state) {
      final authService = GetIt.instance<AuthService>();
      final isAuthenticated = authService.isAuthenticated;
      final isOnAuthFlow = ['/splash', '/auth', '/apartments', '/family-request', '/phone-registration', '/invite'].contains(state.uri.path);
      
      // If not authenticated and not on auth flow, go to splash
      if (!isAuthenticated && !isOnAuthFlow) {
        return '/splash';
      }
      
      // If authenticated and on auth flow (except apartments), go to dashboard
      if (isAuthenticated && isOnAuthFlow && state.uri.path != '/apartments') {
        return '/dashboard';
      }
      
      // If authenticated and trying to go to splash, redirect to dashboard
      if (isAuthenticated && state.uri.path == '/splash') {
        return '/dashboard';
      }
      
      return null; // No redirect needed
    },
    
    routes: [
      // AUTH FLOW ROUTES (without shell)
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthenticationScreen(),
      ),
      
      GoRoute(
        path: '/apartments',
        name: 'apartments',
        builder: (context, state) => const ApartmentsListScreen(),
      ),
      
      // FAMILY ROUTES (without shell for non-authenticated users)
      GoRoute(
        path: '/family-request',
        name: 'family_request',
        builder: (context, state) => const FamilyRequestScreen(),
      ),
      
      GoRoute(
        path: '/phone-registration',
        name: 'phone_registration',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          return PhoneRegistrationScreen(requestId: requestId);
        },
      ),
      
      // INVITE ACCEPTANCE ROUTE (without shell for non-authenticated users)
      GoRoute(
        path: '/invite/:inviteId',
        name: 'invite_accept',
        builder: (context, state) {
          final inviteId = state.pathParameters['inviteId']!;
          return InviteAcceptScreen(inviteId: inviteId);
        },
      ),
      
      // MAIN APP ROUTES (with shell)
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return PremiumMainShell(child: child);
        },
        routes: [
          // DASHBOARD
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          
          // NEWS ROUTES
          GoRoute(
            path: '/news',
            name: 'news',
            builder: (context, state) => const NewsListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'news_detail',
                builder: (context, state) {
                  final newsId = state.pathParameters['id']!;
                  return NewsDetailScreen(newsId: newsId);
                },
              ),
            ],
          ),
          
          // SERVICES ROUTES
          GoRoute(
            path: '/services',
            name: 'services',
            builder: (context, state) => const ServicesScreen(),
            routes: [
              GoRoute(
                path: 'new-request',
                name: 'new_service_request',
                builder: (context, state) {
                  final serviceType = state.uri.queryParameters['type'];
                  return ServiceRequestStepperScreen(initialRequestType: serviceType);
                },
              ),
              GoRoute(
                path: 'requests',
                name: 'service_requests_list',
                builder: (context, state) => const ServiceRequestsListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'service_request_detail',
                    builder: (context, state) {
                      final requestId = state.pathParameters['id']!;
                      return ServiceRequestsListScreen(initialRequestId: requestId);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'my-requests',
                name: 'my_requests',
                builder: (context, state) => const MyRequestsScreen(),
              ),
            ],
          ),
          
          // NOTIFICATIONS
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          
          // PROFILE ROUTES
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'resident',
                name: 'resident_profile',
                builder: (context, state) => const ResidentProfileScreen(),
              ),
              GoRoute(
                path: 'payment',
                name: 'payment',
                builder: (context, state) => const PaymentScreen(),
              ),
              GoRoute(
                path: 'utility-readings',
                name: 'utility_readings',
                builder: (context, state) => const UtilityReadingsScreen(),
              ),
              GoRoute(
                path: 'family',
                name: 'family_management',
                builder: (context, state) => const FamilyManagementScreen(),
              ),
              GoRoute(
                path: 'invites',
                name: 'invites',
                builder: (context, state) => const InviteScreen(),
              ),
            ],
          ),
          
          // SMART HOME ROUTES
          GoRoute(
            path: '/smart-home',
            name: 'smart_home',
            builder: (context, state) => const SmartHomeScreen(),
          ),

          // COMMUNITY
          GoRoute(
            path: '/community',
            name: 'community',
            builder: (context, state) => const CommunityScreen(),
          ),
        ],
      ),
    ],
    
    // Enhanced error handling
    errorBuilder: (context, state) => _buildErrorPage(context, state),
  );
  
  /// Build custom error page
  static Widget _buildErrorPage(BuildContext context, GoRouterState state) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0A),
              Color(0xFF1A1A1A),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0050A3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(60),
                    border: Border.all(
                      color: const Color(0xFF0050A3).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 60,
                    color: Color(0xFF0050A3),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Text(
                  '404',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 48,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'Страница не найдена',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Запрашиваемая страница не существует или была перемещена',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 48),
                
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0050A3), Color(0xFF00AEEF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0050A3).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => context.go('/dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'На главную',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () => context.go('/services'),
                  child: Text(
                    'Сервисы',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF00AEEF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Extension for easier navigation
extension GoRouterExtension on BuildContext {
  /// Navigate and replace current route
  void goAndReplace(String location) {
    go(location);
    // Clear navigation history if needed
  }
  
  /// Navigate with animation
  void goWithAnimation(String location) {
    go(location);
  }
  
  /// Navigate back or to fallback location
  void goBackOr(String fallbackLocation) {
    if (canPop()) {
      pop();
    } else {
      go(fallbackLocation);
    }
  }
  
  /// Navigate to news detail with transition
  void goToNews(String newsId) {
    go('/news/$newsId');
  }
  
  /// Navigate to service request
  void goToServiceRequest(String requestId) {
    go('/services/my-requests');
  }
  
  /// Navigate to new service request with type
  void goToNewServiceRequest({String? serviceType}) {
    final uri = serviceType != null 
        ? '/services/new-request?type=$serviceType'
        : '/services/new-request';
    go(uri);
  }
} 
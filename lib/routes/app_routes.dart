import 'package:flutter/material.dart';
import '../presentation/apartments_list_screen/apartments_list_screen.dart';
import '../presentation/authentication_screen/authentication_screen.dart';
import '../presentation/dashboard_screen/dashboard_screen.dart';
import '../presentation/payment_screen/payment_screen.dart';
import '../presentation/service_request_screen/service_request_screen.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/utility_readings_screen/utility_readings_screen.dart';
import '../presentation/news_screen/news_list_screen.dart';
import '../presentation/news_screen/news_detail_screen.dart';
import '../presentation/notifications_screen/notifications_screen.dart';
import '../presentation/service_requests_list_screen/service_requests_list_screen.dart';
import '../presentation/profile_screen/resident_profile_screen.dart';
import '../presentation/my_requests_screen/my_requests_screen.dart';
import '../presentation/test_my_requests_screen.dart';


class AppRoutes {
  static const String splashScreen = '/';
  static const String authenticationScreen = '/authentication-screen';
  static const String dashboardScreen = '/dashboard-screen';
  static const String serviceRequestScreen = '/service-request-screen';
  static const String utilityReadingsScreen = '/utility-readings-screen';
  static const String paymentScreen = '/payment-screen';
  static const String apartmentsListScreen = '/apartments-list-screen';
  static const String newsListScreen = '/news-list-screen';
  static const String newsDetailScreen = '/news-detail-screen';
  static const String notificationsScreen = '/notifications-screen';
  static const String serviceRequestsListScreen = '/service-requests-list-screen';
  static const String profileScreen = '/profile-screen';
  static const String myRequestsScreen = '/my-requests-screen';
  static const String testMyRequestsScreen = '/test-my-requests-screen';

  static Map<String, WidgetBuilder> get routes {
    return {
      splashScreen: (context) => const SplashScreen(),
      authenticationScreen: (context) => const AuthenticationScreen(),
      dashboardScreen: (context) => const DashboardScreen(),
      serviceRequestScreen: (context) => const ServiceRequestScreen(),
      utilityReadingsScreen: (context) => const UtilityReadingsScreen(),
      paymentScreen: (context) => const PaymentScreen(),
      apartmentsListScreen: (context) => const ApartmentsListScreen(),
      newsListScreen: (context) => const NewsListScreen(),
      newsDetailScreen: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is String) {
          return NewsDetailScreen(newsId: args);
        }
        return const Scaffold(
          body: Center(child: Text('Invalid arguments')),
        );
      },
      notificationsScreen: (context) => const NotificationsScreen(),
      serviceRequestsListScreen: (context) => const ServiceRequestsListScreen(),
      profileScreen: (context) => const ResidentProfileScreen(),
      myRequestsScreen: (context) => const MyRequestsScreen(),
      testMyRequestsScreen: (context) => const TestMyRequestsScreen(),
    };
  }

  // Navigation helper methods
  static void navigateToScreen(BuildContext context, String routeName, {Object? arguments}) {
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  static void navigateAndReplace(BuildContext context, String routeName, {Object? arguments}) {
    Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }

  static void navigateAndRemoveUntil(BuildContext context, String routeName, {Object? arguments}) {
    Navigator.pushNamedAndRemoveUntil(
      context, 
      routeName,
      (Route<dynamic> route) => false,
      arguments: arguments
    );
  }

  static void popUntilScreen(BuildContext context, String routeName) {
    Navigator.popUntil(context, ModalRoute.withName(routeName));
  }

  static void popAndPushScreen(BuildContext context, String routeName, {Map<String, dynamic>? arguments}) {
    Navigator.popAndPushNamed(context, routeName, arguments: arguments);
  }

  static Future<T?> navigateWithResult<T>(BuildContext context, String routeName, {Map<String, dynamic>? arguments}) {
    return Navigator.pushNamed<T>(context, routeName, arguments: arguments);
  }
}

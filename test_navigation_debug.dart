import 'package:flutter/material.dart';
import 'lib/core/utils/navigation_debugger.dart';

/// Test script for debugging navigation issues
class NavigationDebugTest {
  static void runAllTests(BuildContext context) {
    debugPrint('🧪 Starting navigation debug tests...');
    
    testBasicNavigation(context);
    testDeepLinks(context);
    testAuthenticationFlow(context);
    testErrorHandling(context);
    testPerformance(context);
    
    debugPrint('✅ All navigation tests completed');
  }

  /// Test basic navigation flows
  static void testBasicNavigation(BuildContext context) {
    debugPrint('📱 Testing basic navigation...');
    
    try {
      // Test main routes
      context.safeGo('/dashboard');
      context.safeGo('/news');
      context.safeGo('/services');
      context.safeGo('/profile');
      
      // Test nested routes
      context.safeGo('/news/123');
      context.safeGo('/services/new-request?type=cleaning');
      context.safeGo('/profile/payment');
      
      // Test back navigation
      context.safePop();
      context.safePop();
      
      debugPrint('✅ Basic navigation test passed');
    } catch (e) {
      debugPrint('❌ Basic navigation test failed: $e');
    }
  }

  /// Test deep link handling
  static void testDeepLinks(BuildContext context) {
    debugPrint('🔗 Testing deep links...');
    
    try {
      // Test valid invite link
      _handleDeepLink('newport://invite/abc123');
      
      // Test invalid link
      _handleDeepLink('invalid://link');
      
      // Test malformed link
      _handleDeepLink('newport://');
      
      debugPrint('✅ Deep link test passed');
    } catch (e) {
      debugPrint('❌ Deep link test failed: $e');
    }
  }

  /// Test authentication flow
  static void testAuthenticationFlow(BuildContext context) {
    debugPrint('🔐 Testing authentication flow...');
    
    try {
      // Test auth routes
      context.safeGo('/splash');
      context.safeGo('/auth');
      context.safeGo('/apartments');
      context.safeGo('/family-request');
      context.safeGo('/phone-registration?requestId=test');
      
      debugPrint('✅ Authentication flow test passed');
    } catch (e) {
      debugPrint('❌ Authentication flow test failed: $e');
    }
  }

  /// Test error handling
  static void testErrorHandling(BuildContext context) {
    debugPrint('🚨 Testing error handling...');
    
    try {
      // Test invalid routes
      context.safeGo('/invalid-route');
      context.safeGo('/news/invalid-id');
      context.safeGo('/services/invalid-request');
      
      // Test pop when no history
      context.safePop();
      
      debugPrint('✅ Error handling test passed');
    } catch (e) {
      debugPrint('❌ Error handling test failed: $e');
    }
  }

  /// Test navigation performance
  static void testPerformance(BuildContext context) {
    debugPrint('⏱️ Testing navigation performance...');
    
    try {
      final stopwatch = Stopwatch()..start();
      
      // Perform multiple rapid navigations
      for (int i = 0; i < 10; i++) {
        context.safeGo('/dashboard');
        context.safeGo('/news');
        context.safeGo('/services');
        context.safeGo('/profile');
      }
      
      stopwatch.stop();
      final duration = stopwatch.elapsedMilliseconds;
      
      debugPrint('⏱️ Navigation performance: $duration ms for 40 navigations');
      debugPrint('⏱️ Average: ${duration / 40} ms per navigation');
      
      if (duration < 5000) {
        debugPrint('✅ Performance test passed');
      } else {
        debugPrint('⚠️ Performance test warning: Slow navigation detected');
      }
    } catch (e) {
      debugPrint('❌ Performance test failed: $e');
    }
  }

  /// Simulate deep link handling
  static void _handleDeepLink(String link) {
    debugPrint('🔗 Simulating deep link: $link');
    
    try {
      if (link.contains('newport://invite/')) {
        final uri = Uri.parse(link);
        final inviteId = uri.pathSegments.last;
        
        if (inviteId.isNotEmpty) {
          debugPrint('✅ Valid invite link: $inviteId');
        } else {
          debugPrint('❌ Invalid invite link: empty invite ID');
        }
      } else if (link == 'newport://') {
        debugPrint('❌ Malformed deep link');
      } else {
        debugPrint('❌ Unknown deep link format');
      }
    } catch (e) {
      debugPrint('❌ Deep link parsing error: $e');
    }
  }
}

/// Widget to run navigation tests
class NavigationTestWidget extends StatelessWidget {
  const NavigationTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation Debug Tests'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Debug info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Navigation Debug Info',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Current Location: ${context.navigationDebugInfo['currentLocation']}'),
                  Text('Can Pop: ${context.navigationDebugInfo['canPop']}'),
                  Text('Is Navigating: ${NavigationDebugger.isNavigating}'),
                  Text('Route History: ${context.navigationDebugInfo['routeHistory'].join(' → ')}'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test buttons
            ElevatedButton(
              onPressed: () => NavigationDebugTest.runAllTests(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Run All Tests'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: () => NavigationDebugTest.testBasicNavigation(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Test Basic Navigation'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: () => NavigationDebugTest.testDeepLinks(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Test Deep Links'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: () => NavigationDebugTest.testAuthenticationFlow(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Test Auth Flow'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: () => NavigationDebugTest.testErrorHandling(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Test Error Handling'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: () => NavigationDebugTest.testPerformance(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Test Performance'),
            ),
            
            const SizedBox(height: 16),
            
            // Control buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      NavigationDebugger.setDebugMode(!NavigationDebugger.isDebugMode);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Toggle Debug Mode'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.resetNavigation(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Reset Navigation'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: () => NavigationDebugger.clearHistory(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Clear History'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Usage example:
/// 
/// To add this test widget to your app, you can:
/// 
/// 1. Add a debug route to your AppRouter:
/// ```dart
/// GoRoute(
///   path: '/debug',
///   name: 'debug',
///   builder: (context, state) => const NavigationTestWidget(),
/// ),
/// ```
/// 
/// 2. Enable debug mode in your main.dart:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   NavigationDebugger.setDebugMode(true); // Enable debug mode
///   // ... rest of initialization
/// }
/// ```
/// 
/// 3. Navigate to the debug screen:
/// ```dart
/// context.go('/debug');
/// ```
/// 
/// This will give you a comprehensive testing interface for debugging navigation issues! 
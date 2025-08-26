# Navigation Debugging Guide

## 🚨 Common Navigation Errors & Solutions

### 1. "You have popped the last page off of the stack" Error

**Problem:**
```
You have popped the last page off of the stack, there are no pages left to show
'package:go_router/src/delegate.dart': Failed assertion: line 116 pos 7: 'currentConfiguration.isNotEmpty'
```

**Root Cause:**
- Attempting to call `Navigator.pop()` multiple times
- Trying to pop when no pages are left in the navigation stack
- Incorrect navigation logic in dialogs or forms

**Solution:**
```dart
// ❌ WRONG - Double pop
Navigator.of(context).pop(); // Close dialog
Navigator.of(context).pop(); // Close form - ERROR!

// ✅ CORRECT - Use Go Router navigation
Navigator.of(context).pop(); // Close dialog
context.go('/services'); // Safe navigation
```

### 2. Navigation State Conflicts

**Problem:**
- Navigation state becomes inconsistent
- Multiple navigation attempts conflict
- Deep link handling issues

**Debug Steps:**
```dart
// Add debug logging to AppRouter
static final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  debugLogDiagnostics: true, // Enable debug logging
  redirect: (context, state) {
    debugPrint('🔍 Navigation redirect: ${state.uri.path}');
    // ... existing redirect logic
  },
);
```

### 3. Shell Route Navigation Issues

**Problem:**
- Bottom navigation not updating correctly
- Shell route conflicts with nested routes
- Navigation state not syncing with bottom nav

**Debug Steps:**
```dart
// Add state tracking to PremiumMainShell
Widget _buildBottomNavigationBar(BuildContext context) {
  final location = GoRouterState.of(context).uri.toString();
  debugPrint('📍 Current location: $location');
  
  // Check if location matches expected patterns
  final isActive = location.startsWith('/news');
  debugPrint('📰 News active: $isActive');
  
  return Container(
    // ... existing code
  );
}
```

## 🔧 Debugging Tools & Techniques

### 1. Navigation State Inspector

Add this widget to debug navigation state:

```dart
class NavigationDebugWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final location = GoRouterState.of(context).uri.toString();
    
    return Container(
      padding: EdgeInsets.all(8),
      color: Colors.red.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🔍 Navigation Debug:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Location: $location'),
          Text('Can Pop: ${context.canPop()}'),
          Text('Router: ${router.runtimeType}'),
        ],
      ),
    );
  }
}
```

### 2. Route History Tracker

```dart
class RouteHistoryTracker {
  static final List<String> _history = [];
  
  static void addRoute(String route) {
    _history.add(route);
    debugPrint('📚 Route History: ${_history.join(' → ')}');
  }
  
  static void clear() {
    _history.clear();
  }
  
  static List<String> get history => List.unmodifiable(_history);
}
```

### 3. Navigation Error Catcher

```dart
class NavigationErrorCatcher extends StatelessWidget {
  final Widget child;
  
  const NavigationErrorCatcher({required this.child});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: AppRouter.router,
      builder: (context, child) {
        return ErrorWidget.builder = (FlutterErrorDetails details) {
          debugPrint('🚨 Navigation Error: ${details.exception}');
          debugPrint('🚨 Stack trace: ${details.stack}');
          
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Navigation Error'),
                  SizedBox(height: 8),
                  Text('${details.exception}'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/dashboard'),
                    child: Text('Go to Dashboard'),
                  ),
                ],
              ),
            ),
          );
        };
        return child!;
      },
    );
  }
}
```

## 🐛 Common Issues & Fixes

### Issue 1: Deep Link Navigation Conflicts

**Symptoms:**
- App crashes when opening deep links
- Navigation state becomes corrupted
- Multiple navigation attempts

**Fix:**
```dart
void _handleDeepLink(String link) {
  try {
    debugPrint('🔗 Handling deep link: $link');
    
    // Add delay to ensure app is fully initialized
    Future.delayed(Duration(milliseconds: 500), () {
      if (link.contains('newport://invite/')) {
        final uri = Uri.parse(link);
        final inviteId = uri.pathSegments.last;
        
        if (inviteId.isNotEmpty) {
          // Use Go Router for navigation
          final context = _rootNavigatorKey.currentContext;
          if (context != null) {
            context.go('/invite/$inviteId');
          } else {
            _savePendingInvite(inviteId);
          }
        }
      }
    });
  } catch (e) {
    debugPrint('❌ Error handling deep link: $e');
  }
}
```

### Issue 2: Authentication Redirect Loops

**Symptoms:**
- Infinite redirects between auth screens
- App stuck in loading state
- Navigation not responding

**Fix:**
```dart
redirect: (context, state) {
  final authService = GetIt.instance<AuthService>();
  final isAuthenticated = authService.isAuthenticated;
  final isOnAuthFlow = ['/splash', '/auth', '/apartments', '/family-request', '/phone-registration', '/invite'].contains(state.uri.path);
  
  debugPrint('🔐 Auth redirect check:');
  debugPrint('  - Is authenticated: $isAuthenticated');
  debugPrint('  - Current path: ${state.uri.path}');
  debugPrint('  - Is auth flow: $isOnAuthFlow');
  
  // Add protection against redirect loops
  if (!isAuthenticated && !isOnAuthFlow) {
    debugPrint('  → Redirecting to splash');
    return '/splash';
  }
  
  if (isAuthenticated && isOnAuthFlow && state.uri.path != '/apartments') {
    debugPrint('  → Redirecting to dashboard');
    return '/dashboard';
  }
  
  debugPrint('  → No redirect needed');
  return null;
},
```

### Issue 3: Bottom Navigation State Sync

**Symptoms:**
- Bottom nav not highlighting correct tab
- Navigation state out of sync
- Incorrect active state

**Fix:**
```dart
Widget _buildNavItem(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String path,
  required bool isActive,
}) {
  // Add debug logging
  debugPrint('🏷️ Building nav item: $label, active: $isActive, path: $path');
  
  return GestureDetector(
    onTap: () {
      debugPrint('👆 Nav item tapped: $path');
      context.go(path);
    },
    child: Container(
      // ... existing code
    ),
  );
}
```

## 🧪 Testing Navigation

### 1. Navigation Flow Test

```dart
void testNavigationFlow() {
  debugPrint('🧪 Testing navigation flow...');
  
  // Test basic navigation
  context.go('/dashboard');
  context.go('/news');
  context.go('/services');
  context.go('/profile');
  
  // Test nested navigation
  context.go('/news/123');
  context.go('/services/new-request?type=cleaning');
  context.go('/profile/payment');
  
  // Test back navigation
  context.pop();
  context.pop();
  
  debugPrint('✅ Navigation flow test completed');
}
```

### 2. Deep Link Test

```dart
void testDeepLinks() {
  debugPrint('🧪 Testing deep links...');
  
  // Test invite link
  _handleDeepLink('newport://invite/abc123');
  
  // Test invalid link
  _handleDeepLink('invalid://link');
  
  debugPrint('✅ Deep link test completed');
}
```

### 3. Authentication Flow Test

```dart
void testAuthFlow() {
  debugPrint('🧪 Testing auth flow...');
  
  // Test unauthenticated user
  final authService = GetIt.instance<AuthService>();
  authService.signOut();
  
  // Try to access protected route
  context.go('/dashboard'); // Should redirect to /splash
  
  // Test authenticated user
  authService.signInAnonymously();
  
  // Try to access auth route
  context.go('/auth'); // Should redirect to /dashboard
  
  debugPrint('✅ Auth flow test completed');
}
```

## 📊 Navigation Monitoring

### 1. Performance Monitoring

```dart
class NavigationPerformanceMonitor {
  static final Map<String, DateTime> _startTimes = {};
  
  static void startNavigation(String route) {
    _startTimes[route] = DateTime.now();
    debugPrint('⏱️ Navigation started: $route');
  }
  
  static void endNavigation(String route) {
    final startTime = _startTimes[route];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      debugPrint('⏱️ Navigation completed: $route in ${duration.inMilliseconds}ms');
      _startTimes.remove(route);
    }
  }
}
```

### 2. Error Tracking

```dart
class NavigationErrorTracker {
  static final List<String> _errors = [];
  
  static void logError(String error, [StackTrace? stackTrace]) {
    final errorInfo = '${DateTime.now()}: $error';
    _errors.add(errorInfo);
    debugPrint('❌ Navigation error: $error');
    if (stackTrace != null) {
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }
  
  static List<String> get errors => List.unmodifiable(_errors);
  
  static void clear() {
    _errors.clear();
  }
}
```

## 🚀 Quick Fixes

### 1. Reset Navigation State

```dart
void resetNavigationState() {
  debugPrint('🔄 Resetting navigation state...');
  
  // Clear route history
  RouteHistoryTracker.clear();
  
  // Clear navigation errors
  NavigationErrorTracker.clear();
  
  // Go to dashboard
  context.go('/dashboard');
  
  debugPrint('✅ Navigation state reset');
}
```

### 2. Force Navigation

```dart
void forceNavigate(String route) {
  debugPrint('🚀 Force navigating to: $route');
  
  try {
    context.go(route);
  } catch (e) {
    debugPrint('❌ Force navigation failed: $e');
    // Fallback to dashboard
    context.go('/dashboard');
  }
}
```

### 3. Debug Navigation Stack

```dart
void debugNavigationStack() {
  debugPrint('📚 Current navigation stack:');
  debugPrint('  - Can pop: ${context.canPop()}');
  debugPrint('  - Current location: ${GoRouterState.of(context).uri}');
  debugPrint('  - Route history: ${RouteHistoryTracker.history}');
  debugPrint('  - Recent errors: ${NavigationErrorTracker.errors.take(5).toList()}');
}
```

## 🎯 Best Practices

1. **Always use Go Router methods** (`context.go()`, `context.pop()`) instead of Navigator
2. **Check navigation state** before performing actions
3. **Add error handling** to all navigation operations
4. **Use debug logging** to track navigation flow
5. **Test deep links** thoroughly
6. **Monitor navigation performance**
7. **Handle edge cases** (no internet, app state changes)
8. **Keep navigation logic centralized** in AppRouter

## 🔍 Debugging Checklist

- [ ] Check if `debugLogDiagnostics: true` is enabled
- [ ] Verify all navigation uses Go Router methods
- [ ] Test deep link handling
- [ ] Check authentication redirect logic
- [ ] Verify bottom navigation state sync
- [ ] Test back navigation from all screens
- [ ] Check for navigation loops
- [ ] Verify error handling
- [ ] Test navigation performance
- [ ] Check for memory leaks in navigation

This debugging guide should help you identify and fix any navigation issues in your Flutter app! 🚀 
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigation debugging utility for identifying and fixing navigation issues
class NavigationDebugger {
  static final List<String> _routeHistory = [];
  static final List<String> _errors = [];
  static final Map<String, DateTime> _navigationStartTimes = {};
  static bool _isDebugMode = false;

  /// Enable/disable debug mode
  static void setDebugMode(bool enabled) {
    _isDebugMode = enabled;
    debugPrint('🔧 Navigation debug mode: ${enabled ? "ON" : "OFF"}');
  }

  /// Get current debug mode status
  static bool get isDebugMode => _isDebugMode;

  /// Log navigation start
  static void logNavigationStart(String route) {
    if (!_isDebugMode) return;
    
    _navigationStartTimes[route] = DateTime.now();
    _routeHistory.add(route);
    
    debugPrint('🚀 Navigation started: $route');
    debugPrint('📚 Route history: ${_routeHistory.join(' → ')}');
  }

  /// Log navigation end
  static void logNavigationEnd(String route) {
    if (!_isDebugMode) return;
    
    final startTime = _navigationStartTimes[route];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ Navigation completed: $route in ${duration.inMilliseconds}ms');
      _navigationStartTimes.remove(route);
    }
  }

  /// Log navigation error
  static void logError(String error, [StackTrace? stackTrace]) {
    final errorInfo = '${DateTime.now()}: $error';
    _errors.add(errorInfo);
    
    debugPrint('❌ Navigation error: $error');
    if (stackTrace != null) {
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }

  /// Get current navigation state
  static Map<String, dynamic> getNavigationState(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final canPop = context.canPop();
    
    return {
      'currentLocation': location,
      'canPop': canPop,
      'routeHistory': List.unmodifiable(_routeHistory),
      'recentErrors': _errors.take(5).toList(),
      'activeNavigations': _navigationStartTimes.keys.toList(),
    };
  }

  /// Clear navigation history
  static void clearHistory() {
    _routeHistory.clear();
    _errors.clear();
    _navigationStartTimes.clear();
    debugPrint('🧹 Navigation history cleared');
  }

  /// Get route history
  static List<String> get routeHistory => List.unmodifiable(_routeHistory);

  /// Get recent errors
  static List<String> get recentErrors => List.unmodifiable(_errors);

  /// Check if navigation is in progress
  static bool get isNavigating => _navigationStartTimes.isNotEmpty;
}

/// Widget to display navigation debug information
class NavigationDebugWidget extends StatefulWidget {
  final bool showDebugInfo;

  const NavigationDebugWidget({
    super.key,
    this.showDebugInfo = false,
  });

  @override
  State<NavigationDebugWidget> createState() => _NavigationDebugWidgetState();
}

class _NavigationDebugWidgetState extends State<NavigationDebugWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.showDebugInfo) return const SizedBox.shrink();

    final navigationState = NavigationDebugger.getNavigationState(context);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Navigation Debug',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            
            // Expanded content
            if (_isExpanded) ...[
              Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDebugItem('Location', navigationState['currentLocation']),
                    _buildDebugItem('Can Pop', navigationState['canPop'].toString()),
                    _buildDebugItem('Is Navigating', NavigationDebugger.isNavigating.toString()),
                    _buildDebugItem('History', navigationState['routeHistory'].join(' → ')),
                    if (navigationState['recentErrors'].isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Recent Errors:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      ...navigationState['recentErrors'].map((error) => Text(
                        '• $error',
                        style: const TextStyle(color: Colors.white, fontSize: 8),
                      )),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => NavigationDebugger.clearHistory(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            child: const Text('Clear', style: TextStyle(fontSize: 10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => context.go('/dashboard'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            child: const Text('Dashboard', style: TextStyle(fontSize: 10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDebugItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Extension for easier navigation debugging
extension NavigationDebugExtension on BuildContext {
  /// Safe navigation with error handling
  void safeGo(String route) {
    try {
      NavigationDebugger.logNavigationStart(route);
      go(route);
      NavigationDebugger.logNavigationEnd(route);
    } catch (e, stackTrace) {
      NavigationDebugger.logError('Failed to navigate to $route: $e', stackTrace);
      // Fallback to dashboard
      go('/dashboard');
    }
  }

  /// Safe pop with error handling
  void safePop() {
    try {
      if (canPop()) {
        NavigationDebugger.logNavigationStart('pop');
        pop();
        NavigationDebugger.logNavigationEnd('pop');
      } else {
        NavigationDebugger.logError('Cannot pop - no previous route');
        go('/dashboard');
      }
    } catch (e, stackTrace) {
      NavigationDebugger.logError('Failed to pop: $e', stackTrace);
      go('/dashboard');
    }
  }

  /// Get navigation debug info
  Map<String, dynamic> get navigationDebugInfo => 
      NavigationDebugger.getNavigationState(this);

  /// Reset navigation state
  void resetNavigation() {
    NavigationDebugger.clearHistory();
    go('/dashboard');
  }
}

/// Mixin for adding navigation debugging to widgets
mixin NavigationDebugMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    NavigationDebugger.logNavigationStart('${widget.runtimeType}');
  }

  @override
  void dispose() {
    NavigationDebugger.logNavigationEnd('${widget.runtimeType}');
    super.dispose();
  }

  /// Add debug widget to screen
  Widget addNavigationDebug(Widget child, {bool showDebugInfo = false}) {
    return Stack(
      children: [
        child,
        NavigationDebugWidget(showDebugInfo: showDebugInfo),
      ],
    );
  }
}

/// Navigation error boundary widget
class NavigationErrorBoundary extends StatelessWidget {
  final Widget child;
  final Widget Function(BuildContext, Object, StackTrace)? errorBuilder;

  const NavigationErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // Set up global error handler
    ErrorWidget.builder = (FlutterErrorDetails details) {
      NavigationDebugger.logError(
        'Navigation error: ${details.exception}',
        details.stack,
      );

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
                  
                  const Text(
                    'Navigation Error',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    '${details.exception}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  ElevatedButton(
                    onPressed: () {
                      // Error widget can't navigate, but kept for UI consistency
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0050A3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Error Occurred'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    // Return the actual widget that wraps the child with error handling
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (error, stackTrace) {
          NavigationDebugger.logError('Widget build error: $error', stackTrace);
          
          if (errorBuilder != null) {
            return errorBuilder!(context, error, stackTrace);
          }
          
          return Scaffold(
            backgroundColor: const Color(0xFF0A0A0A),
            body: Center(
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
                  const SizedBox(height: 24),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
} 
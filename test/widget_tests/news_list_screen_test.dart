import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:newport_resident/core/models/news_article_model.dart';
import 'package:newport_resident/presentation/news_screen/news_list_screen.dart';
import 'package:newport_resident/core/app_export.dart';

// Generate mocks
@GenerateMocks([NewsService])
import 'news_list_screen_test.mocks.dart';

void main() {
  group('NewsListScreen Widget Tests', () {
    late MockNewsService mockNewsService;
    final getIt = GetIt.instance;

    setUp(() {
      mockNewsService = MockNewsService();
      
      // Clear GetIt and register mock
      if (getIt.isRegistered<NewsService>()) {
        getIt.unregister<NewsService>();
      }
      getIt.registerSingleton<NewsService>(mockNewsService);
    });

    tearDown(() {
      getIt.reset();
    });

    Widget createTestWidget() {
      return Sizer(
        builder: (context, orientation, deviceType) {
          return MaterialApp(
            home: const NewsListScreen(),
            theme: AppTheme.lightTheme,
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.newsDetailScreen) {
                return MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Detail')),
                    body: const Text('Detail Screen'),
                  ),
                  settings: settings,
                );
              }
              return null;
            },
          );
        },
      );
    }

    testWidgets('should show loading indicator initially', (WidgetTester tester) async {
      // Arrange
      when(mockNewsService.fetchLatestNews())
          .thenAnswer((_) => Future.delayed(const Duration(milliseconds: 100), () => []));

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display news list when data is loaded', (WidgetTester tester) async {
      // Arrange
      final mockNews = [
        NewsArticle(
          id: '1',
          title: 'Test News 1',
          preview: 'Preview 1',
          content: 'Content 1',
          publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
          isImportant: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        NewsArticle(
          id: '2',
          title: 'Test News 2',
          preview: 'Preview 2',
          content: 'Content 2',
          publishedAt: DateTime.now().subtract(const Duration(days: 1)),
          isImportant: false,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];

      when(mockNewsService.fetchLatestNews())
          .thenAnswer((_) async => mockNews);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Test News 1'), findsOneWidget);
      expect(find.text('Test News 2'), findsOneWidget);
      expect(find.text('Preview 1'), findsOneWidget);
      expect(find.text('Preview 2'), findsOneWidget);
    });

    testWidgets('should show important badge for important news', (WidgetTester tester) async {
      // Arrange
      final mockNews = [
        NewsArticle(
          id: '1',
          title: 'Important News',
          preview: 'Important preview',
          content: 'Important content',
          publishedAt: DateTime.now(),
          isImportant: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(mockNewsService.fetchLatestNews())
          .thenAnswer((_) async => mockNews);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Важно'), findsOneWidget);
    });

    testWidgets('should show empty state when no news available', (WidgetTester tester) async {
      // Arrange
      when(mockNewsService.fetchLatestNews())
          .thenAnswer((_) async => []);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Пока нет новостей'), findsOneWidget);
    });

    testWidgets('should show error widget when fetch fails', (WidgetTester tester) async {
      // Arrange
      // First call succeeds to avoid initState crash, second call fails
      when(mockNewsService.fetchLatestNews())
          .thenAnswer((_) async => []);
      when(mockNewsService.fetchLatestNews(forceRefresh: true))
          .thenThrow(Exception('Network error'));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Trigger refresh which will fail
      await tester.fling(find.byType(RefreshIndicator), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Не удалось загрузить новости'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets('should refresh news when pull to refresh is triggered', (WidgetTester tester) async {
      // Arrange
      final mockNews = [
        NewsArticle(
          id: '1',
          title: 'Test News',
          preview: 'Preview',
          content: 'Content',
          publishedAt: DateTime.now(),
          isImportant: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(mockNewsService.fetchLatestNews())
          .thenAnswer((_) async => mockNews);
      when(mockNewsService.fetchLatestNews(forceRefresh: true))
          .thenAnswer((_) async => mockNews);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Trigger pull to refresh
      await tester.fling(find.byType(RefreshIndicator), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      // Assert
      verify(mockNewsService.fetchLatestNews(forceRefresh: true)).called(1);
    });

    testWidgets('should navigate to detail screen when news item is tapped', (WidgetTester tester) async {
      // Arrange
      final mockNews = [
        NewsArticle(
          id: '1',
          title: 'Test News',
          preview: 'Preview',
          content: 'Content',
          publishedAt: DateTime.now(),
          isImportant: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(mockNewsService.fetchLatestNews())
          .thenAnswer((_) async => mockNews);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on news item
      await tester.tap(find.text('Test News'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Detail Screen'), findsOneWidget);
    });
  });
} 
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:newport_resident/core/services/auth_service.dart';
import 'package:newport_resident/core/services/api_service.dart';
import 'package:newport_resident/core/services/cache_service.dart';
import 'package:newport_resident/core/services/encryption_service.dart';
import 'package:newport_resident/core/services/logging_service_secure.dart';

import 'auth_service_test.mocks.dart';

@GenerateMocks([
  ApiService,
  CacheService,
  EncryptionService,
  SharedPreferences,
  LoggingService,
])
void main() {
  late AuthService authService;
  late MockApiService mockApiService;
  late MockCacheService mockCacheService;
  late MockEncryptionService mockEncryptionService;
  late MockLoggingService mockLoggingService;

  setUp(() {
    mockApiService = MockApiService();
    mockCacheService = MockCacheService();
    mockEncryptionService = MockEncryptionService();
    mockLoggingService = MockLoggingService();

    authService = AuthService(
      apiService: mockApiService,
      cacheService: mockCacheService,
      encryptionService: mockEncryptionService,
      loggingService: mockLoggingService,
    );
  });

  group('AuthService', () {
    const testApartment = '101';
    const testPhone = '1234567890';
    const testVerificationCode = '123456';

    test('verifyResident success', () async {
      // Arrange
      when(mockApiService.post(
        '/auth/verify',
        data: {
          'apartmentNumber': testApartment,
          'phoneNumber': testPhone,
          'verificationCode': testVerificationCode,
        },
      )).thenAnswer((_) async => {
        'success': true,
        'data': {
          'token': 'test_token',
          'user': {
            'name': 'Test User',
            'apartment': testApartment,
            'phone': testPhone,
          },
        },
      });

      when(mockCacheService.write(any, any)).thenAnswer((_) async {});

      // Act
      final result = await authService.verifyResident(
        apartmentNumber: testApartment,
        phoneNumber: testPhone,
        verificationCode: testVerificationCode,
      );

      // Assert
      expect(result, true);
      verify(mockCacheService.write('token', any)).called(1);
      verify(mockCacheService.write('userData', any)).called(1);
    });

    test('verifyResident failure', () async {
      // Arrange
      when(mockApiService.post(
        '/auth/verify',
        data: {
          'apartmentNumber': testApartment,
          'phoneNumber': testPhone,
          'verificationCode': testVerificationCode,
        },
      )).thenThrow(Exception('Invalid credentials'));

      // Act
      final result = await authService.verifyResident(
        apartmentNumber: testApartment,
        phoneNumber: testPhone,
        verificationCode: testVerificationCode,
      );

      // Assert
      expect(result, false);
      verify(mockLoggingService.error('Error in verifyResident', any)).called(1);
      verifyNever(mockCacheService.write(any, any));
    });

    test('checkAuthStatus returns cached data', () async {
      // Arrange
      when(mockCacheService.read('token'))
          .thenAnswer((_) async => 'encrypted_token');
      when(mockCacheService.read('refreshToken'))
          .thenAnswer((_) async => 'encrypted_refresh_token');
      when(mockCacheService.read('userData'))
          .thenAnswer((_) async => {'name': 'Test User'});
      when(mockEncryptionService.decrypt('encrypted_token'))
          .thenReturn('decrypted_token');
      when(mockEncryptionService.decrypt('encrypted_refresh_token'))
          .thenReturn('decrypted_refresh_token');

      // Act
      final result = await authService.checkAuthStatus();

      // Assert
      expect(result, true);
      expect(authService.isAuthenticated, true);
      verify(mockCacheService.read('token')).called(1);
      verify(mockCacheService.read('refreshToken')).called(1);
      verify(mockCacheService.read('userData')).called(1);

    });

    test('logout clears cached data', () async {
      // Arrange
      when(mockApiService.post('/auth/logout', data: {}))
          .thenAnswer((_) async => {});
      when(mockCacheService.delete(any))
          .thenAnswer((_) async {});

      // Act
      await authService.logout();

      // Assert
      verify(mockCacheService.delete('token')).called(1);
      verify(mockCacheService.delete('refreshToken')).called(1);
      verify(mockCacheService.delete('userData')).called(1);
      expect(authService.isAuthenticated, false);
      expect(authService.token, null);
    });

    test('refreshToken success', () async {
      // Arrange
      when(mockApiService.post('/auth/refresh', data: any))
          .thenAnswer((_) async => {
                'token': 'new_token',
                'refreshToken': 'new_refresh_token',
              });
      when(mockEncryptionService.encrypt(any))
          .thenReturn('encrypted_token');
      when(mockCacheService.write(any, any))
          .thenAnswer((_) async {});

      // Set initial state
      authService.setTestState(
        token: 'old_token',
        refreshToken: 'old_refresh_token',
        isAuthenticated: true,
      );

      // Act
      await authService.refreshToken();

      // Assert
      verify(mockApiService.post('/auth/refresh', data: {
        'refreshToken': 'old_refresh_token',
      })).called(1);
      verify(mockEncryptionService.encrypt('new_token')).called(1);
      verify(mockEncryptionService.encrypt('new_refresh_token')).called(1);
      verify(mockCacheService.write('token', any)).called(1);
      verify(mockCacheService.write('refreshToken', any)).called(1);
    });

    test('refreshToken failure', () async {
      // Arrange
      when(mockApiService.post('/auth/refresh', data: any))
          .thenThrow(Exception('Invalid refresh token'));

      // Set initial state
      authService.setTestState(
        token: 'old_token',
        refreshToken: 'old_refresh_token',
        isAuthenticated: true,
      );

      // Act & Assert
      expect(
        () => authService.refreshToken(),
        throwsException,
      );

      verify(mockLoggingService.error('Token refresh failed', any)).called(1);
    });
  });
} 
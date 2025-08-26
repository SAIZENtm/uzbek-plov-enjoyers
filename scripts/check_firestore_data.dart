// ignore_for_file: avoid_print

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// Простой скрипт для проверки данных в Firestore
void main() async {
  // Инициализация Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "your-api-key",
      authDomain: "your-project.firebaseapp.com", 
      projectId: "your-project-id",
      storageBucket: "your-project.appspot.com",
      messagingSenderId: "123456789",
      appId: "1:123456789:web:abcdef",
    ),
  );

  final firestore = FirebaseFirestore.instance;

  print('🔍 Проверяем структуру базы данных...\n');

  try {
    // Получаем все блоки
    final blocksSnapshot = await firestore.collection('users').get();
    print('📁 Найдено блоков: ${blocksSnapshot.docs.length}');

    if (blocksSnapshot.docs.isEmpty) {
      print('❌ Коллекция users пустая или нет доступа');
      print('   Проверьте правила безопасности в Firebase Console');
      exit(1);
    }

    // Показываем каждый блок
    for (final blockDoc in blocksSnapshot.docs) {
      final blockId = blockDoc.id;
      print('\n🏢 Блок: $blockId');

      // Получаем квартиры в блоке
      final apartmentsSnapshot = await firestore
          .collection('users')
          .doc(blockId)
          .collection('apartments')
          .limit(5) // Показываем только первые 5 для примера
          .get();

      print('   🏠 Квартир найдено: ${apartmentsSnapshot.docs.length}');

      // Показываем примеры квартир
      for (int i = 0; i < apartmentsSnapshot.docs.length && i < 3; i++) {
        final apartmentDoc = apartmentsSnapshot.docs[i];
        final data = apartmentDoc.data();
        
        print('      📋 Квартира ${i + 1}:');
        print('         ID: ${apartmentDoc.id}');
        print('         Номер: ${data['apartment_number'] ?? 'N/A'}');
        print('         Телефон: ${data['phone'] ?? 'N/A'}');
        print('         Владелец: ${data['full_name'] ?? 'N/A'}');
        print('         Паспорт: ${data['passport_number'] ?? 'N/A'}');
      }
    }

    print('\n✅ Проверка завершена успешно');
    
  } catch (e) {
    print('❌ Ошибка при проверке данных: $e');
    exit(1);
  }
} 
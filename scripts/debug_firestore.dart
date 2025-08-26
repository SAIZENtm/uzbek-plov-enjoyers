// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// Простой скрипт для диагностики структуры Firestore
void main() async {
  print('🔍 Диагностика структуры Firestore...');
  
  // Инициализация с минимальными настройками
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "dummy-key",
      authDomain: "newport-23a19.firebaseapp.com",
      projectId: "newport-23a19",
      storageBucket: "newport-23a19.appspot.com",
      messagingSenderId: "123456789",
      appId: "1:123456789:web:abcdef",
    ),
  );

  final firestore = FirebaseFirestore.instance;

  try {
    print('\n📁 Проверяем коллекцию "users"...');
    final usersSnapshot = await firestore.collection('users').limit(10).get();
    print('Найдено документов в users: ${usersSnapshot.docs.length}');
    
    for (var doc in usersSnapshot.docs.take(3)) {
      print('\n📋 Документ: ${doc.id}');
      final data = doc.data();
      print('  apartment_number: ${data['apartment_number']}');
      print('  phone: ${data['phone']}');
      print('  full_name: ${data['full_name']}');
      print('  block_number: ${data['block_number']}');
      
      // Проверяем подколлекции
      final subcollections = ['apartments'];
      for (var subcol in subcollections) {
        try {
          final subSnapshot = await doc.reference.collection(subcol).limit(3).get();
          if (subSnapshot.docs.isNotEmpty) {
            print('  Подколлекция "$subcol": ${subSnapshot.docs.length} документов');
          }
        } catch (e) {
          // Подколлекция не существует
        }
      }
    }

    print('\n🔍 Поиск через collectionGroup("apartments")...');
    final apartmentsQuery = await firestore.collectionGroup('apartments').limit(5).get();
    print('Найдено через collectionGroup: ${apartmentsQuery.docs.length}');
    
    for (var doc in apartmentsQuery.docs.take(3)) {
      final data = doc.data();
      final blockId = doc.reference.parent.parent?.id ?? 'Unknown';
      print('  Блок: $blockId, Квартира: ${data['apartment_number']}, Телефон: ${data['phone']}');
    }

    print('\n📊 Статистика:');
    print('  - Документов в коллекции users: ${usersSnapshot.docs.length}');
    print('  - Найдено через collectionGroup apartments: ${apartmentsQuery.docs.length}');
    
    if (usersSnapshot.docs.isEmpty && apartmentsQuery.docs.isEmpty) {
      print('\n❌ База данных пустая или нет доступа!');
      print('   Рекомендации:');
      print('   1. Проверьте правила безопасности в Firebase Console');
      print('   2. Убедитесь, что данные импортированы');
    } else {
      print('\n✅ Диагностика завершена. Используйте найденные данные для входа.');
    }

  } catch (e) {
    print('❌ Ошибка подключения к Firestore: $e');
    print('   Проверьте интернет-соединение и настройки проекта');
  }
} 
// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:newport_resident/firebase_options.dart';

// Скрипт для создания тестовых данных в Firestore
void main() async {
  print('🔥 Инициализация Firebase...');
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;

  print('📝 Создание тестовой квартиры...');

  // Создаем тестовую квартиру в блоке D BLOK
  await firestore
      .collection('users')
      .doc('D BLOK')
      .collection('apartments')
      .doc('10')
      .set({
    'apartment_number': '10',
    'phone': '+998900050050',
    'full_name': 'Test User',
    'passport_number': 'AB1234567',
    'floor_name': '1 этаж',
    'net_area_m2': 65.5,
    'gross_area_m2': 70.0,
    'ownership_code': 'TEST001',
    'contract_signed': true,
    'block_name': 'D BLOK',
  });

  print('✅ Тестовая квартира создана!');
  print('📋 Данные:');
  print('   Блок: D BLOK');
  print('   Квартира: 10');
  print('   Телефон: +998900050050');
  print('   Владелец: Test User');
  
  print('\\n🔍 Проверяем созданные данные...');
  
  // Проверяем, что данные созданы
  final blocksSnapshot = await firestore.collection('users').get();
  print('Найдено блоков: ${blocksSnapshot.docs.length}');
  
  for (var blockDoc in blocksSnapshot.docs) {
    print('Блок: ${blockDoc.id}');
    final apartmentsSnapshot = await blockDoc.reference.collection('apartments').get();
    print('  Квартир: ${apartmentsSnapshot.docs.length}');
    
    for (var aptDoc in apartmentsSnapshot.docs) {
      final data = aptDoc.data();
      print('  Квартира ${aptDoc.id}: ${data['full_name']} (${data['phone']})');
    }
  }
  
  print('\\n✅ Готово! Теперь попробуйте авторизацию в приложении.');
} 
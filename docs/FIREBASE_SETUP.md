# Настройка Firebase для Newport Resident App

## Настройка правил безопасности Firestore

### Для разработки (временно):

1. Откройте [Firebase Console](https://console.firebase.google.com)
2. Выберите ваш проект
3. Перейдите в Firestore Database → Rules
4. Замените правила на следующие:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

5. Нажмите "Publish"

⚠️ **ВАЖНО**: Эти правила разрешают полный доступ всем пользователям. Используйте только для разработки!

### Для продакшена:

Используйте правила из файла `firestore.rules` в корне проекта.

## Структура базы данных

База данных должна иметь следующую структуру:

```
users/
  └── D BLOK/
      └── apartments/
          └── 01-221/
              ├── apartment_number: "01-221"
              ├── phone: "+998900050050"
              ├── full_name: "Иван Иванов"
              ├── passport_number: "AB1234567"
              └── ... другие поля
  └── E BLOK/
      └── apartments/
          └── 01-222/
              └── ... данные квартиры
```

## Тестовые данные

Для тестирования можно добавить квартиру вручную:

1. В Firebase Console перейдите в Firestore
2. Создайте коллекцию `users`
3. Создайте документ с ID `D BLOK`
4. В этом документе создайте подколлекцию `apartments`
5. Добавьте документ с ID `10` (или любой номер квартиры)
6. Добавьте поля:
   - `apartment_number`: "10"
   - `phone`: "+998900050050"
   - `full_name`: "Test User"
   - `passport_number`: "AB1234567"
   - `floor_name`: "1 этаж"
   - `net_area_m2`: 65.5
   - `gross_area_m2`: 70.0
   - `ownership_code`: "TEST001"
   - `contract_signed`: true

## Импорт данных из Excel

Если у вас есть Excel файл с данными:

1. Поместите файл `final_cleaned.xlsx` в папку `data/`
2. Запустите скрипт импорта:
   ```bash
   dart run scripts/import_data_to_firestore.dart
   ```

## Диагностика проблем

### Проблема: "Found 0 blocks in users collection"

Это означает, что приложение не может получить доступ к коллекции `users` в Firestore. Причины:

1. **Правила безопасности блокируют доступ**
   - Обновите правила в Firebase Console (см. выше)
   - Используйте файл `firestore-dev.rules` для разработки

2. **Неправильная структура базы данных**
   - Проверьте, что коллекция называется `users` (не `blocks`)
   - Убедитесь, что блоки — это документы (D BLOK, E BLOK), а не коллекции

3. **Неправильная конфигурация Firebase**
   - Проверьте файл `firebase_options.dart`
   - Убедитесь, что указан правильный project ID

### Проверка данных

Запустите скрипт проверки:
```bash
dart run scripts/check_firestore_data.dart
```

### Проверка подключения

После настройки правил безопасности:

1. Запустите приложение
2. Введите тестовые данные:
   - Квартира: 10
   - Телефон: +998900050050
3. Проверьте логи на наличие ошибок

### Создание тестовых данных вручную

Если данных нет, создайте тестовую квартиру в Firebase Console:

1. Коллекция: `users`
2. Документ: `D BLOK`
3. Подколлекция: `apartments`
4. Документ: `test-apartment`
5. Поля:
   ```
   apartment_number: "10"
   phone: "+998900050050"
   full_name: "Test User"
   passport_number: "AB1234567"
   ``` 
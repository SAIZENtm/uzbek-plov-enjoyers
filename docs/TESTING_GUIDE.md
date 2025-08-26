# 🧪 Руководство по тестированию Newport Resident

## Структура данных в Firestore

После анализа вашего импорта данных, **реальная структура** следующая:

```
users (коллекция)
├── 10 (документ - квартира 10)
│   ├── apartment_number: "10"
│   ├── phone: "+998900050050"
│   ├── full_name: "Имя владельца"
│   ├── passport_number: "AB1234567"
│   ├── block_number: "D"
│   └── ... (другие поля)
├── 11 (документ - квартира 11)
└── 12 (документ - квартира 12)
```

**НЕ** такая структура, как изначально планировалось:
```
users → D BLOK → apartments → 10
```

## Тестовые данные

Для тестирования найдите в вашей базе данных квартиру с известными данными.

### Проверка данных в Firebase Console

1. Откройте [Firebase Console](https://console.firebase.google.com)
2. Выберите проект `newport-23a19`
3. Firestore Database → Data
4. Откройте коллекцию `users`
5. Найдите любой документ (квартиру)
6. Запомните поля:
   - `apartment_number`
   - `phone`
   - `block_number`

### Тестирование приложения

1. **Запустите приложение**
   ```bash
   flutter run
   ```

2. **Введите данные из Firebase Console**:
   - Квартира: [apartment_number из Firebase]
   - Телефон: [phone из Firebase]

3. **Ожидаемый результат**:
   - Логи покажут: "Found X apartments in users collection" (где X > 0)
   - Логи покажут: "Found matching apartment!"
   - Переход к экрану с информацией о пользователе

### Пример тестовых данных

Если в вашей базе есть квартира с данными:
```json
{
  "apartment_number": "225",
  "phone": "+998901234567",
  "block_number": "D",
  "full_name": "Иван Иванов"
}
```

То тестируйте с:
- Квартира: **225**
- Телефон: **+998901234567**

## Отладка

### Логи показывают "Found 0 apartments"
- Проблема с правилами безопасности Firestore
- Обновите правила в Firebase Console (см. `firestore-dev.rules`)

### Логи показывают "No matching apartment found"
- Проверьте правильность введенных данных
- Убедитесь, что данные точно совпадают с Firebase Console
- Проверьте формат телефона (с + или без)

### Логи показывают найденные квартиры, но не находит совпадение
- Сравните данные в логах с введенными данными
- Возможно, различия в форматировании (пробелы, регистр)

## Структура логов

При успешном поиске вы увидите:
```
💡 Searching for apartment: 225 with phone: +998901234567
💡 Normalized phone: +998901234567
💡 Found 150 apartments in users collection
💡 Checking apartment: 225 (block: D), phone: +998901234567
💡 Found matching apartment!
```

При неуспешном поиске:
```
💡 Found 150 apartments in users collection
💡 Checking apartment: 226 (block: D), phone: +998901111111
💡 Checking apartment: 227 (block: E), phone: +998902222222
...
💡 No matching apartment found
``` 
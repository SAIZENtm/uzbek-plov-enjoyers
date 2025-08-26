# Настройка и запуск тестов Firestore Security Rules

## Установка зависимостей

```bash
# Установка Firebase CLI глобально
npm install -g firebase-tools

# Установка зависимостей для тестов
npm install --save-dev @firebase/rules-unit-testing firebase-admin
```

## Настройка Firebase Emulator

1. Инициализация эмулятора:
```bash
firebase init emulators
# Выберите Firestore emulator
# Порт по умолчанию: 8080
```

2. Запуск эмулятора:
```bash
firebase emulators:start --only firestore
```

## Запуск тестов

В отдельном терминале:
```bash
npm test firestore-rules.test.js
```

## Проверка правил перед деплоем

1. Всегда запускайте тесты перед деплоем правил
2. Используйте разные файлы для разных окружений:
   - `firestore-dev.rules` - для разработки (НЕ ДЕПЛОИТЬ В PROD!)
   - `firestore-secure.rules` - для production
   - `firestore-test.rules` - для тестирования

3. Деплой правил:
```bash
# Для production
firebase deploy --only firestore:rules --project production-project-id

# Убедитесь, что используете правильный файл в firebase.json:
{
  "firestore": {
    "rules": "firestore-secure.rules"
  }
}
```

## CI/CD интеграция

Добавьте в ваш CI pipeline:

```yaml
# .github/workflows/security-rules-test.yml
name: Test Firestore Rules
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
      - run: npm ci
      - run: npm install -g firebase-tools
      - run: firebase emulators:exec --only firestore "npm test firestore-rules.test.js"
```

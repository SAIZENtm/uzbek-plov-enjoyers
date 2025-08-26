# 🚀 Быстрый старт для друзей

## 📱 Что нужно установить

### 1. Flutter SDK
```bash
# macOS (через Homebrew)
brew install flutter

# Или скачать с официального сайта:
# https://flutter.dev/docs/get-started/install
```

### 2. Cursor IDE
```bash
# Скачать с официального сайта:
# https://cursor.sh/
```

### 3. Git
```bash
# macOS
brew install git

# Настройка Git (замените на свои данные)
git config --global user.name "Ваше Имя"
git config --global user.email "ваш@email.com"
```

## 🔧 Настройка проекта

### 1. Клонирование
```bash
# Клонируйте репозиторий (ссылку даст владелец проекта)
git clone https://github.com/USERNAME/newport-resident.git
cd newport-resident
```

### 2. Установка зависимостей
```bash
# Установка Flutter пакетов
flutter pub get

# Проверка что все работает
flutter doctor
```

### 3. Firebase настройка
**ВАЖНО:** Попросите у владельца проекта файлы:
- `google-services.json` → поместить в `android/app/`
- `GoogleService-Info.plist` → поместить в `ios/Runner/`

## 🎯 Создание первой задачи

### 1. Создайте новую ветку
```bash
# Обновите main ветку
git checkout main
git pull origin main

# Создайте ветку для своей задачи
git checkout -b feature/ваше-имя-первая-задача
```

### 2. Внесите изменения
- Откройте проект в Cursor
- Сделайте небольшие изменения (например, измените текст на каком-то экране)
- Сохраните файлы

### 3. Зафиксируйте изменения
```bash
# Добавьте файлы
git add .

# Сделайте коммит
git commit -m "feat: мои первые изменения в проекте"

# Отправьте на GitHub
git push origin feature/ваше-имя-первая-задача
```

### 4. Создайте Pull Request
- Зайдите на GitHub
- Нажмите "Compare & pull request"
- Опишите что изменили
- Назначьте ревьюера

## 📱 Запуск приложения

### Android
```bash
# Запустить Android эмулятор в Android Studio
# Затем в терминале:
flutter run -d android
```

### iOS (только на macOS)
```bash
# Открыть iOS симулятор
open -a Simulator

# Запустить приложение
flutter run -d ios
```

## 🆘 Если что-то не работает

### Проблемы с Flutter
```bash
# Очистка кэша
flutter clean
flutter pub get

# Проверка проблем
flutter doctor -v
```

### Проблемы с Git
```bash
# Если забыли на какой ветке
git branch

# Если нужно отменить изменения
git checkout .

# Если нужно переключиться на main
git checkout main
```

### Проблемы с Gradle (Android)
```bash
# Если ошибки сборки Android
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

## 💬 Связь с командой

- **Вопросы по коду** → GitHub Issues
- **Срочные вопросы** → Telegram группа  
- **Обсуждение задач** → Pull Request комментарии

## 🎯 Полезные ссылки

- [Flutter документация](https://flutter.dev/docs)
- [Dart язык](https://dart.dev/guides)
- [Firebase документация](https://firebase.google.com/docs)
- [Git шпаргалка](https://education.github.com/git-cheat-sheet-education.pdf)

---

**Добро пожаловать в команду! 🎉**

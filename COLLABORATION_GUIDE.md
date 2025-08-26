# 🤝 Руководство по совместной работе над Newport Resident

## 📋 Быстрый старт для команды

### 🚀 Первоначальная настройка

#### 1. Клонирование проекта
```bash
# После создания GitHub репозитория, каждый разработчик выполняет:
git clone https://github.com/ВАШ_USERNAME/newport-resident.git
cd newport-resident

# Установка зависимостей Flutter
flutter pub get

# Проверка, что все работает
flutter doctor
```

#### 2. Настройка Firebase (ВАЖНО!)
Каждый разработчик должен:
- Получить файлы `google-services.json` и `GoogleService-Info.plist` от владельца проекта
- Поместить `google-services.json` в `android/app/`
- Поместить `GoogleService-Info.plist` в `ios/Runner/`
- **НЕ коммитить эти файлы в Git** (они уже в .gitignore)

#### 3. Настройка Cursor для совместной работы
- Установить Cursor IDE
- Включить Git интеграцию в настройках
- Настроить автосохранение и автоформатирование

## 🔄 Рабочий процесс (Git Flow)

### 📝 Структура веток
```
main (основная ветка)
├── develop (ветка разработки)
├── feature/умный-дом-улучшения
├── feature/система-уведомлений
├── feature/новый-дизайн-профиля
└── hotfix/исправление-критической-ошибки
```

### 🎯 Правила работы с ветками

#### Создание новой функции:
```bash
# 1. Переключиться на develop и обновить
git checkout develop
git pull origin develop

# 2. Создать новую ветку для функции
git checkout -b feature/название-функции

# 3. Работать над функцией, делать коммиты
git add .
git commit -m "feat: добавлена функция X"

# 4. Отправить ветку на GitHub
git push origin feature/название-функции

# 5. Создать Pull Request через GitHub
```

#### Исправление багов:
```bash
# Для критических багов
git checkout main
git checkout -b hotfix/описание-бага
# ... исправления ...
git push origin hotfix/описание-бага
```

### 📝 Соглашения о коммитах

Используем [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Новая функция
git commit -m "feat: добавлена система push-уведомлений"

# Исправление бага
git commit -m "fix: исправлена ошибка входа в приложение"

# Улучшение производительности
git commit -m "perf: оптимизирована загрузка изображений"

# Рефакторинг
git commit -m "refactor: переписан сервис аутентификации"

# Документация
git commit -m "docs: обновлено руководство по API"

# Стили/форматирование
git commit -m "style: исправлено форматирование кода"

# Тесты
git commit -m "test: добавлены тесты для AuthService"
```

## 👥 Распределение задач

### 🎨 Разработчик 1 - UI/UX и Frontend
**Зоны ответственности:**
- `lib/presentation/` - все экраны и виджеты
- `lib/theme/` - темы и стили
- `lib/widgets/` - переиспользуемые компоненты
- `assets/` - изображения, шрифты, иконки

**Типичные задачи:**
- Создание новых экранов
- Улучшение дизайна существующих экранов
- Анимации и переходы
- Адаптивность под разные экраны

### ⚙️ Разработчик 2 - Backend и Сервисы
**Зоны ответственности:**
- `lib/core/services/` - бизнес-логика
- `lib/core/models/` - модели данных
- `functions/` - Firebase Cloud Functions
- `firestore.rules` - правила безопасности

**Типичные задачи:**
- Интеграция с Firebase
- Создание новых API
- Оптимизация производительности
- Безопасность данных

### 🏠 Разработчик 3 - IoT и Умный дом
**Зоны ответственности:**
- `lib/presentation/smart_home_screen/` - экраны умного дома
- `lib/core/services/smart_home_service.dart` - логика IoT
- `arduino_newport_iot.ino` - код для устройств
- Интеграция с реальными устройствами

**Типичные задачи:**
- Добавление новых типов устройств
- Улучшение протоколов связи
- Тестирование с реальным железом
- Автоматизация и сценарии

## 🔧 Настройка среды разработки

### 📱 Flutter настройки
```bash
# Проверка окружения
flutter doctor -v

# Настройка для iOS (только на macOS)
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

# Настройка Android
flutter config --android-studio-dir="/Applications/Android Studio.app/Contents"
```

### 🔥 Firebase настройки
```bash
# Установка Firebase CLI
npm install -g firebase-tools

# Логин в Firebase
firebase login

# Инициализация проекта (только один раз)
firebase init

# Деплой функций (при изменениях в functions/)
firebase deploy --only functions
```

## 🚦 Процесс Code Review

### ✅ Чек-лист для Pull Request
- [ ] Код соответствует стилю проекта
- [ ] Добавлены необходимые тесты
- [ ] Документация обновлена
- [ ] Нет конфликтов с main веткой
- [ ] Приложение собирается без ошибок
- [ ] Проверена работа на Android и iOS

### 👀 Кто что ревьюит
- **UI изменения** → ревьюит дизайнер + backend разработчик
- **Backend изменения** → ревьюит frontend + IoT разработчик  
- **IoT изменения** → ревьюит backend + frontend разработчик

## 🐛 Решение конфликтов

### Если возник конфликт при merge:
```bash
# 1. Обновить main ветку
git checkout main
git pull origin main

# 2. Переключиться на свою ветку
git checkout feature/ваша-ветка

# 3. Сделать rebase
git rebase main

# 4. Решить конфликты в файлах
# 5. Продолжить rebase
git add .
git rebase --continue

# 6. Отправить изменения
git push origin feature/ваша-ветка --force-with-lease
```

## 📱 Тестирование

### 🧪 Локальное тестирование
```bash
# Запуск тестов
flutter test

# Запуск на эмуляторе Android
flutter run -d android

# Запуск на симуляторе iOS
flutter run -d ios

# Сборка для продакшена
flutter build apk --release
flutter build ios --release
```

### 🔥 Firebase тестирование
```bash
# Запуск Firebase эмуляторов
firebase emulators:start

# Тестирование Cloud Functions
cd functions
npm test
```

## 📞 Коммуникация

### 💬 Каналы связи
- **Срочные вопросы** → Telegram группа
- **Обсуждение задач** → GitHub Issues
- **Code Review** → GitHub Pull Requests
- **Документация** → README файлы в проекте

### 📅 Встречи команды
- **Ежедневные стендапы** → 10:00 (15 минут)
- **Планирование спринта** → Понедельник 14:00
- **Ретроспектива** → Пятница 16:00

## 🚨 Экстренные ситуации

### 🔥 Если что-то сломалось в main:
1. Создать hotfix ветку от main
2. Исправить проблему
3. Сделать экстренный PR с пометкой [HOTFIX]
4. После мерджа - обновить develop ветку

### 💾 Бэкапы
- Firebase автоматически создает бэкапы
- Код всегда в GitHub
- Локальные копии у каждого разработчика

## 🎯 Полезные команды

```bash
# Посмотреть статус
git status

# Посмотреть историю коммитов
git log --oneline --graph

# Отменить последний коммит (если не запушен)
git reset --soft HEAD~1

# Посмотреть изменения
git diff

# Временно сохранить изменения
git stash
git stash pop

# Обновить все ветки
git fetch --all

# Удалить локальную ветку
git branch -d feature/название-ветки

# Удалить удаленную ветку
git push origin --delete feature/название-ветки
```

## 🏆 Лучшие практики

### ✨ Качество кода
- Используйте осмысленные имена переменных и функций
- Пишите комментарии для сложной логики
- Следуйте принципам SOLID
- Делайте маленькие, атомарные коммиты

### 🔒 Безопасность
- Никогда не коммитьте API ключи
- Используйте .env файлы для секретов
- Регулярно обновляйте зависимости
- Тестируйте на разных устройствах

### 📈 Производительность
- Оптимизируйте изображения перед добавлением
- Используйте lazy loading для списков
- Минимизируйте количество rebuild'ов виджетов
- Профилируйте приложение регулярно

---

## 🎉 Готово к работе!

После выполнения всех шагов выше, ваша команда готова к эффективной совместной разработке Newport Resident приложения!

**Удачи в разработке! 🚀**

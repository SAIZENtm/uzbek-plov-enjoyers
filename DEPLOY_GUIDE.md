# 🚀 Руководство по деплою системы приглашений

## Файлы для деплоя

### Основной файл
- `deploy.html` - Полная система приглашений в одном файле
- `index.html` - Главная страница с навигацией

### Дополнительные файлы (опционально)
- `universal_link_handler.html` - Обработчик универсальных ссылок
- `invite_web.html` - Веб-форма приглашений
- `test_invite_system.html` - Система тестирования

## 🎯 Варианты хостинга

### 1. GitHub Pages (Рекомендуется)

#### Быстрый деплой:
1. Создайте новый репозиторий на GitHub
2. Загрузите файл `deploy.html`
3. Переименуйте его в `index.html`
4. Перейдите в Settings → Pages
5. Выберите Source: "Deploy from a branch"
6. Выберите ветку: `main`
7. Сохраните настройки

#### Ваша ссылка будет:
```
https://ваш-username.github.io/название-репозитория/
```

#### Для приглашений:
```
https://ваш-username.github.io/название-репозитория/?invite=ABC123
```

### 2. Netlify

#### Деплой через Drag & Drop:
1. Перейдите на [netlify.com](https://netlify.com)
2. Зарегистрируйтесь (можно через GitHub)
3. Перетащите файл `deploy.html` в область "Deploy"
4. Переименуйте файл в `index.html` после загрузки
5. Получите ссылку вида: `https://random-name.netlify.app`

#### Кастомный домен:
- В настройках сайта можете изменить поддомен
- Или подключить свой домен

### 3. Vercel

#### Деплой:
1. Перейдите на [vercel.com](https://vercel.com)
2. Зарегистрируйтесь через GitHub
3. Создайте новый проект
4. Загрузите файл `deploy.html` как `index.html`
5. Получите ссылку вида: `https://project-name.vercel.app`

### 4. Firebase Hosting

#### Настройка:
```bash
npm install -g firebase-tools
firebase login
firebase init hosting
# Выберите ваш проект newport-23a19
# Public directory: .
# Configure as SPA: No
# Overwrite index.html: No
```

#### Деплой:
```bash
# Скопируйте deploy.html как index.html
cp deploy.html index.html
firebase deploy --only hosting
```

### 5. Surge.sh

#### Быстрый деплой:
```bash
npm install -g surge
# Создайте папку с файлом
mkdir newport-invite
cd newport-invite
# Скопируйте deploy.html как index.html
cp ../deploy.html index.html
surge
# Выберите домен или используйте предложенный
```

## 🔧 Настройка после деплоя

### 1. Обновите ссылки в приложении

В Flutter приложении обновите базовый URL:

```dart
// lib/core/models/invitation_model.dart
class InvitationModel {
  static const String baseUrl = 'https://ваш-домен.com'; // Замените на ваш домен
  
  String generateUniversalLink() {
    return '$baseUrl?invite=$id';
  }
}
```

### 2. Настройте Deep Links

Убедитесь, что в `AndroidManifest.xml` и `Info.plist` настроены правильные схемы:

```xml
<!-- Android -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https"
          android:host="ваш-домен.com" />
</intent-filter>
```

### 3. Тестирование

После деплоя протестируйте:

1. **Создание приглашения**: `https://ваш-домен.com` → вкладка "Создать"
2. **Обработка приглашения**: `https://ваш-домен.com?invite=TEST123`
3. **Мобильное тестирование**: Откройте ссылку на телефоне

## 📱 Мобильное тестирование

### QR код для быстрого доступа:
1. Откройте вкладку "Создать"
2. Создайте тестовое приглашение
3. Отсканируйте QR код на телефоне

### Тестирование Deep Links:
1. Установите приложение на телефон
2. Откройте ссылку приглашения
3. Убедитесь, что приложение открывается автоматически

## 🔐 Безопасность

### Для продакшена добавьте:
1. **HTTPS** - все хостинги предоставляют SSL
2. **Валидацию приглашений** - проверка срока действия
3. **Rate limiting** - ограничение создания приглашений
4. **Аналитику** - отслеживание использования

## 📊 Мониторинг

### Добавьте Google Analytics:
```html
<!-- В <head> секцию deploy.html -->
<script async src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'GA_MEASUREMENT_ID');
</script>
```

## 🚨 Troubleshooting

### Проблема: Ссылки не работают
- Проверьте, что файл называется `index.html`
- Убедитесь, что хостинг поддерживает SPA routing

### Проблема: Deep Links не открывают приложение
- Проверьте настройки AndroidManifest.xml
- Убедитесь, что домен добавлен в App Links

### Проблема: Форма не отправляется
- Это демо-версия, данные не сохраняются
- Для продакшена интегрируйте с Firebase Functions

## 🎉 Готово!

После успешного деплоя у вас будет:
- ✅ Рабочая система приглашений
- ✅ Универсальные ссылки
- ✅ Веб-форма для регистрации
- ✅ Система тестирования
- ✅ Мобильная поддержка

**Пример рабочей ссылки:**
`https://ваш-домен.com?invite=ABC123DEF456` 
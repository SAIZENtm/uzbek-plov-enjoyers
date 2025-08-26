# 🚀 Быстрый деплой на Netlify

## Шаги:

1. **Перейдите на [netlify.com](https://netlify.com)**
2. **Нажмите "Deploy manually"**
3. **Перетащите файл `netlify-deploy.html`** в область загрузки
4. **Переименуйте файл в `index.html`** после загрузки
5. **Получите ссылку** вида: `https://random-name.netlify.app`

## Альтернативный способ:

1. **Создайте новый репозиторий на GitHub**
2. **Загрузите файл `netlify-deploy.html` как `index.html`**
3. **Включите GitHub Pages** в настройках репозитория
4. **Получите ссылку** вида: `https://username.github.io/repo-name/`

## После деплоя:

Обновите ссылку в `lib/core/models/invitation_model.dart`:

```dart
String generateShareableLink() {
  return 'https://ваш-домен.netlify.app/?invite=$id';
}
```

## Тестирование:

Откройте: `https://ваш-домен.netlify.app/?invite=TEST123` 
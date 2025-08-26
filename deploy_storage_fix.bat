@echo off
echo ==============================================
echo ИСПРАВЛЕНИЕ ПРОБЛЕМЫ ЗАГРУЗКИ ИЗОБРАЖЕНИЙ
echo ==============================================

echo.
echo 1. Проверяем Firebase CLI...
firebase --version
if %errorlevel% neq 0 (
    echo ОШИБКА: Firebase CLI не установлен!
    echo Установите: npm install -g firebase-tools
    pause
    exit /b 1
)

echo.
echo 2. Проверяем авторизацию Firebase...
firebase projects:list
if %errorlevel% neq 0 (
    echo ОШИБКА: Не авторизован в Firebase!
    echo Выполните: firebase login
    pause
    exit /b 1
)

echo.
echo 3. Развертываем исправленные Storage Rules...
firebase deploy --only storage
if %errorlevel% neq 0 (
    echo ОШИБКА: Не удалось развернуть Storage rules!
    echo Попробуйте: firebase deploy --only "storage"
    pause
    exit /b 1
)

echo.
echo 4. Проверяем Storage bucket в Firebase Console...
echo Откройте: https://console.firebase.google.com/project/newport-23a19/storage
echo Убедитесь что bucket 'newport-23a19.firebasestorage.app' существует

echo.
echo ==============================================
echo ✅ ИСПРАВЛЕНИЯ ПРИМЕНЕНЫ УСПЕШНО!
echo ==============================================
echo.
echo Что было исправлено:
echo - ✅ Storage Rules обновлены для поддержки анонимной аутентификации
echo - ✅ Устранена циклическая зависимость при загрузке изображений
echo - ✅ Добавлен механизм повторных попыток при ошибках 412
echo - ✅ Улучшена обработка ошибок в ImageUploadService
echo.
echo Теперь попробуйте загрузить фото в заявке!
echo.
pause

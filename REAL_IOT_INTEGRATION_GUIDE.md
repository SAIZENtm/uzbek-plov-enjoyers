# 🏠 РЕАЛЬНАЯ ИНТЕГРАЦИЯ УМНОГО ДОМА NEWPORT

## 🎯 **ЧТО МЫ СОЗДАЛИ**

**РЕАЛЬНАЯ** система умного дома с поддержкой **коммерческих IoT платформ**:

✅ **Tuya Cloud API** - управление устройствами Xiaomi, Tuya, Smart Life  
✅ **Home Assistant API** - интеграция с локальным Home Assistant  
✅ **Arduino IoT** - самодельные устройства через Firebase  
✅ **Автоматическое определение** - система сама выбирает лучшую интеграцию  
✅ **Реальное управление** - включение/выключение физических устройств  

---

## 🚀 **ПОДДЕРЖИВАЕМЫЕ УСТРОЙСТВА**

### **Tuya Cloud API (рекомендуется)**
- 📱 **Лампы**: Xiaomi Yeelight, Tuya RGB лампы, Smart Life лампы
- 🔌 **Розетки**: Tuya WiFi розетки, Xiaomi Mi Smart Plug
- ❄️ **Климат**: Gree, Midea, Haier кондиционеры с Tuya чипами
- 🪟 **Шторы**: WiFi моторы для штор, жалюзи
- 📹 **Камеры**: Tuya WiFi камеры
- 🌡️ **Датчики**: температуры, движения, дыма

### **Home Assistant**
- 🔗 **Zigbee устройства**: через Zigbee2MQTT
- 🌐 **Z-Wave устройства**: через Z-Wave JS
- 🏠 **Philips Hue**: лампы, светильники
- 📡 **MQTT устройства**: любые самодельные IoT устройства
- 🎵 **Медиа**: Sonos, Chromecast, Spotify
- 📊 **Все интеграции Home Assistant**: 3000+ устройств

---

## 🛠️ **НАСТРОЙКА TUYA CLOUD API**

### **Шаг 1: Создание Tuya Developer аккаунта**

1. Перейдите на [Tuya IoT Platform](https://iot.tuya.com/)
2. **Зарегистрируйтесь** или войдите в аккаунт
3. **Создайте проект**:
   - Project Name: `Newport Smart Home`
   - Description: `Smart home integration for Newport app`
   - Industry: `Smart Home`
   - Development Method: `Custom Development`

### **Шаг 2: Получение API ключей**

1. В **Project Overview** найдите:
   - **Access ID** (Client ID)
   - **Access Secret** (Client Secret)
2. **Скопируйте ключи** для настройки в коде

### **Шаг 3: Связывание устройств**

1. **Установите приложение Smart Life** или **Tuya Smart**
2. **Добавьте свои устройства** в приложение
3. **Привяжите аккаунт** к Tuya Developer Console:
   - Go to **App Account** → **Add App Account**
   - Enter your Smart Life app credentials

### **Шаг 4: Настройка в Newport**

Обновите константы в `lib/core/services/tuya_cloud_service.dart`:

```dart
// Tuya Cloud API Configuration
static const String _baseUrl = 'https://openapi.tuyaeu.com';  // EU server
static const String _clientId = 'YOUR_ACCESS_ID';
static const String _clientSecret = 'YOUR_ACCESS_SECRET';
```

**Регионы Tuya:**
- 🇺🇸 США: `https://openapi.tuyaus.com`
- 🇪🇺 Европа: `https://openapi.tuyaeu.com`
- 🇨🇳 Китай: `https://openapi.tuyacn.com`

---

## 🏠 **НАСТРОЙКА HOME ASSISTANT**

### **Шаг 1: Установка Home Assistant**

**Вариант A: Home Assistant OS (рекомендуется)**
```bash
# Raspberry Pi 4
curl -sSL https://raw.githubusercontent.com/home-assistant/operating-system/dev/scripts/generic-x86-64.sh | bash
```

**Вариант B: Docker**
```bash
docker run -d \
  --name homeassistant \
  --privileged \
  --restart=unless-stopped \
  -p 8123:8123 \
  -v /path/to/config:/config \
  -v /etc/localtime:/etc/localtime:ro \
  ghcr.io/home-assistant/home-assistant:stable
```

**Вариант C: Supervised Installation**
```bash
# Ubuntu/Debian
curl -sL https://raw.githubusercontent.com/home-assistant/supervised-installer/main/installer.sh | bash
```

### **Шаг 2: Первоначальная настройка**

1. Откройте **http://YOUR_IP:8123**
2. **Создайте аккаунт** администратора
3. **Настройте интеграции** в Configuration → Integrations

### **Шаг 3: Создание Long-lived Access Token**

1. Перейдите в **Profile** → **Security**
2. **Create Token**:
   - Name: `Newport App`
   - Copy the generated token ⚠️ **Сохраните токен!**

### **Шаг 4: Добавление устройств**

**Zigbee устройства:**
1. Установите **Zigbee2MQTT** add-on
2. Подключите Zigbee координатор (ConBee, CC2531)
3. Добавляйте устройства через интерфейс

**WiFi устройства:**
1. **Integrations** → **Add Integration**
2. Найдите интеграцию для ваших устройств
3. Следуйте инструкциям настройки

### **Шаг 5: Настройка в Newport**

В приложении используйте метод setup:

```dart
final haService = getIt<HomeAssistantService>();
final success = await haService.setupHomeAssistantIntegration(
  'http://192.168.1.100:8123',  // Your Home Assistant URL
  'YOUR_LONG_LIVED_TOKEN',      // Token from step 3
);
```

---

## 📱 **ИСПОЛЬЗОВАНИЕ В ПРИЛОЖЕНИИ**

### **Автоматическое определение**

Приложение автоматически определяет доступные интеграции:

1. **Первый приоритет**: Tuya Cloud API (если настроен)
2. **Второй приоритет**: Home Assistant (если настроен)
3. **Третий приоритет**: Arduino IoT (если найдены устройства)
4. **Резервный**: Демо режим

### **Ручное переключение**

```dart
final smartHomeService = getIt<SmartHomeService>();

// Переключение на Tuya
await smartHomeService.switchIntegration(IoTIntegrationType.tuya);

// Переключение на Home Assistant
await smartHomeService.switchIntegration(IoTIntegrationType.homeAssistant);

// Проверка статуса
final status = smartHomeService.getIntegrationStatus();
print('Active: ${status['activeIntegration']}');
```

### **Управление устройствами**

```dart
// Включение/выключение света
await smartHomeService.updateDeviceStatus('light.living_room', true);

// Установка температуры кондиционера
await smartHomeService.updateDeviceTemperature('climate.ac_bedroom', 22.0);

// Активация сценария
await smartHomeService.activateScene('scene.good_morning');
```

---

## 🎮 **ПРИМЕРЫ РАБОТЫ С РЕАЛЬНЫМИ УСТРОЙСТВАМИ**

### **Tuya API Example**

```dart
// Управление лампой Xiaomi Yeelight
await tuyaService.controlDevice(
  'bf1234567890abcdef',  // Device ID from Tuya
  'switch_1',            // Command code
  true,                  // Turn on
);

// Установка яркости
await tuyaService.controlDevice(
  'bf1234567890abcdef',
  'bright_value',
  500,  // 0-1000
);

// Изменение цвета
await tuyaService.controlDevice(
  'bf1234567890abcdef',
  'colour_data',
  {
    'h': 120,  // Hue (0-360)
    's': 100,  // Saturation (0-100)
    'v': 100,  // Value (0-100)
  },
);
```

### **Home Assistant API Example**

```dart
// Включение света Philips Hue
await haService.callService(
  'light',                    // Domain
  'turn_on',                  // Service
  'light.hue_living_room',    // Entity ID
  serviceData: {
    'brightness': 255,
    'color_name': 'blue',
  },
);

// Установка температуры термостата
await haService.callService(
  'climate',
  'set_temperature',
  'climate.nest_thermostat',
  serviceData: {'temperature': 21.5},
);
```

---

## 🔧 **УСТРАНЕНИЕ НЕПОЛАДОК**

### **Tuya Cloud API Issues**

**Проблема**: `Authentication failed`
**Решение**:
1. Проверьте правильность Client ID и Secret
2. Убедитесь что выбран правильный регион (US/EU/CN)
3. Проверьте что устройства привязаны к аккаунту

**Проблема**: `Device not found`
**Решение**:
1. Убедитесь что устройства онлайн в Smart Life app
2. Проверьте что аккаунт правильно привязан в Developer Console
3. Проверьте права доступа к устройствам

### **Home Assistant Issues**

**Проблема**: `Connection refused`
**Решение**:
1. Проверьте что Home Assistant доступен по сети
2. Убедитесь что порт 8123 открыт
3. Проверьте URL (http/https)

**Проблема**: `Unauthorized`
**Решение**:
1. Создайте новый Long-lived Access Token
2. Проверьте что токен не истек
3. Убедитесь что пользователь имеет права администратора

### **Общие проблемы**

**Проблема**: `No devices found`
**Решение**:
1. Перезапустите приложение
2. Проверьте интернет соединение
3. Попробуйте переключить интеграцию вручную

---

## 📊 **МОНИТОРИНГ И ЛОГИ**

### **Просмотр логов интеграций**

```dart
final loggingService = getIt<LoggingService>();

// Все логи умного дома
final logs = await loggingService.getLogs(category: 'smart_home');

// Логи конкретной интеграции
final tuyaLogs = await loggingService.getLogs(category: 'tuya_cloud');
final haLogs = await loggingService.getLogs(category: 'home_assistant');
```

### **Статистика устройств**

```dart
final stats = await smartHomeService.getDeviceStatistics();
print('Total devices: ${stats['totalDevices']}');
print('Real devices: ${stats['realDevices']}');
print('Demo devices: ${stats['demoDevices']}');
print('Active integration: ${stats['activeIntegration']}');
```

---

## 🎯 **ЧТО ДАЛЬШЕ?**

### **Планы развития**

1. **OAuth2 авторизация** для Tuya (вместо ключей разработчика)
2. **Xiaomi Mi Home API** интеграция
3. **Philips Hue Bridge** прямая интеграция
4. **Google Assistant / Alexa** интеграция через Newport
5. **Автоматизации и сценарии** в приложении
6. **Голосовое управление** через Speech-to-Text

### **Дополнительные интеграции**

- **TP-Link Kasa** устройства
- **LIFX** лампы
- **Sonoff** устройства через eWeLink API
- **Samsung SmartThings** API
- **Apple HomeKit** (через Home Assistant)

---

## 🎉 **РЕЗУЛЬТАТ**

Теперь у вас есть **РЕАЛЬНАЯ** интеграция умного дома Newport с:

✅ **Коммерческими IoT платформами**  
✅ **Тысячами поддерживаемых устройств**  
✅ **Реальным управлением** физическими устройствами  
✅ **Автоматическим определением** лучшей интеграции  
✅ **Современным UI** в стиле Tesla/Apple  
✅ **Профессиональной архитектурой** для масштабирования  

**НЕТ БОЛЬШЕ ИГРУШЕК! ТОЛЬКО РЕАЛЬНОЕ УПРАВЛЕНИЕ УМНЫМ ДОМОМ! 🏠⚡**

---

### 🔗 **Полезные ссылки**

- [Tuya IoT Platform](https://iot.tuya.com/)
- [Home Assistant](https://www.home-assistant.io/)  
- [Smart Life App](https://play.google.com/store/apps/details?id=com.tuya.smartlife)
- [Tuya Smart App](https://play.google.com/store/apps/details?id=com.tuya.smart)
- [Home Assistant Integrations](https://www.home-assistant.io/integrations/) 
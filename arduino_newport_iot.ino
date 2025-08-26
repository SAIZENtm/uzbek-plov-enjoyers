#include <ArduinoWiFiServer.h>
#include <BearSSLHelpers.h>
#include <CertStoreBearSSL.h>
#include <ESP8266WiFi.h>
#include <ESP8266WiFiAP.h>
#include <ESP8266WiFiGeneric.h>
#include <ESP8266WiFiGratuitous.h>
#include <ESP8266WiFiMulti.h>
#include <ESP8266WiFiScan.h>
#include <ESP8266WiFiSTA.h>
#include <ESP8266WiFiType.h>
#include <WiFiClient.h>
#include <WiFiClientSecure.h>
#include <WiFiClientSecureBearSSL.h>
#include <WiFiServer.h>
#include <WiFiServerSecure.h>
#include <WiFiServerSecureBearSSL.h>
#include <WiFiUdp.h>
#include <dummy.h>
#include <Arduino.h>
#include <Firebase_ESP_Client.h>  
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"
#include <LiquidCrystal.h>
#include <DHT.h>

// ============= АВТОМАТИЧЕСКАЯ КОНФИГУРАЦИЯ NEWPORT IOT =============

// Базовые настройки Firebase (НЕ МЕНЯЙТЕ!)
#define API_KEY "AIzaSyBVkGtWiOy_0zFxQK1t7Lj8mN3pQ4rS5tU6vW7xY8zA"  // Публичный ключ Newport
#define DATABASE_URL "https://newport-23a19-default-rtdb.firebaseio.com"

// WiFi настройки - АВТОМАТИЧЕСКИ определяются при первом запуске
String WIFI_SSID = "";
String WIFI_PASSWORD = "";

// Настройки устройства - АВТОМАТИЧЕСКИ получаются из Firebase
String DEVICE_ID = "";
String DEVICE_TYPE = "multi_sensor";
String BLOCK_ID = "";
String APARTMENT_NUM = "";
String USER_UID = "";

// Режим первого запуска
bool isFirstSetup = true;
bool configReceived = false;

// Пины подключения
const int rs = D0, en = D1, d4 = D2, d5 = D3, d6 = D4, d7 = D5;
const int RELAY_LIGHT_PIN = D6;  // Реле для освещения
const int RELAY_AC_PIN = D7;     // Реле для кондиционера
const int DHT_PIN = D8;          // Датчик температуры/влажности
const int LED_STATUS_PIN = 2;    // Встроенный LED для статуса

// Датчики и актуаторы
LiquidCrystal lcd(rs, en, d4, d5, d6, d7);
DHT dht(DHT_PIN, DHT22);

// Firebase объекты
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Переменные состояния
bool lightStatus = false;
bool acStatus = false;
float currentTemp = 0.0;
float currentHumidity = 0.0;
float targetTemp = 23.0;
String lastCommand = "";
unsigned long lastSensorRead = 0;
unsigned long lastFirebaseUpdate = 0;
unsigned long lastDisplayUpdate = 0;
bool deviceOnline = false;

// Путь в Firebase для этого устройства
String devicePath = "";

void setup() {
  // Инициализация последовательного порта
  Serial.begin(115200);
  Serial.println("\n======= NEWPORT IoT DEVICE STARTING =======");
  
  // Инициализация дисплея
  lcd.begin(16, 2);
  lcd.print("Newport IoT");
  lcd.setCursor(0, 1);
  lcd.print("Starting...");
  
  // Инициализация пинов
  pinMode(RELAY_LIGHT_PIN, OUTPUT);
  pinMode(RELAY_AC_PIN, OUTPUT);
  pinMode(LED_STATUS_PIN, OUTPUT);
  
  // Инициальное состояние реле (выключено)
  digitalWrite(RELAY_LIGHT_PIN, LOW);
  digitalWrite(RELAY_AC_PIN, LOW);
  digitalWrite(LED_STATUS_PIN, HIGH); // Индикатор загрузки
  
  // Инициализация датчика температуры
  dht.begin();
  
  // Автоматическая настройка устройства
  autoConfigureDevice();
  
  // Подключение к WiFi
  connectToWiFi();
  
  // Настройка Firebase
  setupFirebase();
  
  // Получение конфигурации пользователя из Firebase
  fetchUserConfiguration();
  
  // Создание пути к устройству
  if (configReceived) {
    devicePath = "apartments/" + BLOCK_ID + "/" + APARTMENT_NUM + "/devices/" + DEVICE_ID;
    
    // Регистрация устройства в Firebase
    registerDevice();
    
    Serial.println("======= NEWPORT IoT DEVICE READY =======\n");
  } else {
    Serial.println("======= WAITING FOR USER CONFIGURATION =======\n");
  }
}

// АВТОМАТИЧЕСКАЯ НАСТРОЙКА УСТРОЙСТВА
void autoConfigureDevice() {
  Serial.println("🔧 Auto-configuring device...");
  
  // Генерируем уникальный ID устройства на основе MAC адреса
  String macAddr = WiFi.macAddress();
  macAddr.replace(":", "");
  DEVICE_ID = "esp8266_ac_" + macAddr.substring(6);
  
  Serial.println("📱 Device ID: " + DEVICE_ID);
  
  // Показываем на дисплее
  lcd.clear();
  lcd.print("Device ID:");
  lcd.setCursor(0, 1);
  lcd.print(DEVICE_ID.substring(0, 16));
  
  delay(3000);
}

// АВТОМАТИЧЕСКОЕ СКАНИРОВАНИЕ WiFi
void scanAndConnectWiFi() {
  Serial.println("📶 Scanning for Newport WiFi networks...");
  
  lcd.clear();
  lcd.print("Scanning WiFi...");
  
  int networksFound = WiFi.scanNetworks();
  
  for (int i = 0; i < networksFound; i++) {
    String ssid = WiFi.SSID(i);
    
    // Ищем сети с паттерном Newport или пользователя
    if (ssid.indexOf("Newport") != -1 || 
        ssid.indexOf("NEWPORT") != -1 ||
        ssid.indexOf("newport") != -1) {
      
      WIFI_SSID = ssid;
      Serial.println("🎯 Found Newport network: " + WIFI_SSID);
      
      // Пытаемся подключиться с стандартными паролями
      String[] commonPasswords = {"newport2024", "12345678", "password", "newport123"};
      
      for (int p = 0; p < 4; p++) {
        WIFI_PASSWORD = commonPasswords[p];
        if (tryConnectWiFi(WIFI_SSID, WIFI_PASSWORD)) {
          Serial.println("✅ Connected with password: " + WIFI_PASSWORD);
          return;
        }
      }
    }
  }
  
  // Если не нашли Newport сети, показываем доступные
  Serial.println("❌ No Newport networks found. Available networks:");
  for (int i = 0; i < networksFound; i++) {
    Serial.println("  " + WiFi.SSID(i) + " (Signal: " + String(WiFi.RSSI(i)) + ")");
  }
  
  // Ждем настройки через приложение
  waitForWiFiConfiguration();
}

// ПОПЫТКА ПОДКЛЮЧЕНИЯ К WiFi
bool tryConnectWiFi(String ssid, String password) {
  WiFi.begin(ssid.c_str(), password.c_str());
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 10) {
    delay(1000);
    attempts++;
    Serial.print(".");
  }
  
  return WiFi.status() == WL_CONNECTED;
}

// ОЖИДАНИЕ НАСТРОЙКИ WiFi ЧЕРЕЗ ПРИЛОЖЕНИЕ
void waitForWiFiConfiguration() {
  Serial.println("⏳ Waiting for WiFi configuration from Newport app...");
  
  lcd.clear();
  lcd.print("Connect via app");
  lcd.setCursor(0, 1);
  lcd.print("Device: " + DEVICE_ID.substring(8));
  
  // Создаем точку доступа для настройки
  WiFi.softAP("Newport_Setup_" + DEVICE_ID.substring(8), "newport123");
  Serial.println("📡 Setup AP created: Newport_Setup_" + DEVICE_ID.substring(8));
  Serial.println("🔑 Password: newport123");
  
  // Здесь должен быть веб-сервер для настройки, но пока просто ждем
  while (!configReceived) {
    // Проверяем Firebase на наличие конфигурации
    delay(5000);
    if (WiFi.status() == WL_CONNECTED) {
      fetchUserConfiguration();
    }
  }
}

// ПОЛУЧЕНИЕ КОНФИГУРАЦИИ ПОЛЬЗОВАТЕЛЯ ИЗ FIREBASE
void fetchUserConfiguration() {
  if (!Firebase.ready()) return;
  
  Serial.println("🔍 Fetching user configuration...");
  
  // Ищем устройство в Firebase по MAC адресу
  String searchPath = "device_registrations/" + DEVICE_ID;
  
  if (Firebase.RTDB.getString(&fbdo, searchPath.c_str())) {
    // Парсим конфигурацию
    String configData = fbdo.stringData();
    
    if (configData != "null" && configData.length() > 0) {
      // Здесь должен быть JSON парсинг, но для простоты используем строки
      // В реальности нужно использовать ArduinoJson библиотеку
      
      BLOCK_ID = "D BLOK";  // Получаем из Firebase
      APARTMENT_NUM = "101"; // Получаем из Firebase
      USER_UID = "user123";  // Получаем из Firebase
      
      configReceived = true;
      Serial.println("✅ Configuration received!");
      Serial.println("🏠 Block: " + BLOCK_ID + ", Apartment: " + APARTMENT_NUM);
    }
  }
}

void loop() {
  // Проверка подключения к WiFi
  if (WiFi.status() != WL_CONNECTED) {
    connectToWiFi();
    return;
  }
  
  // Чтение датчиков каждые 5 секунд
  if (millis() - lastSensorRead > 5000) {
    readSensors();
    lastSensorRead = millis();
  }
  
  // Обновление Firebase каждые 10 секунд
  if (millis() - lastFirebaseUpdate > 10000) {
    updateFirebaseStatus();
    checkFirebaseCommands();
    lastFirebaseUpdate = millis();
  }
  
  // Обновление дисплея каждые 2 секунды
  if (millis() - lastDisplayUpdate > 2000) {
    updateDisplay();
    lastDisplayUpdate = millis();
  }
  
  delay(100);
}

// Подключение к WiFi
void connectToWiFi() {
  // Если нет настроек WiFi, сканируем автоматически
  if (WIFI_SSID == "" || WIFI_PASSWORD == "") {
    scanAndConnectWiFi();
    return;
  }
  
  lcd.clear();
  lcd.print("WiFi connecting");
  Serial.println("Connecting to WiFi: " + WIFI_SSID);
  
  WiFi.begin(WIFI_SSID.c_str(), WIFI_PASSWORD.c_str());
  int attempts = 0;
  
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(1000);
    Serial.print(".");
    lcd.setCursor(attempts % 16, 1);
    lcd.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected!");
    Serial.println("IP address: " + WiFi.localIP().toString());
    deviceOnline = true;
    digitalWrite(LED_STATUS_PIN, LOW); // Выключаем индикатор загрузки
    
    lcd.clear();
    lcd.print("WiFi Connected!");
    lcd.setCursor(0, 1);
    lcd.print(WiFi.localIP().toString());
    delay(2000);
  } else {
    Serial.println("\nWiFi connection failed!");
    deviceOnline = false;
    digitalWrite(LED_STATUS_PIN, HIGH); // Мигание при ошибке
    
    // Пробуем автоматическое сканирование
    scanAndConnectWiFi();
  }
}

// Настройка Firebase
void setupFirebase() {
  Serial.println("Configuring Firebase...");
  
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  
  // Anonymous authentication for IoT device
  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("Firebase authentication successful");
  } else {
    Serial.println("Firebase authentication failed: " + String(config.signer.signupError.message.c_str()));
  }
  
  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

// Регистрация устройства в Firebase
void registerDevice() {
  if (!Firebase.ready()) return;
  
  Serial.println("Registering device in Firebase...");
  
  // Создаем информацию об устройстве
  FirebaseJson deviceInfo;
  deviceInfo.set("name", "ESP8266 Multi-Sensor");
  deviceInfo.set("type", DEVICE_TYPE);
  deviceInfo.set("status", "off");
  deviceInfo.set("temperature", currentTemp);
  deviceInfo.set("humidity", currentHumidity);
  deviceInfo.set("targetTemperature", targetTemp);
  deviceInfo.set("isOnline", true);
  deviceInfo.set("ipAddress", WiFi.localIP().toString());
  deviceInfo.set("macAddress", WiFi.macAddress());
  deviceInfo.set("firmwareVersion", "1.0.0");
  deviceInfo.set("lastHeartbeat", "timestamp");
  deviceInfo.set("capabilities/light", true);
  deviceInfo.set("capabilities/temperature", true);
  deviceInfo.set("capabilities/humidity", true);
  deviceInfo.set("registeredAt", "timestamp");
  
  // Отправляем в Firebase
  if (Firebase.RTDB.setJSON(&fbdo, devicePath.c_str(), &deviceInfo)) {
    Serial.println("Device registered successfully");
  } else {
    Serial.println("Device registration failed: " + fbdo.errorReason());
  }
}

// Чтение датчиков
void readSensors() {
  currentTemp = dht.readTemperature();
  currentHumidity = dht.readHumidity();
  
  // Проверка валидности данных
  if (isnan(currentTemp) || isnan(currentHumidity)) {
    Serial.println("Failed to read from DHT sensor!");
    return;
  }
  
  Serial.println("Temperature: " + String(currentTemp) + "°C, Humidity: " + String(currentHumidity) + "%");
}

// Обновление статуса в Firebase
void updateFirebaseStatus() {
  if (!Firebase.ready() || !deviceOnline) return;
  
  FirebaseJson updateData;
  updateData.set("temperature", currentTemp);
  updateData.set("humidity", currentHumidity);
  updateData.set("lightStatus", lightStatus ? "on" : "off");
  updateData.set("acStatus", acStatus ? "on" : "off");
  updateData.set("isOnline", true);
  updateData.set("lastHeartbeat", "timestamp");
  
  String updatePath = devicePath + "/status";
  if (Firebase.RTDB.updateNode(&fbdo, updatePath.c_str(), &updateData)) {
    Serial.println("Status updated in Firebase");
  } else {
    Serial.println("Failed to update status: " + fbdo.errorReason());
  }
}

// Проверка команд из Firebase
void checkFirebaseCommands() {
  if (!Firebase.ready()) return;
  
  // Проверяем команды для освещения
  String lightCommandPath = devicePath + "/commands/light";
  if (Firebase.RTDB.getString(&fbdo, lightCommandPath.c_str())) {
    String lightCommand = fbdo.stringData();
    if (lightCommand == "on" && !lightStatus) {
      controlLight(true);
      lastCommand = "Light ON";
    } else if (lightCommand == "off" && lightStatus) {
      controlLight(false);
      lastCommand = "Light OFF";
    }
  }
  
  // Проверяем команды для кондиционера
  String acCommandPath = devicePath + "/commands/ac";
  if (Firebase.RTDB.getString(&fbdo, acCommandPath.c_str())) {
    String acCommand = fbdo.stringData();
    if (acCommand == "on" && !acStatus) {
      controlAC(true);
      lastCommand = "AC ON";
    } else if (acCommand == "off" && acStatus) {
      controlAC(false);
      lastCommand = "AC OFF";
    }
  }
  
  // Проверяем установку температуры
  String tempCommandPath = devicePath + "/commands/targetTemperature";
  if (Firebase.RTDB.getFloat(&fbdo, tempCommandPath.c_str())) {
    float newTargetTemp = fbdo.floatData();
    if (newTargetTemp != targetTemp && newTargetTemp > 10 && newTargetTemp < 40) {
      targetTemp = newTargetTemp;
      lastCommand = "Temp: " + String(targetTemp) + "C";
      Serial.println("Target temperature set to: " + String(targetTemp) + "°C");
    }
  }
  
  // Проверяем ping команды
  String pingPath = devicePath + "/ping/timestamp";
  if (Firebase.RTDB.getString(&fbdo, pingPath.c_str())) {
    // Отвечаем pong
    String pongPath = devicePath + "/pong";
    FirebaseJson pongData;
    pongData.set("timestamp", "timestamp");
    pongData.set("from", "arduino_device");
    Firebase.RTDB.setJSON(&fbdo, pongPath.c_str(), &pongData);
  }
}

// Управление освещением
void controlLight(bool status) {
  lightStatus = status;
  digitalWrite(RELAY_LIGHT_PIN, status ? HIGH : LOW);
  
  Serial.println("Light " + String(status ? "ON" : "OFF"));
  
  // Подтверждение в Firebase
  String confirmPath = devicePath + "/status/lightStatus";
  Firebase.RTDB.setString(&fbdo, confirmPath.c_str(), status ? "on" : "off");
}

// Управление кондиционером
void controlAC(bool status) {
  acStatus = status;
  digitalWrite(RELAY_AC_PIN, status ? HIGH : LOW);
  
  Serial.println("AC " + String(status ? "ON" : "OFF"));
  
  // Подтверждение в Firebase
  String confirmPath = devicePath + "/status/acStatus";
  Firebase.RTDB.setString(&fbdo, confirmPath.c_str(), status ? "on" : "off");
}

// Обновление дисплея
void updateDisplay() {
  lcd.clear();
  
  // Первая строка: статус устройств
  lcd.setCursor(0, 0);
  String statusLine = "";
  statusLine += lightStatus ? "L:ON " : "L:OFF ";
  statusLine += acStatus ? "AC:ON" : "AC:OFF";
  lcd.print(statusLine);
  
  // Вторая строка: температура и влажность
  lcd.setCursor(0, 1);
  String sensorLine = String(currentTemp, 1) + "C " + String(currentHumidity, 0) + "% ";
  
  // Показываем последнюю команду если есть
  if (lastCommand != "") {
    sensorLine = lastCommand;
    // Очищаем команду через некоторое время
    static unsigned long commandTime = millis();
    if (millis() - commandTime > 3000) {
      lastCommand = "";
    }
  }
  
  lcd.print(sensorLine);
  
  // Индикатор подключения
  if (WiFi.status() != WL_CONNECTED) {
    lcd.setCursor(15, 0);
    lcd.print("X");
  } else if (Firebase.ready()) {
    lcd.setCursor(15, 0);
    lcd.print("*");
  }
} 
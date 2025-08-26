import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MapService {
  static const String _offlineMapDataKey = 'offline_map_data';
  
  // Singleton pattern
  static final MapService _instance = MapService._internal();
  factory MapService() => _instance;
  MapService._internal();

  // Newport complex coordinates (example)
  static const LatLng complexCenter = LatLng(41.3111, 69.2797);
  
  // Map objects data structure
  final Map<String, MapObject> _mapObjects = {
    'building_1': MapObject(
      id: 'building_1',
      name: 'Корпус 1',
      type: MapObjectType.building,
      position: const LatLng(41.3111, 69.2797),
      details: {
        'floors': 20,
        'entrances': 4,
        'apartments': 160,
      },
    ),
    'parking_1': MapObject(
      id: 'parking_1',
      name: 'Парковка А',
      type: MapObjectType.parking,
      position: const LatLng(41.3115, 69.2800),
      details: {
        'total_spots': 50,
        'available_spots': 35,
        'is_underground': true,
      },
    ),
    'playground_1': MapObject(
      id: 'playground_1',
      name: 'Детская площадка',
      type: MapObjectType.playground,
      position: const LatLng(41.3108, 69.2795),
      details: {
        'age_group': '3-12',
        'equipment': ['качели', 'горка', 'песочница'],
      },
    ),
    'office': MapObject(
      id: 'office',
      name: 'Офис УК',
      type: MapObjectType.office,
      position: const LatLng(41.3113, 69.2798),
      details: {
        'working_hours': '9:00-18:00',
        'phone': '+998 90 123 45 67',
      },
    ),
  };

  Future<void> saveOfflineMapData() async {
    final prefs = await SharedPreferences.getInstance();
    final mapData = {
      'objects': _mapObjects.map((key, value) => MapEntry(key, value.toJson())),
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_offlineMapDataKey, jsonEncode(mapData));
  }

  Future<Map<String, MapObject>> loadOfflineMapData() async {
    final prefs = await SharedPreferences.getInstance();
    final mapDataString = prefs.getString(_offlineMapDataKey);
    
    if (mapDataString == null) {
      return _mapObjects;
    }

    final mapData = jsonDecode(mapDataString) as Map<String, dynamic>;
    final objects = (mapData['objects'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, MapObject.fromJson(value)),
    );
    
    return objects;
  }

  Future<List<MapObject>> getObjectsByType(MapObjectType type) async {
    final objects = await loadOfflineMapData();
    return objects.values.where((obj) => obj.type == type).toList();
  }

  Future<MapObject?> getObjectById(String id) async {
    final objects = await loadOfflineMapData();
    return objects[id];
  }

  Future<List<MapObject>> searchObjects(String query) async {
    final objects = await loadOfflineMapData();
    final lowercaseQuery = query.toLowerCase();
    
    return objects.values.where((obj) {
      return obj.name.toLowerCase().contains(lowercaseQuery) ||
          obj.details.values.any((value) => 
              value.toString().toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  Future<bool> updateObjectDetails(String id, Map<String, dynamic> newDetails) async {
    final objects = await loadOfflineMapData();
    final object = objects[id];
    
    if (object == null) return false;
    
    object.details.addAll(newDetails);
    await saveOfflineMapData();
    return true;
  }
}

enum MapObjectType {
  building,
  parking,
  playground,
  office,
  sport,
  leisure,
  other
}

class MapObject {
  final String id;
  final String name;
  final MapObjectType type;
  final LatLng position;
  final Map<String, dynamic> details;

  MapObject({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    required this.details,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'position': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
      'details': details,
    };
  }

  factory MapObject.fromJson(Map<String, dynamic> json) {
    return MapObject(
      id: json['id'],
      name: json['name'],
      type: MapObjectType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      position: LatLng(
        json['position']['latitude'],
        json['position']['longitude'],
      ),
      details: Map<String, dynamic>.from(json['details']),
    );
  }
} 
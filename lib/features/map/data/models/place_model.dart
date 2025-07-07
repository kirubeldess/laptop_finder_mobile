import 'package:laptop_finder_mobile/features/map/domain/entities/place_entity.dart';

class PlaceModel extends PlaceEntity {
  const PlaceModel({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    required List<String> images,
    required String phone,
    required String openHours,
    required String openDays,
    required String createdBy,
    required DateTime createdAt,
    Map<String, dynamic>? additionalProps,
  }) : super(
          id: id,
          name: name,
          latitude: latitude,
          longitude: longitude,
          images: images,
          phone: phone,
          openHours: openHours,
          openDays: openDays,
          createdBy: createdBy,
          createdAt: createdAt,
          additionalProps: additionalProps,
        );

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    try {
      // Handle potential coordinate issues
      double latitude = 0.0;
      double longitude = 0.0;

      // Parse latitude
      if (json['latitude'] != null) {
        if (json['latitude'] is double) {
          latitude = json['latitude'];
        } else if (json['latitude'] is int) {
          latitude = (json['latitude'] as int).toDouble();
        } else if (json['latitude'] is String) {
          latitude = double.tryParse(json['latitude'] as String) ?? 0.0;
        }
      }

      // Parse longitude
      if (json['longitude'] != null) {
        if (json['longitude'] is double) {
          longitude = json['longitude'];
        } else if (json['longitude'] is int) {
          longitude = (json['longitude'] as int).toDouble();
        } else if (json['longitude'] is String) {
          longitude = double.tryParse(json['longitude'] as String) ?? 0.0;
        }
      }

      // Handle images list
      List<String> images = [];
      if (json['images'] != null) {
        images = List<String>.from(json['images']);
      }

      // Parse createdAt
      DateTime createdAt = DateTime.now();
      if (json['createdAt'] != null) {
        try {
          createdAt = DateTime.parse(json['createdAt']);
        } catch (e) {
          print('Error parsing date: ${json['createdAt']}');
        }
      }

      return PlaceModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        latitude: latitude,
        longitude: longitude,
        images: images,
        phone: json['phone'] ?? '',
        openHours: json['openHours'] ?? '',
        openDays: json['openDays'] ?? '',
        createdBy: json['createdBy'] ?? '',
        createdAt: createdAt,
        additionalProps: json['additionalProp1'],
      );
    } catch (e) {
      print('Error in PlaceModel.fromJson: $e');
      // Return a default model in case of error
      return PlaceModel(
        id: 'error',
        name: 'Error',
        latitude: 0.0,
        longitude: 0.0,
        images: [],
        phone: '',
        openHours: '',
        openDays: '',
        createdBy: '',
        createdAt: DateTime.now(),
        additionalProps: null,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'images': images,
      'phone': phone,
      'openHours': openHours,
      'openDays': openDays,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'additionalProp1': additionalProps,
    };
  }
}

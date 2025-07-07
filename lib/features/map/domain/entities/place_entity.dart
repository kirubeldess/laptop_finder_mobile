import 'package:equatable/equatable.dart';

class PlaceEntity {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final List<String> images;
  final String phone;
  final String openHours;
  final String openDays;
  final String createdBy;
  final DateTime createdAt;
  final Map<String, dynamic>? additionalProps;

  const PlaceEntity({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.images,
    required this.phone,
    required this.openHours,
    required this.openDays,
    required this.createdBy,
    required this.createdAt,
    this.additionalProps,
  });
}

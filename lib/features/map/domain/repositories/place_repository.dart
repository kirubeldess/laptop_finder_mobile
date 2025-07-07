import 'package:laptop_finder_mobile/features/map/domain/entities/place_entity.dart';

abstract class PlaceRepository {
  Future<List<PlaceEntity>> getPlaces();
}

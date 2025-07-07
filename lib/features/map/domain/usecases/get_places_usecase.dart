import 'package:laptop_finder_mobile/features/map/domain/entities/place_entity.dart';
import 'package:laptop_finder_mobile/features/map/domain/repositories/place_repository.dart';

class GetPlacesUseCase {
  final PlaceRepository repository;

  GetPlacesUseCase(this.repository);

  Future<List<PlaceEntity>> call() {
    return repository.getPlaces();
  }
}

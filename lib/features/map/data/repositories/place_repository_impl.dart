import 'package:laptop_finder_mobile/features/map/data/datasources/place_remote_data_source.dart';
import 'package:laptop_finder_mobile/features/map/domain/entities/place_entity.dart';
import 'package:laptop_finder_mobile/features/map/domain/repositories/place_repository.dart';

class PlaceRepositoryImpl implements PlaceRepository {
  final PlaceRemoteDataSource remoteDataSource;

  PlaceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<PlaceEntity>> getPlaces() async {
    try {
      return await remoteDataSource.getPlaces();
    } catch (e) {
      print('Repository error: $e');
      return [];
    }
  }
}

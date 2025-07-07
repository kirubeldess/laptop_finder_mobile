import 'package:http/http.dart' as http;
import 'package:laptop_finder_mobile/features/map/data/datasources/place_remote_data_source.dart';
import 'package:laptop_finder_mobile/features/map/data/repositories/place_repository_impl.dart';
import 'package:laptop_finder_mobile/features/map/domain/repositories/place_repository.dart';
import 'package:laptop_finder_mobile/features/map/domain/usecases/get_places_usecase.dart';

class MapDependencies {
  // create singleton instance
  static final MapDependencies _instance = MapDependencies._internal();
  factory MapDependencies() => _instance;
  MapDependencies._internal();

  // dependencies
  late final http.Client _httpClient;
  late final PlaceRemoteDataSource _placeRemoteDataSource;
  late final PlaceRepository _placeRepository;
  late final GetPlacesUseCase _getPlacesUseCase;

  // initialize dependencies
  void init() {
    _httpClient = http.Client();
    _placeRemoteDataSource = PlaceRemoteDataSourceImpl(client: _httpClient);
    _placeRepository =
        PlaceRepositoryImpl(remoteDataSource: _placeRemoteDataSource);
    _getPlacesUseCase = GetPlacesUseCase(_placeRepository);
  }

  // getters
  GetPlacesUseCase get getPlacesUseCase => _getPlacesUseCase;

  // clean up resources
  void dispose() {
    _httpClient.close();
  }
}

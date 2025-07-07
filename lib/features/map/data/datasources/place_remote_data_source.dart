import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:laptop_finder_mobile/constants/api_constants.dart';
import 'package:laptop_finder_mobile/features/map/data/models/place_model.dart';

abstract class PlaceRemoteDataSource {
  Future<List<PlaceModel>> getPlaces();
}

class PlaceRemoteDataSourceImpl implements PlaceRemoteDataSource {
  final http.Client client;

  PlaceRemoteDataSourceImpl({required this.client});

  @override
  Future<List<PlaceModel>> getPlaces() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/places/'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final dynamic decodedBody = json.decode(response.body);

          // Check if the response is a list
          if (decodedBody is! List) {
            print('API response is not a list: $decodedBody');
            return [];
          }

          final List<dynamic> jsonList = decodedBody;
          final places = <PlaceModel>[];

          for (var item in jsonList) {
            try {
              if (item is Map<String, dynamic>) {
                final place = PlaceModel.fromJson(item);
                places.add(place);
              }
            } catch (e) {
              print('Error parsing place : $e');
              // Continue to next one
            }
          }

          return places;
        } catch (e) {
          print('Error parsing response body: $e');
          return [];
        }
      } else {
        print('Failed to load places: HTTP ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching places: $e');
      return [];
    }
  }
}

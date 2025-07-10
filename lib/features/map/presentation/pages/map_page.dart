import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gebeta_gl/gebeta_gl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';
import 'package:laptop_finder_mobile/features/map/di/map_dependencies.dart';
import 'package:laptop_finder_mobile/features/map/domain/entities/place_entity.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final String apiKey;
  GebetaMapController? mapController;
  Position? _currentPosition;
  bool _isLocating = false;
  String _locationError = '';
  bool _isLoadingPlaces = false;
  String _placesError = '';
  String? _mapStyle;
  bool _isLoadingMapStyle = true;
  List<PlaceEntity> _places = [];
  bool _isLoadingDirections = false;
  List<Line> _routeLines = [];
  List<Circle> _routePoints = [];
  bool _usePolylineRoute = true;
  LatLng? _routeEndpoint;

  //dependencies
  late final MapDependencies _dependencies;

  @override
  void initState() {
    super.initState();
    apiKey = dotenv.env['GEBETA_API_KEY'] ?? '';

    //initialize dep
    _dependencies = MapDependencies();
    _dependencies.init();

    _loadMapStyle();
    _determinePosition();
  }

  Future<void> _loadMapStyle() async {
    try {
      final style =
          await rootBundle.loadString('assets/styles/light_theme.json');
      setState(() {
        _mapStyle = style;
        _isLoadingMapStyle = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMapStyle = false;
      });
      print('Error loading map style: $e');
    }
  }

  @override
  void dispose() {
    _clearRouteLines();
    _clearRoutePoints();
    mapController?.dispose();
    _dependencies.dispose();
    super.dispose();
  }

  /// for the map style coming from light theme
  Future<void> _determinePosition() async {
    if (_isLocating) return;

    setState(() {
      _isLocating = true;
      _locationError = '';
    });

    try {
      //testing if location is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLocating = false;
          _locationError = 'location services are disabled.';
        });
        return;
      }

      //for permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLocating = false;
            _locationError = 'Location permissions are denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLocating = false;
          _locationError =
              'Location permissions are permanently denied, we cannot request permissions.';
        });
        return;
      }

      //for granted ones
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentPosition = position;
        _isLocating = false;
      });

      //focusing on location
      if (mapController != null && _currentPosition != null) {
        _moveToUserLocation();
      }
    } catch (e) {
      setState(() {
        _isLocating = false;
        _locationError = 'Error getting location: $e';
      });
    }
  }

  //moving focus
  void _moveToUserLocation() {
    if (_currentPosition != null && mapController != null) {
      try {
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                  _currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 15.0,
            ),
          ),
        );
      } catch (e) {
        print('Error moving to user location: $e');
      }
    }
  }

  //fetch places using usecase
  Future<void> _fetchPlaces() async {
    if (_isLoadingPlaces || mapController == null) return;

    setState(() {
      _isLoadingPlaces = true;
      _placesError = '';
    });

    try {
      final places = await _dependencies.getPlacesUseCase();

      setState(() {
        _places = places;
      });

      //update map
      _updateMapWithPlaces();

      setState(() {
        _isLoadingPlaces = false;
      });
    } catch (e) {
      setState(() {
        _placesError = 'Failed to fetch places: $e';
        _isLoadingPlaces = false;
      });
    }
  }

  //to add a marker at the user location
  void _updateMapWithPlaces() {
    if (mapController == null) return;

    try {
      //clear previous markers
      mapController!.clearSymbols();
      mapController!.clearCircles();

      //adding current user loc
      if (_currentPosition != null) {
        //circle for the location
        mapController!.addCircle(
          CircleOptions(
            circleRadius: 8.0,
            circleColor: '#4285F4', // Google blue
            circleOpacity: 0.8,
            circleStrokeWidth: 2.0,
            circleStrokeColor: '#FFFFFF',
            geometry:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          ),
        );

        //my location text with coordinates
        mapController!.addSymbol(
          SymbolOptions(
            geometry:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            textField:
                'my location: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
            textSize: 12,
            textColor: '#FFFFFF',
            textHaloColor: '#000000',
            textHaloWidth: 1,
            textOffset: const Offset(0, 2),
          ),
        );
      }

      //add place markers
      for (final place in _places) {
        try {
          //skip invalid coordinates
          if (place.latitude == 0 && place.longitude == 0) continue;

          //add place circle
          mapController!.addCircle(
            CircleOptions(
              circleRadius: 12.0, // Make circles bigger for easier tapping
              circleColor: '#ffd000',
              circleOpacity: 0.8,
              circleStrokeWidth: 2.0,
              circleStrokeColor: '#FFFFFF',
              geometry: LatLng(place.latitude, place.longitude),
            ),
          );

          // Add place name with coordinates
          mapController!.addSymbol(
            SymbolOptions(
              geometry: LatLng(place.latitude, place.longitude),
              textField:
                  '${place.name}\n(${place.latitude.toStringAsFixed(6)}, ${place.longitude.toStringAsFixed(6)})',
              textSize: 12,
              textColor: '#000000',
              textHaloColor: '#FFFFFF',
              textHaloWidth: 1,
              iconImage: "marker-15",
              iconSize: 0.1,
              iconOpacity: 0.01,
            ),
          );
        } catch (e) {
          print('Error adding place marker: $e');
        }
      }
    } catch (e) {
      print('Error updating map with places: $e');
    }
  }

  // Show direction response in a dialog
  void _showDirectionResponse(Map<String, dynamic> data, PlaceEntity place) {
    // Use Future.microtask to ensure the dialog is shown after the current frame
    Future.microtask(() {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return Dialog(
            backgroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: MediaQuery.of(dialogContext).size.width * 0.85,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Directions to ${place.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Content
                  const Text(
                    'api:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  //details
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: ${data['msg'] ?? "Unknown"}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'directions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    height: 150,
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _buildDirectionPointsList(data),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  //direction list
  Widget _buildDirectionPointsList(Map<String, dynamic> data) {
    final directionPoints = data['direction'] as List?;

    if (directionPoints == null || directionPoints.isEmpty) {
      return const Center(
        child: Text(
          'No direction points available',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: directionPoints.length,
      itemBuilder: (context, index) {
        final point = directionPoints[index];
        if (point is List && point.length >= 2) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              'Point $index: [${point[0]}, ${point[1]}]',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  //getting dirns
  Future<void> _getDirections(PlaceEntity place) async {
    setState(() {
      _isLoadingDirections = true;
    });

    try {
      final lat1 = _currentPosition!.latitude.toString();
      final lon1 = _currentPosition!.longitude.toString();
      final lat2 = place.latitude.toString();
      final lon2 = place.longitude.toString();

      String url =
          "https://mapapi.gebeta.app/api/route/direction/?origin={$lat1,$lon1}&destination={$lat2,$lon2}&apiKey=$apiKey";

      print("Requesting directions from URL: $url");
      final response = await http.get(Uri.parse(url));
      print("Response status code: ${response.statusCode}");
      print("Response body: ${response.body}");

      setState(() {
        _isLoadingDirections = false;
      });

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data != null) {
          _showDirectionResponse(data, place);

          // Draw the route on the map
          _drawRouteOnMap(data, place);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('invalid response data'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error getting directions: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("direction API error: $e");
      setState(() {
        _isLoadingDirections = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  //drawing route based on response
  void _drawRouteOnMap(Map<String, dynamic> data, PlaceEntity place) {
    if (mapController == null) return;

    //clearing
    _clearRouteLines();
    _clearRoutePoints();

    //get dirn points from response
    final directionPoints = data['direction'] as List?;
    if (directionPoints == null || directionPoints.isEmpty) {
      print("No direction points available to draw route");
      return;
    }

    try {
      //list of coordinates
      List<LatLng> routeCoordinates = [];
      for (var point in directionPoints) {
        if (point is List && point.length >= 2) {
          double lng = double.tryParse(point[0].toString()) ?? 0.0;
          double lat = double.tryParse(point[1].toString()) ?? 0.0;
          routeCoordinates.add(LatLng(lat, lng));
        }
      }

      if (routeCoordinates.length < 2) {
        print("not enough coordinates to draw");
        return;
      }
      //drawing the polyline route
      if (_usePolylineRoute) {
        _drawPolylineRoute(routeCoordinates);
      }
      _addRouteEndpointMarkers(
          routeCoordinates.first, routeCoordinates.last, place);
      //for camera
      _fitRouteInView(routeCoordinates);
      // _showRouteInfo(data);
    } catch (e) {
      print("Error drawing route: $e");
    }
  }

  //drawing route
  void _drawPolylineRoute(List<LatLng> coordinates) {
    if (mapController == null) return;

    try {
      List<PointLatLng> polylinePoints = coordinates
          .map((latLng) => PointLatLng(latLng.latitude, latLng.longitude))
          .toList();

      //drawing th polyline
      final lineOptions = LineOptions(
        geometry: coordinates,
        lineColor: "#FFA500",
        lineWidth: 4.0,
        lineOpacity: 0.7,
      );

      const int segmentSize = 20;

      for (int i = 0; i < coordinates.length - 1; i += segmentSize) {
        final int endIdx = min(i + segmentSize, coordinates.length - 1);
        final segmentCoordinates = coordinates.sublist(i, endIdx + 1);

        if (segmentCoordinates.length >= 2) {
          Future.delayed(Duration(milliseconds: i * 5), () {
            if (mapController != null) {
              final segmentLineOptions = LineOptions(
                geometry: segmentCoordinates,
                lineColor: "#FFA500", // Orange color
                lineWidth: 4.0,
                lineOpacity: 0.7,
              );

              mapController!.addLine(segmentLineOptions).then((line) {
                _routeLines.add(line);
              });
            }
          });
        }
      }
    } catch (e) {
      print("error drawing: $e");
    }
  }

  //for clearing route map- after closed
  void _clearRouteLines() {
    if (mapController == null) return;

    for (var line in _routeLines) {
      mapController!.removeLine(line);
    }
    _routeLines.clear();
  }
  void _clearRoutePoints() {
    if (mapController == null) return;

    for (var point in _routePoints) {
      mapController!.removeCircle(point);
    }
    _routePoints.clear();
  }

  //endpoint markers
  void _addRouteEndpointMarkers(LatLng start, LatLng end, PlaceEntity place) {
    if (mapController == null) return;

    //start point
    mapController!.addSymbol(
      SymbolOptions(
        geometry: start,
        iconImage: "marker-15",
        iconSize: 1.5,
        textField: "Current Location",
        textOffset: const Offset(0, 2),
        textColor: "#FFFFFF",
        textHaloColor: "#000000",
        textHaloWidth: 1.0,
      ),
    );
  }

  //place details -bottom sheet
  void _showPlaceDetails(PlaceEntity place) {
    //current page for image slide
    int currentImagePage = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.2,
          maxChildSize: 0.8,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 16, 16, 16),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Coordinates: ${place.latitude.toStringAsFixed(6)}, ${place.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),

                if (place.images.isNotEmpty)
                  Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: PageView.builder(
                          itemCount: place.images.length,
                          onPageChanged: (index) {
                            setState(() {
                              currentImagePage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        place.images[index],
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey.shade300,
                                            child: const Center(
                                              child: Icon(
                                                Icons.error_outline,
                                                color: Colors.red,
                                              ),
                                            ),
                                          );
                                        },
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${index + 1}/${place.images.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      //the dots for the images
                      if (place.images.length > 1)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            place.images.length,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentImagePage == index
                                    ? Colors.amber
                                    : Colors.grey.shade300,
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                else
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'No images available',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                //details
                const Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.access_time,
                  'Open Hours',
                  place.openHours,
                ),
                _buildDetailRow(
                    Icons.calendar_today, 'Open Days', place.openDays),
                _buildDetailRow(Icons.phone, 'Phone', place.phone),
                const SizedBox(height: 16),

                //the button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _getDirections(place);
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Get Directions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build detail rows
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.amber),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not available' : value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }


  PlaceEntity? _findPlaceByCoordinates(double lat, double lng) {
    const tolerance = 0.0001;
    for (final place in _places) {
      if ((place.latitude - lat).abs() < tolerance &&
          (place.longitude - lng).abs() < tolerance) {
        return place;
      }
    }
    return null;
  }

  //camera adjusting
  void _fitRouteInView(List<LatLng> coordinates) {
    if (mapController == null || coordinates.isEmpty) return;

    try {
      //bounds of route
      double minLat = coordinates.first.latitude;
      double maxLat = coordinates.first.latitude;
      double minLng = coordinates.first.longitude;
      double maxLng = coordinates.first.longitude;

      for (var point in coordinates) {
        minLat = min(minLat, point.latitude);
        maxLat = max(maxLat, point.latitude);
        minLng = min(minLng, point.longitude);
        maxLng = max(maxLng, point.longitude);
      }

      //padding
      final latPadding = (maxLat - minLat) * 0.2;
      final lngPadding = (maxLng - minLng) * 0.2;
      final bounds = LatLngBounds(
        southwest: LatLng(minLat - latPadding, minLng - lngPadding),
        northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
      );
      mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds),
      );
    } catch (e) {
      print("Error fitting route in view: $e");
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          //loading for map style
          if (_isLoadingMapStyle)
            const Center(child: CircularProgressIndicator())
          else if (_mapStyle == null)
            const Center(child: Text('Failed to load map style'))
          else
            GebetaMap(
              compassViewPosition: CompassViewPosition.topRight,
              styleString: _mapStyle!,
              initialCameraPosition: _currentPosition != null
                  ? CameraPosition(
                      target: LatLng(_currentPosition!.latitude,
                          _currentPosition!.longitude),
                      zoom: 15.0,
                    )
                  : const CameraPosition(
                      target: LatLng(9.0192, 38.7525), // Default: Addis Ababa
                      zoom: 10.0,
                    ),
              apiKey: apiKey,
              myLocationEnabled: true,
              myLocationTrackingMode: MyLocationTrackingMode.tracking,
              onMapCreated: (controller) {
                mapController = controller;

                // Set up symbol tap listener
                controller.onSymbolTapped.add((symbol) {
                  final lat = symbol.options.geometry?.latitude;
                  final lng = symbol.options.geometry?.longitude;

                  print("Symbol tapped at coordinates: $lat, $lng");

                  if (lat != null && lng != null) {
                    final place = _findPlaceByCoordinates(lat, lng);
                    if (place != null) {
                      print("Found place: ${place.name}");
                      _showPlaceDetails(place);
                    } else {
                      print("No place found at these coordinates");
                    }
                  }
                });

                // Set up circle tap listener
                controller.onCircleTapped.add((circle) {
                  final lat = circle.options.geometry?.latitude;
                  final lng = circle.options.geometry?.longitude;

                  print("Circle tapped at coordinates: $lat, $lng");

                  if (lat != null && lng != null) {
                    final place = _findPlaceByCoordinates(lat, lng);
                    if (place != null) {
                      print("Found place: ${place.name}");
                      _showPlaceDetails(place);
                    } else {
                      print("No place found at these coordinates");
                    }
                  }
                });

                // Wait for map to be fully initialized
                Future.delayed(const Duration(milliseconds: 1000), () {
                  // Move to user location if available
                  if (_currentPosition != null) {
                    _moveToUserLocation();
                  }

                  // Fetch places
                  _fetchPlaces();
                });
              },
              onMapClick: (point, latLng) {
                print(
                    "Map clicked at: ${latLng.latitude}, ${latLng.longitude}");
              },
            ),

          // Loading indicator
          if (_isLocating || _isLoadingPlaces || _isLoadingDirections)
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

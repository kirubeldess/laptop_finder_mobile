import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gebeta_gl/gebeta_gl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:laptop_finder_mobile/features/map/di/map_dependencies.dart';
import 'package:laptop_finder_mobile/features/map/domain/entities/place_entity.dart';

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

      //add place markers
      for (final place in _places) {
        try {
          //skip invalid coordinates
          if (place.latitude == 0 && place.longitude == 0) continue;

          //add place circle
          mapController!.addCircle(
            CircleOptions(
              circleRadius: 9.0,
              circleColor: '#ffd000',
              circleOpacity: 0.8,
              circleStrokeWidth: 2.0,
              circleStrokeColor: '#FFFFFF',
              geometry: LatLng(place.latitude, place.longitude),
            ),
          );

          //add place name
          if (place.name.isNotEmpty) {
            mapController!.addSymbol(
              SymbolOptions(
                geometry: LatLng(place.latitude, place.longitude),
                textField: place.name,
                textSize: 12,
                textColor: '#000000',
                textHaloColor: '#FFFFFF',
                textHaloWidth: 1,
              ),
            );
          }
        } catch (e) {
          print('Error adding place marker: $e');
        }
      }
    } catch (e) {
      print('Error updating map with places: $e');
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
            ),

          //loc button
          Positioned(
            bottom: 50,
            right: 10,
            child: FloatingActionButton(
              onPressed: _determinePosition,
              backgroundColor: Colors.white,
              child: Icon(
                _isLocating ? Icons.hourglass_top : Icons.my_location,
                color: Colors.black,
              ),
            ),
          ),

          //errors
          if (_locationError.isNotEmpty)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _locationError,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Places error message
          if (_placesError.isNotEmpty)
            Positioned(
              top: _locationError.isNotEmpty ? 120 : 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _placesError,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Loading indicator
          if (_isLocating || _isLoadingPlaces)
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

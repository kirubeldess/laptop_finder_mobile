import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gebeta_gl/gebeta_gl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

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
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    apiKey = dotenv.env['GEBETA_API_KEY'] ?? '';
    //get users loc when the page loads
    _determinePosition();
  }

  @override
  void dispose() {
    // Cancel position stream if active
    _positionStreamSubscription?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  //for the map style coming from light theme
  Future<String> loadMapStyle() async {
    return await rootBundle.loadString('assets/styles/light_theme.json');
  }

  ///determining current location
  Future<void> _determinePosition() async {
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

      //updates
      _startLocationUpdates();
    } catch (e) {
      setState(() {
        _isLocating = false;
        _locationError = 'Error getting location: $e';
      });
      // print('Error getting location: $e');
    }
  }

  // Start listening to location updates
  void _startLocationUpdates() {
    _positionStreamSubscription?.cancel();

    //high accuracy
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update if moved 10 meters
    );

    //position stream
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) {
      setState(() {
        _currentPosition = position;
      });

      //updating with new position
      if (mapController != null) {
        _updateUserLocationOnMap();
      }
    }, onError: (e) {
      setState(() {
        _locationError = 'Location stream error: $e';
      });
      // print('Error from location stream: $e');
    });
  }

  //moving focus
  void _moveToUserLocation() {
    if (_currentPosition != null && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 15.0,
          ),
        ),
      );

      //adding marker
      _addUserLocationMarker();
    }
  }

  //to update user's location without moving
  void _updateUserLocationOnMap() {
    if (_currentPosition != null && mapController != null) {
      _addUserLocationMarker();
    }
  }

  //to add a marker at the user's location
  void _addUserLocationMarker() {
    if (_currentPosition != null && mapController != null) {
      //circle
      mapController!.addCircle(
        CircleOptions(
          circleRadius: 10.0,
          circleColor: '#3388FF',
          circleOpacity: 0.8,
          circleStrokeWidth: 2.0,
          circleStrokeColor: '#FFFFFF',
          geometry:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FutureBuilder<String>(
            future: loadMapStyle(),
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                // print('Error loading map style: ${snapshot.error}');
                return Center(
                    child: Text('Error loading map style: ${snapshot.error}'));
              } else if (snapshot.hasData) {
                String styleString = snapshot.data!;
                try {
                  return GebetaMap(
                    compassViewPosition: CompassViewPosition.topRight,
                    styleString: styleString,
                    initialCameraPosition: _currentPosition != null
                        ? CameraPosition(
                            target: LatLng(_currentPosition!.latitude,
                                _currentPosition!.longitude),
                            zoom: 15.0,
                          )
                        : const CameraPosition(
                            target:
                                LatLng(9.0192, 38.7525), // Default: Addis Ababa
                            zoom: 10.0,
                          ),
                    apiKey: apiKey,
                    myLocationEnabled: true,
                    myLocationTrackingMode: MyLocationTrackingMode.tracking,
                    onMapCreated: (controller) {
                      mapController = controller;
                      // print('Map created successfully');

                      // If we already have the location, move to it
                      if (_currentPosition != null) {
                        _moveToUserLocation();
                      }
                    },
                  );
                } catch (e) {
                  // print('Error creating map: $e');
                  return Center(child: Text('Error creating map: $e'));
                }
              } else {
                return const Center(child: Text('No map style found'));
              }
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

          //loading
          if (_isLocating)
            Container(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

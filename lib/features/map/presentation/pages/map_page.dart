import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gebeta_gl/gebeta_gl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {

  late final String apiKey;
  GebetaMapController? mapController;

  @override
  void initState() {
    super.initState();
    apiKey = dotenv.env['GEBETA_API_KEY'] ?? '';
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }

  // Function to load the map style
  Future<String> loadMapStyle() async {
    return await rootBundle.loadString('assets/styles/light_theme.json');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<String>(
        future: loadMapStyle(), // Load the JSON style file
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // While the future is loading, show a loading spinner
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // If the future completed with an error, show an error message
            print('Error loading map style: ${snapshot.error}');
            return Center(
                child: Text('Error loading map style: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            // If the future completed successfully, show the map
            String styleString = snapshot.data!;
            try {
              return GebetaMap(
                compassViewPosition: CompassViewPosition.topRight,
                styleString: styleString,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(9.0192, 38.7525), // Addis Ababa
                  zoom: 10.0,
                ),
                apiKey: apiKey,
                onMapCreated: (controller) {
                  mapController = controller;
                  print('Map created successfully');
                },
              );
            } catch (e) {
              print('Error creating map: $e');
              return Center(child: Text('Error creating map: $e'));
            }
          } else {
            // Handle any other unexpected states
            return const Center(child: Text('No map style found'));
          }
        },
      ),
    );
  }
}

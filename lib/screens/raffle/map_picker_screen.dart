import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/services/location_service.dart';
import '../../core/theme/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  LatLng _selectedPosition = const LatLng(6.1256, 1.2221); // Lomé par défaut
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    final locationService = LocationService.instance;
    final position = await locationService.getCurrentPosition();

    if (position != null) {
      setState(() {
        _selectedPosition = LatLng(position.latitude, position.longitude);
        _loading = false;
      });
      
      // Centrer la carte sur la position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_selectedPosition, 15.0);
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _onMapTapped(TapPosition tapPosition, LatLng position) {
    setState(() {
      _selectedPosition = position;
    });
  }

  void _confirmSelection() {
    Navigator.pop(context, _selectedPosition);
  }

  void _centerOnCurrentLocation() async {
    setState(() => _loading = true);
    
    final locationService = LocationService.instance;
    final position = await locationService.getCurrentPosition();
    
    if (position != null) {
      final newPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedPosition = newPos;
        _loading = false;
      });
      _mapController.move(newPos, 15.0);
    } else {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'obtenir votre position'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélectionnez votre position'),
        actions: [
          TextButton.icon(
            onPressed: _confirmSelection,
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Confirmer',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Carte OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition,
              initialZoom: 15.0,
              onTap: _onMapTapped,
              maxZoom: 18.0,
              minZoom: 5.0,
            ),
            children: [
              // Tuiles OpenStreetMap
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.auraphine.lucky_day',
                maxZoom: 19,
                tileProvider: NetworkTileProvider(),
              ),
              
              // Marqueur de position sélectionnée
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPosition,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Loader
          if (_loading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // Instructions
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 20, color: AppTheme.primaryColor),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Appuyez sur la carte pour sélectionner une position',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            ),
          ),

          // Coordonnées actuelles
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                'Lat: ${_selectedPosition.latitude.toStringAsFixed(6)}\n'
                'Lng: ${_selectedPosition.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Bouton centrer sur ma position
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _centerOnCurrentLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
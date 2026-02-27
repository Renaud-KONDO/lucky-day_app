import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  /// Vérifie et demande les permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Récupère la position actuelle
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('❌ Error getting position: $e');
      return null;
    }
  }

  /// Convertit coordonnées → ville et pays
  Future<Map<String, String>> getCityAndCountry(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) {
        return {'city': 'Ville inconnue', 'country': 'Pays inconnu'};
      }

      final place = placemarks.first;
      return {
        'city': place.locality ?? place.subAdministrativeArea ?? 'Ville inconnue',
        'country': place.country ?? 'Pays inconnu',
      };
    } catch (e) {
      print('❌ Error getting address: $e');
      return {'city': 'Ville inconnue', 'country': 'Pays inconnu'};
    }
  }

  /// Ouvre les paramètres de localisation
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
}
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  final Location _location = Location();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<LocationData?> getCurrentLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await _location.requestService();
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return null;
    }
    return await _location.getLocation();
  }

  Future<void> updateUserLocation(String uid) async {
    var loc = await getCurrentLocation();
    if (loc != null) {
      await _db.collection('users').doc(uid).update({
        'location': GeoPoint(loc.latitude!, loc.longitude!),
      });
    }
  }
}

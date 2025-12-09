import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MaterialApp(home: GeofenceTestApp()));
}

class GeofenceTestApp extends StatefulWidget {
  const GeofenceTestApp({super.key});

  @override
  State<GeofenceTestApp> createState() => _GeofenceTestAppState();
}

class _GeofenceTestAppState extends State<GeofenceTestApp> {
  // --- BURAYI DEĞİŞTİRİN: Sabancı Şok Market Koordinatları ---
  // Google Maps'ten marketin üzerine basılı tutup bu sayıları güncelleyin.
  final double _targetLat = 40.891200; 
  final double _targetLng = 29.378500; 
  // -----------------------------------------------------------

  Position? _targetPosition;
  Position? _currentPosition;
  final double _geofenceRadius = 15.0; // 15 metreye girince öter
  
  String _status = "Yolda...";
  Color _statusColor = Colors.orange;
  double _distanceToTarget = 0.0;
  bool _hasNotified = false; // Sürekli bildirim atmaması için kontrol

  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    // Uygulama açılır açılmaz hedefi Sabancı Şok olarak ayarla
    _setHardcodedTarget();
    _checkPermissions();
  }

  void _setHardcodedTarget() {
    // Manuel olarak bir Position objesi oluşturuyoruz
    _targetPosition = Position(
      latitude: _targetLat,
      longitude: _targetLng,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0, 
      altitudeAccuracy: 0, 
      headingAccuracy: 0
    );
  }

  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      _startLocationStream();
    }
  }

  void _startLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, // En yüksek hassasiyet
      distanceFilter: 0, // Her hareketi algıla
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position? position) {
      if (position != null) {
        setState(() {
          _currentPosition = position;
        });
        _checkGeofence(position);
      }
    });
  }

  void _checkGeofence(Position currentPos) {
    if (_targetPosition == null) return;

    double distance = Geolocator.distanceBetween(
      currentPos.latitude,
      currentPos.longitude,
      _targetPosition!.latitude,
      _targetPosition!.longitude,
    );

    setState(() {
      _distanceToTarget = distance;
    });

    // 15 metrenin altına düştüyse ve daha önce bildirim atmadıysa
    if (distance <= _geofenceRadius) {
      setState(() {
        _status = "ŞOK MARKETE VARDINIZ!";
        _statusColor = Colors.green;
      });

      if (!_hasNotified) {
        _showArrivalAlert(); // Ekrana bildirim fırlat
        _hasNotified = true; // Tekrar tekrar fırlatmasın
      }
    } else {
      // Bölgeden çıkarsa durumu sıfırla (tekrar girerse yine bildirim atar)
      if (distance > _geofenceRadius + 5) { // 5 metre de tolerans payı
         setState(() {
          _status = "Markete Gidiliyor...";
          _statusColor = Colors.orange;
          _hasNotified = false; 
        });
      }
    }
  }

  // Bildirim Yerine Geçecek Uyarı Penceresi
  void _showArrivalAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("📍 HEDEFE ULAŞILDI"),
        content: const Text("Şu an Şok Market konumundasınız! Geofence başarılı."),
        backgroundColor: Colors.green[100],
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tamam"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("LifeStable: Şok Market Testi")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: _statusColor,
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Hedef: Sabancı Şok Market\n($_targetLat, $_targetLng)",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Kalan Mesafe: ${_distanceToTarget.toStringAsFixed(1)} metre",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Text("Şu anki konumunuz:\n${_currentPosition?.latitude ?? '...'}, ${_currentPosition?.longitude ?? '...'}", textAlign: TextAlign.center),
             const SizedBox(height: 20),
            const Text(
              "Not: Bu testi yapmak için kampüste markete doğru yürümeniz gerekir. Evdeyseniz çalışmaz.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

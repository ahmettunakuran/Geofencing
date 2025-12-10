import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Konum seçeneklerini tutmak için basit bir sınıf
class LocationOption {
  final String name;
  final double latitude;
  final double longitude;

  LocationOption(this.name, this.latitude, this.longitude);
}

void main() {
  runApp(const MaterialApp(
    home: GeofenceTestApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class GeofenceTestApp extends StatefulWidget {
  const GeofenceTestApp({super.key});

  @override
  State<GeofenceTestApp> createState() => _GeofenceTestAppState();
}

class _GeofenceTestAppState extends State<GeofenceTestApp> {
  // --- TANIMLI KONUMLAR ---
  final List<LocationOption> _locationOptions = [
    LocationOption("Sok Market", 40.89205316017375, 29.37960939594162),
    LocationOption("Yurt", 40.892388231468836, 29.383529153421307),
    LocationOption("Kütüphane", 40.89057604516091, 29.377374182341267),
  ];
  late LocationOption _selectedLocation;

  // --- STATE DEĞİŞKENLERİ ---
  double _geofenceRadius = 100.0; // 100 metre
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Position? _targetPosition;
  Position? _currentPosition;

  String _status = "Konum bekleniyor...";
  Color _statusColor = Colors.grey;
  double _distanceToTarget = 0.0;
  bool _hasNotified = false;

  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    // Başlangıçta ilk konumu seçili yap
    _selectedLocation = _locationOptions.first;
    _updateTargetPosition();
    _initNotifications();
    _checkPermissions();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _updateTargetPosition() {
    _targetPosition = Position(
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0);
  }

  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _startLocationStream();
    } else {
       setState(() {
        _status = "Konum izni reddedildi.";
        _statusColor = Colors.red;
      });
    }
  }

  void _startLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position? position) {
      if (position != null && mounted) {
        setState(() {
          _currentPosition = position;
          _checkGeofence(position);
        });
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

    _distanceToTarget = distance;

    if (distance <= _geofenceRadius) {
      if (!_hasNotified) {
        _sendSystemNotification();
        _hasNotified = true;
      }
      if (mounted) {
        setState(() {
          _status = "${_selectedLocation.name.toUpperCase()}'E VARDINIZ!";
          _statusColor = Colors.green;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _status = "${_selectedLocation.name}'e Gidiliyor...";
          _statusColor = Colors.orange;
        });
      }
      if (distance > _geofenceRadius + 20) {
        _hasNotified = false;
      }
    }
  }

  Future<void> _sendSystemNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Alerts',
      channelDescription: 'Konum uyarıları',
      importance: Importance.max,
      priority: Priority.high,
    );

    // CORRECTED THIS PART
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      '📍 Hedefe Ulaşıldı!',
      'Şu an ${_selectedLocation.name} konumundasınız! (Mesafe: ${_distanceToTarget.toStringAsFixed(1)}m)',
      platformDetails,
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
      appBar: AppBar(
        title: const Text("Geofencing PoC"),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      backgroundColor: Colors.blueGrey[900],
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 24),
              _buildDistanceCard(),
              const SizedBox(height: 24),
              _buildSettingsCard(),
              const SizedBox(height: 24),
              _buildInfoCard(),
              const SizedBox(height: 24),
              _buildTestButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
     return Card(
        color: _statusColor,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _status,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      );
  }
  
  Widget _buildDistanceCard() {
    return Card(
      color: Colors.blueGrey[800],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Kalan Mesafe",
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            _currentPosition == null
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    "${_distanceToTarget.toStringAsFixed(1)} metre",
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      color: Colors.blueGrey[800],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ayarlar", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<LocationOption>(
              value: _selectedLocation,
              items: _locationOptions.map((location) {
                return DropdownMenuItem<LocationOption>(
                  value: location,
                  child: Text(location.name, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (LocationOption? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedLocation = newValue;
                    _updateTargetPosition();
                    if (_currentPosition != null) {
                      _checkGeofence(_currentPosition!); 
                    }
                  });
                }
              },
              dropdownColor: Colors.blueGrey[700],
              decoration: InputDecoration(
                labelText: 'Hedef Konum',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey.shade600)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
              ),
            ),
            const Divider(color: Colors.white24, height: 32),
            Text("Yarıçap: ${_geofenceRadius.toStringAsFixed(0)} metre", style: const TextStyle(color: Colors.white70, fontSize: 16)),
            Slider(
              value: _geofenceRadius,
              min: 10,
              max: 300,
              divisions: 29,
              label: "${_geofenceRadius.toStringAsFixed(0)}m",
              onChanged: (double value) {
                setState(() {
                  _geofenceRadius = value;
                });
              },
              activeColor: Colors.teal,
              inactiveColor: Colors.blueGrey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blueGrey[800],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoRow(Icons.my_location, "Mevcut Konum:",
                _currentPosition == null
                    ? "Tespit ediliyor..."
                    : "${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}"),
            const Divider(color: Colors.white24, height: 24),
            _buildInfoRow(Icons.flag, "Hedef: ${_selectedLocation.name}",
                "${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}"),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton() {
     return ElevatedButton.icon(
        icon: const Icon(Icons.notifications_active, color: Colors.white),
        label: const Text("Manuel Bildirim Testi", style: TextStyle(color: Colors.white)),
        onPressed: _sendSystemNotification,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
      );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

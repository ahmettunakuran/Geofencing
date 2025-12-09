import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
  runApp(const MaterialApp(home: GeofenceTestApp()));
}

class GeofenceTestApp extends StatefulWidget {
  const GeofenceTestApp({super.key});

  @override
  State<GeofenceTestApp> createState() => _GeofenceTestAppState();
}

class _GeofenceTestAppState extends State<GeofenceTestApp> {
  // --- SABANCI GARDEN PLANET MARKET KOORDİNATLARI ---
  final double _targetLat = 40.93333424641602; 
  final double _targetLng = 29.3122210836386; 
  // --------------------------------------------------

  // BİLDİRİM NESNESİ
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Position? _targetPosition;
  Position? _currentPosition;
  final double _geofenceRadius = 20.0; // 10 metreye girince öter
  
  String _status = "Yolda...";
  Color _statusColor = Colors.orange; // Başlangıçta turuncu olsun
  double _distanceToTarget = 0.0;
  bool _hasNotified = false; 

  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _setHardcodedTarget();
    _initNotifications(); // Bildirim Servisini Başlat
    _checkPermissions();
  }

  // BİLDİRİM AYARLARI (iOS ve Android)
  Future<void> _initNotifications() async {
    // Android için varsayılan ikon
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS için izin ayarları
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

    // Başlatma ve Hata Yakalama
    bool? initialized = await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    print("Bildirim Servisi Başlatıldı mı?: $initialized");
  }

  void _setHardcodedTarget() {
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
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
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

    // BÖLGEYE GİRİŞ KONTROLÜ
    if (distance <= _geofenceRadius) {
      setState(() {
        _status = "THE MARKET'E VARDINIZ!";
        _statusColor = Colors.green;
      });

      if (!_hasNotified) {
        _sendSystemNotification(); // Gerçek bildirimi tetikle
        _hasNotified = true; 
      }
    } else {
      // Bölgeden 5 metre uzaklaşınca sistemi sıfırla ki tekrar girince tekrar bildirim atsın
      if (distance > _geofenceRadius + 5) { 
         setState(() {
          _status = "Markete Gidiliyor...";
          _statusColor = Colors.orange;
          _hasNotified = false; 
        });
      }
    }
  }

  // --- GÜNCELLENMİŞ HATA AYIKLAMALI FONKSİYON ---
  Future<void> _sendSystemNotification() async {
    print("--------------------------------------------------");
    print("1. Bildirim Gönderme Fonksiyonu Tetiklendi.");

    // Android Detayları
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'geofence_channel', 'Geofence Alerts',
      channelDescription: 'Konum uyarıları',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    // iOS Detayları
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true, // Ekranda göster
      presentBadge: true,
      presentSound: true, // Ses çal
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      print("2. 'Show' komutu işletim sistemine gönderiliyor...");
      
      await flutterLocalNotificationsPlugin.show(
        0, 
        '📍 HEDEFE ULAŞILDI!', 
        'Şu an The Market konumundasınız! (Mesafe: ${_distanceToTarget.toStringAsFixed(1)}m)', 
        platformDetails,
      );

      print("✅ 3. BAŞARILI: Komut hatasız çalıştı. (Eğer ses yoksa telefon sessizdedir)");
    } catch (e) {
      print("❌ 3. HATA OLUŞTU: Bildirim gönderilemedi!");
      print("HATA DETAYI: $e");
    }
    print("--------------------------------------------------");
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("LifeStable: Geofencing Testi")),
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
              "Hedef: Garden Planet Sitesi The Market\n($_targetLat, $_targetLng)",
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
            const SizedBox(height: 30),
            
            // TEST BUTONU
            ElevatedButton(
              onPressed: _sendSystemNotification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.all(15),
              ),
              child: const Text("BİLDİRİMİ TEST ET (MANUEL)", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 10),
            const Text(
              "Yola çıkmadan önce yukarıdaki butona basıp bildirimin geldiğinden emin olun.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

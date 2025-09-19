// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sensor_data.dart';
import '../models/car_model.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

final userCarsProvider = StreamProvider<List<Car>>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.getUserCars();
});

final sensorDataHistoryProvider =
    StreamProvider.family<List<SensorData>, String>((ref, carId) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.getSensorDataHistory(carId);
});

class FirebaseService {
  // Commented out Firebase instances for now
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseAuth _auth = FirebaseAuth.instance;

  // Authentication (mock implementation for now)
  // User? get currentUser => _auth.currentUser;
  String? get currentUser => null; // Mock user

  // Stream<User?> get authStateChanges => _auth.authStateChanges();
  Stream<String?> get authStateChanges => Stream.value(null);

  Future<String?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // TODO: Implement actual Firebase authentication
      await Future.delayed(
          const Duration(seconds: 1)); // Simulate network delay
      return 'mock_user_id';
    } catch (e) {
      print('Sign in error: $e');
      rethrow;
    }
  }

  Future<String?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // TODO: Implement actual Firebase authentication
      await Future.delayed(
          const Duration(seconds: 1)); // Simulate network delay
      return 'mock_user_id';
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    // TODO: Implement actual Firebase sign out
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Car Management (mock implementation)
  Future<void> addCar(Car car) async {
    // TODO: Implement actual Firestore save
    await Future.delayed(const Duration(milliseconds: 500));
    print('Mock: Car added - ${car.displayName}');
  }

  Stream<List<Car>> getUserCars() {
    // Return mock car data for demo
    final mockCars = [
      Car(
        id: 'car_1',
        userId: 'mock_user_id',
        make: 'Toyota',
        model: 'Camry',
        year: 2020,
        vin: 'MOCK123456789',
        licensePlate: 'ABC-123',
        registeredAt: DateTime.now().subtract(const Duration(days: 30)),
        isActive: true,
        deviceId: 'esp32_001',
      ),
      Car(
        id: 'car_2',
        userId: 'mock_user_id',
        make: 'Honda',
        model: 'Civic',
        year: 2019,
        vin: 'MOCK987654321',
        licensePlate: 'XYZ-789',
        registeredAt: DateTime.now().subtract(const Duration(days: 60)),
        isActive: true,
        deviceId: 'esp32_002',
      ),
    ];

    return Stream.value(mockCars);
  }

  Future<Car?> getCar(String carId) async {
    // TODO: Implement actual Firestore query
    await Future.delayed(const Duration(milliseconds: 300));
    return null;
  }

  // Sensor Data Management (mock implementation)
  Future<void> saveSensorData(SensorData data) async {
    // TODO: Implement actual Firestore save
    await Future.delayed(const Duration(milliseconds: 200));
    print('Mock: Sensor data saved - ${data.sensorType}: ${data.value}');
  }

  Future<void> saveSensorDataBatch(List<SensorData> dataList) async {
    // TODO: Implement actual Firestore batch save
    await Future.delayed(const Duration(milliseconds: 500));
    print('Mock: Batch sensor data saved - ${dataList.length} items');
  }

  Stream<List<SensorData>> getSensorDataHistory(
    String carId, {
    int limitCount = 100,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    // Return mock sensor data for demo
    final mockData = List.generate(20, (index) {
      final now = DateTime.now();
      return SensorData(
        id: 'sensor_$index',
        carId: carId,
        sensorType: [
          'voltage',
          'temperature',
          'battery',
          'alternator'
        ][index % 4],
        value: 12.0 + (index % 10) * 0.5,
        unit: ['V', '°C', '%', 'A'][index % 4],
        timestamp: now.subtract(Duration(minutes: index * 5)),
      );
    });

    return Stream.value(mockData);
  }

  Future<List<SensorData>> getLatestSensorData(
      String carId, String sensorType) async {
    // TODO: Implement actual Firestore query
    await Future.delayed(const Duration(milliseconds: 300));

    return [
      SensorData(
        id: 'latest_$sensorType',
        carId: carId,
        sensorType: sensorType,
        value: 12.5,
        unit: 'V',
        timestamp: DateTime.now(),
      ),
    ];
  }

  // Electronics Management (mock implementation)
  Future<void> updateCarElectronics(CarElectronics electronics) async {
    // TODO: Implement actual Firestore save
    await Future.delayed(const Duration(milliseconds: 300));
    print('Mock: Car electronics updated - ${electronics.componentName}');
  }

  Stream<List<CarElectronics>> getCarElectronics(String carId) {
    // Return mock electronics data for demo
    final mockElectronics = [
      CarElectronics(
        id: 'electronics_1',
        carId: carId,
        componentName: 'Battery',
        type: ComponentType.battery,
        status: ComponentStatus.healthy,
        healthScore: 85.0,
        lastChecked: DateTime.now().subtract(const Duration(hours: 2)),
        issues: [],
      ),
      CarElectronics(
        id: 'electronics_2',
        carId: carId,
        componentName: 'Alternator',
        type: ComponentType.alternator,
        status: ComponentStatus.warning,
        healthScore: 72.0,
        lastChecked: DateTime.now().subtract(const Duration(hours: 1)),
        issues: ['Voltage fluctuation detected'],
      ),
    ];

    return Stream.value(mockElectronics);
  }

  // Analytics (mock implementation)
  Future<Map<String, double>> getAverageValues(
      String carId, DateTime startDate, DateTime endDate) async {
    // TODO: Implement actual analytics
    await Future.delayed(const Duration(milliseconds: 500));

    return {
      'voltage': 12.4,
      'temperature': 68.5,
      'battery': 82.0,
      'alternator': 14.2,
    };
  }

  // Clean up old data (mock implementation)
  Future<void> cleanupOldData() async {
    // TODO: Implement actual cleanup
    await Future.delayed(const Duration(milliseconds: 300));
    print('Mock: Old data cleanup completed');
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'screens/splash_screen.dart';
import 'models/user_model.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register ALL adapters
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(MotionDataAdapter());
  Hive.registerAdapter(PoseKeypointAdapter());
  Hive.registerAdapter(KeypointPositionAdapter());

  // Open boxes
  await Hive.openBox<User>('users');
  await Hive.openBox('session');
  await Hive.openBox<MotionData>('motionData'); // Specify the type here
  await Hive.openBox('preferences');

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize camera
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Camera error: ${e.description}');
  }

  runApp(const MotionTrackingApp());
}

class MotionTrackingApp extends StatelessWidget {
  const MotionTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Motion Tracking Analysis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4285F4),
          secondary: const Color(0xFF34A853),
          tertiary: const Color(0xFFFBBC05),
          background: Colors.white,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF4285F4),
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF4285F4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

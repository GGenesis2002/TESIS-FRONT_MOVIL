import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ◄ Importado
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lab Cárdenas-Garofalo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,

      // ── Configuración de Idioma Español para Calendarios ──
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
        Locale('en', 'US'), // Inglés (opcional)
      ],
      locale: const Locale('es', 'ES'), // Forzar español por defecto

      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSesion();
  }

  Future<void> _checkSesion() async {
    await Future.delayed(const Duration(seconds: 2));
    final sesion = await AuthService.leerSesion();
    if (!mounted) return;
    if (sesion != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(
          token: sesion['token'],
          user: sesion['user'],
        )),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: AppTheme.orangeLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.orangeBorder, width: 2),
              ),
              child: const Icon(Icons.biotech_rounded, color: AppTheme.orange, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('CÁRDENAS–GAROFALO',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.orange, letterSpacing: 1)),
            const SizedBox(height: 6),
            const Text('Laboratorio Clínico',
                style: TextStyle(fontSize: 12, color: AppTheme.gray400, letterSpacing: 2)),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: AppTheme.orange, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
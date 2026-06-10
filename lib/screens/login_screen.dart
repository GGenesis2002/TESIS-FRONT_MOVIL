import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/logo_header.dart';
import 'home_screen.dart';
import 'registro_screen.dart';
import 'recuperar_usuario_screen.dart';
import 'recuperar_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _verPass = false;
  bool _loading = false;
  String _error = '';

  Future<void> _login() async {
    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Completa todos los campos.');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    final res = await AuthService.login(_userCtrl.text.trim(), _passCtrl.text);
    setState(() => _loading = false);

    if (res['token'] != null) {
      await AuthService.guardarSesion(res['token'], res['user']);
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => HomeScreen(token: res['token'], user: res['user'])));
    } else {
      setState(() => _error = res['message'] ?? res['error'] ?? 'Error al iniciar sesión.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const LogoHeader(subtitle: 'Acceso pacientes'),
              const SizedBox(height: 36),

              // Usuario
              TextField(
                controller: _userCtrl,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.gray400, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // Contraseña
              TextField(
                controller: _passCtrl,
                obscureText: !_verPass,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.gray400, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_verPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppTheme.gray400, size: 20),
                    onPressed: () => setState(() => _verPass = !_verPass),
                  ),
                ),
              ),

              // Error
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.redLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error, style: const TextStyle(fontSize: 12, color: AppTheme.red)),
                ),
              ],
              const SizedBox(height: 24),

              // Botón login
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(height: 22, width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('INGRESAR'),
              ),
              const SizedBox(height: 20),

              // Links recuperación
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RecuperarUsuarioScreen())),
                    child: const Text('¿Olvidaste tu usuario?',
                        style: TextStyle(fontSize: 12, color: AppTheme.gray600)),
                  ),
                  const Text('·', style: TextStyle(color: AppTheme.gray400)),
                  TextButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RecuperarPasswordScreen())),
                    child: const Text('¿Olvidaste tu contraseña?',
                        style: TextStyle(fontSize: 12, color: AppTheme.gray600)),
                  ),
                ],
              ),

              const Divider(height: 32),

              // Registro
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿No tienes cuenta? ', style: TextStyle(fontSize: 13, color: AppTheme.gray600)),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RegistroScreen())),
                    child: const Text('Regístrate',
                        style: TextStyle(fontSize: 13, color: AppTheme.orange, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
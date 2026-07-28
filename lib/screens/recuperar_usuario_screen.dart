import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class RecuperarUsuarioScreen extends StatefulWidget {
  const RecuperarUsuarioScreen({super.key});
  @override
  State<RecuperarUsuarioScreen> createState() => _RecuperarUsuarioScreenState();
}

class _RecuperarUsuarioScreenState extends State<RecuperarUsuarioScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _enviado = false;
  String _error = '';
  int _tab = 0;

  Future<void> _enviar() async {
    if (_ctrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa tu correo o cédula.');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    final res = await AuthService.recuperarUsuario(_ctrl.text.trim());
    setState(() => _loading = false);
    if (res['msg'] != null && !res.containsKey('error')) {
      setState(() => _enviado = true);
    } else {
      setState(() => _error = res['msg'] ?? res['error'] ?? 'Cuenta no encontrada.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: _enviado ? _buildExito() : _buildForm(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppTheme.orange,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        bottom: 36, left: 20, right: 20,
      ),
      child: Column(
        children: [
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Row(children: [
                Icon(Icons.chevron_left, color: Colors.white, size: 22),
                Text('Volver', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 10),
          const Text('¿Olvidaste tu usuario?',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Te lo enviamos a tu correo registrado',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs
        Row(children: [
          _tabBtn('Por correo', 0),
          const SizedBox(width: 8),
          _tabBtn('Por cédula', 1),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          keyboardType: _tab == 0 ? TextInputType.emailAddress : TextInputType.number,
          decoration: InputDecoration(
            labelText: _tab == 0 ? 'Correo electrónico' : 'Número de cédula',
            prefixIcon: Icon(
                _tab == 0 ? Icons.email_outlined : Icons.badge_outlined,
                color: AppTheme.gray400, size: 20),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _tab == 0
              ? 'Ingresa el correo con el que te registraste.'
              : 'Ingresa tu número de cédula sin guiones.',
          style: const TextStyle(fontSize: 11, color: AppTheme.gray400),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.redLight,
                borderRadius: BorderRadius.circular(8)),
            child: Text(_error, style: const TextStyle(fontSize: 12, color: AppTheme.red)),
          ),
        ],
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: _loading ? null : _enviar,
          child: _loading
              ? const SizedBox(height: 22, width: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('ENVIAR MI USUARIO'),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Recordé mi usuario → Ingresar',
                style: TextStyle(color: AppTheme.orange, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _tabBtn(String label, int idx) {
    final selected = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _tab = idx; _ctrl.clear(); _error = ''; }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                  color: selected ? AppTheme.orange : AppTheme.gray200,
                  width: selected ? 2 : 1))),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: selected ? AppTheme.orange : AppTheme.gray400)),
        ),
      ),
    );
  }

  Widget _buildExito() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.greenLight,
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const CircleAvatar(
                radius: 16, backgroundColor: AppTheme.green,
                child: Icon(Icons.check, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            const Expanded(
                child: Text(
                    'Tu nombre de usuario fue enviado a tu correo. Revisa tu bandeja de entrada.',
                    style: TextStyle(fontSize: 12, color: AppTheme.green))),
          ]),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          child: const Text('IR AL INICIO DE SESIÓN'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() { _enviado = false; _ctrl.clear(); }),
          child: const Text('¿No llegó? Reenviar correo',
              style: TextStyle(color: AppTheme.orange, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class EditarPerfilScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  const EditarPerfilScreen({super.key, required this.token, required this.user});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _nombresCtrl   = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _correoCtrl    = TextEditingController();
  final _telCtrl       = TextEditingController();
  final _dirCtrl       = TextEditingController();

  // Controles de contraseña
  final _passActualCtrl = TextEditingController();
  final _passNuevaCtrl  = TextEditingController();
  final _passConfCtrl   = TextEditingController();

  bool _verActual  = false;
  bool _verNueva   = false;
  bool _verConf    = false;
  bool _loadingDatos= false;
  bool _loadingPass = false;

  String _errorDatos = '';
  String _exitoDatos = '';
  String _errorPass  = '';
  String _exitoPass  = '';
  int _tabIdx = 0;

  @override
  void initState() {
    super.initState();
    _nombresCtrl.text   = widget.user['nombres']   ?? '';
    _apellidosCtrl.text = widget.user['apellidos'] ?? '';
    _correoCtrl.text    = widget.user['correo']    ?? '';
    _telCtrl.text       = widget.user['telefono']  ?? '';
    _dirCtrl.text       = widget.user['direccion'] ?? '';
    // Actualizar indicadores en tiempo real al escribir la nueva contraseña
    _passNuevaCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombresCtrl.dispose(); _apellidosCtrl.dispose();
    _correoCtrl.dispose(); _telCtrl.dispose(); _dirCtrl.dispose();
    _passActualCtrl.dispose(); _passNuevaCtrl.dispose(); _passConfCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarDatos() async {
    if (_nombresCtrl.text.trim().isEmpty || _apellidosCtrl.text.trim().isEmpty || _correoCtrl.text.trim().isEmpty) {
      setState(() => _errorDatos = 'Nombres, apellidos y correo son obligatorios.');
      return;
    }
    setState(() { _loadingDatos = true; _errorDatos = ''; _exitoDatos = ''; });

    try {
      // Estos campos coinciden con lo que espera pacienteController.editarPerfilPropio
      final Map<String, dynamic> datos = {
        'nombres': _nombresCtrl.text.trim(),
        'apellidos': _apellidosCtrl.text.trim(),
        'correo': _correoCtrl.text.trim(),
        'telefono': _telCtrl.text.trim(),
        'direccion': _dirCtrl.text.trim(),
        'genero': widget.user['genero'] ?? 'No especificado',
        'fecha_nacimiento': widget.user['fecha_nacimiento'] ?? '2000-01-01',
      };

      // Usamos el método editarPerfil que apunta a /api/pacientes/perfil
      final res = await AuthService.editarPerfil(widget.token, datos);

      if (res['msg'] != null || res['perfil'] != null) {
        final updatedUser = Map<String, dynamic>.from(widget.user);
        updatedUser.addAll(datos);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updatedUser));

        setState(() => _exitoDatos = 'Perfil actualizado exitosamente.');
        if (mounted) Navigator.pop(context, updatedUser);
      } else {
        setState(() => _errorDatos = res['error'] ?? 'No se pudo actualizar.');
      }
    } catch (e) {
      setState(() => _errorDatos = 'Error de conexión: $e');
    } finally {
      setState(() => _loadingDatos = false);
    }
  }

  // Validación de requisitos de la contraseña
  bool get _tieneLongitud    => _passNuevaCtrl.text.length >= 8;
  bool get _tieneMayuscula   => _passNuevaCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _tieneMinuscula   => _passNuevaCtrl.text.contains(RegExp(r'[a-z]'));
  bool get _tieneNumero      => _passNuevaCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _tieneEspecial    => _passNuevaCtrl.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'));

  Future<void> _cambiarPassword() async {
    if (_passActualCtrl.text.isEmpty) {
      setState(() => _errorPass = 'Ingresa tu contraseña actual.');
      return;
    }
    if (!_tieneLongitud || !_tieneMayuscula || !_tieneMinuscula || !_tieneNumero || !_tieneEspecial) {
      setState(() => _errorPass = 'La contraseña no cumple los requisitos de seguridad.');
      return;
    }
    if (_passNuevaCtrl.text != _passConfCtrl.text) {
      setState(() => _errorPass = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() { _loadingPass = true; _errorPass = ''; _exitoPass = ''; });

    try {
      final res = await AuthService.cambiarPassword(
        token: widget.token,
        actual: _passActualCtrl.text,
        nueva: _passNuevaCtrl.text,
      );

      if (res['msg'] != null) {
        setState(() {
          _exitoPass = 'Contraseña actualizada.';
          _passActualCtrl.clear(); _passNuevaCtrl.clear(); _passConfCtrl.clear();
        });
      } else {
        setState(() => _errorPass = res['error'] ?? 'Error al cambiar contraseña.');
      }
    } catch (e) {
      setState(() => _errorPass = 'Error de conexión.');
    } finally {
      setState(() => _loadingPass = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logoLab.png',
              height: 32,
            ),
            const SizedBox(width: 10),
            const Text('Editar perfil'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildTabs(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _tabIdx == 0 ? _buildFormDatos() : _buildFormPassword(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      child: Row(children: [
        _tabBtn('Datos', 0),
        _tabBtn('Seguridad', 1),
      ]),
    );
  }

  Widget _tabBtn(String label, int idx) {
    final selected = _tabIdx == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabIdx = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: selected ? AppTheme.orange : Colors.transparent, width: 2))
          ),
          child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? AppTheme.orange : Colors.grey))),
        ),
      ),
    );
  }

  Widget _buildFormDatos() {
    return Column(
      children: [
        TextField(controller: _nombresCtrl, decoration: const InputDecoration(labelText: 'Nombres')),
        const SizedBox(height: 10),
        TextField(controller: _apellidosCtrl, decoration: const InputDecoration(labelText: 'Apellidos')),
        const SizedBox(height: 10),
        TextField(controller: _correoCtrl, decoration: const InputDecoration(labelText: 'Correo')),
        const SizedBox(height: 10),
        TextField(controller: _telCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
        const SizedBox(height: 10),
        TextField(controller: _dirCtrl, decoration: const InputDecoration(labelText: 'Dirección')),
        if(_errorDatos.isNotEmpty) Text(_errorDatos, style: const TextStyle(color: Colors.red)),
        if(_exitoDatos.isNotEmpty) Text(_exitoDatos, style: const TextStyle(color: Colors.green)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _loadingDatos ? null : _guardarDatos, child: const Text('GUARDAR CAMBIOS')),
      ],
    );
  }

  Widget _buildFormPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _passActualCtrl,
          obscureText: !_verActual,
          decoration: InputDecoration(
            labelText: 'Contraseña Actual',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.gray400, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_verActual ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.gray400, size: 20),
              onPressed: () => setState(() => _verActual = !_verActual),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passNuevaCtrl,
          obscureText: !_verNueva,
          decoration: InputDecoration(
            labelText: 'Nueva Contraseña',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.gray400, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_verNueva ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.gray400, size: 20),
              onPressed: () => setState(() => _verNueva = !_verNueva),
            ),
          ),
        ),
        // ── Indicadores de seguridad ──
        if (_passNuevaCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildRequisitosPassword(),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _passConfCtrl,
          obscureText: !_verConf,
          decoration: InputDecoration(
            labelText: 'Confirmar Contraseña',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.gray400, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_verConf ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.gray400, size: 20),
              onPressed: () => setState(() => _verConf = !_verConf),
            ),
          ),
        ),
        if (_errorPass.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.redLight, borderRadius: BorderRadius.circular(8)),
            child: Text(_errorPass, style: const TextStyle(fontSize: 12, color: AppTheme.red)),
          ),
        ],
        if (_exitoPass.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.greenLight, borderRadius: BorderRadius.circular(8)),
            child: Text(_exitoPass, style: const TextStyle(fontSize: 12, color: AppTheme.green)),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _loadingPass ? null : _cambiarPassword, child: const Text('CAMBIAR CONTRASEÑA')),
      ],
    );
  }

  Widget _buildRequisitosPassword() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Requisitos de seguridad:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.gray600)),
          const SizedBox(height: 6),
          _reqItem('Mínimo 8 caracteres',            _tieneLongitud),
          _reqItem('Al menos una mayúscula (A-Z)',    _tieneMayuscula),
          _reqItem('Al menos una minúscula (a-z)',    _tieneMinuscula),
          _reqItem('Al menos un número (0-9)',        _tieneNumero),
          _reqItem('Al menos un carácter especial (!@#\$...)', _tieneEspecial),
        ],
      ),
    );
  }

  Widget _reqItem(String label, bool cumple) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            cumple ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: cumple ? AppTheme.green : AppTheme.gray400,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, color: cumple ? AppTheme.green : AppTheme.gray400)),
        ],
      ),
    );
  }
}
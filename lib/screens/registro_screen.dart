import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/logo_header.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _nombresCtrl    = TextEditingController();
  final _apellidosCtrl  = TextEditingController();
  final _cedulaCtrl     = TextEditingController();
  final _correoCtrl     = TextEditingController();
  final _telCtrl        = TextEditingController();
  final _dirCtrl        = TextEditingController(); // <- AGREGADO
  final _fechaNacCtrl   = TextEditingController(); // <- AGREGADO
  final _userCtrl       = TextEditingController();
  final _passCtrl       = TextEditingController();

  String _genero = 'M';
  bool _loading  = false;
  bool _verPass  = false;
  String _error  = '';
  String _exito  = '';

  // Requisitos de contraseña en tiempo real
  bool get _passTieneLongitud  => _passCtrl.text.length >= 8;
  bool get _passTieneMayuscula => _passCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _passTieneMinuscula => _passCtrl.text.contains(RegExp(r'[a-z]'));
  bool get _passTieneNumero    => _passCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _passTieneEspecial  => _passCtrl.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'));

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _cedulaCtrl.dispose();
    _correoCtrl.dispose();
    _telCtrl.dispose();
    _dirCtrl.dispose();
    _fechaNacCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Actualizar indicadores de contraseña en tiempo real
    _passCtrl.addListener(() => setState(() {}));
  }

  // Función para seleccionar la fecha de nacimiento cómodamente
  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccionado = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );

    if (seleccionado != null) {
      setState(() {
        // Formato estricto YYYY-MM-DD requerido por PostgreSQL
        _fechaNacCtrl.text =
        "${seleccionado.year}-${seleccionado.month.toString().padLeft(2, '0')}-${seleccionado.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _registrar() async {
    if (_nombresCtrl.text.isEmpty || _apellidosCtrl.text.isEmpty ||
        _cedulaCtrl.text.isEmpty  || _correoCtrl.text.isEmpty ||
        _fechaNacCtrl.text.isEmpty || _dirCtrl.text.isEmpty ||
        _userCtrl.text.isEmpty    || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Completa todos los campos obligatorios (*).');
      return;
    }

    // Validar cédula: exactamente 10 dígitos numéricos
    if (_cedulaCtrl.text.trim().length != 10 || !RegExp(r'^\d{10}$').hasMatch(_cedulaCtrl.text.trim())) {
      setState(() => _error = 'La cédula debe tener exactamente 10 dígitos.');
      return;
    }

    // Validar formato de correo
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_correoCtrl.text.trim())) {
      setState(() => _error = 'Ingresa un correo electrónico válido.');
      return;
    }

    // Validar contraseña con todos los requisitos
    if (!_passTieneLongitud || !_passTieneMayuscula || !_passTieneMinuscula ||
        !_passTieneNumero   || !_passTieneEspecial) {
      setState(() => _error = 'La contraseña no cumple los requisitos de seguridad indicados.');
      return;
    }

    setState(() { _loading = true; _error = ''; _exito = ''; });

    // Enviamos el objeto JSON exacto que espera pacienteController.registrarPaciente
    final res = await AuthService.registrarPaciente({
      'nombres'         : _nombresCtrl.text.trim(),
      'apellidos'       : _apellidosCtrl.text.trim(),
      'cedula'          : _cedulaCtrl.text.trim(),
      'correo'          : _correoCtrl.text.trim(),
      'telefono': _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
      'direccion'       : _dirCtrl.text.trim(),       // <- ENVIADO
      'fecha_nacimiento': _fechaNacCtrl.text.trim(), // <- ENVIADO
      'username'        : _userCtrl.text.trim(),
      'password'        : _passCtrl.text,
      'genero'          : _genero,
    });

    setState(() => _loading = false);

    if (res['msg'] != null || res['id_usuario'] != null) {
      setState(() => _exito = '¡Cuenta creada exitosamente! Ya puedes iniciar sesión.');
    } else {
      setState(() => _error = res['error'] ?? 'Error al registrarse.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: LogoHeader(subtitle: 'Registro de paciente')),
            const SizedBox(height: 24),

            if (_exito.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppTheme.greenLight,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_exito,
                      style: const TextStyle(color: AppTheme.green, fontSize: 13))),
                ]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('IR AL LOGIN'),
              ),
            ] else ...[
              _label('Nombres *'),
              TextField(controller: _nombresCtrl,
                  decoration: const InputDecoration(labelText: 'Nombres completos')),
              const SizedBox(height: 12),

              _label('Apellidos *'),
              TextField(controller: _apellidosCtrl,
                  decoration: const InputDecoration(labelText: 'Apellidos completos')),
              const SizedBox(height: 12),

              _label('Cédula *'),
              TextField(controller: _cedulaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Número de cédula')),
              const SizedBox(height: 12),

              _label('Fecha de Nacimiento *'),
              TextField(
                controller: _fechaNacCtrl,
                readOnly: true, // Evita que escriban texto manual roto
                onTap: () => _seleccionarFecha(context),
                decoration: const InputDecoration(
                  labelText: 'YYYY-MM-DD',
                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),

              _label('Correo electrónico *'),
              TextField(controller: _correoCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'correo@ejemplo.com')),
              const SizedBox(height: 12),

              _label('Teléfono / Celular'),
              TextField(controller: _telCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: '09XXXXXXXX')),
              const SizedBox(height: 12),

              _label('Dirección *'),
              TextField(controller: _dirCtrl,
                  decoration: const InputDecoration(labelText: 'Calle principal, secundaria y nro. casa')),
              const SizedBox(height: 12),

              _label('Género'),
              Row(children: [
                _genderBtn('M', 'Masculino'),
                const SizedBox(width: 10),
                _genderBtn('F', 'Femenino'),
                const SizedBox(width: 10),
              ]),
              const SizedBox(height: 12),

              _label('Usuario *'),
              TextField(
                controller: _userCtrl,
                inputFormatters: [
                  // Solo letras, números y guión bajo — sin espacios ni símbolos
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Solo letras, números y _  (sin espacios)',
                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 20, color: AppTheme.gray400),
                ),
              ),
              const SizedBox(height: 12),

              _label('Contraseña *'),
              TextField(
                controller: _passCtrl,
                obscureText: !_verPass,
                decoration: InputDecoration(
                  labelText: 'Mín. 8 caracteres con mayúscula, número y carácter especial',
                  suffixIcon: IconButton(
                    icon: Icon(_verPass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                        color: AppTheme.gray400, size: 20),
                    onPressed: () => setState(() => _verPass = !_verPass),
                  ),
                ),
              ),
              // Indicadores de seguridad en tiempo real
              if (_passCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildRequisitosPassword(),
              ],

              if (_error.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppTheme.redLight,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error, style: const TextStyle(fontSize: 12, color: AppTheme.red)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _loading ? null : _registrar,
                child: _loading
                    ? const SizedBox(height: 22, width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('CREAR CUENTA'),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
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
          _reqItem('Mínimo 8 caracteres',                      _passTieneLongitud),
          _reqItem('Al menos una mayúscula (A-Z)',              _passTieneMayuscula),
          _reqItem('Al menos una minúscula (a-z)',              _passTieneMinuscula),
          _reqItem('Al menos un número (0-9)',                  _passTieneNumero),
          _reqItem('Al menos un carácter especial (!@#\$...)', _passTieneEspecial),
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
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 11, color: cumple ? AppTheme.green : AppTheme.gray400)),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4, top: 4),
    child: Text(text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.gray600)),
  );

  Widget _genderBtn(String val, String label) => GestureDetector(
    onTap: () => setState(() => _genero = val),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: _genero == val ? AppTheme.orange : Colors.white,
          border: Border.all(
              color: _genero == val ? AppTheme.orange : AppTheme.gray200),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: _genero == val ? Colors.white : AppTheme.gray600)),
    ),
  );
}
import 'dart:math';
import 'package:flutter/material.dart';
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
  final _dirCtrl        = TextEditingController();
  final _fechaNacCtrl   = TextEditingController();
  final _cedulaFocus    = FocusNode();

  String _genero = 'M';
  bool _loading  = false;
  String _error  = '';
  String _exito  = '';

  // ── Estado de la verificación de cédula ─────────────────────────────────
  bool _verificandoCedula = false;
  // true si la cédula ya pertenece a un PACIENTE existente: bloquea el registro
  bool _cedulaBloqueada = false;
  // true si la cédula ya pertenece a una cuenta con otro rol (ej. personal del
  // laboratorio): se le suma el rol Paciente sin generar credenciales nuevas
  bool _usuarioExistente = false;

  // Credenciales generadas automáticamente al registrar (se muestran en la
  // pantalla de éxito para que el paciente las guarde, ya que él no las elige)
  Map<String, String>? _credencialesGeneradas;

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _cedulaCtrl.dispose();
    _correoCtrl.dispose();
    _telCtrl.dispose();
    _dirCtrl.dispose();
    _fechaNacCtrl.dispose();
    _cedulaFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _cedulaFocus.addListener(() {
      if (!_cedulaFocus.hasFocus) _verificarCedula();
    });
  }

  // ── Quita tildes básicas (á->a, ñ->n, etc.) sin depender de paquetes extra ─
  String _quitarAcentos(String texto) {
    const conAcentos = 'áéíóúÁÉÍÓÚñÑüÜ';
    const sinAcentos = 'aeiouAEIOUnNuU';
    var resultado = texto;
    for (int i = 0; i < conAcentos.length; i++) {
      resultado = resultado.replaceAll(conAcentos[i], sinAcentos[i]);
    }
    return resultado;
  }

  String _limpiarPrimeraPalabra(String texto) {
    final sinAcentos = _quitarAcentos(texto);
    final partes = sinAcentos.trim().toLowerCase().split(RegExp(r'\s+'));
    if (partes.isEmpty) return '';
    return partes.first.replaceAll(RegExp(r'[^a-z]'), '');
  }

  // Genera un username legible: nombre + inicial de apellido + 3 dígitos de
  // la cédula (ej. "jennyg268"), igual que en la gestión web de pacientes.
  String _generarUsername(String nombres, String apellidos, String cedula) {
    final primerNombre = _limpiarPrimeraPalabra(nombres);
    final apellidoLimpio = _limpiarPrimeraPalabra(apellidos);
    final inicialApellido = apellidoLimpio.isNotEmpty ? apellidoLimpio[0] : '';
    final soloDigitos = cedula.replaceAll(RegExp(r'\D'), '');
    final sufijoCedula = soloDigitos.length >= 3
        ? soloDigitos.substring(soloDigitos.length - 3)
        : soloDigitos;
    final base = '$primerNombre$inicialApellido';
    return '${base.isEmpty ? "usuario" : base}$sufijoCedula';
  }

  // Contraseña temporal legible (sin caracteres ambiguos como 0/O, 1/l/I)
  String _generarPasswordTemporal() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final rnd = Random.secure();
    return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  // ── Verifica la cédula apenas el usuario sale del campo ─────────────────
  Future<void> _verificarCedula() async {
    final cedula = _cedulaCtrl.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(cedula)) return;

    setState(() {
      _verificandoCedula = true;
      _cedulaBloqueada = false;
      _usuarioExistente = false;
      _error = '';
    });

    final res = await AuthService.verificarCedula(cedula);

    if (res['existe'] == true) {
      if (res['esPaciente'] == true) {
        setState(() {
          _cedulaBloqueada = true;
          _error = 'Esta cédula ya está registrada como paciente. Si es tuya, '
              'inicia sesión en vez de crear una cuenta nueva.';
          _verificandoCedula = false;
        });
        return;
      }
      // Existe con otro rol (ej. personal del laboratorio): no se toca su
      // cuenta actual, solo se le sumará el rol de Paciente al guardar.
      setState(() {
        _usuarioExistente = true;
        _verificandoCedula = false;
      });
      return;
    }

    // No existe en el sistema aún → autocompletar nombres/apellidos con el SRI
    final sri = await AuthService.consultarSRI(cedula);
    if (sri['encontrado'] == true) {
      setState(() {
        if (_nombresCtrl.text.trim().isEmpty) {
          _nombresCtrl.text = sri['nombres'] ?? '';
        }
        if (_apellidosCtrl.text.trim().isEmpty) {
          _apellidosCtrl.text = sri['apellidos'] ?? '';
        }
      });
    }
    setState(() => _verificandoCedula = false);
  }

  Future<void> _registrar() async {
    if (_cedulaBloqueada) {
      setState(() => _error = 'Esta cédula ya está registrada como paciente.');
      return;
    }

    final cedulaActual = _cedulaCtrl.text.trim();
    if (cedulaActual.isEmpty ||
        cedulaActual.length != 10 ||
        !RegExp(r'^\d{10}$').hasMatch(cedulaActual)) {
      setState(() => _error = 'La cédula debe tener exactamente 10 dígitos.');
      return;
    }
    // Estos dos son datos de la tabla paciente: siempre obligatorios, sin
    // importar si la cuenta ya existía con otro rol o es totalmente nueva.
    if (_fechaNacCtrl.text.isEmpty || _dirCtrl.text.isEmpty) {
      setState(() => _error = 'Completa todos los campos obligatorios (*).');
      return;
    }

    setState(() { _loading = true; _error = ''; _exito = ''; });

    // ── Chequeo de seguridad justo antes de enviar ──────────────────────
    // No confiamos solo en el aviso que se mostró al salir del campo cédula
    // (pudo no haberse disparado a tiempo). Volvemos a consultar aquí mismo,
    // con el resultado fresco, para decidir qué campos exigir y si se
    // generan credenciales nuevas o no.
    final estadoCedula = await AuthService.verificarCedula(cedulaActual);

    // Si la consulta falló (servidor caído, sin internet, o la ruta nueva del
    // backend todavía no está desplegada), NO asumimos que la cédula es
    // nueva: sería peligroso generar credenciales sin saber si ya existía una
    // cuenta. Avisamos y detenemos el registro.
    if (estadoCedula['error'] != null) {
      setState(() {
        _loading = false;
        _error = 'No se pudo verificar tu cédula (${estadoCedula['error']}). '
            'Intenta de nuevo en unos segundos.';
      });
      return;
    }

    final bool cedulaBloqueadaFresca = estadoCedula['esPaciente'] == true;
    final bool usuarioExistenteFresco =
        estadoCedula['existe'] == true && estadoCedula['esPaciente'] != true;

    setState(() {
      _cedulaBloqueada = cedulaBloqueadaFresca;
      _usuarioExistente = usuarioExistenteFresco;
    });

    if (cedulaBloqueadaFresca) {
      setState(() {
        _loading = false;
        _error = 'Esta cédula ya está registrada como paciente. Si es tuya, '
            'inicia sesión en vez de crear una cuenta nueva.';
      });
      return;
    }

    // Nombres, apellidos y correo solo se piden (y se validan) cuando la
    // cuenta es totalmente nueva. Si la cédula ya pertenece a alguien con
    // otro rol, esos datos ya existen en la tabla usuario y el backend los
    // ignora, así que no tiene sentido exigirlos aquí.
    if (!usuarioExistenteFresco) {
      if (_nombresCtrl.text.isEmpty || _apellidosCtrl.text.isEmpty ||
          _correoCtrl.text.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Completa todos los campos obligatorios (*).';
        });
        return;
      }
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_correoCtrl.text.trim())) {
        setState(() {
          _loading = false;
          _error = 'Ingresa un correo electrónico válido.';
        });
        return;
      }
    }

    final datosBase = <String, dynamic>{
      'nombres'         : _nombresCtrl.text.trim(),
      'apellidos'       : _apellidosCtrl.text.trim(),
      'cedula'          : cedulaActual,
      'correo'          : _correoCtrl.text.trim(),
      'telefono'        : _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
      'direccion'       : _dirCtrl.text.trim(),
      'fecha_nacimiento': _fechaNacCtrl.text.trim(),
      'genero'          : _genero,
    };

    Map<String, dynamic> res;
    String? usuarioGenerado;
    String? passwordGenerado;

    if (usuarioExistenteFresco) {
      // La cédula ya pertenece a una cuenta existente: no se generan
      // credenciales nuevas, el backend conserva las que ya tenía.
      res = await AuthService.registrarPaciente(datosBase);
    } else {
      usuarioGenerado = _generarUsername(
          _nombresCtrl.text, _apellidosCtrl.text, _cedulaCtrl.text);
      passwordGenerado = _generarPasswordTemporal();

      res = await AuthService.registrarPaciente({
        ...datosBase,
        'username': usuarioGenerado,
        'password': passwordGenerado,
      });

      // Si por coincidencia ese username ya está en uso, reintenta una vez
      // con un sufijo numérico (igual que en la gestión web de pacientes).
      final mensaje = (res['error'] ?? res['msg'] ?? '').toString().toLowerCase();
      if (mensaje.contains('usuario ya está en uso') ||
          mensaje.contains('nombre de usuario ya')) {
        final sufijo = (10 + Random().nextInt(80)).toString();
        usuarioGenerado = '$usuarioGenerado$sufijo';
        res = await AuthService.registrarPaciente({
          ...datosBase,
          'username': usuarioGenerado,
          'password': passwordGenerado,
        });
      }
    }

    setState(() => _loading = false);

    if (res['msg'] != null || res['id_usuario'] != null) {
      setState(() {
        if (usuarioExistenteFresco) {
          _credencialesGeneradas = null;
          _exito = 'Tu cédula ya tenía una cuenta en el sistema; le agregamos '
              'el acceso de Paciente. Ingresa con tu usuario y contraseña '
              'actuales, no cambiaron.';
        } else {
          _credencialesGeneradas = {
            'username': usuarioGenerado!,
            'password': passwordGenerado!,
          };
          _exito = '¡Cuenta creada exitosamente! Guarda tu usuario y '
              'contraseña, los necesitarás para iniciar sesión. Si no '
              'inicias sesión dentro de 1 mes, tu cuenta estará inactiva y '
              'deberás acercarte al laboratorio para activarla.';
        }
      });
    } else {
      setState(() => _error = res['error'] ?? 'Error al registrarse.');
    }
  }

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
        _fechaNacCtrl.text =
        "${seleccionado.year}-${seleccionado.month.toString().padLeft(2, '0')}-${seleccionado.day.toString().padLeft(2, '0')}";
      });
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
              if (_credencialesGeneradas != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    border: Border.all(color: const Color(0xFFFDBA74), width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tus credenciales de acceso',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.dark)),
                      const SizedBox(height: 8),
                      Text('Usuario: ${_credencialesGeneradas!['username']}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.dark)),
                      const SizedBox(height: 4),
                      Text('Contraseña: ${_credencialesGeneradas!['password']}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.dark)),
                      const SizedBox(height: 8),
                      const Text('Guárdalos ahora: no se volverán a mostrar. '
                          'Puedes cambiar tu contraseña más tarde desde tu perfil.',
                          style: TextStyle(fontSize: 11, color: AppTheme.gray600)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('IR AL LOGIN'),
              ),
            ] else ...[
              _label('Cédula *'),
              TextField(
                key: const ValueKey('campo_cedula'),
                controller: _cedulaCtrl,
                focusNode: _cedulaFocus,
                keyboardType: TextInputType.number,
                onEditingComplete: _verificarCedula,
                decoration: InputDecoration(
                  labelText: 'Número de cédula',
                  suffixIcon: _verificandoCedula
                      ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        height: 16, width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              const Text('Ingresa primero tu cédula: así podemos autocompletar tus datos.',
                  style: TextStyle(fontSize: 11, color: AppTheme.gray400)),
              if (_usuarioExistente) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppTheme.orangeLight,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'Esta cédula ya tiene una cuenta en el sistema (por ejemplo, '
                        'personal del laboratorio). Ya tenemos tus nombres, apellidos, '
                        'correo, usuario y contraseña — no hace falta que los repitas. '
                        'Solo completa los datos de abajo para tu perfil de paciente.',
                    style: TextStyle(fontSize: 11, color: AppTheme.dark),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                const SizedBox(height: 12),

                _label('Nombres *'),
                TextField(
                    key: const ValueKey('campo_nombres'),
                    controller: _nombresCtrl,
                    decoration: const InputDecoration(labelText: 'Nombres completos')),
                const SizedBox(height: 12),

                _label('Apellidos *'),
                TextField(
                    key: const ValueKey('campo_apellidos'),
                    controller: _apellidosCtrl,
                    decoration: const InputDecoration(labelText: 'Apellidos completos')),
                const SizedBox(height: 12),
              ],

              _label('Fecha de Nacimiento *'),
              TextField(
                key: const ValueKey('campo_fecha_nac'),
                controller: _fechaNacCtrl,
                readOnly: true,
                onTap: () => _seleccionarFecha(context),
                decoration: const InputDecoration(
                  labelText: 'YYYY-MM-DD',
                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),

              if (!_usuarioExistente) ...[
                _label('Correo electrónico *'),
                TextField(
                    key: const ValueKey('campo_correo'),
                    controller: _correoCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'correo@ejemplo.com')),
                const SizedBox(height: 12),
              ],

              _label('Teléfono / Celular'),
              TextField(
                  key: const ValueKey('campo_telefono'),
                  controller: _telCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: '09XXXXXXXX')),
              const SizedBox(height: 12),

              _label('Dirección *'),
              TextField(
                  key: const ValueKey('campo_direccion'),
                  controller: _dirCtrl,
                  decoration: const InputDecoration(labelText: 'Calle principal, secundaria y nro. casa')),
              const SizedBox(height: 12),

              _label('Género'),
              Row(children: [
                _genderBtn('M', 'Masculino'),
                const SizedBox(width: 10),
                _genderBtn('F', 'Femenino'),
                const SizedBox(width: 10),
              ]),

              if (!_usuarioExistente) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.gray200)),
                  child: const Text(
                    'Tu usuario y contraseña se generarán automáticamente al '
                        'crear la cuenta y se te mostrarán al final.',
                    style: TextStyle(fontSize: 11, color: AppTheme.gray600),
                  ),
                ),
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
                onPressed: (_loading || _cedulaBloqueada) ? null : _registrar,
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
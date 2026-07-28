import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class RecuperarPasswordScreen extends StatefulWidget {
  const RecuperarPasswordScreen({super.key});
  @override
  State<RecuperarPasswordScreen> createState() => _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  int _paso = 1;
  final _correoCtrl = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _confirmCtrl= TextEditingController();
  String _codigo = '';
  String _error  = '';
  bool _loading  = false;
  bool _verPass  = false;
  bool _exito    = false;

  Future<void> _enviarCodigo() async {
    if (_correoCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa tu correo.');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    final res = await AuthService.solicitarCodigo(_correoCtrl.text.trim());
    setState(() => _loading = false);
    if (res['msg'] != null && res['msg'].toString().contains('éxito')) {
      setState(() => _paso = 2);
    } else {
      setState(() => _error = res['msg'] ?? res['error'] ?? 'Correo no registrado.');
    }
  }

  Future<void> _cambiarPassword() async {
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    final pass = _passCtrl.text;
    final cumpleRequisitos = pass.length >= 8 &&
        pass.contains(RegExp(r'[A-Z]')) &&
        pass.contains(RegExp(r'[a-z]')) &&
        pass.contains(RegExp(r'[0-9]')) &&
        pass.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'));
    if (!cumpleRequisitos) {
      setState(() => _error =
      'Mínimo 8 caracteres, con mayúscula, minúscula, número y carácter especial.');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    final res = await AuthService.validarYCambiarPassword(
      correo: _correoCtrl.text.trim(),
      codigo: _codigo,
      nuevaPassword: _passCtrl.text,
    );
    setState(() => _loading = false);
    if (res['msg'] != null && res['msg'].toString().contains('correctamente')) {
      setState(() => _exito = true);
    } else {
      setState(() => _error = res['msg'] ?? res['error'] ?? 'Código incorrecto.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_exito) return _buildExitoScreen();
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
                  child: Column(children: [
                    _buildProgressBar(),
                    const SizedBox(height: 6),
                    _buildPasoLabel(),
                    const SizedBox(height: 16),
                    if (_paso == 1) _buildPaso1(),
                    if (_paso == 2) _buildPaso2(),
                    if (_paso == 3) _buildPaso3(),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppTheme.redLight,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(_error,
                            style: const TextStyle(fontSize: 12, color: AppTheme.red)),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final icons = [Icons.lock_outline_rounded, Icons.shield_outlined, Icons.edit_outlined];
    final titles = ['Recuperar contraseña', 'Ingresa el código', 'Nueva contraseña'];
    final subs = [
      'Te enviaremos un código de verificación',
      'Código de 6 dígitos enviado a tu correo',
      'Elige una contraseña segura',
    ];
    return Container(
      color: AppTheme.orange,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        bottom: 36, left: 20, right: 20,
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => _paso > 1
                ? setState(() { _paso--; _error = ''; })
                : Navigator.pop(context),
            child: const Row(children: [
              Icon(Icons.chevron_left, color: Colors.white, size: 22),
              Text('Volver', style: TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Container(
          width: 58, height: 58,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Icon(icons[_paso - 1], color: Colors.white, size: 30),
        ),
        const SizedBox(height: 10),
        Text(titles[_paso - 1],
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subs[_paso - 1],
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: List.generate(3, (i) => Expanded(
        child: Container(
          height: 4,
          margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
          decoration: BoxDecoration(
              color: i < _paso ? AppTheme.orange : AppTheme.gray200,
              borderRadius: BorderRadius.circular(2)),
        ),
      )),
    );
  }

  Widget _buildPasoLabel() {
    final labels = [
      'Paso 1 de 3 — Verificar correo',
      'Paso 2 de 3 — Ingresar código',
      'Paso 3 de 3 — Nueva contraseña',
    ];
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(labels[_paso - 1],
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.orange)),
    );
  }

  Widget _buildPaso1() {
    return Column(children: [
      TextField(
        controller: _correoCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Correo registrado',
          prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppTheme.gray400),
        ),
      ),
      const SizedBox(height: 6),
      const Text('Recibirás un código válido para un solo uso.',
          style: TextStyle(fontSize: 11, color: AppTheme.gray400)),
      const SizedBox(height: 18),
      ElevatedButton(
        onPressed: _loading ? null : _enviarCodigo,
        child: _loading
            ? const SizedBox(height: 22, width: 22,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('ENVIAR CÓDIGO'),
      ),
    ]);
  }

  Widget _buildPaso2() {
    return Column(children: [
      const Text('Código de 6 dígitos',
          style: TextStyle(fontSize: 13, color: AppTheme.gray600)),
      const SizedBox(height: 14),
      PinCodeTextField(
        appContext: context,
        length: 6,
        onChanged: (val) => _codigo = val,
        onCompleted: (val) {
          _codigo = val;
          setState(() { _paso = 3; _error = ''; });
        },
        pinTheme: PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: BorderRadius.circular(10),
          fieldHeight: 50,
          fieldWidth: 44,
          activeFillColor: AppTheme.orangeLight,
          selectedFillColor: AppTheme.orangeLight,
          inactiveFillColor: const Color(0xFFFAFAFA),
          activeColor: AppTheme.orange,
          selectedColor: AppTheme.orange,
          inactiveColor: AppTheme.gray200,
        ),
        enableActiveFill: true,
        cursorColor: AppTheme.orange,
        keyboardType: TextInputType.number,
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Código de un solo uso',
              style: TextStyle(fontSize: 11, color: AppTheme.gray400)),
          TextButton(
            onPressed: _enviarCodigo,
            child: const Text('Reenviar',
                style: TextStyle(color: AppTheme.orange, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ]);
  }

  Widget _buildPaso3() {
    return Column(children: [
      TextField(
        controller: _passCtrl,
        obscureText: !_verPass,
        decoration: InputDecoration(
          labelText: 'Nueva contraseña',
          prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppTheme.gray400),
          suffixIcon: IconButton(
            icon: Icon(_verPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20, color: AppTheme.gray400),
            onPressed: () => setState(() => _verPass = !_verPass),
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _confirmCtrl,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Confirmar contraseña',
          prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppTheme.gray400),
        ),
      ),
      const SizedBox(height: 18),
      ElevatedButton(
        onPressed: _loading ? null : _cambiarPassword,
        child: _loading
            ? const SizedBox(height: 22, width: 22,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('CAMBIAR CONTRASEÑA'),
      ),
    ]);
  }

  Widget _buildExitoScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(
                    color: AppTheme.greenLight, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: AppTheme.green, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('¡Contraseña actualizada!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.dark)),
              const SizedBox(height: 8),
              const Text('Ya puedes ingresar con tu nueva contraseña.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.gray600)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('IR AL INICIO DE SESIÓN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
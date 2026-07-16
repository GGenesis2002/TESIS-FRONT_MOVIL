import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String get _base {
    return 'https://tesis-backend-qr.onrender.com/api';
  }
  static String get baseUrl => _base;
  static const _timeout = Duration(seconds: 12);

  // ── LOGIN ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    try {
      final res = await http
          .post(
        Uri.parse('$_base/login/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      )
          .timeout(_timeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── REGISTRO PACIENTE ──────────────────────────────────
  static Future<Map<String, dynamic>> registrarPaciente(
      Map<String, dynamic> datos) async {
    try {
      final res = await http
          .post(
        Uri.parse('$_base/pacientes/registro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(datos),
      )
          .timeout(_timeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // Base sin '/api', para endpoints montados en la raíz del backend (ej. /documento)
  static String get _baseRoot => _base.replaceFirst(RegExp(r'/api$'), '');

  // ── VERIFICAR CÉDULA (público, para el registro) ───────
  // Solo confirma si la cédula ya existe en el sistema y si ya tiene el rol
  // Paciente. No expone datos personales de nadie.
  static Future<Map<String, dynamic>> verificarCedula(String cedula) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/pacientes/verificar-cedula/$cedula'))
          .timeout(_timeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── CONSULTAR SRI (autocompletar nombres/apellidos por cédula) ─
  static Future<Map<String, dynamic>> consultarSRI(String cedula) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseRoot/documento/consultar/$cedula'))
          .timeout(_timeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── EDITAR PERFIL PROPIO ───────────────────────────────
  static Future<Map<String, dynamic>> editarPerfil(
      String token, Map<String, dynamic> datos) async {
    try {
      final res = await http
          .put(
        Uri.parse('$_base/pacientes/perfil'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(datos),
      )
          .timeout(_timeout);
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['perfil'] != null) {
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString('user');
        if (userStr != null) {
          final user = jsonDecode(userStr) as Map<String, dynamic>;
          final perfil = body['perfil'] as Map<String, dynamic>;
          user['nombres']          = perfil['nombres'];
          user['apellidos']        = perfil['apellidos'];
          user['correo']           = perfil['correo'];
          user['telefono']         = perfil['telefono'];
          user['direccion']        = perfil['direccion'];
          user['genero']           = perfil['genero'];
          user['fecha_nacimiento'] = perfil['fecha_nacimiento'];
          await prefs.setString('user', jsonEncode(user));
        }
      }
      return body;
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── RECUPERAR USUARIO ──────────────────────────────────
  static Future<Map<String, dynamic>> recuperarUsuario(
      String identificador) async {
    try {
      final res = await http
          .post(
        Uri.parse('$_base/login/recuperar-usuario'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identificador': identificador}),
      )
          .timeout(_timeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── SOLICITAR CÓDIGO RESET PASSWORD ───────────────────
  static Future<Map<String, dynamic>> solicitarCodigo(String correo) async {
    try {
      final res = await http
          .post(
        Uri.parse('$_base/login/solicitar-codigo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'correo': correo}),
      )
          .timeout(_timeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── VALIDAR CÓDIGO Y CAMBIAR PASSWORD ─────────────────
  static Future<Map<String, dynamic>> validarYCambiarPassword({
    required String correo,
    required String codigo,
    required String nuevaPassword,
  }) async {
    try {
      final res = await http
          .post(
        Uri.parse('$_base/login/validar-codigo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo': correo,
          'codigo': codigo,
          'nuevaPassword': nuevaPassword,
        }),
      )
          .timeout(_timeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── MIS ÓRDENES (paciente) ─────────────────────────────
  static Future<Map<String, dynamic>> misOrdenes(String token) async {
    try {
      final res = await http
          .get(
        Uri.parse('$_base/ordenes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )
          .timeout(_timeout);
      return {'data': jsonDecode(res.body)};
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── OBTENER DETALLE DE ORDEN ──────────────────────────
  static Future<Map<String, dynamic>> obtenerDetalleOrden(String token, int idOrden) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/ordenes/$idOrden/detalle'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);
      return {'data': jsonDecode(res.body)};
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── ÓRDENES VALIDADAS DEL PACIENTE (para pantalla Resultados) ──
  static Future<Map<String, dynamic>> ordenesValidadasPaciente(String token) async {
    try {
      final res = await http
          .get(
        Uri.parse('$_base/resultado/paciente/ordenes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )
          .timeout(_timeout);
      return {'data': jsonDecode(res.body)};
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── DETALLE DE RESULTADOS DE UNA ORDEN (paciente) ─────
  static Future<Map<String, dynamic>> detalleResultadosPaciente(
      String token, int idOrden) async {
    try {
      final res = await http
          .get(
        Uri.parse('$_base/resultado/paciente/orden/$idOrden'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )
          .timeout(_timeout);
      return {'data': jsonDecode(res.body)};
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── MIS RESULTADOS (paciente) ─────────────────────────
  static Future<Map<String, dynamic>> misResultados(
      String token, int idOrden) async {
    try {
      final res = await http
          .get(
        Uri.parse('$_base/resultados/paciente/orden/$idOrden'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )
          .timeout(_timeout);
      final body = jsonDecode(res.body);
      // El backend devuelve { data: [...] }, lo pasamos directo
      return body is Map && body['data'] != null
          ? body as Map<String, dynamic>
          : {'data': body};
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── NOTIFICACIONES ─────────────────────────────────────
  static Future<Map<String, dynamic>> misNotificaciones(
      String token, {int? idUsuarioRol}) async {
    try {
      final res = await http
          .get(
        Uri.parse('$_base/notificaciones'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          if (idUsuarioRol != null)
            'x-id-usuario-rol': idUsuarioRol.toString(),
        },
      )
          .timeout(_timeout);
      return {'data': jsonDecode(res.body)};
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── CATEGORÍAS ─────────────────────────────────────────
  static Future<Map<String, dynamic>> listarCategorias(String token) async {
    try {
      final res = await http
          .get(
        Uri.parse('$_base/categorias'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )
          .timeout(_timeout);
      return {'data': jsonDecode(res.body)};
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── EXÁMENES POR CATEGORÍA ─────────────────────────────
  static Future<Map<String, dynamic>> listarExamenesPorCategoria(
      String token, int idCategoria) async {
    try {
      final res = await http
          .get(
        Uri.parse('$_base/examenes?id_categoria=$idCategoria'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )
          .timeout(_timeout);
      return {'data': jsonDecode(res.body)};
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── CREAR PRE-ORDEN ────────────────────────────────────
  static Future<Map<String, dynamic>> crearOrden(
      String token, List<Map<String, dynamic>> examenes) async {
    try {
      final res = await http
          .post(
        Uri.parse('$_base/ordenes/paciente/generar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'examenes': examenes}),
      )
          .timeout(_timeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── ELIMINAR ORDEN ─────────────────────────────────────
  static Future<Map<String, dynamic>> eliminarOrden(
      String token, int idOrden) async {
    try {
      final res = await http
          .delete(
        Uri.parse('$_base/ordenes/$idOrden'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )
          .timeout(_timeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── EDITAR ORDEN (paciente) ────────────────────────────
  static Future<Map<String, dynamic>> editarOrdenPaciente(
      String token, int idOrden, List<Map<String, dynamic>> examenes) async {
    try {
      final res = await http
          .put(
        Uri.parse('$_base/ordenes/paciente/$idOrden/editar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'examenes': examenes}),
      )
          .timeout(_timeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── OBTENER PERFIL COMPLETO ────────────────────────────
  static Future<Map<String, dynamic>> obtenerPerfilCompleto(String token) async {
    try {
      final res = await http
          .get(
        Uri.parse('$_base/pacientes/perfil'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )
          .timeout(_timeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {'error': 'El servidor tardó demasiado. Verifica tu conexión.'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ── GUARDAR / LEER TOKEN LOCAL ─────────────────────────
  static Future<void> guardarSesion(
      String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user', jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> leerSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final token   = prefs.getString('token');
    final userStr = prefs.getString('user');
    if (token == null || userStr == null) return null;
    return {
      'token': token,
      'user': jsonDecode(userStr),
    };
  }

  // ── ACTUALIZAR DATOS PACIENTE ──────────────────────────
  static Future<Map<String, dynamic>> actualizarPaciente({
    required String token,
    required String idUsuario,
    required Map<String, dynamic> datos,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$_base/pacientes/$idUsuario'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(datos),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }


  // ── Marcar una notificación como leída ────────────────────────────────────────
  static Future<Map<String, dynamic>> leerNotificacion(
      String token, dynamic id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notificaciones/$id/leer'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return {'data': jsonDecode(response.body)};
      }
      return {'error': 'Error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

// ── Eliminar una notificación ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> eliminarNotificacion(
      String token, dynamic id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notificaciones/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return {'ok': true};
      }
      return {'error': 'Error ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }


  // ── CAMBIAR CONTRASEÑA (usuario logueado) ──────────────
  static Future<Map<String, dynamic>> cambiarPassword({
    required String token,
    required String actual,
    required String nueva,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$_base/usuarios/update-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'actual': actual, 'nueva': nueva}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  static Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
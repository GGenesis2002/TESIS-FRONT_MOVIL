import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class NotificacionesScreen extends StatefulWidget {
  final String token;
  const NotificacionesScreen({super.key, required this.token});
  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  List<dynamic> _notifs = [];
  Timer? _refreshTimer;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _cargar(); // primera carga: sí mostramos el spinner de pantalla completa
    // Auto-refresh cada 30 segundos (silencioso, sin parpadeo de pantalla)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _cargar(silencioso: true);
    });
  }

  // ─── Carga las notificaciones desde el backend ───────────────────────────
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Si [silencioso] es true (auto-refresh en segundo plano), no se muestra
  // el loading de pantalla completa ni se limpia el contenido actual:
  // la lista solo se actualiza "por debajo" cuando llegan los nuevos datos,
  // para que el usuario no note que se está actualizando.
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    final sesion = await AuthService.leerSesion();
    final idUsuarioRol = sesion?['user']?['id_usuario_rol'] as int?;
    final res = await AuthService.misNotificaciones(widget.token, idUsuarioRol: idUsuarioRol);
    if (!mounted) return;
    if (!silencioso) setState(() => _loading = false);

    if (res['data'] != null) {
      final data = res['data'];
      setState(() {
        _notifs = data['notificaciones'] ?? [];
      });
    } else {
      // En modo silencioso no mostramos error de pantalla completa;
      // simplemente se intenta de nuevo en el próximo ciclo.
      if (!silencioso) {
        setState(() => _error = res['error'] ?? 'Error al cargar notificaciones.');
      }
    }
  }

  // ─── Marca una notificación como leída ───────────────────────────────────
  Future<void> _marcarLeida(dynamic notif) async {
    if (notif['leido'] == true) return;
    final id = notif['id_notificacion'];
    final res = await AuthService.leerNotificacion(widget.token, id);
    if (res['data'] != null) {
      setState(() {
        final idx = _notifs.indexWhere((n) => n['id_notificacion'] == id);
        if (idx != -1) _notifs[idx] = {..._notifs[idx], 'leido': true};
      });
    } else {
      _mostrarError('No se pudo marcar como leída.');
    }
  }

  // ─── Elimina una notificación ─────────────────────────────────────────────
  Future<void> _eliminar(dynamic notif) async {
    final id = notif['id_notificacion'];
    final res = await AuthService.eliminarNotificacion(widget.token, id);
    if (res['ok'] == true) {
      setState(() => _notifs.removeWhere((n) => n['id_notificacion'] == id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notificación eliminada'),
            backgroundColor: AppTheme.gray400,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      _mostrarError('No se pudo eliminar la notificación.');
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Formatea la fecha mostrando "hace X tiempo" ──────────────────────────
  String _formatearFecha(dynamic fecha) {
    if (fecha == null) return '';
    try {
      final dt = DateTime.parse(fecha.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Ahora mismo';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
      if (diff.inDays == 1) return 'Ayer';
      if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
      return fecha.toString().substring(0, 10);
    } catch (_) {
      return fecha.toString().length > 10
          ? fecha.toString().substring(0, 10)
          : fecha.toString();
    }
  }

  // ─── Determina el ícono según el contenido del mensaje ───────────────────
  IconData _iconoPorMensaje(String mensaje) {
    final m = mensaje.toLowerCase();
    if (m.contains('resultado') || m.contains('examen') || m.contains('listo')) {
      return Icons.science_rounded;
    }
    if (m.contains('pago') || m.contains('orden') || m.contains('pagar')) {
      return Icons.payment_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final noLeidas = _notifs.where((n) => n['leido'] != true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logoLab.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 10),
            const Text('Notificaciones'),
            if (noLeidas > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$noLeidas',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _cargar,
          ),
        ],
      ),

      body: _loading
          ? const Center(
        child: CircularProgressIndicator(color: AppTheme.orange),
      )
          : _error.isNotEmpty
          ? _buildError()
          : _notifs.isEmpty
          ? _buildVacio()
          : _buildLista(),
    );
  }

  // ─── Estado vacío ─────────────────────────────────────────────────────────
  Widget _buildVacio() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 64, color: AppTheme.gray400),
          SizedBox(height: 16),
          Text(
            'No tienes notificaciones',
            style: TextStyle(fontSize: 15, color: AppTheme.gray400, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Aquí aparecerán tus alertas\nde resultados y pagos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.gray400),
          ),
        ],
      ),
    );
  }

  // ─── Estado de error ──────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.red),
          const SizedBox(height: 12),
          Text(_error, style: const TextStyle(color: AppTheme.red, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.orange),
          ),
        ],
      ),
    );
  }

  // ─── Lista principal con swipe para eliminar ──────────────────────────────
  Widget _buildLista() {
    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      color: AppTheme.orange,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _notifs.length,
        itemBuilder: (_, i) {
          final n = _notifs[i];
          return _buildItem(n);
        },
      ),
    );
  }

  // ─── Tarjeta individual con swipe ─────────────────────────────────────────
  Widget _buildItem(dynamic n) {
    final leido = n['leido'] == true;
    final mensaje = n['mensaje']?.toString() ?? '';

    return Dismissible(
      key: ValueKey(n['id_notificacion']),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar notificación'),
            content: const Text('¿Estás seguro de que quieres eliminar esta notificación?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => _eliminar(n),
      child: GestureDetector(
        onTap: () => _marcarLeida(n),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: leido ? Colors.white : AppTheme.orangeLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: leido ? AppTheme.gray200 : AppTheme.orangeBorder,
            ),
            boxShadow: leido
                ? []
                : [
              BoxShadow(
                color: AppTheme.orange.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: leido ? AppTheme.gray100 : AppTheme.orange,
              child: Icon(
                _iconoPorMensaje(mensaje),
                color: leido ? AppTheme.gray400 : Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              mensaje,
              style: TextStyle(
                fontSize: 13,
                fontWeight: leido ? FontWeight.w400 : FontWeight.w600,
                color: AppTheme.dark,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text(
                    _formatearFecha(n['fecha']),
                    style: const TextStyle(fontSize: 11, color: AppTheme.gray400),
                  ),
                  if (!leido) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Nueva',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing: leido
                ? null
                : const Icon(
              Icons.circle,
              size: 10,
              color: AppTheme.orange,
            ),
          ),
        ),
      ),
    );
  }
}
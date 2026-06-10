import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/bottom_nav.dart';
import 'login_screen.dart';
import 'ordenes_screen.dart';
import 'resultados_screen.dart';
import 'notificaciones_screen.dart';
import 'editar_perfil_screen.dart';
import '../widgets/logo_header.dart';

class HomeScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const HomeScreen({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;
  int _notifNoLeidas = 0;
  Timer? _refreshTimer;
  late Map<String, dynamic> _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    // Si la sesión guardada no tiene telefono/direccion (usuarios registrados antes
    // del fix, o primer login), los cargamos desde el backend una sola vez.
    if (_currentUser['telefono'] == null && _currentUser['direccion'] == null) {
      _hidratarPerfil();
    }
    _cargarNotifNoLeidas();
    // Auto-refresh cada 30 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _cargarNotifNoLeidas();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _hidratarPerfil() async {
    final res = await AuthService.obtenerPerfilCompleto(widget.token);
    if (res['perfil'] != null) {
      final perfil = res['perfil'] as Map<String, dynamic>;
      setState(() {
        _currentUser['telefono']         = perfil['telefono'];
        _currentUser['direccion']        = perfil['direccion'];
        _currentUser['genero']           = perfil['genero'];
        _currentUser['fecha_nacimiento'] = perfil['fecha_nacimiento'];
        _currentUser['cedula']           = perfil['cedula'];
      });
      // Persistir para futuros arranques
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(_currentUser));
    }
  }

  Future<void> _cargarNotifNoLeidas() async {
    final sesion = await AuthService.leerSesion();
    final idUsuarioRol = sesion?['user']?['id_usuario_rol'] as int?;
    final res = await AuthService.misNotificaciones(widget.token, idUsuarioRol: idUsuarioRol);
    if (!mounted) return;
    if (res['data'] != null) {
      final notifs = res['data']['notificaciones'] ?? [];
      setState(() {
        _notifNoLeidas = (notifs as List).where((n) => n['leido'] != true).length;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService.cerrarSesion();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Definimos las pantallas aquí para que hereden los cambios en _currentUser en cada rebuild
    final screens = [
      _HomeDashboard(
        token: widget.token,
        user: _currentUser,
        onNuevaOrden: () => setState(() => _idx = 1),
      ),
      OrdenesScreen(token: widget.token),
      ResultadosScreen(token: widget.token),
      NotificacionesScreen(token: widget.token),
      _PerfilTab(
        token: widget.token,
        user: _currentUser,
        onLogout: _logout,
        onUpdateUser: (newUser) {
          setState(() {
            _currentUser = newUser;
          });
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _idx,
        children: screens,
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _idx,
        notifCount: _notifNoLeidas,
        onTap: (i) {
          if (i == 3) _cargarNotifNoLeidas(); // refresca al entrar a Alertas
          setState(() => _idx = i);
        },
      ),
    );
  }
}

// ───────────────── Dashboard ─────────────────
class _HomeDashboard extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  final VoidCallback onNuevaOrden;

  const _HomeDashboard({
    required this.token,
    required this.user,
    required this.onNuevaOrden,
  });

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  int _totalOrdenes = 0;
  int _totalResultados = 0;
  List<dynamic> _ultimasOrdenes = [];
  Timer? _dashTimer;
  bool _loadingStats = true;
  // Órdenes generadas hace más de 2 días sin pagar
  List<dynamic> _ordenesPendientesVencidas = [];

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
    _dashTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _cargarEstadisticas();
    });
  }

  @override
  void dispose() {
    _dashTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarEstadisticas() async {
    final res = await AuthService.misOrdenes(widget.token);
    if (!mounted) return;
    setState(() => _loadingStats = false);
    if (res['data'] != null && res['data'] is List) {
      final todas = res['data'] as List;
      final ahora = DateTime.now();
      setState(() {
        _totalOrdenes = todas.length;
        _totalResultados = todas.where((o) => o['estado'] == 'Validado').length;
        _ultimasOrdenes = todas.take(3).toList();
        // Detectar órdenes 'Generada' con más de 2 días sin pagar
        _ordenesPendientesVencidas = todas.where((o) {
          if (o['estado'] != 'Generada') return false;
          try {
            final fecha = DateTime.parse(o['fecha_orden'].toString());
            return ahora.difference(fecha).inDays >= 2;
          } catch (_) { return false; }
        }).toList();
      });
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Publicado': return AppTheme.green;
      case 'Pagada':    return AppTheme.blue;
      case 'Cancelada': return AppTheme.red;
      default:          return AppTheme.amber;
    }
  }

  Color _bgEstado(String estado) {
    switch (estado) {
      case 'Publicado': return AppTheme.greenLight;
      case 'Pagada':    return AppTheme.blueLight;
      case 'Cancelada': return AppTheme.redLight;
      default:          return AppTheme.amberLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.user['nombres'] ?? 'Paciente';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarEstadisticas,
          color: AppTheme.orange,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/logoLab.png',
                          width: 50,
                          height: 50,
                        ),
                        const SizedBox(width: 12),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bienvenido',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.gray400,
                              ),
                            ),
                            Text(
                              nombre,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.dark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),


                  ],
                ),
                const SizedBox(height: 6),
                const Text('CÁRDENAS–GAROFALO', style: TextStyle(fontSize: 10, color: AppTheme.orange, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 24),
                // ── Alerta órdenes pendientes de pago ──
                if (_ordenesPendientesVencidas.isNotEmpty) ...[
                  _AlertaPendientePago(
                    cantidad: _ordenesPendientesVencidas.length,
                    onVerOrdenes: widget.onNuevaOrden,
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.receipt_long_outlined,
                      label: 'Mis órdenes totales',
                      value: _loadingStats ? '…' : '$_totalOrdenes',
                      color: AppTheme.orange,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.science_outlined,
                      label: 'Resultados',
                      value: _loadingStats ? '…' : '$_totalResultados',
                      color: AppTheme.green,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: widget.onNuevaOrden,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: AppTheme.orange, borderRadius: BorderRadius.circular(14)),
                    child: const Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 28),
                        SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Crear nueva pre-orden', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                            Text('Selecciona tus exámenes', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Actividad reciente', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.dark)),
                const SizedBox(height: 12),
                if (_loadingStats)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: AppTheme.orange, strokeWidth: 2),
                  ))
                else if (_ultimasOrdenes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.gray200)),
                    child: const Center(child: Text('Aquí aparecerán tus últimas órdenes', style: TextStyle(fontSize: 12, color: AppTheme.gray400))),
                  )
                else
                  ..._ultimasOrdenes.map((o) {
                    final estado = o['estado'] ?? 'Generada';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.gray200)),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: _bgEstado(estado), borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.receipt_long_rounded, color: _colorEstado(estado), size: 18),
                        ),
                        title: Text('#${o['numero_ticket'] ?? '—'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text('Total: \$${o['total'] ?? '0.00'}', style: const TextStyle(fontSize: 11, color: AppTheme.gray600)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: _bgEstado(estado), borderRadius: BorderRadius.circular(20)),
                          child: Text(estado, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _colorEstado(estado))),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────── Alerta pago pendiente ─────────────────
class _AlertaPendientePago extends StatelessWidget {
  final int cantidad;
  final VoidCallback onVerOrdenes;

  const _AlertaPendientePago({required this.cantidad, required this.onVerOrdenes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCA28), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFCA28),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.access_time_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cantidad == 1
                      ? '¡Tienes 1 orden pendiente de pago!'
                      : '¡Tienes $cantidad órdenes pendientes de pago!',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF7D5A00)),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Llevan más de 2 días sin ser pagadas. Acércate al laboratorio.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9A7200)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onVerOrdenes,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCA28),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Ver',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF7D5A00))),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────── Stat Card ─────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.gray200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.gray400)),
          ],
        ),
      ),
    );
  }
}

// ───────────────── Perfil ─────────────────
class _PerfilTab extends StatelessWidget {
  final String token;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  final Function(Map<String, dynamic>) onUpdateUser;

  const _PerfilTab({
    required this.token,
    required this.user,
    required this.onLogout,
    required this.onUpdateUser,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                child: ClipOval(
                  child: Image.asset(
                    'assets/logoLab.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${user['nombres'] ?? ''} ${user['apellidos'] ?? ''}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.dark),
              ),
              Text(user['username'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.gray400)),
              const SizedBox(height: 24),
              _InfoTile(icon: Icons.email_outlined,       label: 'Correo',    value: user['correo']    ?? '—'),
              _InfoTile(icon: Icons.badge_outlined,       label: 'Usuario',   value: user['username'] ?? '—'),
              _InfoTile(icon: Icons.phone_outlined,       label: 'Teléfono',  value: user['telefono'] ?? '—'),
              _InfoTile(icon: Icons.location_on_outlined, label: 'Dirección', value: user['direccion'] ?? '—'),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () async {
                  // Esperamos los datos de retorno al cerrar la vista EditarPerfilScreen
                  final updatedUser = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditarPerfilScreen(token: token, user: user),
                    ),
                  );

                  // Si regresó un usuario con datos nuevos, actualizamos la vista superior
                  if (updatedUser != null && updatedUser is Map<String, dynamic>) {
                    onUpdateUser(updatedUser);
                  }
                },
                icon: const Icon(Icons.edit_rounded),
                label: const Text('EDITAR PERFIL'),
              ),
              const SizedBox(height: 30),
              OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded, color: AppTheme.red),
                label: const Text('Cerrar sesión', style: TextStyle(color: AppTheme.red, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: AppTheme.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────── Info Tile ─────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.gray200)),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.gray400, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.gray400)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.dark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
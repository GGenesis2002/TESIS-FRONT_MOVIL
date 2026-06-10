import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class OrdenesScreen extends StatefulWidget {
  final String token;
  const OrdenesScreen({super.key, required this.token});
  @override
  State<OrdenesScreen> createState() => _OrdenesScreenState();
}

class _OrdenesScreenState extends State<OrdenesScreen> {
  List<dynamic> _ordenes = [];
  Timer? _refreshTimer;
  bool _loading = true;
  String _error = '';
  String _filtro = 'Todas';

  @override
  void initState() {
    super.initState();
    _cargar();
    // Auto-refresh cada 30 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _cargar();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = ''; });
    final res = await AuthService.misOrdenes(widget.token);
    setState(() => _loading = false);
    if (res['data'] != null) {
      setState(() => _ordenes = res['data'] is List ? res['data'] : []);
    } else {
      setState(() => _error = res['error'] ?? 'Error al cargar órdenes.');
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

  void _abrirNuevaOrden() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NuevaOrdenSheet(
        token: widget.token,
        // FIX 3: al crear, callback recibe ticket+qr para mostrar diálogo
        onOrdenCreada: (ticket, qrData, total) {
          Navigator.pop(context);
          _cargar();
          if (ticket != null && qrData != null) {
            _mostrarQRCreado(ticket, qrData, total);
          }
        },
      ),
    );
  }

  void _abrirEditarOrden(dynamic orden) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NuevaOrdenSheet(
        token: widget.token,
        ordenExistente: orden,
        onOrdenCreada: (_, __, ___) { Navigator.pop(context); _cargar(); },
      ),
    );
  }

  // FIX 3: Diálogo QR tras crear orden, con aviso de 5 días
  void _mostrarQRCreado(String ticket, String qrData, double total) {
    // qrData es "data:image/png;base64,iVBOR..."
    // Extraer solo la parte base64:
    final base64Str = qrData.contains(',') ? qrData.split(',').last : qrData;
    final bytes = base64Decode(base64Str);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // \u2500\u2500 \xcdcono \xe9xito \u2500\u2500
                Container(
                  width: 52, height: 52,
                  decoration: const BoxDecoration(
                      color: AppTheme.greenLight, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: AppTheme.green, size: 28),
                ),
                const SizedBox(height: 12),
                const Text('\xa1Orden registrada!',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.dark)),
                const SizedBox(height: 16),

                // \u2500\u2500 Ticket y total \u2500\u2500
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                      color: AppTheme.orangeLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.orangeBorder)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ticket',
                              style: TextStyle(fontSize: 10, color: AppTheme.gray600)),
                          Text('#$ticket',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.orange)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Total a pagar',
                              style: TextStyle(fontSize: 10, color: AppTheme.gray600)),
                          Text('\$${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.orange)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // \u2500\u2500 QR \u2500\u2500
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.gray200),
                  ),
                  child: Image.memory(bytes, width: 180, height: 180),
                ),
                const SizedBox(height: 14),

                // \u2500\u2500 Aviso de caducidad \u2500\u2500
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFCA28))),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 16, color: Color(0xFF7D5A00)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ac\xe9rcate al laboratorio m\xe1ximo en 4 d\xedas. '
                              'Si la orden no es pagada al 5.\xb0 d\xeda, ser\xe1 eliminada autom\xe1ticamente.',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7D5A00),
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // \u2500\u2500 Bot\xf3n cerrar \u2500\u2500
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('ENTENDIDO'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // FIX 2: Bottom sheet "Ver orden" con exámenes + QR
  void _verOrden(dynamic orden) async {
    final idOrden = orden['id_orden'];
    if (idOrden == null) return;

    // Cargamos el detalle (exámenes) desde el endpoint
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerOrdenSheet(
        token: widget.token,
        orden: orden,
      ),
    );
  }

  Future<void> _eliminarOrden(dynamic orden) async {
    final idOrden = orden['id_orden'];
    if (idOrden == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar orden',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(
          '¿Seguro que deseas eliminar la orden #${orden['numero_ticket'] ?? idOrden}?\nEsta acción no se puede deshacer.',
          style: const TextStyle(fontSize: 13, color: AppTheme.gray600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.gray600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final res = await AuthService.eliminarOrden(widget.token, idOrden as int);
    if (!mounted) return;

    if (res['error'] == null) {
      _cargar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Orden eliminada correctamente.'),
          backgroundColor: AppTheme.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error'] ?? 'Error al eliminar.'),
          backgroundColor: AppTheme.red,
        ),
      );
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
            const Text('Mis órdenes'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNuevaOrden,
        backgroundColor: AppTheme.orange,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nueva orden',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.orange))
          : _error.isNotEmpty
          ? Center(child: Text(_error, style: const TextStyle(color: AppTheme.red)))
          : _ordenes.isEmpty
          ? Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.receipt_long_outlined, size: 56, color: AppTheme.gray400),
          const SizedBox(height: 12),
          const Text('No tienes órdenes aún',
              style: TextStyle(fontSize: 14, color: AppTheme.gray400)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _abrirNuevaOrden,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('Crear primera orden'),
          ),
        ]),
      )
          : Column(
        children: [
          // ── Barra de filtros ──
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: ['Todas', 'Generada', 'Pagada', 'En Proceso'].map((f) {
                final isSelected = _filtro == f;
                Color chipColor;
                switch (f) {
                  case 'Generada':   chipColor = AppTheme.amber; break;
                  case 'Pagada':     chipColor = AppTheme.blue; break;
                  case 'En Proceso': chipColor = AppTheme.green; break;
                  default:           chipColor = AppTheme.orange;
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filtro = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? chipColor : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? chipColor : AppTheme.gray200,
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: chipColor.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
                            : [],
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppTheme.gray600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // ── Lista filtrada ──
          Expanded(
            child: Builder(builder: (context) {
              final ordenesFiltradas = _filtro == 'Todas'
                  ? _ordenes
                  : _ordenes.where((o) => (o['estado'] ?? 'Generada') == _filtro).toList();

              if (ordenesFiltradas.isEmpty) {
                return Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.filter_list_off_rounded, size: 48, color: AppTheme.gray400),
                    const SizedBox(height: 12),
                    Text('No hay órdenes con estado "$_filtro"',
                        style: const TextStyle(fontSize: 13, color: AppTheme.gray400)),
                  ]),
                );
              }

              return RefreshIndicator(
                onRefresh: _cargar,
                color: AppTheme.orange,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: ordenesFiltradas.length,
                  itemBuilder: (_, i) {
                    final o = ordenesFiltradas[i];
                    final estado = o['estado'] ?? 'Generada';
                    final puedeEditar = estado == 'Generada';

                    return Dismissible(
                      key: Key('orden_${o['id_orden']}'),
                      direction: puedeEditar
                          ? DismissDirection.endToStart
                          : DismissDirection.none,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
                            SizedBox(height: 4),
                            Text('Eliminar',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      confirmDismiss: (_) async {
                        await _eliminarOrden(o);
                        return false;
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.gray200),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                    color: _bgEstado(estado),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.receipt_long_rounded,
                                    color: _colorEstado(estado), size: 22),
                              ),
                              title: Text('#${o['numero_ticket'] ?? '—'}',
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                'Total: \$${o['total'] ?? '0.00'}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.gray600),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: _bgEstado(estado),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(estado,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _colorEstado(estado))),
                              ),
                            ),

                            // ── Botones de acción ──
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                              child: Row(
                                children: [
                                  // FIX 2: botón VER siempre visible
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _verOrden(o),
                                      icon: const Icon(Icons.qr_code_rounded, size: 16),
                                      label: const Text('Ver', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.gray600,
                                        side: const BorderSide(color: AppTheme.gray200),
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),

                                  if (puedeEditar) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _abrirEditarOrden(o),
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        label: const Text('Editar',
                                            style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.orange,
                                          side: const BorderSide(
                                              color: AppTheme.orangeBorder),
                                          padding:
                                          const EdgeInsets.symmetric(vertical: 6),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _eliminarOrden(o),
                                        icon: const Icon(Icons.delete_outline_rounded,
                                            size: 16),
                                        label: const Text('Eliminar',
                                            style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.red,
                                          side: const BorderSide(color: AppTheme.red),
                                          padding:
                                          const EdgeInsets.symmetric(vertical: 6),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  FIX 2: Bottom sheet "Ver orden" — QR + exámenes + total
// ═══════════════════════════════════════════════════════
class _VerOrdenSheet extends StatefulWidget {
  final String token;
  final dynamic orden;
  const _VerOrdenSheet({required this.token, required this.orden});
  @override
  State<_VerOrdenSheet> createState() => _VerOrdenSheetState();
}

class _VerOrdenSheetState extends State<_VerOrdenSheet> {
  List<dynamic> _examenes = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final idOrden = widget.orden['id_orden'] as int?;
    if (idOrden == null) {
      setState(() { _loading = false; _error = 'ID inválido.'; });
      return;
    }
    final res = await AuthService.obtenerDetalleOrden(widget.token, idOrden);
    setState(() => _loading = false);
    if (res['data'] != null) {
      setState(() => _examenes = res['data'] is List ? res['data'] : []);
    } else {
      setState(() => _error = res['error'] ?? 'Error al cargar detalle.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.orden;
    final estado = o['estado'] ?? 'Generada';
    final qrCodigo = o['qr_codigo'] as String?;
    final esGenerada = estado == 'Generada';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppTheme.gray200, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${o['numero_ticket'] ?? '—'}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.dark)),
                    Text(
                      o['fecha_orden'] != null
                          ? o['fecha_orden'].toString().substring(0, 10)
                          : '',
                      style: const TextStyle(fontSize: 12, color: AppTheme.gray400),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _bgEstadoStatic(estado),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(estado,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _colorEstadoStatic(estado))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.orange))
                : _error.isNotEmpty
                ? Center(
                child: Text(_error, style: const TextStyle(color: AppTheme.red)))
                : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── QR (solo si está Generada y existe el código) ──
                  if (esGenerada && qrCodigo != null) ...[
                    const Text('Código QR',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.dark)),
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.gray200),
                        ),
                        child: QrImageView(
                          data: qrCodigo,
                          version: QrVersions.auto,
                          size: 180,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Aviso 5 días
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.amberLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.amber.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined,
                              color: AppTheme.amber, size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Presenta este QR al llegar. Si no cancelas en 5 días, la orden se eliminará automáticamente.',
                              style: TextStyle(fontSize: 11, color: AppTheme.dark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Exámenes ──
                  const Text('Exámenes solicitados',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.dark)),
                  const SizedBox(height: 10),
                  if (_examenes.isEmpty)
                    const Text('Sin exámenes registrados.',
                        style: TextStyle(fontSize: 13, color: AppTheme.gray400))
                  else
                    ..._examenes.map((ex) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.gray200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                                color: AppTheme.orangeLight,
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.biotech_outlined,
                                color: AppTheme.orange, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ex['nombre_examen'] ?? '—',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.dark),
                                ),
                                if (ex['nombre_categoria'] != null)
                                  Text(ex['nombre_categoria'],
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.gray400)),
                              ],
                            ),
                          ),
                          Text(
                            '\$${ex['subtotal'] ?? '—'}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.dark),
                          ),
                        ],
                      ),
                    )),

                  // ── Total ──
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.orangeLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total a pagar',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.dark)),
                        Text(
                          '\$${o['total'] ?? '0.00'}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.orange),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorEstadoStatic(String estado) {
    switch (estado) {
      case 'Publicado': return AppTheme.green;
      case 'Pagada':    return AppTheme.blue;
      case 'Cancelada': return AppTheme.red;
      default:          return AppTheme.amber;
    }
  }

  Color _bgEstadoStatic(String estado) {
    switch (estado) {
      case 'Publicado': return AppTheme.greenLight;
      case 'Pagada':    return AppTheme.blueLight;
      case 'Cancelada': return AppTheme.redLight;
      default:          return AppTheme.amberLight;
    }
  }
}

// ═══════════════════════════════════════════════════════
//  BOTTOM SHEET — Nueva / Editar orden  (con carrito)
// ═══════════════════════════════════════════════════════
class _NuevaOrdenSheet extends StatefulWidget {
  final String token;
  // FIX 3: callback lleva ticket y qrData al crear, null al editar
  final void Function(String? ticket, String? qrData, double total) onOrdenCreada;
  final dynamic ordenExistente;

  const _NuevaOrdenSheet({
    required this.token,
    required this.onOrdenCreada,
    this.ordenExistente,
  });

  @override
  State<_NuevaOrdenSheet> createState() => _NuevaOrdenSheetState();
}

class _NuevaOrdenSheetState extends State<_NuevaOrdenSheet> {
  List<dynamic> _categorias = [];
  List<dynamic> _examenes = [];
  final Map<int, dynamic> _seleccionados = {};

  bool _loadingCats = true;
  bool _loadingExams = false;
  bool _loadingDetalle = false; // FIX 1: carga del detalle previo
  dynamic _catSeleccionada;
  bool _creando = false;
  String _error = '';

  bool _carritoAbierto = false;

  final _searchCtrl = TextEditingController();
  String _busqueda = '';

  bool get _esEdicion => widget.ordenExistente != null;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();


    // FIX 1: si es edición, cargar los exámenes previos de la orden
    if (_esEdicion) {
      _precargarExamenesOrden();
    }
  }

  // FIX 1: Carga los exámenes que ya tenía la orden y los pone en el carrito
  Future<void> _precargarExamenesOrden() async {
    setState(() => _loadingDetalle = true);
    final idOrden = widget.ordenExistente['id_orden'] as int?;
    if (idOrden == null) { setState(() => _loadingDetalle = false); return; }

    final res = await AuthService.obtenerDetalleOrden(widget.token, idOrden);
    setState(() => _loadingDetalle = false);

    if (res['data'] is List) {
      for (final ex in res['data']) {
        final id = ex['id_examen'] as int?;
        if (id != null) {
          // Construimos un objeto compatible con el mapa de seleccionados
          _seleccionados[id] = {
            'id_examen': id,
            'nombre_examen': ex['nombre_examen'] ?? '—',
            'precio': ex['subtotal'],
          };
        }
      }
      setState(() {});
    }
  }

  Future<void> _cargarCategorias() async {
    final res = await AuthService.listarCategorias(widget.token);
    if (res['data'] != null) {
      setState(() {
        _loadingCats = false;
        _categorias = res['data'] is List ? res['data'] : [];
      });
    } else {
      setState(() {
        _loadingCats = false;
        _error = res['error'] ?? 'Error al cargar categorías.';
      });
    }
  }

  Future<void> _seleccionarCategoria(dynamic cat) async {
    setState(() {
      _catSeleccionada = cat;
      _examenes = [];
      _loadingExams = true;
      _busqueda = '';
      _searchCtrl.clear();
      _error = '';
    });
    final res = await AuthService.listarExamenesPorCategoria(
        widget.token, cat['id_categoria'] as int);
    if (res['data'] != null) {
      setState(() {
        _loadingExams = false;
        _examenes = res['data'] is List ? res['data'] : [];
      });
    } else {
      setState(() {
        _loadingExams = false;
        _error = res['error'] ?? 'Error al cargar exámenes.';
      });
    }
  }

  Future<void> _confirmarOrden() async {
    if (_seleccionados.isEmpty) return;
    setState(() { _creando = true; _error = ''; });

    try {
      final examenes = _seleccionados.values
          .map((ex) => {
        'id_examen': ex['id_examen'] as int,
        'precio': ex['precio'],
      })
          .toList();

      Map<String, dynamic> res;

      if (_esEdicion) {
        res = await AuthService.editarOrdenPaciente(
          widget.token,
          widget.ordenExistente['id_orden'] as int,
          examenes,
        );
      } else {
        res = await AuthService.crearOrden(widget.token, examenes);
      }

      if (!mounted) return;

      // ✅ Siempre limpiar _creando primero
      setState(() => _creando = false);

      if (res['error'] != null) {
        setState(() => _error = res['error'] ?? 'Error al procesar la orden.');
        return;
      }

      // ✅ El servidor devuelve { ticket, qr (base64 imagen), msg }
      // Para el diálogo QR, guardamos el ticket y la imagen base64
      final ticket = res['ticket'] as String?;
      final qrImg  = res['qr']     as String?;   // ← es PNG base64

      widget.onOrdenCreada(
        _esEdicion ? null : ticket,
        _esEdicion ? null : qrImg,
        _esEdicion ? 0 : _total,
      );

    } catch (e) {
      if (mounted) setState(() { _creando = false; _error = 'Error inesperado: $e'; });
    }
  }

  double get _total => _seleccionados.values
      .fold(0, (sum, e) => sum + (double.tryParse('${e['precio']}') ?? 0));

  List<dynamic> get _examenesFiltrados => _examenes
      .where((e) => (e['nombre_examen'] ?? '').toLowerCase().contains(_busqueda))
      .toList();

  OverlayEntry? _carritoOverlay;

  void _mostrarCarrito() {
    _carritoOverlay?.remove();
    _carritoOverlay = OverlayEntry(builder: (ctx) => _CarritoOverlay(
      seleccionados: _seleccionados,
      total: _total,
      creando: _creando,
      esEdicion: _esEdicion,
      onEliminar: (id) { setState(() => _seleccionados.remove(id)); _carritoOverlay?.markNeedsBuild(); },
      onCerrar: () { _carritoOverlay?.remove(); _carritoOverlay = null; setState(() => _carritoAbierto = false); },
      onConfirmar: _confirmarOrden,
    ));
    Overlay.of(context).insert(_carritoOverlay!);
    setState(() => _carritoAbierto = true);
  }

  void _ocultarCarrito() {
    _carritoOverlay?.remove();
    _carritoOverlay = null;
    setState(() => _carritoAbierto = false);
  }

  @override
  void dispose() {
    _carritoOverlay?.remove();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppTheme.gray200,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (_catSeleccionada != null)
                  GestureDetector(
                    onTap: () => setState(() {
                      _catSeleccionada = null;
                      _examenes = [];
                      _busqueda = '';
                      _searchCtrl.clear();
                    }),
                    child: const Row(children: [
                      Icon(Icons.chevron_left, color: AppTheme.orange, size: 22),
                      SizedBox(width: 2),
                    ]),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _catSeleccionada == null
                            ? (_esEdicion ? 'Editar orden' : 'Nueva pre-orden')
                            : _catSeleccionada['nombre_categoria'] ?? 'Exámenes',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.dark),
                      ),
                      if (_loadingDetalle)
                        const Text('Cargando exámenes anteriores…',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.orange)),
                      if (_esEdicion && !_loadingDetalle && _seleccionados.isNotEmpty && _catSeleccionada == null)
                        Text(
                          '${_seleccionados.length} examen${_seleccionados.length > 1 ? 'es' : ''} en carrito',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.gray400),
                        ),
                    ],
                  ),
                ),
                // Botón carrito — abre Overlay, no Stack
                GestureDetector(
                  onTap: () => _carritoAbierto ? _ocultarCarrito() : _mostrarCarrito(),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _carritoAbierto ? AppTheme.orange : AppTheme.orangeLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.shopping_cart_outlined,
                          color: _carritoAbierto ? Colors.white : AppTheme.orange,
                          size: 20,
                        ),
                      ),
                      if (_seleccionados.isNotEmpty)
                        Positioned(
                          top: -4, right: -4,
                          child: Container(
                            width: 18, height: 18,
                            decoration: const BoxDecoration(
                                color: AppTheme.red, shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                '${_seleccionados.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _catSeleccionada == null
                  ? 'Selecciona una categoría'
                  : 'Toca un examen para agregarlo al carrito',
              style: const TextStyle(fontSize: 12, color: AppTheme.gray400),
            ),
          ),
          const SizedBox(height: 12),

          // Buscador
          if (_catSeleccionada != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _busqueda = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar examen...',
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: AppTheme.gray400),
                  suffixIcon: _busqueda.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppTheme.gray400),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _busqueda = '');
                    },
                  )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.gray200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.gray200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.orange)),
                ),
              ),
            ),

          if (_catSeleccionada != null) const SizedBox(height: 10),

          // Contenido principal — sin Stack que interfiera
          Expanded(
            child: _loadingCats
                ? const Center(
                child: CircularProgressIndicator(color: AppTheme.orange))
                : _catSeleccionada == null
                ? _buildCategorias()
                : _loadingExams
                ? const Center(
                child: CircularProgressIndicator(color: AppTheme.orange))
                : _buildExamenes(),
          ),

          // Error
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppTheme.redLight,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_error,
                    style: const TextStyle(fontSize: 12, color: AppTheme.red)),
              ),
            ),

          if (_seleccionados.isNotEmpty) _buildBarraConfirmar(),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  // ── Grid de categorías ──
  Widget _buildCategorias() {
    if (_categorias.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: AppTheme.gray400),
            const SizedBox(height: 12),
            const Text('No se pudieron cargar las categorías',
                style: TextStyle(fontSize: 13, color: AppTheme.gray400)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() { _loadingCats = true; _error = ''; });
                _cargarCategorias();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: _categorias.length,
      itemBuilder: (_, i) {
        final cat = _categorias[i];
        return GestureDetector(
          onTap: () => _seleccionarCategoria(cat),
          child: Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.gray200)),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: AppTheme.orangeLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.science_outlined,
                      color: AppTheme.orange, size: 20),
                ),
                Text(cat['nombre_categoria'] ?? '—',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.dark),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Lista de exámenes — FIX 1: marca los ya seleccionados ──
  Widget _buildExamenes() {
    final lista = _examenesFiltrados;
    if (lista.isEmpty) {
      return Center(
          child: Text(
            _busqueda.isNotEmpty
                ? 'Sin resultados para "$_busqueda"'
                : 'Sin exámenes en esta categoría',
            style: const TextStyle(fontSize: 13, color: AppTheme.gray400),
          ));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final ex = lista[i];
        final id = ex['id_examen'] as int?;
        // FIX 1: refleja correctamente si ya estaba en la orden anterior
        final seleccionado = id != null && _seleccionados.containsKey(id);
        return GestureDetector(
          onTap: () {
            if (id == null) return;
            setState(() {
              if (seleccionado) {
                _seleccionados.remove(id);
              } else {
                _seleccionados[id] = ex;
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: seleccionado ? AppTheme.orangeLight : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: seleccionado ? AppTheme.orange : AppTheme.gray200,
                  width: seleccionado ? 1.5 : 1),
            ),
            child: ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: seleccionado ? AppTheme.orange : AppTheme.gray100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  seleccionado ? Icons.check_rounded : Icons.biotech_outlined,
                  color: seleccionado ? Colors.white : AppTheme.gray400,
                  size: 20,
                ),
              ),
              title: Text(ex['nombre_examen'] ?? '—',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: seleccionado ? AppTheme.orange : AppTheme.dark)),
              subtitle: ex['descripcion'] != null
                  ? Text(ex['descripcion'],
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.gray400),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)
                  : null,
              trailing: Text('\$${ex['precio'] ?? '—'}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: seleccionado ? AppTheme.orange : AppTheme.dark)),
            ),
          ),
        );
      },
    );
  }

  // ── Barra inferior de confirmación rápida ──
  Widget _buildBarraConfirmar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.orange, borderRadius: BorderRadius.circular(14)),
      // Row con mainAxisAlignment.spaceBetween — SIN Spacer ni Expanded
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Texto izquierda
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  '${_seleccionados.length} examen${_seleccionados.length > 1 ? 'es' : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text('Total: \$${_total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          // Botones derecha
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _mostrarCarrito,
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.shopping_cart_outlined,
                      color: Colors.white, size: 18),
                ),
              ),
              _creando
                  ? const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : GestureDetector(
                onTap: _confirmarOrden,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _esEdicion ? 'Actualizar' : 'Confirmar',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppTheme.orange),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// ═══════════════════════════════════════════════════════
//  Overlay del carrito — widget independiente, fuera del árbol del sheet
// ═══════════════════════════════════════════════════════
class _CarritoOverlay extends StatelessWidget {
  final Map<int, dynamic> seleccionados;
  final double total;
  final bool creando;
  final bool esEdicion;
  final void Function(int id) onEliminar;
  final VoidCallback onCerrar;
  final VoidCallback onConfirmar;

  const _CarritoOverlay({
    required this.seleccionados,
    required this.total,
    required this.creando,
    required this.esEdicion,
    required this.onEliminar,
    required this.onCerrar,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fondo oscuro — cierra el carrito al tocar
        Positioned.fill(
          child: GestureDetector(
            onTap: onCerrar,
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),
        ),
        // Panel lateral derecho
        Positioned(
          top: 0, bottom: 0, right: 0,
          width: 300,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(-4, 0))
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_cart_rounded,
                              color: AppTheme.orange, size: 22),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Carrito',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.dark)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 20, color: AppTheme.gray400),
                            onPressed: onCerrar,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: seleccionados.isEmpty
                          ? const Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.remove_shopping_cart_outlined,
                                    size: 44, color: AppTheme.gray400),
                                SizedBox(height: 10),
                                Text('El carrito está vacío',
                                    style: TextStyle(
                                        fontSize: 13, color: AppTheme.gray400)),
                              ]))
                          : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: seleccionados.values.map((ex) {
                          final id = ex['id_examen'] as int?;
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            leading: Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                  color: AppTheme.orangeLight,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.biotech_outlined,
                                  color: AppTheme.orange, size: 18),
                            ),
                            title: Text(ex['nombre_examen'] ?? '—',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.dark),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text('\$${ex['precio'] ?? '—'}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.orange,
                                    fontWeight: FontWeight.w700)),
                            trailing: id != null
                                ? GestureDetector(
                              onTap: () => onEliminar(id),
                              child: Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                    color: AppTheme.redLight,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.remove_rounded,
                                    color: AppTheme.red, size: 16),
                              ),
                            )
                                : null,
                          );
                        }).toList(),
                      ),
                    ),
                    if (seleccionados.isNotEmpty) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    '${seleccionados.length} examen${seleccionados.length > 1 ? 'es' : ''}',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppTheme.gray400)),
                                Text('Total: \$${total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.dark)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: creando ? null : onConfirmar,
                                child: creando
                                    ? const SizedBox(
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                    : Text(esEdicion
                                    ? 'ACTUALIZAR ORDEN'
                                    : 'CONFIRMAR ORDEN'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
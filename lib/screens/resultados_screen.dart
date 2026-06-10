import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
// ══════════════════════════════════════════════════════════
//  PANTALLA PRINCIPAL — lista de órdenes validadas
// ══════════════════════════════════════════════════════════
class ResultadosScreen extends StatefulWidget {
  final String token;
  const ResultadosScreen({super.key, required this.token});
  @override
  State<ResultadosScreen> createState() => _ResultadosScreenState();
}

class _ResultadosScreenState extends State<ResultadosScreen> {
  List<dynamic> _ordenes = [];
  Timer? _refreshTimer;
  bool _loading = true;
  String _error = '';

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
    setState(() {
      _loading = true;
      _error = '';
    });
    final res = await AuthService.misOrdenes(widget.token);
    setState(() => _loading = false);
    if (res['data'] != null) {
      final todas = res['data'] is List ? res['data'] as List : [];
      setState(() =>
      _ordenes = todas.where((o) => o['estado'] == 'Validado').toList());
    } else {
      setState(() => _error = res['error'] ?? 'Error al cargar.');
    }
  }

  void _verDetalle(dynamic orden) {
    if (orden['id_orden'] == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleResultadosSheet(
        token: widget.token,
        orden: orden,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logoLab.png',
              height: 32,
            ),
            const SizedBox(width: 10),
            const Text('Mis Resultados'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargar,
          ),
        ],
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: AppTheme.orange))
          : _error.isNotEmpty
          ? Center(
          child: Text(_error,
              style: const TextStyle(color: AppTheme.red)))
          : _ordenes.isEmpty
          ? const Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.science_outlined,
                    size: 56, color: AppTheme.gray400),
                SizedBox(height: 12),
                Text('No hay resultados publicados aún',
                    style: TextStyle(
                        fontSize: 14, color: AppTheme.gray400)),
              ]))
          : RefreshIndicator(
        onRefresh: _cargar,
        color: AppTheme.orange,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _ordenes.length,
          itemBuilder: (_, i) => _OrdenCard(
            orden: _ordenes[i],
            onTap: () => _verDetalle(_ordenes[i]),
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta de orden en la lista ──────────────────────────
class _OrdenCard extends StatelessWidget {
  final dynamic orden;
  final VoidCallback onTap;
  const _OrdenCard({required this.orden, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fecha = orden['fecha_orden'] != null
        ? orden['fecha_orden'].toString().substring(0, 10)
        : '—';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.gray200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: AppTheme.greenLight,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.science_rounded,
                color: AppTheme.green, size: 22),
          ),
          title: Text(
            '#${orden['numero_ticket'] ?? '—'}',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.dark),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('Fecha: $fecha',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.gray600)),
              const SizedBox(height: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.greenLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.check_circle_rounded,
                      size: 12, color: AppTheme.green),
                  SizedBox(width: 4),
                  Text('Validado',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.green)),
                ]),
              ),
            ],
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppTheme.gray400),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  BOTTOM SHEET — resultados agrupados por categoría y examen
// ══════════════════════════════════════════════════════════
class _DetalleResultadosSheet extends StatefulWidget {
  final String token;
  final dynamic orden;
  const _DetalleResultadosSheet({required this.token, required this.orden});
  @override
  State<_DetalleResultadosSheet> createState() =>
      _DetalleResultadosSheetState();
}

class _DetalleResultadosSheetState extends State<_DetalleResultadosSheet> {
  Map<String, Map<String, List<dynamic>>> _agrupado = {};
  String? _pdfUrl;
  bool _loading = true;
  String _error = '';

  final Set<String> _categoriasAbiertas = {};
  final Set<String> _examenesAbiertos = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final idOrden = widget.orden['id_orden'] as int?;
    if (idOrden == null) {
      setState(() {
        _loading = false;
        _error = 'ID de orden inválido.';
      });
      return;
    }

    final res = await AuthService.misResultados(widget.token, idOrden);
    setState(() => _loading = false);

    if (res['data'] == null) {
      setState(() =>
      _error = res['error'] ?? 'No se pudieron cargar los resultados.');
      return;
    }

    final lista = res['data'] is List ? res['data'] as List : [];

    // ── Extraer URL del PDF ──
    String? pdfUrl;
    for (final r in lista) {
      final u = r['archivo_pdf']?.toString() ?? '';
      if (u.isNotEmpty && u.startsWith('http')) {
        pdfUrl = u;
        break;
      }
    }
    if (pdfUrl == null || pdfUrl.isEmpty) {
      final fallback = widget.orden['archivo_pdf']?.toString() ?? '';
      if (fallback.isNotEmpty && fallback.startsWith('http')) {
        pdfUrl = fallback;
      }
    }

    // ── Agrupar por categoría → examen ──
    final agrupado = <String, Map<String, List<dynamic>>>{};
    for (final r in lista) {
      final cat = (r['nombre_categoria'] ??
          r['categoria'] ??
          r['categoria_nombre'] ??
          'Sin categoría')
          .toString();
      final exam = (r['nombre_examen'] ??
          r['examen'] ??
          r['examen_nombre'] ??
          'Examen')
          .toString();

      agrupado.putIfAbsent(cat, () => {});
      agrupado[cat]!.putIfAbsent(exam, () => []);
      agrupado[cat]![exam]!.add(r);
    }

    final primeraCategoria =
    agrupado.keys.isNotEmpty ? agrupado.keys.first : null;
    if (primeraCategoria != null) {
      _categoriasAbiertas.add(primeraCategoria);
      final primerExamen = agrupado[primeraCategoria]!.keys.isNotEmpty
          ? agrupado[primeraCategoria]!.keys.first
          : null;
      if (primerExamen != null) {
        _examenesAbiertos.add('$primeraCategoria|$primerExamen');
      }
    }

    setState(() {
      _agrupado = agrupado;
      _pdfUrl = (pdfUrl != null && pdfUrl.isNotEmpty) ? pdfUrl : null;
    });
  }

  // ── Abre el visor interno de PDF ──────────────────────
  Future<void> _abrirPDF() async {
    print("PDF URL: $_pdfUrl");

    if (_pdfUrl == null) {
      print("PDF URL es NULL");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          url: _pdfUrl!,
          titulo: '#${widget.orden['numero_ticket'] ?? '—'}',
        ),
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    final fecha = widget.orden['fecha_orden'] != null
        ? widget.orden['fecha_orden'].toString().substring(0, 10)
        : '—';
    final ticket = '#${widget.orden['numero_ticket'] ?? '—'}';

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          // ── Handle ──
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.gray200,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          // ── Encabezado ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppTheme.greenLight,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.science_rounded,
                      color: AppTheme.green, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ticket,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.dark)),
                      Text('Fecha: $fecha',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.gray400)),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppTheme.greenLight,
                      borderRadius: BorderRadius.circular(20)),
                  child:
                  Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.check_circle_rounded,
                        size: 12, color: AppTheme.green),
                    SizedBox(width: 4),
                    Text('Validado',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.green)),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppTheme.gray200.withOpacity(0.8)),

          // ── Cuerpo ──
          Expanded(
            child: _loading
                ? const Center(
                child: CircularProgressIndicator(color: AppTheme.orange))
                : _error.isNotEmpty
                ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(_error,
                      style: const TextStyle(
                          color: AppTheme.red, fontSize: 13)),
                ))
                : _agrupado.isEmpty
                ? const Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 48, color: AppTheme.gray400),
                      SizedBox(height: 12),
                      Text('Sin resultados disponibles',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.gray400)),
                    ]))
                : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: _agrupado.entries
                  .map((catEntry) =>
                  _buildCategoria(catEntry.key, catEntry.value))
                  .toList(),
            ),
          ),

          // ── Botón PDF fijo ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 12,
                    offset: const Offset(0, -3)),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _abrirPDF,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                label: Text(
                  _pdfUrl != null
                      ? 'VER RESULTADO EN PDF'
                      : 'PDF NO DISPONIBLE',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  _pdfUrl != null ? AppTheme.orange : AppTheme.gray400,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sección de categoría (colapsable) ─────────────────
  Widget _buildCategoria(
      String categoria, Map<String, List<dynamic>> examenes) {
    final abierta = _categoriasAbiertas.contains(categoria);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.gray200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: abierta ? Radius.zero : const Radius.circular(14),
            ),
            onTap: () => setState(() {
              if (abierta) {
                _categoriasAbiertas.remove(categoria);
              } else {
                _categoriasAbiertas.add(categoria);
              }
            }),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.category_rounded,
                        size: 16, color: AppTheme.orange),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      categoria,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.dark),
                    ),
                  ),
                  Text(
                    '${examenes.length} examen${examenes.length != 1 ? 'es' : ''}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.gray400),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    abierta
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppTheme.gray400,
                  ),
                ],
              ),
            ),
          ),
          if (abierta) ...[
            Divider(height: 1, color: AppTheme.gray200),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: examenes.entries
                    .map((e) => _buildExamen(categoria, e.key, e.value))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Bloque de examen con sus parámetros ───────────────
  Widget _buildExamen(
      String categoria, String examen, List<dynamic> parametros) {
    final key = '$categoria|$examen';
    final abierto = _examenesAbiertos.contains(key);

    final tieneAlerta = parametros.any((p) {
      final e = _evaluar(
          p['resultado'] ?? p['valor_obtenido'],
          p['rango_min'],
          p['rango_max']);
      return e == _EstadoValor.alto || e == _EstadoValor.bajo;
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: tieneAlerta
              ? AppTheme.red.withOpacity(0.3)
              : AppTheme.gray200,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(10),
              bottom: abierto ? Radius.zero : const Radius.circular(10),
            ),
            onTap: () => setState(() {
              if (abierto) {
                _examenesAbiertos.remove(key);
              } else {
                _examenesAbiertos.add(key);
              }
            }),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.biotech_rounded,
                      size: 16, color: AppTheme.gray400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      examen,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.dark),
                    ),
                  ),
                  if (tieneAlerta)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Revisar',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.red)),
                    ),
                  Text(
                    '${parametros.length} parámetro${parametros.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.gray400),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    abierto
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppTheme.gray400,
                  ),
                ],
              ),
            ),
          ),
          if (abierto) ...[
            Divider(height: 1, color: AppTheme.gray200),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Column(
                children: parametros.map((p) => _buildParametro(p)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Fila de un parámetro individual ───────────────────
  Widget _buildParametro(dynamic p) {
    final nombreParam = (p['nombre_parametro'] ??
        p['parametro'] ??
        p['nombre'] ??
        p['parametro_nombre'] ??
        '—')
        .toString();
    final valorRaw = p['resultado'] ?? p['valor_obtenido'];
    final valor = valorRaw?.toString() ?? '—';
    final unidad = p['unidad']?.toString() ?? '';
    final estado = _evaluar(valorRaw, p['rango_min'], p['rango_max']);
    final rango = _rangoTexto(p);
    final color = _colorEstado(estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: estado == _EstadoValor.normal || estado == _EstadoValor.sinDato
              ? AppTheme.gray200
              : color.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              nombreParam,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.dark),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  unidad.isNotEmpty ? '$valor $unidad' : valor,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
                if (rango != '—')
                  Text(
                    rango,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.gray400),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _EstadoBadge(estado: estado),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────
  _EstadoValor _evaluar(dynamic val, dynamic min, dynamic max) {
    if (val == null || val.toString().isEmpty) return _EstadoValor.sinDato;
    final num = double.tryParse(val.toString());
    final dMin = double.tryParse(min?.toString() ?? '');
    final dMax = double.tryParse(max?.toString() ?? '');
    if (num == null) return _EstadoValor.normal;
    if (dMin != null && num < dMin) return _EstadoValor.bajo;
    if (dMax != null && num > dMax) return _EstadoValor.alto;
    return _EstadoValor.normal;
  }

  String _rangoTexto(dynamic r) {
    final min = r['rango_min']?.toString();
    final max = r['rango_max']?.toString();
    final ref = r['valor_referencia']?.toString();
    if (min != null && max != null) return '$min – $max';
    if (ref != null && ref.isNotEmpty) return ref;
    return '—';
  }

  Color _colorEstado(_EstadoValor e) {
    switch (e) {
      case _EstadoValor.alto:
        return AppTheme.red;
      case _EstadoValor.bajo:
        return const Color(0xFF2563EB);
      default:
        return AppTheme.dark;
    }
  }
}

// ══════════════════════════════════════════════════════════
//  VISOR DE PDF — pantalla completa, descarga temporal
// ══════════════════════════════════════════════════════════
class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String titulo;
  const PdfViewerScreen({super.key, required this.url, required this.titulo});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _descargando = true;
  String? _error;
  String? _rutaLocal;
  int _totalPaginas = 0;
  int _paginaActual = 0;
  PDFViewController? _controller;

  @override
  void initState() {
    super.initState();
    _descargarPDF();
  }

  Future<void> _descargarPDF() async {
    print("Descargando PDF desde: ${widget.url}");
    try {
      final response = await http
          .get(Uri.parse(widget.url))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Error HTTP ${response.statusCode}');
      }

      final dir = await getTemporaryDirectory();
      final nombreArchivo =
          'resultado_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final archivo = File('${dir.path}/$nombreArchivo');
      await archivo.writeAsBytes(response.bodyBytes);

      if (mounted) {
        setState(() {
          _rutaLocal = archivo.path;
          _descargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar el PDF: $e';
          _descargando = false;
        });
      }
    }
  }

  // Navegar a una página específica
  void _irAPagina(int pagina) {
    _controller?.setPage(pagina);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.titulo,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            if (_totalPaginas > 0)
              Text(
                'Página ${_paginaActual + 1} de $_totalPaginas',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, size: 22),
            tooltip: 'Abrir externamente',
            onPressed: () async {
              if (_rutaLocal == null) return;

              await OpenFilex.open(_rutaLocal!);
            },
          ),
        ],
      ),
      body: _descargando
          ? _buildCargando()
          : _error != null
          ? _buildError()
          : _buildVisor(),

      // ── Barra de navegación de páginas (solo si hay más de 1) ──
      bottomNavigationBar: (!_descargando && _error == null && _totalPaginas > 1)
          ? _buildNavPaginas()
          : null,
    );
  }

  // ── Estado: descargando ──
  Widget _buildCargando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.orange,
            strokeWidth: 2.5,
          ),
          SizedBox(height: 16),
          Text(
            'Cargando documento…',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          SizedBox(height: 6),
          Text(
            'Esto puede tomar unos segundos',
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Estado: error ──
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppTheme.red, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'No se pudo cargar el PDF',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Reintentar
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _descargando = true;
                  _error = null;
                });
                _descargarPDF();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),

          ],
        ),
      ),
    );
  }

  // ── Visor PDF ──
  Widget _buildVisor() {
    return PDFView(
      filePath: _rutaLocal!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      fitPolicy: FitPolicy.BOTH,
      onRender: (pages) {
        if (mounted) setState(() => _totalPaginas = pages ?? 0);
      },
      onError: (e) {
        if (mounted) setState(() => _error = e.toString());
      },
      onPageError: (page, e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error en página $page: $e'),
            backgroundColor: AppTheme.red,
          ));
        }
      },
      onViewCreated: (controller) {
        if (mounted) setState(() => _controller = controller);
      },
      onPageChanged: (page, total) {
        if (mounted) {
          setState(() {
            _paginaActual = page ?? 0;
            _totalPaginas = total ?? _totalPaginas;
          });
        }
      },
    );
  }

  // ── Barra de navegación entre páginas ──
  Widget _buildNavPaginas() {
    return Container(
      height: 56,
      color: const Color(0xFF1A1A1A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Anterior
          IconButton(
            onPressed: _paginaActual > 0
                ? () => _irAPagina(_paginaActual - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: _paginaActual > 0 ? Colors.white : Colors.white24,
            iconSize: 28,
          ),
          const SizedBox(width: 8),
          // Indicador de páginas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_paginaActual + 1} / $_totalPaginas',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          // Siguiente
          IconButton(
            onPressed: _paginaActual < _totalPaginas - 1
                ? () => _irAPagina(_paginaActual + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: _paginaActual < _totalPaginas - 1
                ? Colors.white
                : Colors.white24,
            iconSize: 28,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  HELPERS DE UI
// ══════════════════════════════════════════════════════════
enum _EstadoValor { normal, alto, bajo, sinDato }

class _EstadoBadge extends StatelessWidget {
  final _EstadoValor estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    late String label;
    late Color bg;
    late Color fg;
    switch (estado) {
      case _EstadoValor.alto:
        label = 'Alto';
        bg = const Color(0xFFFEE2E2);
        fg = AppTheme.red;
        break;
      case _EstadoValor.bajo:
        label = 'Bajo';
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case _EstadoValor.sinDato:
        label = '—';
        bg = AppTheme.gray200;
        fg = AppTheme.gray400;
        break;
      default:
        label = 'Normal';
        bg = AppTheme.greenLight;
        fg = AppTheme.green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../servicios/pdf_servicios.dart';
import 'reportes_planificadores.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeOsc = Color(0xFF1B5E20);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _mostaza = Color(0xFFF5A623);
  static const Color _cafe = Color(0xFF8B5E3C);
  static const Color _fondo = Color(0xFFF4F6F8);

  String seccion = 'usuarios';

  // Usuarios
  String buscarUsuario = '';
  final buscarCtrl = TextEditingController();
  String formatoUsuarios = 'PDF';
  String filtroEstadoUsuarios = 'Todos';

  // Favoritos
  String buscarFavorito = '';
  final buscarFavoritoCtrl = TextEditingController();
  String formatoFavoritos = 'PDF';

  // Recetas
  String buscarReceta = '';
  final buscarRecetaCtrl = TextEditingController();
  String formatoRecetas = 'PDF';
  String categoriaSeleccionada = 'Todas';
  List<String> categorias = ['Todas'];

  static const List<List<Color>> _paletas = [
    [Color(0xFF1565C0), Color(0xFFE3F2FD)],
    [Color(0xFF6A1B9A), Color(0xFFF3E5F5)],
    [Color(0xFF00838F), Color(0xFFE0F7FA)],
    [Color(0xFFE65100), Color(0xFFFFF3E0)],
    [Color(0xFF558B2F), Color(0xFFF1F8E9)],
    [Color(0xFFC62828), Color(0xFFFFEBEE)],
    [Color(0xFF4527A0), Color(0xFFEDE7F6)],
    [Color(0xFF00695C), Color(0xFFE0F2F1)],
  ];

  static List<Color> _paletaPara(String seed) {
    int hash = 0;
    for (final c in seed.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return _paletas[hash % _paletas.length];
  }

  List<QueryDocumentSnapshot> _ordenarDocs(
    List<QueryDocumentSnapshot> lista,
    String campo,
    String orden,
  ) {
    lista.sort((a, b) {
      final da = a.data() as Map<String, dynamic>;
      final db = b.data() as Map<String, dynamic>;
      final na = (da[campo] ?? '').toString().trim().toLowerCase();
      final nb = (db[campo] ?? '').toString().trim().toLowerCase();
      if (na.isEmpty && nb.isEmpty) return 0;
      if (na.isEmpty) return 1;
      if (nb.isEmpty) return -1;
      return orden == 'A-Z' ? na.compareTo(nb) : nb.compareTo(na);
    });
    return lista;
  }

  @override
  void initState() {
    super.initState();
    cargarCategorias();
  }

  @override
  void dispose() {
    buscarCtrl.dispose();
    buscarFavoritoCtrl.dispose();
    buscarRecetaCtrl.dispose();
    super.dispose();
  }

  Future<void> cargarCategorias() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('app-Categorías')
        .get();
    final nombres = snapshot.docs
        .map((doc) => doc.data()['nombre']?.toString() ?? '')
        .where((n) => n.toLowerCase() != 'todas')
        .toList();
    setState(() => categorias = ['Todas', ...nombres]);
  }

  Widget _chipSeccion({
    required String label,
    required String valor,
    required IconData icono,
  }) {
    final activo = seccion == valor;
    return GestureDetector(
      onTap: () {
        if (valor == 'planificador') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ReportesPlanificadoresScreen(),
            ),
          );
          return;
        }
        setState(() => seccion = valor);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: activo ? _verde : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: activo ? _verdeOsc : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: activo
              ? [
                  BoxShadow(
                    color: _verde.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 14,
              color: activo ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: activo ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool expanded = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        isDense: true,
        isExpanded: expanded,
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _botonReporte(VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.download_rounded, size: 15, color: Colors.white),
      label: const Text(
        'Reporte',
        style: TextStyle(color: Colors.white, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _verde,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  Widget _buscador({
    required TextEditingController ctrl,
    required String valor,
    required String hint,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: valor.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onClear,
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: CustomScrollView(
        slivers: [
          // ── Header verde con Yagu ─────────────────────────────────────
          SliverToBoxAdapter(child: _buildHeader(context)),

          // ── Contenido scrollable ──────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),

                // Yagu dice
                _buildYaguDice(),
                const SizedBox(height: 20),

                // 4 métricas
                _buildMetricas(),
                const SizedBox(height: 20),

                // Chips de sección
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chipSeccion(
                        label: 'Usuarios',
                        valor: 'usuarios',
                        icono: Icons.people_outline,
                      ),
                      const SizedBox(width: 8),
                      _chipSeccion(
                        label: 'Recetas',
                        valor: 'recetas',
                        icono: Icons.restaurant_menu_outlined,
                      ),
                      const SizedBox(width: 8),
                      _chipSeccion(
                        label: 'Favoritos',
                        valor: 'favoritos',
                        icono: Icons.favorite_border,
                      ),
                      const SizedBox(width: 8),
                      _chipSeccion(
                        label: 'Planificador',
                        valor: 'planificador',
                        icono: Icons.calendar_month_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (seccion == 'usuarios') ...[
                  _buildBarraBusqueda(
                    ctrl: buscarCtrl,
                    valor: buscarUsuario,
                    hint: 'Buscar usuario...',
                    formato: formatoUsuarios,
                    onChangedBuscar: (v) =>
                        setState(() => buscarUsuario = v.toLowerCase()),
                    onClearBuscar: () => setState(() {
                      buscarUsuario = '';
                      buscarCtrl.clear();
                    }),
                    onChangedFormato: (v) =>
                        setState(() => formatoUsuarios = v!),
                    onExportar: () async {
                      if (formatoUsuarios == 'PDF')
                        await PdfService.generarReporteUsuarios(
                          filtroEstadoUsuarios,
                        );
                      else if (formatoUsuarios == 'Excel')
                        await PdfService.generarExcelUsuarios(
                          filtroEstadoUsuarios,
                        );
                      else if (formatoUsuarios == 'CSV')
                        await PdfService.generarCsvUsuarios(
                          filtroEstadoUsuarios,
                        );
                    },
                  ),
                  const SizedBox(height: 10),
                  _dropdown<String>(
                    value: filtroEstadoUsuarios,
                    items: const [
                      DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                      DropdownMenuItem(value: 'Activo', child: Text('Activos')),
                      DropdownMenuItem(
                        value: 'Inactivo',
                        child: Text('Inactivos'),
                      ),
                      DropdownMenuItem(
                        value: 'Inhabilitado',
                        child: Text('Inhabilitados'),
                      ),
                    ],
                    onChanged: (v) => setState(() => filtroEstadoUsuarios = v!),
                  ),
                  const SizedBox(height: 16),
                  _titulo('Usuarios'),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('app-usuarios')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(
                          child: CircularProgressIndicator(color: _verde),
                        );
                      final usuarios = _ordenarDocs(
                        snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final nombre = (data['nombre'] ?? '')
                              .toString()
                              .toLowerCase();
                          final ultimoAcceso = data['ultimoAcceso'];
                          String estado = 'Inactivo';
                          if (ultimoAcceso != null) {
                            final dias = DateTime.now()
                                .difference(ultimoAcceso.toDate())
                                .inDays;
                            if (dias <= 30)
                              estado = 'Activo';
                            else if (dias <= 60)
                              estado = 'Inactivo';
                            else
                              estado = 'Inhabilitado';
                          }
                          return nombre.contains(buscarUsuario) &&
                              (filtroEstadoUsuarios == 'Todos' ||
                                  estado == filtroEstadoUsuarios);
                        }).toList(),
                        'nombre',
                        'A-Z',
                      );

                      return Column(
                        children: usuarios.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final paleta = _paletaPara(doc.id);
                          return GestureDetector(
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: Text(
                                  data['nombre'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _infoFila(
                                        Icons.mail_outline,
                                        'Correo',
                                        data['correo'] ?? data['email'] ?? '',
                                      ),
                                      _infoFila(
                                        Icons.shield_outlined,
                                        'Rol',
                                        data['rol'] ?? 'user',
                                      ),
                                      _infoFila(
                                        Icons.circle,
                                        'Estado',
                                        'Activo',
                                      ),
                                      _infoFila(
                                        Icons.calendar_today,
                                        'Registro',
                                        data['creadoEn'] != null
                                            ? _formatFecha(
                                                data['creadoEn'].toDate(),
                                              )
                                            : 'Sin registro',
                                      ),
                                      _infoFila(
                                        Icons.access_time,
                                        'Último acceso',
                                        data['ultimoAcceso'] != null
                                            ? _formatFecha(
                                                data['ultimoAcceso'].toDate(),
                                              )
                                            : 'Sin acceso',
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              PdfService.generarReporteUsuario(
                                                data,
                                              ),
                                          icon: const Icon(
                                            Icons.picture_as_pdf,
                                            size: 16,
                                          ),
                                          label: const Text('Exportar PDF'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _verde,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            child: _itemLista(
                              leading: CircleAvatar(
                                backgroundColor: paleta[1],
                                child: Icon(Icons.person, color: paleta[0]),
                              ),
                              titulo: data['nombre'] ?? 'Sin nombre',
                              subtitulo: data['correo'] ?? data['email'] ?? '',
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],

                if (seccion == 'recetas') ...[
                  _buildBarraBusqueda(
                    ctrl: buscarRecetaCtrl,
                    valor: buscarReceta,
                    hint: 'Buscar receta...',
                    formato: formatoRecetas,
                    onChangedBuscar: (v) =>
                        setState(() => buscarReceta = v.toLowerCase()),
                    onClearBuscar: () => setState(() {
                      buscarReceta = '';
                      buscarRecetaCtrl.clear();
                    }),
                    onChangedFormato: (v) =>
                        setState(() => formatoRecetas = v!),
                    onExportar: () async {
                      if (formatoRecetas == 'PDF')
                        await PdfService.generarReporteRecetas(
                          categoria: categoriaSeleccionada,
                          buscar: buscarReceta,
                        );
                      else if (formatoRecetas == 'Excel')
                        await PdfService.generarExcelRecetas(
                          categoria: categoriaSeleccionada,
                          buscar: buscarReceta,
                        );
                      else if (formatoRecetas == 'CSV')
                        await PdfService.generarCsvRecetas(
                          categoria: categoriaSeleccionada,
                          buscar: buscarReceta,
                        );
                    },
                  ),
                  const SizedBox(height: 10),
                  _dropdown<String>(
                    value: categoriaSeleccionada,
                    expanded: false,
                    items: categorias
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => categoriaSeleccionada = v!),
                  ),
                  const SizedBox(height: 16),
                  _titulo('Recetas'),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('app-recetas-completas')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(
                          child: CircularProgressIndicator(color: _verde),
                        );
                      final recetas = _ordenarDocs(
                        snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final nombre = (data['nombre'] ?? '')
                              .toString()
                              .toLowerCase();
                          final categoria = (data['categoria'] ?? '')
                              .toString()
                              .toLowerCase();
                          return nombre.contains(buscarReceta) &&
                              (categoriaSeleccionada == 'Todas' ||
                                  categoria ==
                                      categoriaSeleccionada.toLowerCase());
                        }).toList(),
                        'nombre',
                        'A-Z',
                      );

                      return Column(
                        children: recetas.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return GestureDetector(
                            onTap: () =>
                                _mostrarDetalleReceta(context, doc.id, data),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      data['imagen'] ?? '',
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 56,
                                        height: 56,
                                        color: _verdeClaro,
                                        child: const Icon(
                                          Icons.image,
                                          color: _verde,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['nombre'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          data['categoria'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],

                if (seccion == 'favoritos') ...[
                  _buildBarraBusqueda(
                    ctrl: buscarFavoritoCtrl,
                    valor: buscarFavorito,
                    hint: 'Buscar usuario...',
                    formato: formatoFavoritos,
                    onChangedBuscar: (v) =>
                        setState(() => buscarFavorito = v.toLowerCase()),
                    onClearBuscar: () => setState(() {
                      buscarFavorito = '';
                      buscarFavoritoCtrl.clear();
                    }),
                    onChangedFormato: (v) =>
                        setState(() => formatoFavoritos = v!),
                    onExportar: () async {
                      if (formatoFavoritos == 'PDF')
                        await PdfService.generarReporteFavoritos();
                      else if (formatoFavoritos == 'Excel')
                        await PdfService.generarExcelFavoritos();
                      else if (formatoFavoritos == 'CSV')
                        await PdfService.generarCsvFavoritos();
                    },
                  ),
                  const SizedBox(height: 16),
                  _titulo('Favoritos por usuario'),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('app-usuarios')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(
                          child: CircularProgressIndicator(color: _verde),
                        );
                      final usuarios = _ordenarDocs(
                        snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final nombre = (data['nombre'] ?? '')
                              .toString()
                              .toLowerCase();
                          return nombre.contains(buscarFavorito);
                        }).toList(),
                        'nombre',
                        'A-Z',
                      );

                      return Column(
                        children: usuarios.map((userDoc) {
                          final userData =
                              userDoc.data() as Map<String, dynamic>;
                          final uid = userDoc.id;
                          final paleta = _paletaPara(uid);
                          return GestureDetector(
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: Text(
                                  userData['nombre'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                content: FutureBuilder<QuerySnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('app-usuarios')
                                      .doc(uid)
                                      .collection('favoritos')
                                      .get(),
                                  builder: (context, favSnapshot) {
                                    if (!favSnapshot.hasData)
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: _verde,
                                        ),
                                      );
                                    final favoritos = favSnapshot.data!.docs;
                                    return SizedBox(
                                      width: 300,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _verdeClaro,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '${favoritos.length} favoritos',
                                              style: const TextStyle(
                                                color: _verde,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  PdfService.generarReporteFavoritosUsuario(
                                                    userData['nombre'] ?? '',
                                                    userData['correo'] ??
                                                        userData['email'] ??
                                                        '',
                                                    favoritos,
                                                  ),
                                              icon: const Icon(
                                                Icons.picture_as_pdf,
                                                size: 16,
                                              ),
                                              label: const Text('Exportar PDF'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _verde,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...favoritos.map((favDoc) {
                                            final fav =
                                                favDoc.data()
                                                    as Map<String, dynamic>;
                                            return ListTile(
                                              dense: true,
                                              leading: const Icon(
                                                Icons.favorite,
                                                color: Colors.red,
                                                size: 18,
                                              ),
                                              title: Text(
                                                fav['nombre'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            child: _itemLista(
                              leading: CircleAvatar(
                                backgroundColor: paleta[1],
                                child: Icon(Icons.person, color: paleta[0]),
                              ),
                              titulo: userData['nombre'] ?? 'Sin nombre',
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Nuevo Header verde con Yagu ────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2D9E73),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 0, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Texto izquierdo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Row(
                      children: [
                        const Icon(Icons.menu, color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            children: [
                              TextSpan(
                                text: 'Yagu ',
                                style: TextStyle(color: Colors.white),
                              ),
                              TextSpan(
                                text: 'reporta',
                                style: TextStyle(color: Color(0xFFB2DFCD)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '¡Hola, Admin! 👋',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Yagu preparó tu resumen de hoy',
                      style: TextStyle(color: Color(0xFFB2DFCD), fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Imagen Yagu
              Image.asset(
                'assets/images/yagu_reportes.png',
                height: 130,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const SizedBox(height: 130, width: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tarjeta "Yagu dice" ────────────────────────────────────────────────────
  Widget _buildYaguDice() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('app-Categorías')
          .snapshots(),
      builder: (context, snap) {
        // Para el mensaje usamos la primera categoría como la más popular (simplificado)
        final categoria = snap.hasData && snap.data!.docs.isNotEmpty
            ? (snap.data!.docs.first.data() as Map)['nombre']?.toString() ??
                  'Postres'
            : 'Postres';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFE0A8), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5A623),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lightbulb,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Yagu dice:\n',
                        style: TextStyle(
                          color: Color(0xFFF5A623),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: 'La categoría '),
                      TextSpan(
                        text: categoria,
                        style: const TextStyle(
                          color: Color(0xFF2D9E73),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                        text: ' fue la más consultada esta semana. 🍰',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 4 tarjetas de métricas ─────────────────────────────────────────────────
  Widget _buildMetricas() {
    return Row(
      children: [
        Expanded(
          child: _metricaTile(
            'Usuarios',
            Icons.people,
            FirebaseFirestore.instance.collection('app-usuarios').snapshots(),
            const Color(0xFFE8F5FF),
            const Color(0xFF4A90D9),
            '12%',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricaTile(
            'Recetas',
            Icons.restaurant_menu,
            FirebaseFirestore.instance
                .collection('app-recetas-completas')
                .snapshots(),
            const Color(0xFFFFF3E0),
            const Color(0xFFF5A623),
            '8%',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricaTile(
            'Favoritos',
            Icons.favorite,
            FirebaseFirestore.instance.collection('app-usuarios').snapshots(),
            const Color(0xFFFFEBEB),
            Colors.redAccent,
            '5%',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricaTile(
            'Planificados',
            Icons.calendar_month,
            FirebaseFirestore.instance.collection('app-Categorías').snapshots(),
            const Color(0xFFEFE9FF),
            Colors.deepPurple,
            '3%',
          ),
        ),
      ],
    );
  }

  Widget _metricaTile(
    String label,
    IconData icono,
    Stream<QuerySnapshot> stream,
    Color bg,
    Color accent,
    String pct,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (ctx, snap) {
        final total = snap.hasData ? snap.data!.docs.length : 0;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: accent, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '↑ $pct',
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Barra buscar + formato + exportar (estilo mockup) ─────────────────────
  Widget _buildBarraBusqueda({
    required TextEditingController ctrl,
    required String valor,
    required String hint,
    required String formato,
    required ValueChanged<String> onChangedBuscar,
    required VoidCallback onClearBuscar,
    required ValueChanged<String?> onChangedFormato,
    required VoidCallback onExportar,
  }) {
    return Column(
      children: [
        // Buscador
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[400]),
            suffixIcon: valor.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: onClearBuscar,
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: onChangedBuscar,
        ),
        const SizedBox(height: 10),
        // Formato + Exportar
        Row(
          children: [
            // Dropdown formato
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButton<String>(
                value: formato,
                underline: const SizedBox(),
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: 'PDF',
                    child: Text(
                      'PDF',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Excel',
                    child: Text(
                      'Excel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'CSV',
                    child: Text(
                      'CSV',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                onChanged: onChangedFormato,
              ),
            ),
            const SizedBox(width: 10),
            // Botón exportar
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onExportar,
                icon: const Icon(
                  Icons.download_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'Exportar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _verde,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cardResumen(
    String titulo,
    IconData icono,
    Stream<QuerySnapshot> stream,
    Color color,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final total = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Icon(icono, size: 28, color: color),
              const SizedBox(height: 8),
              Text(
                total.toString(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                titulo,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _itemLista({
    required Widget leading,
    required String titulo,
    String? subtitulo,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (subtitulo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _titulo(String texto) {
    return Row(
      children: [
        Text(
          texto,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _infoFila(IconData icono, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 14, color: _verde),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFecha(DateTime dt) {
    const meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${dt.day.toString().padLeft(2, '0')} ${meses[dt.month - 1]} ${dt.year}';
  }

  // Detalle completo de receta con ingredientes + pasos + PDF
  void _mostrarDetalleReceta(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Imagen
                      if ((data['imagen'] ?? '').isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            data['imagen'],
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 180,
                              color: _verdeClaro,
                              child: const Icon(
                                Icons.restaurant,
                                color: _verde,
                                size: 60,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Nombre + info básica
                      Text(
                        data['nombre'] ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        children: [
                          if ((data['categoria'] ?? '').isNotEmpty)
                            _badge(
                              Icons.category,
                              data['categoria'],
                              Colors.purple,
                            ),
                          _badge(
                            Icons.local_fire_department,
                            _formatearCalorias(data['calorias']),
                            Colors.orange,
                          ),
                          if ((int.tryParse(
                                    data['tiempo']?.toString() ?? '0',
                                  ) ??
                                  0) >
                              0)
                            _badge(
                              Icons.access_time,
                              '${data['tiempo']} min',
                              Colors.blue,
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Ingredientes
                      _subtitulo('Ingredientes'),
                      const SizedBox(height: 8),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _cargarIngredientes(data['ingredientes'] ?? []),
                        builder: (context, snap) {
                          if (!snap.hasData)
                            return const Center(
                              child: CircularProgressIndicator(color: _verde),
                            );
                          if (snap.data!.isEmpty)
                            return Text(
                              'Sin ingredientes',
                              style: TextStyle(color: Colors.grey[500]),
                            );
                          return Column(
                            children: snap.data!
                                .map(
                                  (ing) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: _verde,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _formatearIngrediente(ing),
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Pasos
                      _subtitulo('Preparación'),
                      const SizedBox(height: 8),
                      FutureBuilder<List<String>>(
                        future: _cargarPasos(docId, data),
                        builder: (context, snap) {
                          if (!snap.hasData)
                            return const Center(
                              child: CircularProgressIndicator(color: _verde),
                            );
                          if (snap.data!.isEmpty)
                            return Text(
                              'Sin pasos registrados',
                              style: TextStyle(color: Colors.grey[500]),
                            );
                          return Column(
                            children: snap.data!
                                .asMap()
                                .entries
                                .map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: const BoxDecoration(
                                            color: _verde,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${e.key + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              e.value,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      const Divider(height: 1, thickness: 1),
                    ],
                  ),
                ),
              ),
              // ── Botón fijo fuera del scroll ──────────────────────────
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final pasos = await _cargarPasos(docId, data);
                        final ings = await _cargarIngredientes(
                          data['ingredientes'] ?? [],
                        );
                        if (formatoRecetas == 'PDF')
                          await PdfService.generarReporteRecetaIndividual(
                            data,
                            ings,
                            pasos,
                          );
                        else if (formatoRecetas == 'Excel')
                          await PdfService.generarExcelRecetaIndividual(
                            data,
                            ings,
                            pasos,
                          );
                        else
                          await PdfService.generarCsvRecetaIndividual(
                            data,
                            ings,
                            pasos,
                          );
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        'Exportar ${formatoRecetas == 'PDF'
                            ? 'PDF'
                            : formatoRecetas == 'Excel'
                            ? 'Excel'
                            : 'CSV'} completo',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _verde,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _cargarIngredientes(
    List<dynamic> rawIngs,
  ) async {
    final List<Map<String, dynamic>> result = [];
    for (final item in rawIngs) {
      if (item is! Map) continue;
      final id = item['ingrediente_id']?.toString() ?? '';
      final cantidad = item['cantidad']?.toString() ?? '';
      final unidad = item['unidad']?.toString() ?? '';
      String nombre = id.replaceAll('-', ' ');
      if (id.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('ingredientes_maestros')
              .doc(id)
              .get();
          if (doc.exists) nombre = doc.data()!['nombre']?.toString() ?? nombre;
        } catch (_) {}
      }
      result.add({'nombre': nombre, 'cantidad': cantidad, 'unidad': unidad});
    }
    return result;
  }

  Future<List<String>> _cargarPasos(
    String docId,
    Map<String, dynamic> data,
  ) async {
    List<dynamic> pasos = [];
    if (data.containsKey('pasos_ordenados')) {
      pasos = List.from(data['pasos_ordenados'] ?? []);
    } else if (data.containsKey('pasos')) {
      pasos = List.from(data['pasos'] ?? []);
    }
    if (pasos.isEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('steps-recetas')
            .doc(docId)
            .get();
        if (doc.exists) pasos = List.from(doc.data()!['pasos_ordenados'] ?? []);
        if (pasos.isEmpty) {
          final q = await FirebaseFirestore.instance
              .collection('steps-recetas')
              .where('receta_id', isEqualTo: docId)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty)
            pasos = List.from(q.docs.first.data()['pasos_ordenados'] ?? []);
        }
      } catch (_) {}
    }
    pasos.sort((a, b) {
      final oa = int.tryParse(a['orden']?.toString() ?? '0') ?? 0;
      final ob = int.tryParse(b['orden']?.toString() ?? '0') ?? 0;
      return oa.compareTo(ob);
    });
    return pasos
        .map((p) => (p['instruccion'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Widget _badge(IconData icono, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtitulo(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A2E),
      ),
    );
  }

  /// Formatea una línea de ingrediente mostrando cantidad, unidad y nombre.
  /// Si la unidad está vacía se omite para evitar "4  de papas holandesas".
  String _formatearIngrediente(Map<String, dynamic> ing) {
    final cantidad = _aFraccion(ing['cantidad']?.toString() ?? '');
    final unidad = (ing['unidad'] ?? '').toString().trim();
    final nombre = (ing['nombre'] ?? '').toString().trim();

    if (cantidad.isEmpty && unidad.isEmpty) return nombre;
    if (unidad.isEmpty) return '$cantidad de $nombre';
    if (cantidad.isEmpty) return '$unidad de $nombre';
    return '$cantidad $unidad de $nombre';
  }

  /// Formatea calorías: muestra el valor si existe y es > 0, o "Sin datos" si no.
  String _formatearCalorias(dynamic valor) {
    if (valor == null) return 'Sin calorías';
    final cal = double.tryParse(valor.toString());
    if (cal == null || cal <= 0) return 'Sin calorías';
    return '${cal.toStringAsFixed(0)} cal';
  }

  /// Convierte un valor numérico a fracción legible.
  /// Ej: 0.5 → "½", 0.25 → "¼", 1.5 → "1½", 2.0 → "2"
  String _aFraccion(String raw) {
    final val = double.tryParse(raw.trim());
    if (val == null || raw.trim().isEmpty) return raw;

    final fracciones = {
      0.125: '⅛',
      0.25: '¼',
      0.333: '⅓',
      0.5: '½',
      0.667: '⅔',
      0.75: '¾',
    };

    final entero = val.truncate();
    final decimal = val - entero;

    String parteDecimal = '';
    for (final entry in fracciones.entries) {
      if ((decimal - entry.key).abs() < 0.04) {
        parteDecimal = entry.value;
        break;
      }
    }

    if (parteDecimal.isEmpty) {
      // Si no coincide con fracción conocida, mostrar el valor limpio
      return val == val.truncateToDouble()
          ? entero.toString()
          : val
                .toStringAsFixed(2)
                .replaceAll(RegExp(r'0+$'), '')
                .replaceAll(RegExp(r'\.$'), '');
    }

    if (entero == 0) return parteDecimal;
    return '$entero$parteDecimal';
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

class GestionarUsuariosScreen extends StatefulWidget {
  const GestionarUsuariosScreen({super.key});

  @override
  State<GestionarUsuariosScreen> createState() =>
      _GestionarUsuariosScreenState();
}

class _GestionarUsuariosScreenState extends State<GestionarUsuariosScreen> {
  static const Color _verde        = Color(0xFF2D9E73);
  static const Color _verdeClaro   = Color(0xFFE8F7F1);
  static const Color _mostaza      = Color(0xFFF5A623);
  static const Color _cafe         = Color(0xFF8B5E3C);
  static const Color _fondo        = Color(0xFFF5F6FA);
  static const Color _rojo         = Color(0xFFE53935);

  String _buscar    = '';
  String _filtroRol = 'Todos';

  final _buscarCtrl = TextEditingController();

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _ordenar(List<QueryDocumentSnapshot> lista) {
    lista.sort((a, b) {
      final da = a.data() as Map<String, dynamic>;
      final db = b.data() as Map<String, dynamic>;
      final na = (da['nombre'] ?? '').toString().trim().toLowerCase();
      final nb = (db['nombre'] ?? '').toString().trim().toLowerCase();
      if (na.isEmpty && nb.isEmpty) return 0;
      if (na.isEmpty) return 1;
      if (nb.isEmpty) return -1;
      return na.compareTo(nb);
    });
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: Column(
        children: [
          _buildHeader(context),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _fondo,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _buscarCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar usuario...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                      suffixIcon: _buscar.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded, color: Colors.grey[400], size: 18),
                              onPressed: () => setState(() {
                                _buscar = '';
                                _buscarCtrl.clear();
                              }),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) => setState(() => _buscar = v.toLowerCase()),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildFiltro(
                      icono: Icons.people_outline_rounded,
                      color: const Color(0xFF6D4C41),
                      colorFondo: const Color(0xFFF5EDE6),
                      valor: _filtroRol,
                      items: const ['Todos', 'user', 'admin'],
                      labels: const ['Todos', 'Usuarios', 'Admins'],
                      onChanged: (v) => setState(() => _filtroRol = v),
                    ),
                    const Spacer(),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('app-usuarios')
                          .snapshots(),
                      builder: (_, snap) {
                        final total = snap.data?.docs.length ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6D4C41),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$total usuarios',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('app-usuarios')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _verde));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildVacio('No hay usuarios registrados');
                }

                var lista = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                  final correo = (data['correo'] ?? data['email'] ?? '')
                      .toString()
                      .toLowerCase();
                  final rol = data['rol'] ?? 'user';
                  return (nombre.contains(_buscar) || correo.contains(_buscar)) &&
                      (_filtroRol == 'Todos' || rol == _filtroRol);
                }).toList();

                lista = _ordenar(lista);

                if (lista.isEmpty) {
                  return _buildVacio('Sin resultados para "$_buscar"');
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc  = lista[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return _UsuarioCard(
                      docId: doc.id,
                      data: data,
                      onRolChanged: () =>
                          _confirmarCambioRol(context, doc.id, data),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFE0F5EF),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _verde,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _verde.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Gestionar\nusuarios',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Administra roles y permisos',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 115,
                  height: 115,
                  color: const Color(0xFFE0F5EF),
                  child: Image.asset(
                    'assets/images/jaguar_admin.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: _verde,
                      size: 52,
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

  Widget _buildFiltro({
    required IconData icono,
    required Color color,
    required Color colorFondo,
    required String valor,
    required List<String> items,
    required List<String> labels,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: color, size: 15),
          const SizedBox(width: 5),
          DropdownButton<String>(
            value: valor,
            underline: const SizedBox(),
            isDense: true,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600),
            dropdownColor: Colors.white,
            iconEnabledColor: color,
            items: List.generate(
              items.length,
              (i) => DropdownMenuItem(value: items[i], child: Text(labels[i])),
            ),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVacio(String mensaje) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(mensaje,
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _confirmarCambioRol(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final esAdmin = (data['rol'] ?? 'user') == 'admin';
    final nombre  = data['nombre'] ?? 'este usuario';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              esAdmin ? Icons.person_remove_rounded : Icons.shield_rounded,
              color: esAdmin ? _rojo : _verde,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                esAdmin ? 'Quitar admin' : 'Hacer administrador',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          esAdmin
              ? '¿Quitar permisos de admin a "$nombre"? Pasará a ser usuario normal.'
              : '¿Dar permisos de administrador a "$nombre"?',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: esAdmin ? _rojo : _verde,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              esAdmin ? 'Quitar admin' : 'Hacer admin',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await FirebaseFirestore.instance
        .collection('app-usuarios')
        .doc(docId)
        .update({'rol': esAdmin ? 'user' : 'admin'});

    final actualUser = FirebaseAuth.instance.currentUser;
    if (actualUser != null && actualUser.uid == docId && esAdmin) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }
}

class _UsuarioCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onRolChanged;

  static const Color _verde        = Color(0xFF2D9E73);
  static const Color _verdeClaro   = Color(0xFFE8F7F1);
  static const Color _mostaza      = Color(0xFFF5A623);
  static const Color _mostazaClaro = Color(0xFFFFF3DC);
  static const Color _cafe         = Color(0xFF8B5E3C);
  static const Color _rojo         = Color(0xFFE53935);

  static const List<List<Color>> _paletasUsuario = [
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
    return _paletasUsuario[hash % _paletasUsuario.length];
  }

  const _UsuarioCard({
    required this.docId,
    required this.data,
    required this.onRolChanged,
  });

  @override
  Widget build(BuildContext context) {
    final String nombre = data['nombre'] ?? '';
    final String correo = data['correo'] ?? data['email'] ?? '';
    final String rol    = data['rol'] ?? 'user';
    final bool esAdmin  = rol == 'admin';

    String fechaStr = '';
    if (data['creadoEn'] != null) {
      try {
        final dt = (data['creadoEn'] as dynamic).toDate() as DateTime;
        const meses = ['Ene','Feb','Mar','Abr','May','Jun',
                       'Jul','Ago','Sep','Oct','Nov','Dic'];
        fechaStr = 'Se unió el ${dt.day.toString().padLeft(2,'0')} '
            '${meses[dt.month - 1]} ${dt.year}';
      } catch (_) {}
    }

    final List<Color> paleta = esAdmin ? [_mostaza, _mostazaClaro] : _paletaPara(docId);
    final Color avatarColor  = paleta[0];
    final Color avatarBg     = paleta[1];
    final Color rolTextColor = esAdmin ? _cafe : paleta[0];
    final Color puntoBg      = esAdmin ? _mostaza : paleta[0];
    final Color btnBg        = esAdmin ? _rojo.withValues(alpha: 0.08) : _verde.withValues(alpha: 0.08);
    final Color btnBorder    = esAdmin ? _rojo.withValues(alpha: 0.3)  : _verde.withValues(alpha: 0.3);
    final Color btnColor     = esAdmin ? _rojo : _verde;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: esAdmin
              ? _mostaza.withValues(alpha: 0.25)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: avatarBg, shape: BoxShape.circle),
                  child: Icon(
                    esAdmin ? Icons.shield_rounded : Icons.person_rounded,
                    color: avatarColor,
                    size: 26,
                  ),
                ),
                Positioned(
                  bottom: 1, right: 1,
                  child: Container(
                    width: 13, height: 13,
                    decoration: BoxDecoration(
                      color: puntoBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre.isNotEmpty ? nombre : 'Sin nombre',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: nombre.isNotEmpty ? const Color(0xFF1A1A2E) : Colors.grey[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: esAdmin ? _mostazaClaro : avatarBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      esAdmin ? 'Administrador' : 'Usuario',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: rolTextColor,
                      ),
                    ),
                  ),
                  if (correo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.mail_outline_rounded, size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(correo,
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1),
                        ),
                      ],
                    ),
                  ],
                  if (fechaStr.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 10, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(fechaStr,
                            style: TextStyle(fontSize: 10.5, color: Colors.grey[400])),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRolChanged,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: btnBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: btnBorder, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      esAdmin ? Icons.person_remove_rounded : Icons.shield_rounded,
                      size: 16,
                      color: btnColor,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      esAdmin ? 'Quitar\nadmin' : 'Hacer\nadmin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: btnColor,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
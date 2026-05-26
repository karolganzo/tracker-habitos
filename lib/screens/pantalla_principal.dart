import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/habito.dart';
import '../logica_estadisticas.dart';
import 'formulario_habito.dart';


class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final CollectionReference _coleccion =
      FirebaseFirestore.instance.collection('habitos');

  String _fechaHoy() {
    final ahora = DateTime.now();
    final mes = ahora.month.toString().padLeft(2, '0');
    final dia = ahora.day.toString().padLeft(2, '0');
    return '${ahora.year}-$mes-$dia';
  }

  String _horaDisplay(BuildContext context, String hhmm) {
    if (hhmm.isEmpty) return '';
    final p = hhmm.split(':');
    final t = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    return t.format(context);
  }

  String _fechaEncabezado() {
    final ahora = DateTime.now();
    const dias = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves',
      'Viernes', 'Sábado', 'Domingo'
    ];
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${dias[ahora.weekday - 1]} ${ahora.day} de ${meses[ahora.month - 1]}';
  }

  // Devuelve un mensaje motivador según el progreso del día
  String _mensajeMotivador(int completados, int total) {
    if (total == 0) return '¡Crea tu primer hábito! 🌱';
    if (completados == 0) return '¡A darle, tú puedes! 💪';
    if (completados == total) return '¡Día perfecto! 🎉🔥';
    final restantes = total - completados;
    if (completados / total >= 0.5) {
      return '¡Ya casi! Te falta${restantes == 1 ? '' : 'n'} $restantes 🙌';
    }
    return '¡Buen comienzo, sigue así! ✨';
  }

  Future<void> _alternarHabito(Habito habito) async {
    final hoy = _fechaHoy();
    habito.alternar(hoy);
    await _coleccion.doc(habito.id).update({
      'completados': habito.completados,
    });
  }

  Future<void> _eliminarHabito(Habito habito) async {
    await _coleccion.doc(habito.id).delete();
  }

  void _abrirFormulario({Habito? habito}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FormularioHabito(habito: habito)),
    );
  }

  void _confirmarEliminar(Habito habito) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar hábito?'),
        content: Text('Se eliminará "${habito.nombre}" y su historial.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _eliminarHabito(habito);
              Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoy = _fechaHoy();
    final ahora = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _coleccion.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final docs = snapshot.data?.docs ?? [];

            final todos = docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Habito(
                id: doc.id,
                nombre: data['nombre'] ?? '',
                descripcion: data['descripcion'] ?? '',
                hora: data['hora'] ?? '',
                dias: (data['dias'] as List?)
                        ?.map((e) => (e as num).toInt())
                        .toList() ??
                    [],
                completados:
                    List<String>.from(data['completados'] ?? <String>[]),
                creado: data['creado'] ?? '',
                color: (data['color'] as num?)?.toInt() ?? 0xFFF5C518,
              );
            }).toList();

            // Solo los hábitos programados para HOY
            final habitosHoy = todos
                .where((h) => habitoAplicaEnFecha(h.dias, ahora))
                .toList();

            // Ordenar por hora: primero los que tienen hora (más temprana
            // arriba), y al final los que no tienen hora asignada.
            habitosHoy.sort((a, b) {
              if (a.hora.isEmpty && b.hora.isEmpty) return 0;
              if (a.hora.isEmpty) return 1;
              if (b.hora.isEmpty) return -1;
              return a.hora.compareTo(b.hora);
            });

            // Estadísticas globales (consideran los días programados).
            final habitosMap = todos.map((h) {
              return {
                'completados': h.completados,
                'dias': h.dias,
              };
            }).toList();
            final stats = calcularEstadisticas(habitosMap);

            final completadosHoy =
                habitosHoy.where((h) => h.estaCompletado(hoy)).length;
            final total = habitosHoy.length;
            final progreso = total == 0 ? 0.0 : completadosHoy / total;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- Encabezado con racha ----------
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 6),
                      Text('${stats.rachaActual}',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(
                        _fechaEncabezado(),
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---------- Tarjeta de progreso ----------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _mensajeMotivador(completadosHoy, total),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF5C518),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progreso,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey[800],
                                  valueColor:
                                      const AlwaysStoppedAnimation(
                                          Color(0xFFF5C518)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$completadosHoy / $total',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ---------- Lista de hábitos de hoy ----------
                Expanded(
                  child: todos.isEmpty
                      ? Center(
                          child: Text(
                            'Aún no tienes hábitos.\nToca + para crear el primero.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      : habitosHoy.isEmpty
                          ? Center(
                              child: Text(
                                'No tienes hábitos programados para hoy. 🎉',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20),
                              itemCount: habitosHoy.length,
                              itemBuilder: (context, index) {
                                final habito = habitosHoy[index];
                                final hecho = habito.estaCompletado(hoy);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1C1C1E),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border(
                                      left: BorderSide(
                                        color: Color(habito.color),
                                        width: 4,
                                      ),
                                    ),
                                  ),
                                  child: ListTile(
                                    onTap: () => _alternarHabito(habito),
                                    leading: Icon(
                                      hecho
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color: hecho
                                          ? Color(habito.color)
                                          : Colors.grey,
                                      size: 28,
                                    ),
                                    title: Text(
                                      habito.nombre,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        decoration: hecho
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: hecho
                                            ? Colors.grey
                                            : Colors.white,
                                      ),
                                    ),
                                    subtitle: (habito.hora.isEmpty &&
                                            habito.descripcion.isEmpty)
                                        ? null
                                        : Row(
                                            children: [
                                              if (habito.hora.isNotEmpty) ...[
                                                Icon(Icons.access_time,
                                                    size: 14,
                                                    color: Colors.grey[500]),
                                                const SizedBox(width: 3),
                                              ],
                                              Text(
                                                [
                                                  if (habito.hora.isNotEmpty)
                                                    _horaDisplay(context,
                                                        habito.hora),
                                                  if (habito.descripcion
                                                      .isNotEmpty)
                                                    habito.descripcion,
                                                ].join('   ·   '),
                                              ),
                                            ],
                                          ),
                                    trailing: PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert,
                                          color: Colors.grey),
                                      onSelected: (op) {
                                        if (op == 'editar') {
                                          _abrirFormulario(habito: habito);
                                        } else if (op == 'eliminar') {
                                          _confirmarEliminar(habito);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: 'editar',
                                            child: Text('Editar')),
                                        PopupMenuItem(
                                            value: 'eliminar',
                                            child: Text('Eliminar')),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(),
        backgroundColor: const Color(0xFFF5C518),
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }

}
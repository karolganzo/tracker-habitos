import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/habito.dart';
import '../logica_estadisticas.dart';
import 'pantalla_detalle_habito.dart';
import 'formulario_habito.dart';

class PantallaHabitos extends StatefulWidget {
  const PantallaHabitos({super.key});

  @override
  State<PantallaHabitos> createState() => _PantallaHabitosState();
}

class _PantallaHabitosState extends State<PantallaHabitos> {
  final _coleccion = FirebaseFirestore.instance.collection('habitos');

  String _diasTexto(List<int> dias) {
    if (dias.isEmpty || dias.length == 7) return 'Todos los días';
    const nombres = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final orden = [...dias]..sort();
    return orden.map((d) => nombres[d - 1]).join(', ');
  }

  String _horaTexto(BuildContext context, String hhmm) {
    if (hhmm.isEmpty) return '';
    final p = hhmm.split(':');
    final t = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    return t.format(context);
  }

  Future<void> _eliminarHabito(Habito habito) async {
    await _coleccion.doc(habito.id).delete();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Mis hábitos')),
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

            if (docs.isEmpty) {
              return Center(
                child: Text(
                  'Aún no tienes hábitos.\nCréalos desde la pestaña "Hoy".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500]),
                ),
              );
            }

            // Convertimos a objetos Habito y ordenamos alfabéticamente
            final habitos = docs.map((doc) {
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
            }).toList()
              ..sort((a, b) =>
                  a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: habitos.length,
              itemBuilder: (context, index) {
                final habito = habitos[index];

                final stats = calcularEstadisticasHabito(
                  completados: habito.completados,
                  dias: habito.dias,
                  creado: habito.creado,
                );
                final porcentaje = (stats.porcentaje * 100).round();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PantallaDetalleHabito(habito: habito),
                        ),
                      );
                    },
                    title: Text(
                      habito.nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (habito.hora.isNotEmpty) ...[
                            Icon(Icons.access_time,
                                size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            [
                              if (habito.hora.isNotEmpty)
                                _horaTexto(context, habito.hora),
                              _diasTexto(habito.dias),
                            ].join('   ·   '),
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Indicador circular de %
                        SizedBox(
                          width: 46,
                          height: 46,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 46,
                                height: 46,
                                child: CircularProgressIndicator(
                                  value: stats.porcentaje,
                                  strokeWidth: 4,
                                  backgroundColor: Colors.grey[850],
                                  valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFF34C759)),
                                ),
                              ),
                              Text('$porcentaje%',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              color: Colors.grey),
                          onSelected: (op) {
                            if (op == 'editar') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FormularioHabito(habito: habito),
                                ),
                              );
                            } else if (op == 'eliminar') {
                              _confirmarEliminar(habito);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'editar', child: Text('Editar')),
                            PopupMenuItem(
                                value: 'eliminar', child: Text('Eliminar')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FormularioHabito()),
          );
        },
        backgroundColor: const Color(0xFFF5C518),
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}

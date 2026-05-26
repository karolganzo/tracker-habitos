import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import '../logica_estadisticas.dart';

class PantallaRachas extends StatefulWidget {
  const PantallaRachas({super.key});

  @override
  State<PantallaRachas> createState() => _PantallaRachasState();
}

class _PantallaRachasState extends State<PantallaRachas> {
  final CollectionReference _coleccion =
      FirebaseFirestore.instance.collection('habitos');
  DateTime _diaFocal = DateTime.now();

  String _fechaTexto(DateTime d) {
    final mes = d.month.toString().padLeft(2, '0');
    final dia = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mes-$dia';
  }

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF34C759);
    const amarillo = Color(0xFFF5C518);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Rachas')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _coleccion.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            // Guardamos completados y días de cada hábito.
            final habitosMap = <Map<String, dynamic>>[];
            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              habitosMap.add({
                'completados':
                    List<String>.from(data['completados'] ?? <String>[]),
                'dias': (data['dias'] as List?)
                        ?.map((e) => (e as num).toInt())
                        .toList() ??
                    <int>[],
              });
            }

            final stats = calcularEstadisticas(habitosMap);

            // Color del puntito de un día: cuántos tocaban vs cuántos se
            // cumplieron ese día.
            Color colorDoto(DateTime dia) {
              final fechaTxt = _fechaTexto(dia);
              int tocaban = 0;
              int cumplidos = 0;
              for (final h in habitosMap) {
                final dias = List<int>.from(h['dias'] ?? <int>[]);
                if (!habitoAplicaEnFecha(dias, dia)) continue;
                tocaban++;
                final completados =
                    List<String>.from(h['completados'] ?? <String>[]);
                if (completados.contains(fechaTxt)) cumplidos++;
              }
              if (cumplidos == 0) return Colors.grey.shade800;
              if (cumplidos >= tocaban) return verde; // todos los que tocaban
              return amarillo;
            }

            final ultimos7 = List.generate(
              7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));
            final perfectos7 =
                ultimos7.where((d) => colorDoto(d) == verde).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---------- Las dos llamas ----------
                Row(
                  children: [
                    _tarjetaRacha(
                      color: verde,
                      titulo: 'Días Perfectos',
                      actual: stats.rachaActual,
                      mejor: stats.mejorRacha,
                    ),
                    const SizedBox(width: 12),
                    _tarjetaRacha(
                      color: amarillo,
                      titulo: 'Días Activos',
                      actual: stats.rachaActivaActual,
                      mejor: stats.mejorRachaActiva,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ---------- Resumen últimos 7 días ----------
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$perfectos7 / 7 perfectos',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ultimos7.map((dia) {
                          const etiquetas = [
                            'L', 'M', 'M', 'J', 'V', 'S', 'D'
                          ];
                          final esHoy = _fechaTexto(dia) ==
                              _fechaTexto(DateTime.now());
                          return Column(
                            children: [
                              Text(
                                etiquetas[dia.weekday - 1],
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      esHoy ? amarillo : Colors.grey[500],
                                  fontWeight: esHoy
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: colorDoto(dia),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---------- Calendario con puntitos ----------
                Card(
                  color: const Color(0xFF1C1C1E),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _diaFocal,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      rowHeight: 56,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Mes'
                      },
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                      calendarStyle:
                          const CalendarStyle(outsideDaysVisible: false),
                      onPageChanged: (foco) => _diaFocal = foco,
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (c, dia, f) =>
                            _celdaDoto(dia.day, colorDoto(dia)),
                        todayBuilder: (c, dia, f) =>
                            _celdaDoto(dia.day, colorDoto(dia), esHoy: true),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ---------- Leyenda ----------
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _leyenda(verde, 'Perfecto'),
                    const SizedBox(width: 16),
                    _leyenda(amarillo, 'Parcial'),
                    const SizedBox(width: 16),
                    _leyenda(Colors.grey.shade700, 'Sin actividad'),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tarjetaRacha({
    required Color color,
    required String titulo,
    required int actual,
    required int mejor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.local_fire_department, size: 52, color: color),
            const SizedBox(height: 8),
            Text(titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('$actual',
                style: TextStyle(
                    fontSize: 36, fontWeight: FontWeight.bold, color: color)),
            Text('racha actual',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            const SizedBox(height: 10),
            Divider(color: Colors.grey[800]),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, size: 16, color: color),
                const SizedBox(width: 6),
                Text('Mejor: $mejor',
                    style: TextStyle(color: Colors.grey[300])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _celdaDoto(int numero, Color colorDoto, {bool esHoy = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$numero',
            style: TextStyle(
              fontWeight: esHoy ? FontWeight.bold : FontWeight.normal,
              color: esHoy ? const Color(0xFFF5C518) : Colors.white,
            )),
        const SizedBox(height: 4),
        Container(
          width: 7,
          height: 7,
          decoration:
              BoxDecoration(color: colorDoto, shape: BoxShape.circle),
        ),
      ],
    );
  }

  Widget _leyenda(Color color, String texto) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
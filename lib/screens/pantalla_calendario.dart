import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import '../logica_estadisticas.dart';

class PantallaCalendario extends StatefulWidget {
  const PantallaCalendario({super.key});

  @override
  State<PantallaCalendario> createState() => _PantallaCalendarioState();
}

class _PantallaCalendarioState extends State<PantallaCalendario> {
  final CollectionReference _coleccion =
      FirebaseFirestore.instance.collection('habitos');

  DateTime _diaFocal = DateTime.now();
  DateTime _diaSeleccionado = DateTime.now();

  String _fechaTexto(DateTime d) {
    final mes = d.month.toString().padLeft(2, '0');
    final dia = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mes-$dia';
  }

  String _fechaBonita(DateTime d) {
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${d.day} de ${meses[d.month - 1]} de ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _coleccion.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Guardamos nombre, completados y días de cada hábito
            final habitos = <Map<String, dynamic>>[];
            for (final doc in docs(snapshot)) {
              final data = doc.data() as Map<String, dynamic>;
              habitos.add({
                'nombre': data['nombre'] ?? '',
                'completados':
                    List<String>.from(data['completados'] ?? <String>[]),
                'dias': (data['dias'] as List?)
                        ?.map((e) => (e as num).toInt())
                        .toList() ??
                    <int>[],
              });
            }

            // Color de un día: cuántos hábitos TOCABAN ese día vs cuántos
            // se cumplieron
            Color? colorDia(DateTime dia) {
              final fechaTxt = _fechaTexto(dia);
              int tocaban = 0;
              int cumplidos = 0;
              for (final h in habitos) {
                final dias = List<int>.from(h['dias'] ?? <int>[]);
                if (!habitoAplicaEnFecha(dias, dia)) continue;
                tocaban++;
                final completados =
                    List<String>.from(h['completados'] ?? <String>[]);
                if (completados.contains(fechaTxt)) cumplidos++;
              }
              if (cumplidos == 0) return null;
              if (cumplidos >= tocaban) return const Color(0xFF34C759); // todos
              return const Color(0xFFF5C518); // algunos
            }

            // Hábitos que TOCABAN el día seleccionado 
            final habitosDelDia = habitos
                .where((h) => habitoAplicaEnFecha(
                    List<int>.from(h['dias'] ?? <int>[]), _diaSeleccionado))
                .toList();

            final claveSel = _fechaTexto(_diaSeleccionado);

            return Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  color: const Color(0xFF1C1C1E),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _diaFocal,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    calendarStyle: const CalendarStyle(outsideDaysVisible: false),
                    selectedDayPredicate: (dia) =>
                        isSameDay(_diaSeleccionado, dia),
                    onDaySelected: (sel, foco) {
                      setState(() {
                        _diaSeleccionado = sel;
                        _diaFocal = foco;
                      });
                    },
                    onPageChanged: (foco) => _diaFocal = foco,
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, dia, foco) =>
                          _celda(dia.day, colorDia(dia)),
                      todayBuilder: (context, dia, foco) =>
                          _celda(dia.day, colorDia(dia), esHoy: true),
                      selectedBuilder: (context, dia, foco) =>
                          _celda(dia.day, colorDia(dia), seleccionado: true),
                    ),
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _leyenda(const Color(0xFF34C759), 'Todos'),
                    const SizedBox(width: 16),
                    _leyenda(const Color(0xFFF5C518), 'Algunos'),
                    const SizedBox(width: 16),
                    _leyenda(Colors.grey.shade700, 'Ninguno'),
                  ],
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        _fechaBonita(_diaSeleccionado),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (habitosDelDia.isEmpty)
                        Text('No había hábitos programados para este día.',
                            style: TextStyle(color: Colors.grey[500]))
                      else
                        ...habitosDelDia.map((h) {
                          final completados =
                              h['completados'] as List<String>;
                          final hecho = completados.contains(claveSel);
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              hecho
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: hecho
                                  ? const Color(0xFF34C759)
                                  : Colors.grey,
                            ),
                            title: Text('${h['nombre']}'),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot> docs(AsyncSnapshot<QuerySnapshot> snapshot) {
    return snapshot.data?.docs ?? [];
  }

  Widget _celda(int numero, Color? color,
      {bool esHoy = false, bool seleccionado = false}) {
    Border? borde;
    if (seleccionado) {
      borde = Border.all(color: Colors.white, width: 2);
    } else if (esHoy) {
      borde = Border.all(color: Colors.white24, width: 1.5);
    }
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: borde,
      ),
      alignment: Alignment.center,
      child: Text(
        '$numero',
        style: TextStyle(
          color: color != null ? Colors.black : Colors.white,
          fontWeight:
              (esHoy || seleccionado) ? FontWeight.bold : FontWeight.normal,
        ),
      ),
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
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/habito.dart';
import '../logica_estadisticas.dart';

class PantallaDetalleHabito extends StatefulWidget {
  final Habito habito;
  const PantallaDetalleHabito({super.key, required this.habito});

  @override
  State<PantallaDetalleHabito> createState() => _PantallaDetalleHabitoState();
}

class _PantallaDetalleHabitoState extends State<PantallaDetalleHabito> {
  DateTime _diaFocal = DateTime.now();

  static const _verde = Color(0xFF34C759);
  static const _amarillo = Color(0xFFF5C518);

  String _fechaTexto(DateTime d) {
    final mes = d.month.toString().padLeft(2, '0');
    final dia = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mes-$dia';
  }

  String _diasTexto(List<int> dias) {
    if (dias.isEmpty || dias.length == 7) return 'Todos los días';
    const nombres = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final orden = [...dias]..sort();
    return orden.map((d) => nombres[d - 1]).join(', ');
  }

  String _horaTexto(BuildContext context, String hhmm) {
    if (hhmm.isEmpty) return 'Sin hora';
    final p = hhmm.split(':');
    final t = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    return t.format(context);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.habito;
    final stats = calcularEstadisticasHabito(
      completados: h.completados,
      dias: h.dias,
      creado: h.creado,
    );
    final porcentaje = (stats.porcentaje * 100).round();

    // Color del puntito en el mini-calendario
    Color? colorDoto(DateTime dia) {
      if (!habitoAplicaEnFecha(h.dias, dia)) return null; // no tocaba: sin punto
      return h.completados.contains(_fechaTexto(dia))
          ? _verde
          : Colors.grey.shade800;
    }

    return Scaffold(
      appBar: AppBar(title: Text(h.nombre)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---------- Info básica ----------
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (h.descripcion.isNotEmpty) ...[
                    Text(h.descripcion,
                        style: TextStyle(color: Colors.grey[300])),
                    const SizedBox(height: 10),
                  ],
                  Row(children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(_horaTexto(context, h.hora)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.event_repeat, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(_diasTexto(h.dias)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---------- Círculo de porcentaje ----------
            Center(
              child: SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                        value: stats.porcentaje,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey[850],
                        valueColor: const AlwaysStoppedAnimation(_verde),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$porcentaje%',
                            style: const TextStyle(
                                fontSize: 34, fontWeight: FontWeight.bold)),
                        Text('cumplimiento',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[400])),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ---------- Tarjetas de stats ----------
            Row(
              children: [
                _stat('✅', '${stats.cumplidos}/${stats.programados}', 'Días'),
                const SizedBox(width: 10),
                _stat('🔥', '${stats.rachaActual}', 'Racha'),
                const SizedBox(width: 10),
                _stat('🏆', '${stats.mejorRacha}', 'Mejor'),
              ],
            ),
            const SizedBox(height: 20),

            // ---------- Mini-calendario del hábito ----------
            const Text('Historial',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              color: const Color(0xFF1C1C1E),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _diaFocal,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  rowHeight: 52,
                  availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarStyle: const CalendarStyle(outsideDaysVisible: false),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _leyenda(_verde, 'Cumplido'),
                const SizedBox(width: 16),
                _leyenda(Colors.grey.shade700, 'No cumplido'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String emoji, String valor, String etiqueta) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(valor,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(etiqueta,
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  Widget _celdaDoto(int numero, Color? colorDoto, {bool esHoy = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$numero',
            style: TextStyle(
              fontWeight: esHoy ? FontWeight.bold : FontWeight.normal,
              color: esHoy ? _amarillo : Colors.white,
            )),
        const SizedBox(height: 4),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: colorDoto ?? Colors.transparent,
            shape: BoxShape.circle,
          ),
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
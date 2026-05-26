import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/habito.dart';
import 'package:flutter/cupertino.dart';

class FormularioHabito extends StatefulWidget {
  final Habito? habito; // null = crear; con valor = editar
  const FormularioHabito({super.key, this.habito});

  @override
  State<FormularioHabito> createState() => _FormularioHabitoState();
}

class _FormularioHabitoState extends State<FormularioHabito> {
  final _coleccion = FirebaseFirestore.instance.collection('habitos');
  late TextEditingController _nombre;
  late TextEditingController _descripcion;
  TimeOfDay? _hora;
  late Set<int> _dias; // 1..7
  late int _color;

  static const _etiquetasDias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  static const _coloresPredefinidos = [
    0xFFF5C518, // amarillo
    0xFF34C759, // verde
    0xFF0A84FF, // azul
    0xFFFF453A, // rojo
    0xFFFF9F0A, // naranja
    0xFFBF5AF2, // morado
    0xFF5AC8FA, // cian
    0xFFFF2D55, // rosa
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.habito;
    _nombre = TextEditingController(text: h?.nombre ?? '');
    _descripcion = TextEditingController(text: h?.descripcion ?? '');
    // Si no hay días definidos, asumimos todos los días
    _dias = (h == null || h.dias.isEmpty)
        ? {1, 2, 3, 4, 5, 6, 7}
        : h.dias.toSet();
    if (h != null && h.hora.isNotEmpty) {
      final p = h.hora.split(':');
      _hora = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    _color = h?.color ?? 0xFFF5C518;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  // Convierte la hora elegida a texto "HH:mm" para guardar
  String _horaTexto() {
    if (_hora == null) return '';
    final hh = _hora!.hour.toString().padLeft(2, '0');
    final mm = _hora!.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
  // Selector de hora tipo rueda
  Future<void> _elegirHora() async {
    final base = _hora ?? const TimeOfDay(hour: 8, minute: 0);
    DateTime temp = DateTime(2020, 1, 1, base.hour, base.minute);

    final confirmado = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    const Text('Selecciona la hora',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Listo'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(brightness: Brightness.dark),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: temp,
                    use24hFormat:
                        MediaQuery.of(context).alwaysUse24HourFormat,
                    onDateTimeChanged: (d) => temp = d,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmado == true) {
      setState(() => _hora = TimeOfDay(hour: temp.hour, minute: temp.minute));
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre no puede estar vacío')),
      );
      return;
    }

    final datos = <String, dynamic>{
      'nombre': nombre,
      'descripcion': _descripcion.text.trim(),
      'hora': _horaTexto(),
      'dias': _dias.toList()..sort(),
      'color': _color,
    };

    if (widget.habito == null) {
      datos['completados'] = <String>[];
      datos['creado'] = DateTime.now().toIso8601String();
      await _coleccion.add(datos);
    } else {
      await _coleccion.doc(widget.habito!.id).update(datos);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.habito != null;

    return Scaffold(
      appBar: AppBar(title: Text(editando ? 'Editar hábito' : 'Nuevo hábito')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _nombre,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. Meditar',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descripcion,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Ej. 10 minutos',
              ),
            ),
            const SizedBox(height: 28),

            // ---------- Hora ----------
            const Text('Hora',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(
                        _hora == null ? 'Sin hora' : _hora!.format(context)),
                    onPressed: _elegirHora,
                  ),
                ),
                if (_hora != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Quitar hora',
                    onPressed: () => setState(() => _hora = null),
                  ),
              ],
            ),
            const SizedBox(height: 28),

            // ---------- Días de la semana ----------
            const Text('Días',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (i) {
                final dia = i + 1; // 1..7
                final activo = _dias.contains(dia);
                return FilterChip(
                  label: Text(_etiquetasDias[i]),
                  selected: activo,
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _dias.add(dia);
                      } else {
                        _dias.remove(dia);
                      }
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              _dias.length == 7
                  ? 'Todos los días'
                  : _dias.isEmpty
                      ? 'Selecciona al menos un día'
                      : '${_dias.length} días por semana',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            const SizedBox(height: 28),

            // ---------- Color ----------
            const Text('Color',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _coloresPredefinidos.map((c) {
                final seleccionado = _color == c;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: seleccionado
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 36),

            FilledButton(
              onPressed: _dias.isEmpty ? null : _guardar,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF5C518),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(editando ? 'Guardar cambios' : 'Crear hábito'),
            ),
          ],
        ),
      ),
    );
  }
}
class Estadisticas {
  final int rachaActual;       // racha de días perfectos
  final int mejorRacha;        // mejor racha de días perfectos
  final int rachaActivaActual; // racha de días activos (al menos uno)
  final int mejorRachaActiva;  // mejor racha de días activos
  final int totalCompletados;  // total histórico de marcas
  final int diasPerfectos;     // cantidad de días perfectos
  final int diasActivos;       // cantidad de días con al menos uno

  Estadisticas({
    required this.rachaActual,
    required this.mejorRacha,
    required this.rachaActivaActual,
    required this.mejorRachaActiva,
    required this.totalCompletados,
    required this.diasPerfectos,
    required this.diasActivos,
  });
}

String _fechaTexto(DateTime d) {
  final mes = d.month.toString().padLeft(2, '0');
  final dia = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mes-$dia';
}

DateTime _parseFecha(String f) {
  final p = f.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

bool habitoAplicaEnFecha(List<int> dias, DateTime fecha) {
  if (dias.isEmpty) return true;
  return dias.contains(fecha.weekday);
}

// Dado un conjunto de días "válidos", calcula la racha actual y la mejor.
({int actual, int mejor}) _rachas(Set<String> dias) {
  int actual = 0;
  DateTime cursor = DateTime.now();
  if (!dias.contains(_fechaTexto(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  while (dias.contains(_fechaTexto(cursor))) {
    actual++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  int mejor = 0;
  for (final fecha in dias) {
    final dia = _parseFecha(fecha);
    final anterior = dia.subtract(const Duration(days: 1));
    if (!dias.contains(_fechaTexto(anterior))) {
      int largo = 1;
      DateTime sig = dia.add(const Duration(days: 1));
      while (dias.contains(_fechaTexto(sig))) {
        largo++;
        sig = sig.add(const Duration(days: 1));
      }
      if (largo > mejor) mejor = largo;
    }
  }
  return (actual: actual, mejor: mejor);
}

Estadisticas calcularEstadisticas(List<Map<String, dynamic>> habitos) {
  if (habitos.isEmpty) {
    return Estadisticas(
      rachaActual: 0, mejorRacha: 0,
      rachaActivaActual: 0, mejorRachaActiva: 0,
      totalCompletados: 0, diasPerfectos: 0, diasActivos: 0,
    );
  }

  // Reunimos todas las fechas que aparecen en cualquier hábito.
  // Para cada una contaremos cuántos hábitos tocaban y cuántos se cumplieron.
  final Set<String> todasLasFechas = {};
  int totalCompletados = 0;

  for (final h in habitos) {
    final completados = List<String>.from(h['completados'] ?? <String>[]);
    totalCompletados += completados.length;
    todasLasFechas.addAll(completados);
  }

  final diasPerfectos = <String>{};
  final diasActivos = <String>{};

  for (final fechaTxt in todasLasFechas) {
    final fecha = _parseFecha(fechaTxt);

    int tocaban = 0;   // hábitos programados para ese día
    int cumplidos = 0; // de esos, cuántos se completaron

    for (final h in habitos) {
      final dias = List<int>.from(h['dias'] ?? <int>[]);
      if (!habitoAplicaEnFecha(dias, fecha)) continue; // no tocaba ese día
      tocaban++;
      final completados = List<String>.from(h['completados'] ?? <String>[]);
      if (completados.contains(fechaTxt)) cumplidos++;
    }

    if (cumplidos >= 1) diasActivos.add(fechaTxt);
    // Día perfecto: tocaba al menos uno y se cumplieron todos los que tocaban.
    if (tocaban > 0 && cumplidos >= tocaban) diasPerfectos.add(fechaTxt);
  }

  final rp = _rachas(diasPerfectos);
  final ra = _rachas(diasActivos);

  return Estadisticas(
    rachaActual: rp.actual,
    mejorRacha: rp.mejor,
    rachaActivaActual: ra.actual,
    mejorRachaActiva: ra.mejor,
    totalCompletados: totalCompletados,
    diasPerfectos: diasPerfectos.length,
    diasActivos: diasActivos.length,
  );
}

// ---------- Estadísticas de un solo hábito ----------

class EstadisticasHabito {
  final int cumplidos;    // veces que se completó
  final int programados;  // veces que tocaba (desde su creación hasta hoy)
  final double porcentaje; // 0..1
  final int rachaActual;  // ocurrencias programadas seguidas cumplidas
  final int mejorRacha;

  EstadisticasHabito({
    required this.cumplidos,
    required this.programados,
    required this.porcentaje,
    required this.rachaActual,
    required this.mejorRacha,
  });
}

EstadisticasHabito calcularEstadisticasHabito({
  required List<String> completados,
  required List<int> dias,
  required String creado,
}) {
  // Fecha de inicio: la de creación; si falta, usamos la primera marca u hoy.
  DateTime inicio;
  try {
    inicio = creado.isNotEmpty ? DateTime.parse(creado) : DateTime.now();
  } catch (_) {
    inicio = DateTime.now();
  }
  inicio = DateTime(inicio.year, inicio.month, inicio.day);

  final ahora = DateTime.now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final setCompletados = completados.toSet();

  // Recorremos día por día desde la creación hasta hoy.
  int programados = 0;
  int cumplidos = 0;
  int mejorRacha = 0;
  int corrida = 0;

  DateTime cursor = inicio;
  while (!cursor.isAfter(hoy)) {
    if (habitoAplicaEnFecha(dias, cursor)) {
      programados++;
      if (setCompletados.contains(_fechaTexto(cursor))) {
        cumplidos++;
        corrida++;
        if (corrida > mejorRacha) mejorRacha = corrida;
      } else {
        corrida = 0;
      }
    }
    cursor = cursor.add(const Duration(days: 1));
  }


  final hoyTocaba = habitoAplicaEnFecha(dias, hoy);
  final hoyCumplido = setCompletados.contains(_fechaTexto(hoy));
  int progAjustado = programados;
  if (hoyTocaba && !hoyCumplido) progAjustado--;
  final porcentaje = progAjustado <= 0 ? 0.0 : cumplidos / progAjustado;


  int rachaActual = 0;
  DateTime c = hoy;
  while (!c.isBefore(inicio)) {
    if (habitoAplicaEnFecha(dias, c)) {
      final cumplido = setCompletados.contains(_fechaTexto(c));
      if (cumplido) {
        rachaActual++;
      } else if (c == hoy) {
      } else {
        break;
      }
    }
    c = c.subtract(const Duration(days: 1));
  }

  return EstadisticasHabito(
    cumplidos: cumplidos,
    programados: programados,
    porcentaje: porcentaje,
    rachaActual: rachaActual,
    mejorRacha: mejorRacha,
  );
}
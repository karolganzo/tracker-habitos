class Habito {
  String id;
  String nombre;
  String descripcion;
  String hora;
  List<int> dias;
  List<String> completados;
  String creado; // fecha de creación (ISO), para calcular el % de cumplimiento
  int color;

  Habito({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.hora = '',
    List<int>? dias,
    List<String>? completados,
    this.creado = '',
    this.color = 0xFFF5C518,
  })  : dias = dias ?? [],
        completados = completados ?? [];

  bool estaCompletado(String fecha) => completados.contains(fecha);

  void alternar(String fecha) {
    if (completados.contains(fecha)) {
      completados.remove(fecha);
    } else {
      completados.add(fecha);
    }
  }
}
class Station {
  final String stationId;
  final String name;
  final List<String> aliases;
  final List<String> urdu;
  final List<String> pashto;
  final List<String> servedBy;

  Station({
    required this.stationId,
    required this.name,
    required this.aliases,
    required this.urdu,
    required this.pashto,
    required this.servedBy,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      stationId: json['station_id'] as String,
      name: json['name'] as String,
      aliases: List<String>.from(json['aliases'] as List? ?? const []),
      urdu: List<String>.from(json['urdu'] as List? ?? const []),
      pashto: List<String>.from(json['pashto'] as List? ?? const []),
      servedBy: List<String>.from(json['served_by'] as List? ?? const []),
    );
  }
}

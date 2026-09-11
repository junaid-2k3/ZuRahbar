class FareBand {
  final int index;
  final double minKm;
  final double? maxKm;
  final int farePkr;

  FareBand({required this.index, required this.minKm, this.maxKm, required this.farePkr});

  factory FareBand.fromJson(Map<String, dynamic> json) {
    return FareBand(
      index: json['index'] as int,
      minKm: (json['min_km'] as num).toDouble(),
      maxKm: (json['max_km'] as num?)?.toDouble(),
      farePkr: json['fare_pkr'] as int,
    );
  }
}

class Fares {
  final String currency;
  final String basis;
  final int singleJourneyTicketPkr;
  final int feederExpressFlatFarePkr;
  final List<FareBand> bands;

  Fares({
    required this.currency,
    required this.basis,
    required this.singleJourneyTicketPkr,
    required this.feederExpressFlatFarePkr,
    required this.bands,
  });

  factory Fares.fromJson(Map<String, dynamic> json) {
    return Fares(
      currency: json['currency'] as String,
      basis: json['basis'] as String,
      singleJourneyTicketPkr: json['single_journey_ticket_pkr'] as int,
      feederExpressFlatFarePkr: json['feeder_express_flat_fare_pkr'] as int,
      bands: (json['bands'] as List)
          .map((band) => FareBand.fromJson(band as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ServiceHours {
  final String opens;
  final String closes;

  ServiceHours({required this.opens, required this.closes});

  factory ServiceHours.fromJson(Map<String, dynamic> json) {
    return ServiceHours(
      opens: json['opens'] as String,
      closes: json['closes'] as String,
    );
  }
}

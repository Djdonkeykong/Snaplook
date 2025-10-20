class GarmentDetection {
  final String label;
  final double score;
  final List<int> bbox;
  final String imageUrl;

  GarmentDetection({
    required this.label,
    required this.score,
    required this.bbox,
    required this.imageUrl,
  });

  factory GarmentDetection.fromJson(Map<String, dynamic> json) {
    return GarmentDetection(
      label: json['label'] ?? '',
      score: (json['score'] ?? 0).toDouble(),
      bbox: (json['bbox'] as List<dynamic>?)?.cast<int>() ?? [0, 0, 0, 0],
      imageUrl: json['image_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'score': score,
      'bbox': bbox,
      'image_url': imageUrl,
    };
  }
}

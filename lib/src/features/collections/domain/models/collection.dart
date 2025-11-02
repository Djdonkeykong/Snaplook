class Collection {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int itemCount;
  final String? coverImageUrl;

  const Collection({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.itemCount = 0,
    this.coverImageUrl,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      itemCount: json['item_count'] as int? ?? 0,
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'item_count': itemCount,
      'cover_image_url': coverImageUrl,
    };
  }

  Collection copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? itemCount,
    String? coverImageUrl,
  }) {
    return Collection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      itemCount: itemCount ?? this.itemCount,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    );
  }
}

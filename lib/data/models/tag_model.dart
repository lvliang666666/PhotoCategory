class TagModel {
  final int? id;
  final String name;
  final int colorValue;
  final int createdAt;

  const TagModel({
    this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'color_value': colorValue,
        'created_at': createdAt,
      };

  factory TagModel.fromMap(Map<String, Object?> map) => TagModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        colorValue: map['color_value'] as int,
        createdAt: map['created_at'] as int,
      );
}

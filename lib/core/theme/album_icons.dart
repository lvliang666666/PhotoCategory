import 'package:flutter/material.dart';

class AlbumIconOption {
  final String keyName;
  final String label;
  final IconData icon;

  const AlbumIconOption(this.keyName, this.label, this.icon);
}

class AlbumIcons {
  AlbumIcons._();

  static const options = <AlbumIconOption>[
    AlbumIconOption('album', '相册', Icons.photo_album_rounded),
    AlbumIconOption('sun', '阳光', Icons.wb_sunny_rounded),
    AlbumIconOption('leaf', '自然', Icons.eco_rounded),
    AlbumIconOption('heart', '珍藏', Icons.favorite_rounded),
    AlbumIconOption('moon', '夜晚', Icons.nightlight_round),
    AlbumIconOption('cloud', '天空', Icons.cloud_rounded),
    AlbumIconOption('flight', '旅行', Icons.flight_rounded),
    AlbumIconOption('pet', '宠物', Icons.pets_rounded),
    AlbumIconOption('food', '美食', Icons.restaurant_rounded),
    AlbumIconOption('book', '阅读', Icons.menu_book_rounded),
    AlbumIconOption('star', '星光', Icons.star_rounded),
    AlbumIconOption('coffee', '日常', Icons.local_cafe_rounded),
  ];

  static IconData resolve(String keyName) => options
      .firstWhere((item) => item.keyName == keyName,
          orElse: () => options.first)
      .icon;
}

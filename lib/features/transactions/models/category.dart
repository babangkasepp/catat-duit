import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String icon;
  final String color;
  final String type; // 'expense' | 'income'
  final bool isDefault;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    required this.isDefault,
  });

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as String,
        name: m['name'] as String,
        icon: m['icon'] as String,
        color: m['color'] as String,
        type: m['type'] as String,
        isDefault: (m['is_default'] as int) == 1,
      );

  Color get colorValue {
    final hex = color.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

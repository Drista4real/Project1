import 'package:flutter/material.dart';

enum EnvelopePillar {
  needs(
    'needs',
    'Nhu cầu thiết yếu',
    'Thiết yếu',
    'Thiết yếu',
    50,
    Color(0xFF2D5A43),
    Color(0xFFEAF2EC),
  ),
  wants(
    'wants',
    'Mong muốn & sở thích',
    'Mong muốn',
    'Mong muốn',
    25,
    Color(0xFFA0401C),
    Color(0xFFFFF1EC),
  ),
  culture(
    'culture',
    'Nuôi dưỡng tâm hồn',
    'Tâm hồn / Học',
    'Tâm hồn',
    15,
    Color(0xFF005D49),
    Color(0xFFE2FAF2),
  ),
  unexpected(
    'unexpected',
    'Dự phòng & bất ngờ',
    'Dự phòng',
    'Dự phòng',
    10,
    Color(0xFF414943),
    Color(0xFFEBEFEA),
  );

  const EnvelopePillar(
    this.key,
    this.title,
    this.label,
    this.shortLabel,
    this.suggestedPercent,
    this.color,
    this.tint,
  );
  final String key, title, label, shortLabel;
  final int suggestedPercent;
  final Color color, tint;
  Color get barColor => switch (this) {
    wants => const Color(0xFFFE875D),
    culture => const Color(0xFF85D6BB),
    unexpected => const Color(0xFFC0C9C1),
    needs => color,
  };

  static EnvelopePillar? fromKey(Object? key) {
    for (final pillar in values) {
      if (pillar.key == key) return pillar;
    }
    return null;
  }
}

abstract final class EnvelopeStyle {
  static const canvas = Color(0xFFF6FBF5);
  static const primary = Color(0xFF14422D);
  static const ink = Color(0xFF181D1A);
  static const muted = Color(0xFF606A62);
  static const soft = Color(0xFFF0F5F0);
  static const border = Color(0xFFEBEFEA);
}

import 'package:flutter/material.dart';
import '../models/envelope_pillar.dart';

ThemeData envelopeTheme(ThemeData theme) => theme.copyWith(
  textTheme: theme.textTheme.apply(
    fontFamily: 'BeVietnamPro',
    bodyColor: EnvelopeStyle.ink,
    displayColor: EnvelopeStyle.ink,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: EnvelopeStyle.primary,
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      foregroundColor: EnvelopeStyle.primary,
      side: BorderSide.none,
      backgroundColor: EnvelopeStyle.border,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: EnvelopeStyle.primary,
      textStyle: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 12),
    ),
  ),
);

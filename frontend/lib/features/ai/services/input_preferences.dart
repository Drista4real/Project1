import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class InputPreferences {
  Future<int?> category(String text);
  Future<void> remember(String text, int categoryId);
}

class LocalInputPreferences implements InputPreferences {
  LocalInputPreferences(this.userId);
  final String Function() userId;

  String _key(String text) {
    final phrase = text
        .toLowerCase()
        .replaceAll(RegExp(r'\d+ đồng'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return 'ai-category-${userId()}-${sha256.convert(utf8.encode(phrase))}';
  }

  @override
  Future<int?> category(String text) async =>
      (await SharedPreferences.getInstance()).getInt(_key(text));

  @override
  Future<void> remember(String text, int categoryId) async {
    final preferences = await SharedPreferences.getInstance();
    final prefix = 'ai-category-${userId()}-';
    final keys = preferences
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .toList();
    if (keys.length >= 100 && !keys.contains(_key(text))) {
      await preferences.remove(keys.first);
    }
    await preferences.setInt(_key(text), categoryId);
  }
}

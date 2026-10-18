import 'package:flutter/material.dart';

/// Use the same bundled Vietnamese typography as the envelope screens.
class ManagementTheme extends StatelessWidget {
  const ManagementTheme({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const label = TextStyle(
      fontFamily: 'BeVietnamPro',
      fontWeight: FontWeight.w600,
    );
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'BeVietnamPro'),
        primaryTextTheme: theme.primaryTextTheme.apply(
          fontFamily: 'BeVietnamPro',
        ),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle:
              (theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge)
                  ?.copyWith(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                  ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: (theme.filledButtonTheme.style ?? const ButtonStyle())
              .copyWith(textStyle: const WidgetStatePropertyAll(label)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: (theme.outlinedButtonTheme.style ?? const ButtonStyle())
              .copyWith(textStyle: const WidgetStatePropertyAll(label)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: (theme.textButtonTheme.style ?? const ButtonStyle()).copyWith(
            textStyle: const WidgetStatePropertyAll(label),
          ),
        ),
      ),
      child: Builder(builder: builder),
    );
  }
}

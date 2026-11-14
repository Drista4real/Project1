import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_routes.dart';

/// Return to the actual opener, including an imperative MaterialPageRoute.
/// A named screen opened without history returns to its logical parent.
void popOrGo<T>(
  BuildContext context, {
  String fallbackRoute = AppRoutes.home,
  T? result,
}) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop<T>(result);
  } else {
    context.go(fallbackRoute);
  }
}

class AppExitButton extends StatelessWidget {
  const AppExitButton({
    super.key,
    this.close = false,
    this.enabled = true,
    this.fallbackRoute = AppRoutes.home,
    this.onPressed,
  });

  final bool close;
  final bool enabled;
  final String fallbackRoute;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: close ? 'Đóng' : 'Quay lại',
    icon: Icon(close ? Icons.close_rounded : Icons.arrow_back_rounded),
    onPressed: enabled
        ? onPressed ?? () => popOrGo(context, fallbackRoute: fallbackRoute)
        : null,
  );
}

/// Match Android Back to the toolbar on secondary browsing screens.
/// Forms with save/discard guards keep their own PopScope instead.
class AppBackScope extends StatelessWidget {
  const AppBackScope({
    required this.child,
    this.fallbackRoute = AppRoutes.home,
    super.key,
  });

  final Widget child;
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: Navigator.of(context).canPop(),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) popOrGo(context, fallbackRoute: fallbackRoute);
    },
    child: child,
  );
}

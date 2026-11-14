import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';

/// Ekranın altında sabit duran ana aksiyon alanı (Oyunu Başlat, El Ekle).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.sm,
            AppSpacing.screen,
            AppSpacing.sm,
          ),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

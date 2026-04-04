import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 40,
    this.showFallbackText = false,
  });

  final double height;
  final bool showFallbackText;

  static const String _assetPath = 'assets/images/Chandra_logo.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetPath,
      height: height,
      width: null,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      errorBuilder: (context, error, stackTrace) {
        if (showFallbackText) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Padam Heart Care Centre',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          );
        }

        return Icon(Icons.favorite, color: Theme.of(context).colorScheme.primary, size: height * 0.7);
      },
    );
  }
}

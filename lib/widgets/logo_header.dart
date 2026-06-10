import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LogoHeader extends StatelessWidget {
  final String subtitle;
  const LogoHeader({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/logoLab.png',
          width: 90,
          height: 90,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 12),
        const Text(
          'Laboratorio Clínico',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 3,
            color: AppTheme.gray400,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'CÁRDENAS–GAROFALO',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppTheme.orange,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 2.5,
            color: AppTheme.gray400,
          ),
        ),
      ],
    );
  }
}
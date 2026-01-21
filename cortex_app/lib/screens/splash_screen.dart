import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Splash screen shown immediately on app launch
/// while Firebase and Hive initialize in the background.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo/icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.hub_rounded,
                size: 48,
                color: isDark ? AppTheme.darkBackground : Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            // App name
            Text(
              'Cortex',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary,
              ),
            ),
            const SizedBox(height: 32),
            // Loading indicator
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

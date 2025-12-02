import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapod_flutter/mediapod_flutter.dart';

void main() {
  group('MediaTheme', () {
    test('creates default theme with expected values', () {
      const theme = MediaTheme();

      expect(theme.primaryColor, Colors.blue);
      expect(theme.backgroundColor, Colors.white);
      expect(theme.errorColor, Colors.red);
      expect(theme.gridSpacing, 4.0);
      expect(theme.tileAspectRatio, 1.0);
      expect(theme.animationDuration, const Duration(milliseconds: 200));
    });

    test('creates dark theme with appropriate colors', () {
      final theme = MediaTheme.dark();

      expect(theme.backgroundColor, Colors.grey.shade900);
      expect(theme.surfaceColor, Colors.grey.shade800);
      expect(theme.titleStyle?.color, Colors.white);
    });

    test('creates light theme with appropriate colors', () {
      final theme = MediaTheme.light();

      expect(theme.backgroundColor, Colors.white);
      expect(theme.titleStyle?.color, Colors.black87);
    });

    test('creates theme from Flutter ThemeData', () {
      final themeData = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          primary: Colors.purple,
        ),
      );

      final theme = MediaTheme.fromTheme(themeData);

      expect(theme.primaryColor, themeData.colorScheme.primary);
      expect(theme.errorColor, themeData.colorScheme.error);
    });

    test('copyWith creates new theme with modified values', () {
      const original = MediaTheme();
      final modified = original.copyWith(
        primaryColor: Colors.green,
        gridSpacing: 8.0,
      );

      expect(modified.primaryColor, Colors.green);
      expect(modified.gridSpacing, 8.0);
      // Unchanged values remain the same
      expect(modified.backgroundColor, original.backgroundColor);
      expect(modified.errorColor, original.errorColor);
    });

    test('getOverlayGradient returns gradient with correct direction', () {
      const theme = MediaTheme();

      final topGradient = theme.getOverlayGradient(fromTop: true);
      expect(topGradient.begin, Alignment.topCenter);
      expect(topGradient.end, Alignment.bottomCenter);

      final bottomGradient = theme.getOverlayGradient(fromTop: false);
      expect(bottomGradient.begin, Alignment.bottomCenter);
      expect(bottomGradient.end, Alignment.topCenter);
    });

    test('uses custom overlay gradient when provided', () {
      final customGradient = LinearGradient(colors: [Colors.red, Colors.blue]);

      final theme = MediaTheme(overlayGradient: customGradient);

      expect(theme.getOverlayGradient(), customGradient);
    });

    test('equality works correctly', () {
      const theme1 = MediaTheme();
      const theme2 = MediaTheme();
      final theme3 = const MediaTheme().copyWith(primaryColor: Colors.red);

      expect(theme1, equals(theme2));
      expect(theme1, isNot(equals(theme3)));
    });

    test('hashCode is consistent', () {
      const theme1 = MediaTheme();
      const theme2 = MediaTheme();

      expect(theme1.hashCode, theme2.hashCode);
    });
  });

  group('MediaThemeProvider', () {
    testWidgets('provides theme to descendants', (tester) async {
      final testTheme = MediaTheme(primaryColor: Colors.purple);

      late MediaTheme retrievedTheme;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaThemeProvider(
            theme: testTheme,
            child: Builder(
              builder: (context) {
                retrievedTheme = MediaThemeProvider.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(retrievedTheme.primaryColor, Colors.purple);
    });

    testWidgets('returns default theme when no provider found', (tester) async {
      late MediaTheme retrievedTheme;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              retrievedTheme = MediaThemeProvider.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(retrievedTheme.primaryColor, Colors.blue); // default
    });

    testWidgets('maybeOf returns null when no provider found', (tester) async {
      MediaTheme? retrievedTheme;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              retrievedTheme = MediaThemeProvider.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(retrievedTheme, isNull);
    });

    testWidgets('updateShouldNotify returns true when theme changes', (
      tester,
    ) async {
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaThemeProvider(
            theme: const MediaTheme(primaryColor: Colors.blue),
            child: Builder(
              builder: (context) {
                MediaThemeProvider.of(context);
                buildCount++;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);

      // Rebuild with different theme
      await tester.pumpWidget(
        MaterialApp(
          home: MediaThemeProvider(
            theme: const MediaTheme(primaryColor: Colors.red),
            child: Builder(
              builder: (context) {
                MediaThemeProvider.of(context);
                buildCount++;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(buildCount, 2);
    });
  });
}

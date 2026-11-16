import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/strings/app_strings.dart';
import 'package:rebs_hrms/core/theme/app_theme.dart';
import 'package:rebs_hrms/core/utils/view_state.dart';
import 'package:rebs_hrms/core/widgets/primary_button.dart';
import 'package:rebs_hrms/core/widgets/skeleton_box.dart';
import 'package:rebs_hrms/core/widgets/state_builder.dart';

/// Wraps a widget in the real app theme (the kit reads context.palette).
Widget themed(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('StateBuilder', () {
    Widget build(ViewState<String> state, {VoidCallback? onRetry}) => themed(
          StateBuilder<String>(
            state: state,
            onRetry: onRetry,
            builder: (_, data) => Text(data.value),
          ),
        );

    testWidgets('loading shows skeleton placeholders, not a spinner',
        (tester) async {
      await tester.pumpWidget(build(const ViewLoading()));
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('data shows the built content', (tester) async {
      await tester.pumpWidget(build(const ViewData('hello')));
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('empty shows the empty title', (tester) async {
      await tester.pumpWidget(build(const ViewEmpty()));
      expect(find.text(AppStrings.emptyTitle), findsOneWidget);
    });

    testWidgets('error shows the message and retry calls back',
        (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        build(const ViewError('No connection'), onRetry: () => retried++),
      );
      expect(find.text('No connection'), findsOneWidget);
      await tester.tap(find.text(AppStrings.retry));
      expect(retried, 1);
    });
  });

  group('PrimaryButton', () {
    testWidgets('tap fires once; loading shows a spinner and blocks taps',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        themed(PrimaryButton(label: 'Check In', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Check In'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 1);

      await tester.pumpWidget(
        themed(
          PrimaryButton(
            label: 'Check In',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Check In'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 1);
    });
  });
}

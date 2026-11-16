import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/strings/app_strings.dart';
import 'package:rebs_hrms/core/theme/app_theme.dart';
import 'package:rebs_hrms/core/widgets/notice_sheet.dart';

/// The sheet shown when an action the user asked for cannot be done
/// (for example "Apply for Leave" while offline).
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  const short = Duration(milliseconds: 400);

  testWidgets('offline leave: shows the exact message and a Got it button',
      (tester) async {
    bool? closedWith;
    await tester.pumpWidget(host(NoticeSheetContent(
      title: AppStrings.offlineSheetTitle,
      message: AppStrings.leaveOffline,
      onClose: (result) => closedWith = result,
    )));
    await tester.pump(short);

    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text("You're offline. Leave requests need a connection."),
        findsOneWidget);

    await tester.tap(find.text(AppStrings.gotIt));
    await tester.pump(short);
    expect(closedWith, isFalse);
  });

  testWidgets('Try again: stays open while still offline', (tester) async {
    bool? closedWith;
    var attempts = 0;
    await tester.pumpWidget(host(NoticeSheetContent(
      title: AppStrings.offlineSheetTitle,
      message: AppStrings.leaveOffline,
      actionLabel: AppStrings.retry,
      onAction: () async {
        attempts++;
        return false; // the server still does not answer
      },
      onClose: (result) => closedWith = result,
    )));
    await tester.pump(short);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pump(short);

    expect(attempts, 1);
    expect(closedWith, isNull); // not closed
    expect(find.text(AppStrings.leaveOffline), findsOneWidget);
  });

  testWidgets('Try again: closes with true once back online, and cannot be '
      'tapped twice while checking', (tester) async {
    bool? closedWith;
    var attempts = 0;
    final check = Completer<bool>();
    await tester.pumpWidget(host(NoticeSheetContent(
      title: AppStrings.offlineSheetTitle,
      message: AppStrings.leaveOffline,
      actionLabel: AppStrings.retry,
      onAction: () {
        attempts++;
        return check.future;
      },
      onClose: (result) => closedWith = result,
    )));
    await tester.pump(short);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pump(short);
    // Still checking: a spinner is shown and a second tap does nothing.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text(AppStrings.retry));
    await tester.pump(short);
    expect(attempts, 1);

    check.complete(true);
    await tester.pump(short);
    expect(closedWith, isTrue);
  });
}

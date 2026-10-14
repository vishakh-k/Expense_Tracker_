// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_tracker/widgets/expenses.dart';
import 'package:expense_tracker/models/expense.dart';

void main() {
  test('expense data can be serialized and restored', () {
    final original = Expense(
      title: 'Train ticket',
      amount: 12.5,
      date: DateTime(2026, 10, 14),
      category: Category.travel,
    );

    final restored = Expense.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.amount, original.amount);
    expect(restored.date, original.date);
    expect(restored.category, original.category);
  });

  testWidgets('welcome screen appears once and remembers Get Started', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: Expenses()));
    await tester.pumpAndSettle();

    expect(find.text('Personal finance\nmade simple.'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Expense overview'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('expense_tracker.onboarding_complete'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MaterialApp(home: Expenses()));
    await tester.pumpAndSettle();
    expect(find.text('Expense overview'), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);
  });

  testWidgets('shows expenses and opens the add expense form', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: Expenses()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Expense overview'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Flutter Course'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Flutter Course'), findsOneWidget);
    expect(find.text('Cinema'), findsOneWidget);

    await tester.tap(find.byTooltip('Add expense'));
    await tester.pumpAndSettle();

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Save Expense'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Coffee');
    await tester.enterText(find.byType(TextField).at(1), '4.50');
    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Expense'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    final savedExpenses = jsonDecode(
      preferences.getString('expense_tracker.expenses')!,
    ) as List<dynamic>;
    expect(
      savedExpenses.any((expense) => expense['title'] == 'Coffee'),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MaterialApp(home: Expenses()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Coffee'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Coffee'), findsOneWidget);
  });

  testWidgets('navigation, budget editing, and data management work', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: Expenses()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-analytics')));
    await tester.pumpAndSettle();
    expect(find.text('A clear view of your spending.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-budget')));
    await tester.pumpAndSettle();
    expect(find.text('Set a limit that works for you.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit-budget')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '700');
    await tester.tap(find.text('Save budget'));
    await tester.pumpAndSettle();
    expect(find.text('\$700.00'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getDouble('expense_tracker.monthly_budget'), 700);

    await tester.tap(find.byKey(const ValueKey('nav-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Automatic local saving'), findsOneWidget);
    await tester.tap(find.text('Clear all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear data'));
    await tester.pumpAndSettle();
    expect(find.text('0 saved transactions'), findsOneWidget);
  });
}

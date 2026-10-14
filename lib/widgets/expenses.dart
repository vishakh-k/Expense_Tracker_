import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:expense_tracker/widgets/chart/chart.dart';
import 'package:expense_tracker/widgets/expenses_list/expenses.dart';
import 'package:expense_tracker/widgets/new_expenses.dart';

enum _Destination { home, analytics, budget, profile }

class Expenses extends StatefulWidget {
  const Expenses({super.key});

  @override
  State<Expenses> createState() => _ExpensesState();
}

class _ExpensesState extends State<Expenses> {
  static const _expensesKey = 'expense_tracker.expenses';
  static const _budgetKey = 'expense_tracker.monthly_budget';
  static const _monthKey = 'expense_tracker.selected_month';
  static const _onboardingKey = 'expense_tracker.onboarding_complete';

  final List<Expense> _registeredExpenses = [
    Expense(
      title: 'Flutter Course',
      amount: 19.99,
      date: DateTime.now(),
      category: Category.work,
    ),
    Expense(
      title: 'Cinema',
      amount: 15.69,
      date: DateTime.now(),
      category: Category.leisure,
    ),
  ];

  DateTime _selectedMonth = DateTime.now();
  _Destination _destination = _Destination.home;
  double _monthlyBudget = 500;
  bool _isLoading = true;
  bool _hasCompletedOnboarding = false;
  SharedPreferences? _preferences;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    List<Expense>? savedExpenses;
    double? savedBudget;
    DateTime? savedMonth;
    bool? hasCompletedOnboarding;
    try {
      _preferences = await SharedPreferences.getInstance();
      final savedJson = _preferences!.getString(_expensesKey);
      if (savedJson != null) {
        final decoded = jsonDecode(savedJson) as List<dynamic>;
        savedExpenses = decoded
            .map(
              (expenseJson) => Expense.fromJson(
                Map<String, dynamic>.from(expenseJson as Map),
              ),
            )
            .toList();
      }
      savedBudget = _preferences!.getDouble(_budgetKey);
      final savedMonthString = _preferences!.getString(_monthKey);
      if (savedMonthString != null) {
        savedMonth = DateTime.tryParse(savedMonthString);
      }
      hasCompletedOnboarding = _preferences!.getBool(_onboardingKey) ?? false;
    } catch (_) {
      savedExpenses = null;
    }

    if (!mounted) return;
    setState(() {
      if (savedExpenses != null) {
        _registeredExpenses
          ..clear()
          ..addAll(savedExpenses);
      }
      if (savedBudget != null && savedBudget > 0) {
        _monthlyBudget = savedBudget;
      }
      if (savedMonth != null) _selectedMonth = savedMonth;
      _hasCompletedOnboarding = hasCompletedOnboarding ?? false;
      _isLoading = false;
    });
    if (savedExpenses == null) _persistData();
  }

  void _persistData() {
    final preferences = _preferences;
    if (preferences == null) return;

    final expensesJson = jsonEncode(
      _registeredExpenses.map((expense) => expense.toJson()).toList(),
    );
    final budget = _monthlyBudget;
    final selectedMonth = _selectedMonth.toIso8601String();
    final previousSave = _saveQueue;
    _saveQueue = () async {
      try {
        await previousSave;
      } catch (_) {}
      try {
        await preferences.setString(_expensesKey, expensesJson);
        await preferences.setDouble(_budgetKey, budget);
        await preferences.setString(_monthKey, selectedMonth);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save your changes.')),
          );
        }
      }
    }();
  }

  void _openAddExpenseOverlay() {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) => NewExpense(onAddExpense: _addExpense),
    );
  }

  void _addExpense(Expense expense) {
    setState(() => _registeredExpenses.add(expense));
    _persistData();
  }

  void _removeExpense(Expense expense) {
    final expenseIndex = _registeredExpenses.indexOf(expense);
    setState(() => _registeredExpenses.remove(expense));
    _persistData();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: const Text('Expense deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() => _registeredExpenses.insert(expenseIndex, expense));
            _persistData();
          },
        ),
      ),
    );
  }

  List<Expense> get _selectedExpenses => _registeredExpenses
      .where(
        (expense) =>
            expense.date.year == _selectedMonth.year &&
            expense.date.month == _selectedMonth.month,
      )
      .toList();

  double get _monthlyTotal =>
      _selectedExpenses.fold(0, (total, expense) => total + expense.amount);

  Widget _navigationItem({
    required _Destination destination,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final selected = _destination == destination;
    final color = selected ? appPrimaryColor : appMutedColor;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label tab',
        child: InkWell(
          key: ValueKey('nav-${destination.name}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _destination = destination),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 21),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(color: appMutedColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHome(List<DateTime> months) {
    final selectedExpenses = _selectedExpenses;
    return ListView(
      key: const ValueKey('home-screen'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expense overview',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your money, in focus',
                    style: TextStyle(color: appMutedColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<DateTime>(
            onSelected: (month) {
              setState(() => _selectedMonth = month);
              _persistData();
            },
            itemBuilder: (context) => [
              for (final month in months)
                PopupMenuItem(
                  value: month,
                  child: Text(DateFormat('MMMM yyyy').format(month)),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: appSurfaceRaisedColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: appBorderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down, size: 17),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appPrimaryColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MONTHLY SPENDING',
                      style: TextStyle(
                        color: appBackgroundColor.withValues(alpha: 0.66),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '\$${_monthlyTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: appBackgroundColor,
                        fontSize: 32,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${selectedExpenses.length} ${selectedExpenses.length == 1 ? 'transaction' : 'transactions'} recorded',
                      style: TextStyle(
                        color: appBackgroundColor.withValues(alpha: 0.72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 92,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      top: 0,
                      right: 2,
                      child: Icon(
                        Icons.monetization_on,
                        color: appVioletColor,
                        size: 24,
                      ),
                    ),
                    const Positioned(
                      top: 18,
                      right: 25,
                      child: Icon(
                        Icons.monetization_on,
                        color: appBackgroundColor,
                        size: 20,
                      ),
                    ),
                    Transform.rotate(
                      angle: -0.12,
                      child: Container(
                        width: 66,
                        height: 48,
                        decoration: BoxDecoration(
                          color: appVioletColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x55310B82),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: appTextColor,
                          size: 34,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Chart(expenses: selectedExpenses),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text(
              'Recent expenses',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '${selectedExpenses.length} TOTAL',
              style: const TextStyle(
                color: appMutedColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (selectedExpenses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'No expenses this month yet.',
                style: TextStyle(color: appMutedColor),
              ),
            ),
          )
        else
          ExpensesList(
            expenses: selectedExpenses,
            onRemoveExpense: _removeExpense,
          ),
      ],
    );
  }

  Widget _monthlyTrendChart() {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (index) => DateTime(now.year, now.month - (5 - index)),
    );
    final totals = months.map((month) {
      return _registeredExpenses
          .where(
            (expense) =>
                expense.date.year == month.year &&
                expense.date.month == month.month,
          )
          .fold<double>(0, (total, expense) => total + expense.amount);
    }).toList();
    final highestTotal = totals.fold<double>(
      0,
      (highest, total) => total > highest ? total : highest,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly trend',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 126,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var index = 0; index < months.length; index++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            totals[index] == 0
                                ? ''
                                : totals[index].toStringAsFixed(0),
                            style: const TextStyle(
                              color: appMutedColor,
                              fontSize: 9,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 82,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                width: 22,
                                height: highestTotal == 0
                                    ? 4
                                    : 8 + (totals[index] / highestTotal * 66),
                                decoration: BoxDecoration(
                                  color: index == months.length - 1
                                      ? appPrimaryColor
                                      : appVioletColor,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('MMM').format(months[index]),
                            style: const TextStyle(
                              color: appMutedColor,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalytics(List<Expense> selectedExpenses) {
    final topCategory = Category.values
        .map(
          (category) => ExpenseBucket.forCategory(selectedExpenses, category),
        )
        .fold<ExpenseBucket?>(
          null,
          (best, bucket) =>
              best == null || bucket.totalExpenses > best.totalExpenses
              ? bucket
              : best,
        );
    return ListView(
      key: const ValueKey('analytics-screen'),
      padding: const EdgeInsets.all(20),
      children: [
        _pageHeader('Analytics', 'A clear view of your spending.'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, color: appPrimaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total amount spent'),
                      const SizedBox(height: 4),
                      Text(
                        '\$${_monthlyTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: appPrimaryColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _monthlyTrendChart(),
        const SizedBox(height: 20),
        Chart(expenses: selectedExpenses),
        const SizedBox(height: 20),
        if (topCategory != null && topCategory.totalExpenses > 0)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: categoryColors[topCategory.category]!
                    .withValues(alpha: 0.16),
                child: Icon(
                  categoryIcons[topCategory.category],
                  color: categoryColors[topCategory.category],
                ),
              ),
              title: const Text('Top category'),
              subtitle: Text(categoryLabels[topCategory.category]!),
              trailing: Text(
                '\$${topCategory.totalExpenses.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: appPrimaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBudget() {
    final remaining = _monthlyBudget - _monthlyTotal;
    final progress = (_monthlyTotal / _monthlyBudget).clamp(0.0, 1.0);
    final isOverBudget = remaining < 0;
    return ListView(
      key: const ValueKey('budget-screen'),
      padding: const EdgeInsets.all(20),
      children: [
        _pageHeader('Monthly budget', 'Set a limit that works for you.'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Spending limit',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('edit-budget'),
                      tooltip: 'Edit monthly budget',
                      onPressed: _editBudget,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                Text(
                  '\$${_monthlyBudget.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: appPrimaryColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: appSurfaceRaisedColor,
                    color: isOverBudget ? appNegativeColor : appPrimaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Text('Spent')),
                    Text('\$${_monthlyTotal.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(isOverBudget ? 'Over budget' : 'Remaining'),
                    ),
                    Text(
                      '\$${remaining.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isOverBudget
                            ? appNegativeColor
                            : appPositiveColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _editBudget,
          icon: const Icon(Icons.tune),
          label: const Text('Change monthly limit'),
        ),
      ],
    );
  }

  Widget _buildProfile() {
    return ListView(
      key: const ValueKey('profile-screen'),
      padding: const EdgeInsets.all(20),
      children: [
        _pageHeader('Profile', 'Your account and data settings.'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: appSurfaceRaisedColor,
                  child: Icon(
                    Icons.person_outline,
                    color: appPrimaryColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal wallet',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_registeredExpenses.length} saved transactions',
                      style: const TextStyle(
                        color: appMutedColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'DATA MANAGEMENT',
            style: TextStyle(
              color: appMutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(
                  Icons.cloud_done_outlined,
                  color: appPrimaryColor,
                ),
                title: Text('Automatic local saving'),
                subtitle: Text(
                  'Expenses and budget are stored on this device.',
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: appNegativeColor,
                ),
                title: const Text('Clear all data'),
                subtitle: const Text('Remove saved expenses and reset budget.'),
                onTap: _confirmClearData,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editBudget() async {
    final newBudget = await showDialog<double>(
      context: context,
      builder: (context) => _BudgetDialog(initialBudget: _monthlyBudget),
    );
    if (!mounted ||
        newBudget == null ||
        !newBudget.isFinite ||
        newBudget <= 0) {
      return;
    }
    setState(() => _monthlyBudget = newBudget);
    _persistData();
  }

  Future<void> _confirmClearData() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This removes every saved expense and resets your monthly budget.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear data'),
          ),
        ],
      ),
    );
    if (shouldClear != true || !mounted) return;
    setState(() {
      _registeredExpenses.clear();
      _monthlyBudget = 500;
    });
    _persistData();
  }

  Future<void> _completeOnboarding() async {
    try {
      await _preferences?.setBool(_onboardingKey, true);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _hasCompletedOnboarding = true);
  }

  Widget _welcomeArtwork(double width) {
    final cardWidth = math.min(width * 0.82, 300.0);
    return SizedBox(
      width: width,
      height: 300,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 8,
            left: width * 0.08,
            child: Transform.rotate(
              angle: -0.13,
              child: Container(
                width: 94,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F2E9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: appTextColor, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: appPrimaryColor,
                      offset: Offset(3, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.laptop_chromebook_rounded,
                      color: appVioletColor,
                      size: 53,
                    ),
                    Positioned(
                      top: 9,
                      right: 13,
                      child: Icon(
                        Icons.warning_rounded,
                        color: appPrimaryColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Transform.rotate(
              angle: -0.11,
              child: Container(
                width: cardWidth,
                height: cardWidth * 0.57,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: const Color(0xFF9A4DFF),
                  borderRadius: BorderRadius.circular(18),
                  border: const Border(
                    bottom: BorderSide(color: appPrimaryColor, width: 5),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: appPrimaryColor,
                      offset: Offset(4, 7),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Spacer(),
                        Text(
                          'VISA',
                          style: TextStyle(
                            color: appBackgroundColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Container(
                      width: 32,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9D2F2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(
                        Icons.memory_rounded,
                        color: appVioletColor,
                        size: 19,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '••••  ••••  ••••  2026',
                      style: TextStyle(
                        color: appBackgroundColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'PERSONAL FINANCE',
                      style: TextStyle(
                        color: appBackgroundColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: width * 0.06,
            bottom: 10,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 82,
                height: 72,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: appPrimaryColor,
                  border: Border.all(color: const Color(0xFFE36B35), width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: appVioletColor,
                      offset: Offset(3, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_box_outline_blank, size: 13),
                    SizedBox(height: 1),
                    Icon(Icons.check_box_outline_blank, size: 13),
                    SizedBox(height: 1),
                    Icon(Icons.check_box_outline_blank, size: 13),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: width * 0.015,
            bottom: 35,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: appVioletColor,
                shape: BoxShape.circle,
                border: Border.all(color: appTextColor, width: 3),
              ),
              child: const Icon(
                Icons.priority_high_rounded,
                color: appTextColor,
                size: 25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Scaffold(
      backgroundColor: appBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final artworkHeight = (constraints.maxHeight * 0.47).clamp(
                  270.0,
                  350.0,
                );
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _WelcomeGridPainter()),
                    ),
                    SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 10, 28, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: artworkHeight,
                                child: Center(
                                  child: _welcomeArtwork(
                                    constraints.maxWidth - 56,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Personal finance\nmade simple.',
                                style: TextStyle(
                                  color: appPrimaryColor,
                                  fontFamily: 'serif',
                                  fontSize: 29,
                                  height: 1.18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Managing your finances has never\nbeen easier.',
                                style: TextStyle(
                                  color: appTextColor,
                                  fontSize: 15,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FilledButton(
                                  onPressed: _completeOnboarding,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: appPrimaryColor,
                                    foregroundColor: appBackgroundColor,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      side: const BorderSide(
                                        color: appVioletColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Get Started',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: appBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: appPrimaryColor)),
      );
    }
    if (!_hasCompletedOnboarding) return _buildWelcomeScreen();

    final now = DateTime.now();
    final months = List.generate(
      12,
      (index) => DateTime(now.year, now.month - index),
    );
    final screen = switch (_destination) {
      _Destination.home => _buildHome(months),
      _Destination.analytics => _buildAnalytics(_selectedExpenses),
      _Destination.budget => _buildBudget(),
      _Destination.profile => _buildProfile(),
    };

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add expense',
        onPressed: _openAddExpenseOverlay,
        backgroundColor: appVioletColor,
        foregroundColor: appPrimaryColor,
        elevation: 5,
        child: const Icon(Icons.add, size: 29),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: BottomAppBar(
                color: appSurfaceColor,
                elevation: 8,
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                notchMargin: 7,
                shape: const CircularNotchedRectangle(),
                child: Row(
                  children: [
                    _navigationItem(
                      destination: _Destination.home,
                      label: 'Home',
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                    ),
                    _navigationItem(
                      destination: _Destination.analytics,
                      label: 'Analytics',
                      icon: Icons.analytics_outlined,
                      selectedIcon: Icons.analytics_rounded,
                    ),
                    const SizedBox(width: 52),
                    _navigationItem(
                      destination: _Destination.budget,
                      label: 'Budget',
                      icon: Icons.account_balance_wallet_outlined,
                      selectedIcon: Icons.account_balance_wallet_rounded,
                    ),
                    _navigationItem(
                      destination: _Destination.profile,
                      label: 'Profile',
                      icon: Icons.person_outline_rounded,
                      selectedIcon: Icons.person_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: appPrimaryColor),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey(_destination),
                      child: screen,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = appBorderColor.withValues(alpha: 0.42)
      ..strokeWidth = 0.7;
    const gridSize = 26.0;
    for (var x = 0.0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.initialBudget});

  final double initialBudget;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialBudget.toStringAsFixed(2),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Monthly spending budget'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Budget amount',
          prefixText: '\$ ',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, double.tryParse(_controller.text.trim())),
          child: const Text('Save budget'),
        ),
      ],
    );
  }
}

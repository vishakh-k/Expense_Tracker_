import 'package:flutter/material.dart';

import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/theme/app_colors.dart';

class Chart extends StatelessWidget {
  const Chart({super.key, required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final buckets = Category.values
        .map((category) => ExpenseBucket.forCategory(expenses, category))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spending breakdown',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 9),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: buckets.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 112,
          ),
          itemBuilder: (context, index) {
            final bucket = buckets[index];
            final color = categoryColors[bucket.category]!;
            final foreground = color.computeLuminance() > 0.42
                ? appBackgroundColor
                : appTextColor;
            return Card(
              color: color,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      categoryIcons[bucket.category],
                      color: foreground,
                      size: 32,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      categoryLabels[bucket.category]!,
                      style: TextStyle(color: foreground, fontSize: 12),
                    ),
                    Text(
                      '\$${bucket.totalExpenses.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

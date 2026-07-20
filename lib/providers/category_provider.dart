import 'package:flutter/foundation.dart';
import '../models/category_model.dart';

class CategoryProvider extends ChangeNotifier {
  List<AppCategory> _expenseCategories = [];
  List<AppCategory> _incomeCategories = [];

  CategoryProvider() {
    _expenseCategories = List.from(AppCategory.defaultExpenseCategories);
    _incomeCategories = List.from(AppCategory.defaultIncomeCategories);
  }

  List<AppCategory> get expenseCategories => List.unmodifiable(_expenseCategories);
  List<AppCategory> get incomeCategories => List.unmodifiable(_incomeCategories);

  List<AppCategory> categoriesForType(CategoryType type) =>
      type == CategoryType.expense ? _expenseCategories : _incomeCategories;

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  void addCategory(AppCategory category) {
    if (category.type == CategoryType.expense) {
      _expenseCategories.add(category);
    } else {
      _incomeCategories.add(category);
    }
    notifyListeners();
  }

  void updateCategory(AppCategory oldCategory, AppCategory newCategory) {
    if (oldCategory.type == newCategory.type) {
      final list = newCategory.type == CategoryType.expense
          ? _expenseCategories
          : _incomeCategories;
      final idx = list.indexWhere((c) => c.name == oldCategory.name);
      if (idx != -1) {
        list[idx] = newCategory;
      } else {
        list.add(newCategory);
      }
    } else {
      if (oldCategory.type == CategoryType.expense) {
        _expenseCategories.removeWhere((c) => c.name == oldCategory.name);
      } else {
        _incomeCategories.removeWhere((c) => c.name == oldCategory.name);
      }
      
      if (newCategory.type == CategoryType.expense) {
        _expenseCategories.add(newCategory);
      } else {
        _incomeCategories.add(newCategory);
      }
    }
    notifyListeners();
  }

  void deleteCategory(AppCategory category) {
    if (category.type == CategoryType.expense) {
      _expenseCategories.removeWhere((c) => c.name == category.name);
    } else {
      _incomeCategories.removeWhere((c) => c.name == category.name);
    }
    notifyListeners();
  }

  void incrementUsage(String categoryName, CategoryType type) {
    final list = type == CategoryType.expense ? _expenseCategories : _incomeCategories;
    final idx = list.indexWhere((c) => c.name == categoryName);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(usageCount: list[idx].usageCount + 1);
      notifyListeners();
    }
  }

  AppCategory? findByName(String name, CategoryType type) {
    final list = categoriesForType(type);
    try {
      return list.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }
}

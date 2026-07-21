import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transaction_model.dart';
import '../models/goal_model.dart';
import '../models/lend_borrow_model.dart';
import '../models/wallet_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  static const String _dbName = 'money_manager.db';
  static const int _dbVersion = 6;
  static const String _tableName = 'transactions';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<void> initialize() async {
    await database;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        saved_amount REAL NOT NULL DEFAULT 0,
        target_date TEXT NOT NULL,
        category_name TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE goal_savings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (goal_id) REFERENCES goals(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE lend_borrow (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        person_name TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        note TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        payment_method TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE wallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        icon_code_point INTEGER NOT NULL,
        color_value INTEGER NOT NULL,
        note TEXT,
        include_in_total INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'available',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE wallet_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_wallet_id INTEGER NOT NULL,
        to_wallet_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (from_wallet_id) REFERENCES wallets(id) ON DELETE CASCADE,
        FOREIGN KEY (to_wallet_id) REFERENCES wallets(id) ON DELETE CASCADE
      )
    ''');

    // Seed with sample data
    await _seedSampleData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN title TEXT NOT NULL DEFAULT ""');
      } catch (e) {
        // Ignore if column already exists
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN created_at TEXT NOT NULL DEFAULT ""');
      } catch (e) {
        // Ignore if column already exists
      }
    }
    if (oldVersion < 4) {
      // Schema was mixed up with createdAt vs created_at, drop and recreate for a clean slate
      await db.execute('DROP TABLE IF EXISTS $_tableName');
      await _onCreate(db, newVersion);
    }
    if (oldVersion < 5) {
      // Add goals and lend_borrow tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          target_amount REAL NOT NULL,
          saved_amount REAL NOT NULL DEFAULT 0,
          target_date TEXT NOT NULL,
          category_name TEXT NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS goal_savings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          goal_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          FOREIGN KEY (goal_id) REFERENCES goals(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS lend_borrow (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          person_name TEXT NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          due_date TEXT NOT NULL,
          note TEXT,
          status TEXT NOT NULL DEFAULT 'pending',
          payment_method TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      // Add wallets and wallet_transfers tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS wallets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          balance REAL NOT NULL DEFAULT 0,
          icon_code_point INTEGER NOT NULL,
          color_value INTEGER NOT NULL,
          note TEXT,
          include_in_total INTEGER NOT NULL DEFAULT 1,
          status TEXT NOT NULL DEFAULT 'available',
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS wallet_transfers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          from_wallet_id INTEGER NOT NULL,
          to_wallet_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      // Seed sample wallets for existing users
      await _seedSampleWallets(db);
    }
  }

  Future<void> _seedSampleWallets(Database db) async {
    final now = DateTime.now().toIso8601String();
    // Color integers: 0xFFRRGGBB format (ARGB)
    // 0xFF00B894 = green, 0xFFE17055 = orange, 0xFF6C5CE7 = purple,
    // 0xFF0984E3 = blue, 0xFFFDAA3D = yellow
    final wallets = [
      {
        'name': 'Cash',
        'type': 'cash',
        'balance': 12500.0,
        'icon_code_point': Icons.account_balance_wallet_rounded.codePoint,
        'color_value': 0xFF00B894,
        'note': null,
        'include_in_total': 1,
        'status': 'available',
        'created_at': now,
      },
      {
        'name': 'Sampath Bank',
        'type': 'bank_account',
        'balance': 95000.0,
        'icon_code_point': Icons.account_balance_rounded.codePoint,
        'color_value': 0xFFE17055,
        'note': null,
        'include_in_total': 1,
        'status': 'available',
        'created_at': now,
      },
      {
        'name': 'Card Wallet',
        'type': 'card',
        'balance': 18500.0,
        'icon_code_point': Icons.credit_card_rounded.codePoint,
        'color_value': 0xFF6C5CE7,
        'note': null,
        'include_in_total': 1,
        'status': 'available',
        'created_at': now,
      },
      {
        'name': 'Savings',
        'type': 'savings',
        'balance': 60000.0,
        'icon_code_point': Icons.savings_rounded.codePoint,
        'color_value': 0xFF0984E3,
        'note': null,
        'include_in_total': 1,
        'status': 'saved',
        'created_at': now,
      },
      {
        'name': 'Business Wallet',
        'type': 'business',
        'balance': 42000.0,
        'icon_code_point': Icons.business_center_rounded.codePoint,
        'color_value': 0xFF6C5CE7,
        'note': null,
        'include_in_total': 1,
        'status': 'available',
        'created_at': now,
      },
      {
        'name': 'Koko / Mintpay',
        'type': 'koko_mintpay',
        'balance': 17000.0,
        'icon_code_point': Icons.account_balance_wallet_rounded.codePoint,
        'color_value': 0xFFFDAA3D,
        'note': '17,000 due',
        'include_in_total': 0,
        'status': 'installment',
        'created_at': now,
      },
    ];
    for (final w in wallets) {
      await db.insert('wallets', w);
    }
  }


  Future<void> _seedSampleData(Database db) async {
    final now = DateTime.now();
    // Seed sample wallets
    await _seedSampleWallets(db);
    final samples = [
      {
        'title': 'Salary',
        'amount': 120000.0,
        'type': 'income',
        'category': 'Salary',
        'date': DateTime(now.year, now.month, 1).toIso8601String(),
        'note': 'Monthly salary',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'title': 'Freelance Work',
        'amount': 20000.0,
        'type': 'income',
        'category': 'Freelance',
        'date': DateTime(now.year, now.month, 1).toIso8601String(),
        'note': 'Client project',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'title': 'Electricity Bill',
        'amount': 2500.0,
        'type': 'expense',
        'category': 'Bills',
        'date': DateTime(now.year, now.month, 2).toIso8601String(),
        'note': null,
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'title': 'Transport',
        'amount': 300.0,
        'type': 'expense',
        'category': 'Transport',
        'date': DateTime(now.year, now.month, now.day - 1 < 1 ? 1 : now.day - 1).toIso8601String(),
        'note': 'Auto rickshaw',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'title': 'Food',
        'amount': 500.0,
        'type': 'expense',
        'category': 'Food',
        'date': now.toIso8601String(),
        'note': 'Lunch',
        'created_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final sample in samples) {
      await db.insert(_tableName, sample);
    }
  }

  // ─── CRUD ────────────────────────────────────────────────────────────────────

  Future<int> insertTransaction(TransactionModel tx) async {
    final db = await database;
    final map = tx.toMap();
    map['created_at'] = DateTime.now().toIso8601String();
    return db.insert(_tableName, map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateTransaction(TransactionModel tx) async {
    final db = await database;
    return db.update(
      _tableName,
      tx.toMap(),
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllTransactions() async {
    final db = await database;
    await db.delete(_tableName);
  }

  Future<void> clearAllLendBorrows() async {
    final db = await database;
    await db.delete('lend_borrow');
  }

  Future<void> clearAllGoals() async {
    final db = await database;
    await db.delete('goals');
    await db.delete('goal_savings');
  }

  // ─── Queries ─────────────────────────────────────────────────────────────────

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final rows = await db.query(_tableName, orderBy: 'date DESC, id DESC');
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<List<TransactionModel>> getRecentTransactions({int limit = 10}) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<List<TransactionModel>> getTransactionsByMonth(
      int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final rows = await db.query(
      _tableName,
      where: "date >= ? AND date < ?",
      whereArgs: [start, end],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<List<TransactionModel>> getTransactionsByDateRange(
      DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: "date >= ? AND date <= ?",
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<List<TransactionModel>> searchTransactions(String query) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: "title LIKE ? OR category LIKE ? OR note LIKE ?",
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'date DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  // ─── Aggregates ───────────────────────────────────────────────────────────────

  Future<double> getTotalBalance() async {
    final db = await database;
    final incomeResult = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM $_tableName WHERE type = 'income'");
    final expenseResult = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM $_tableName WHERE type = 'expense'");
    final income = (incomeResult.first['total'] as num).toDouble();
    final expense = (expenseResult.first['total'] as num).toDouble();
    return income - expense;
  }

  Future<double> getMonthlyIncome(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM $_tableName WHERE type = 'income' AND date >= ? AND date < ?",
      [start, end],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getMonthlyExpenses(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM $_tableName WHERE type = 'expense' AND date >= ? AND date < ?",
      [start, end],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getTodaySpending() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day + 1).toIso8601String();
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM $_tableName WHERE type = 'expense' AND date >= ? AND date < ?",
      [start, end],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<Map<String, double>> getCategoryTotals(
      TransactionType type, int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final results = await db.rawQuery(
      "SELECT category, SUM(amount) as total FROM $_tableName WHERE type = ? AND date >= ? AND date < ? GROUP BY category ORDER BY total DESC",
      [type.name, start, end],
    );
    return {
      for (final row in results)
        row['category'] as String: (row['total'] as num).toDouble()
    };
  }

  Future<List<Map<String, dynamic>>> getLast6MonthsSummary() async {
    final db = await database;
    final results = await db.rawQuery("""
      SELECT 
        strftime('%Y-%m', date) as month,
        type,
        SUM(amount) as total
      FROM $_tableName
      WHERE date >= datetime('now', '-6 months')
      GROUP BY month, type
      ORDER BY month ASC
    """);
    return results;
  }

  Future<void> closeDatabase() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  // ─── Goals CRUD ───────────────────────────────────────────────────────────────

  Future<int> insertGoal(GoalModel goal) async {
    final db = await database;
    final map = goal.toMap();
    return db.insert('goals', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateGoal(GoalModel goal) async {
    final db = await database;
    return db.update('goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
  }

  Future<int> deleteGoal(int id) async {
    final db = await database;
    await db.delete('goal_savings', where: 'goal_id = ?', whereArgs: [id]);
    return db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<GoalModel>> getAllGoals() async {
    final db = await database;
    final rows = await db.query('goals', orderBy: 'created_at DESC');
    return rows.map(GoalModel.fromMap).toList();
  }

  Future<int> addGoalSavings(GoalSavingsEntry entry) async {
    final db = await database;
    final id = await db.insert('goal_savings', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    // Update the goal's saved_amount
    await db.rawUpdate(
      'UPDATE goals SET saved_amount = saved_amount + ? WHERE id = ?',
      [entry.amount, entry.goalId],
    );
    return id;
  }

  Future<List<GoalSavingsEntry>> getGoalSavings(int goalId) async {
    final db = await database;
    final rows = await db.query(
      'goal_savings',
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'date DESC',
    );
    return rows.map(GoalSavingsEntry.fromMap).toList();
  }

  // ─── Lend/Borrow CRUD ─────────────────────────────────────────────────────────

  Future<int> insertLendBorrow(LendBorrowModel entry) async {
    final db = await database;
    return db.insert('lend_borrow', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateLendBorrow(LendBorrowModel entry) async {
    final db = await database;
    return db.update(
      'lend_borrow',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteLendBorrow(int id) async {
    final db = await database;
    return db.delete('lend_borrow', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<LendBorrowModel>> getAllLendBorrow() async {
    final db = await database;
    final rows = await db.query('lend_borrow', orderBy: 'created_at DESC');
    return rows.map(LendBorrowModel.fromMap).toList();
  }

  // ─── Wallets CRUD ──────────────────────────────────────────────────────────────

  Future<int> insertWallet(WalletModel wallet) async {
    final db = await database;
    return db.insert('wallets', wallet.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateWallet(WalletModel wallet) async {
    final db = await database;
    return db.update('wallets', wallet.toMap(),
        where: 'id = ?', whereArgs: [wallet.id]);
  }

  Future<int> deleteWallet(int id) async {
    final db = await database;
    await db.delete('wallet_transfers',
        where: 'from_wallet_id = ? OR to_wallet_id = ?', whereArgs: [id, id]);
    return db.delete('wallets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WalletModel>> getAllWallets() async {
    final db = await database;
    final rows = await db.query('wallets', orderBy: 'created_at ASC');
    return rows.map(WalletModel.fromMap).toList();
  }

  Future<int> insertWalletTransfer(WalletTransfer transfer) async {
    final db = await database;
    return db.insert('wallet_transfers', transfer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<WalletTransfer>> getTransfersByWallet(int walletId) async {
    final db = await database;
    final rows = await db.query(
      'wallet_transfers',
      where: 'from_wallet_id = ? OR to_wallet_id = ?',
      whereArgs: [walletId, walletId],
      orderBy: 'date DESC',
    );
    return rows.map(WalletTransfer.fromMap).toList();
  }

  Future<double> getMonthlyTransfers() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).toIso8601String();
    final end = DateTime(now.year, now.month + 1, 1).toIso8601String();
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM wallet_transfers WHERE date >= ? AND date < ?',
      [start, end],
    );
    return (result.first['total'] as num).toDouble();
  }
}

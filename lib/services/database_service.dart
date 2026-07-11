import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transaction_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  static const String _dbName = 'money_manager.db';
  static const int _dbVersion = 4;
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
  }

  Future<void> _seedSampleData(Database db) async {
    final now = DateTime.now();
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
}

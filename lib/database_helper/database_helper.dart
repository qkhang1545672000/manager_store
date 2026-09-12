import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('grocery_store.db');
    return _database!;
  }

  // 1. Khởi tạo CSDL
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // 2. Tạo 2 bảng: products và product_aliases
  Future _createDB(Database db, int version) async {
    // Bảng 1: Sản phẩm chính
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        image_path TEXT
      )
    ''');

    // Bảng 2: Tên lóng / Tên gọi phụ (Liên kết với bảng products)
    await db.execute('''
      CREATE TABLE product_aliases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        alias_name TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');
  }

  // ==================== CÁC THAO TÁC CSDL ====================

  // Xóa sản phẩm theo ID (Tự động xóa luôn các tên lóng tương ứng)
  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // Lấy toàn bộ danh sách sản phẩm
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await instance.database;
    // Sắp xếp sản phẩm mới nhất lên đầu (tùy chọn)
    return await db.query('products', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final db = await database;
    final cleanQuery = query.trim().toLowerCase();

    if (cleanQuery.isEmpty) return [];

    // 1. Kiểm tra chính xác mã vạch trước
    final barcodeResults = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [cleanQuery],
    );
    if (barcodeResults.isNotEmpty) return barcodeResults;

    // 2. Tìm theo Tên chuẩn của sản phẩm (chứa từ khóa)
    final nameResults = await db.query(
      'products',
      where: 'LOWER(name) LIKE ?',
      whereArgs: ['%$cleanQuery%'],
    );
    if (nameResults.isNotEmpty) return nameResults;

    // 3. Nếu không tìm thấy ở Tên chuẩn -> Tìm theo Tên lóng/Tên phụ
    final aliasResults = await db.rawQuery(
      '''
    SELECT DISTINCT p.* 
    FROM products p
    INNER JOIN product_aliases pa ON p.id = pa.product_id
    WHERE pa.alias_name LIKE ?
  ''',
      ['%$cleanQuery%'],
    );

    return aliasResults;
  }
}

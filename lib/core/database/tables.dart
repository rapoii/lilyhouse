class AppTables {
  static const String costumes = 'costumes';
  static const String accessories = 'accessories';
  static const String customers = 'customers';
  static const String rentals = 'rentals';
  static const String installments = 'installments';
  static const String installmentLogs = 'installment_logs';
  static const String syncQueue = 'sync_queue';

  static const List<String> allTables = [
    costumes,
    accessories,
    customers,
    rentals,
    installments,
    installmentLogs,
    syncQueue,
  ];

  static const String createCostumes = '''
    CREATE TABLE costumes (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      anime_series TEXT NOT NULL,
      size TEXT NOT NULL,
      rent_price_3days REAL NOT NULL,
      status TEXT NOT NULL,
      cover_photo TEXT,
      gallery_photos TEXT,
      included_accessories TEXT,
      notes TEXT,
      sync_status TEXT DEFAULT 'pending'
    );
  ''';

  static const String createAccessories = '''
    CREATE TABLE accessories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      related_costume_id TEXT,
      condition_status TEXT NOT NULL,
      photo_url TEXT,
      sync_status TEXT DEFAULT 'pending'
    );
  ''';

  static const String createCustomers = '''
    CREATE TABLE customers (
      id TEXT PRIMARY KEY,
      full_name TEXT NOT NULL,
      phone TEXT NOT NULL,
      parent_phone TEXT,
      address TEXT NOT NULL,
      social_media TEXT,
      ktp_photo_url TEXT,
      selfie_ktp_url TEXT,
      sync_status TEXT DEFAULT 'pending'
    );
  ''';

  static const String createRentals = '''
    CREATE TABLE rentals (
      id TEXT PRIMARY KEY,
      costume_id TEXT NOT NULL,
      customer_id TEXT NOT NULL,
      start_date TEXT NOT NULL,
      end_date TEXT NOT NULL,
      duration_days INTEGER NOT NULL,
      purpose TEXT NOT NULL,
      total_price REAL NOT NULL,
      dp_amount REAL NOT NULL,
      payment_status TEXT NOT NULL,
      item_status TEXT NOT NULL,
      notes TEXT,
      sync_status TEXT DEFAULT 'pending'
    );
  ''';

  static const String createInstallments = '''
    CREATE TABLE installments (
      id TEXT PRIMARY KEY,
      item_name TEXT NOT NULL,
      store_name TEXT,
      total_cost REAL NOT NULL,
      total_paid REAL NOT NULL,
      remaining_balance REAL NOT NULL,
      due_date TEXT,
      status TEXT NOT NULL,
      sync_status TEXT DEFAULT 'pending'
    );
  ''';

  static const String createInstallmentLogs = '''
    CREATE TABLE installment_logs (
      id TEXT PRIMARY KEY,
      installment_id TEXT NOT NULL,
      payment_date TEXT NOT NULL,
      amount_paid REAL NOT NULL,
      proof_photo_url TEXT,
      notes TEXT,
      sync_status TEXT DEFAULT 'pending'
    );
  ''';

  static const String createSyncQueue = '''
    CREATE TABLE sync_queue (
      id TEXT PRIMARY KEY,
      table_name TEXT NOT NULL,
      record_id TEXT NOT NULL,
      action TEXT NOT NULL,
      payload TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''';
}

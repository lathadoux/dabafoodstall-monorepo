// path: frontend/mobile/lib/data/database/database_helper.dart
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String _databaseName = "pos_local.db";
  static const int _databaseVersion = 1;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint("🧱 [SQLite Helper] Création physique des tables relationnelles cohérentes...");

    await db.execute('PRAGMA foreign_keys = ON');

    await db.execute('''
      CREATE TABLE pos_params (
        id_param INTEGER PRIMARY KEY AUTOINCREMENT,
        id_tenant INTEGER NOT NULL,
        id_pos INTEGER NOT NULL DEFAULT 1, -- 🔑 AJOUT CRITIQUE : Identifie le point de vente actuel
        device_fingerprint TEXT NOT NULL, 
        nom_pos TEXT NOT NULL,
        telephone_pos TEXT,
        devise TEXT,
        adresse_pos TEXT,
        version_schema TEXT, 
        cle_activation_scellee TEXT,
        date_activation TEXT,
        date_derniere_utilisation TEXT,
        jours_utilises_cumules INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE tenants (
        id_tenant INTEGER PRIMARY KEY,
        nom_business TEXT NOT NULL,
        date_inscription TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE familles (
        id_famille INTEGER PRIMARY KEY,
        id_tenant INTEGER NOT NULL,
        nom_famille TEXT NOT NULL,
        type_famille TEXT NOT NULL CHECK(type_famille IN ('vente', 'achat')),
        type_pos TEXT NOT NULL DEFAULT 'general',
        UNIQUE(id_tenant, nom_famille),
        FOREIGN KEY (id_tenant) REFERENCES tenants (id_tenant) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE articles (
        id_article INTEGER PRIMARY KEY,
        id_tenant INTEGER NOT NULL,
        id_famille INTEGER NOT NULL,
        nom_article TEXT NOT NULL,
        type_article TEXT NOT NULL CHECK(type_article IN ('vente', 'achat')),
        prix_unitaire REAL,
        unite_mesure TEXT NOT NULL DEFAULT 'pcs',
        type_pos TEXT NOT NULL DEFAULT 'general',
        UNIQUE(id_tenant, nom_article),
        FOREIGN KEY (id_tenant) REFERENCES tenants (id_tenant) ON DELETE CASCADE,
        FOREIGN KEY (id_famille) REFERENCES familles (id_famille) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id_user INTEGER PRIMARY KEY AUTOINCREMENT,
        id_tenant INTEGER NOT NULL,
        nom_user TEXT NOT NULL,
        role_user TEXT NOT NULL CHECK(role_user IN ('admin', 'manager', 'vendor')),
        password_user TEXT NOT NULL,
        pin_user TEXT NOT NULL,
        FOREIGN KEY (id_tenant) REFERENCES tenants (id_tenant) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE cash_sessions (
        id_session INTEGER PRIMARY KEY AUTOINCREMENT,
        id_tenant INTEGER NOT NULL,
        id_pos INTEGER NOT NULL DEFAULT 1,          -- 🔑 COUCHE MULTI-POS : Identifie l'étal physique
        device_fingerprint TEXT NOT NULL,           -- 🔑 COUCHE MATÉRIELLE : Identifie la tablette/smartphone
        id_user INTEGER NOT NULL,
        date_heure_ouv TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
        date_heure_clot TEXT,
        montant_init REAL NOT NULL CHECK(montant_init >= 0),
        montant_theo REAL NOT NULL DEFAULT 0,
        montant_reel REAL,
        statut_sync INTEGER NOT NULL DEFAULT 0 CHECK(statut_sync IN (0, 1)),
        FOREIGN KEY (id_tenant) REFERENCES tenants (id_tenant) ON DELETE CASCADE,
        FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id_cde INTEGER PRIMARY KEY AUTOINCREMENT,
        id_session INTEGER NOT NULL,
        id_user INTEGER NOT NULL,
        date_heure_cde TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
        statut_commande TEXT NOT NULL DEFAULT 'actif' CHECK(statut_commande IN ('actif', 'en_attente', 'paye', 'termine', 'achat')),
        tag_commande TEXT,
        mode_reglement TEXT NOT NULL DEFAULT 'Cash' CHECK(mode_reglement IN ('Cash', 'Mobile Money')),
        total_amount REAL NOT NULL DEFAULT 0.0,
        statut_sync INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (id_session) REFERENCES cash_sessions(id_session) ON DELETE RESTRICT,
        FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id_cde INTEGER NOT NULL,
        id_article INTEGER NOT NULL,
        qte_vendue REAL NOT NULL CHECK(qte_vendue > 0),
        prix_facture REAL NOT NULL,
        PRIMARY KEY (id_cde, id_article),
        FOREIGN KEY (id_cde) REFERENCES orders(id_cde) ON DELETE CASCADE,
        FOREIGN KEY (id_article) REFERENCES articles(id_article) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE financial_transactions (
        id_trans INTEGER PRIMARY KEY AUTOINCREMENT,
        id_session INTEGER NOT NULL,
        id_user INTEGER NOT NULL,
        id_cde INTEGER,
        id_article_achat INTEGER,
        type_trans TEXT NOT NULL CHECK(type_trans IN ('ouverture', 'encaissement_vente', 'achat_direct', 'versement')),
        montant_trans REAL NOT NULL CHECK(montant_trans >= 0),
        sens_flux TEXT NOT NULL CHECK(sens_flux IN ('DEBIT', 'CREDIT')),
        mode_reglement TEXT NOT NULL CHECK(mode_reglement IN ('especes', 'orange_money', 'wave', 'mtn_money')),
        qte_achat_historique REAL DEFAULT 0,
        date_heure_trans TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
        statut_sync INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (id_session) REFERENCES cash_sessions(id_session) ON DELETE RESTRICT,
        FOREIGN KEY (id_cde) REFERENCES orders(id_cde) ON DELETE SET NULL,
        FOREIGN KEY (id_article_achat) REFERENCES articles(id_article) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE rapports_z (
        id_rapport_z INTEGER PRIMARY KEY AUTOINCREMENT,
        id_tenant INTEGER NOT NULL,
        id_session INTEGER UNIQUE NOT NULL,
        id_user INTEGER NOT NULL,
        date_generation TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
        total_ventes REAL NOT NULL,
        total_achats REAL NOT NULL,
        solde_especes REAL NOT NULL,
        solde_mobile_money REAL NOT NULL DEFAULT 0,
        ecart_caisse REAL NOT NULL DEFAULT 0,
        signature_hash TEXT NOT NULL,
        statut_sync INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (id_tenant) REFERENCES tenants (id_tenant) ON DELETE CASCADE,
        FOREIGN KEY (id_session) REFERENCES cash_sessions(id_session) ON DELETE RESTRICT,
        FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE RESTRICT
      )
    ''');
 
     // =====================================================================
    // 🔑 EXTENSION SYMETRIQUE SYNC ENGINE V2 : GESTION DES ABONNEMENTS ET PARAMÈTRES
    // =====================================================================

    // 1. Table des verrous de fonctionnalités (Flashage descendant exclusif serveur)
    await db.execute('''
      CREATE TABLE local_license_config (
        feature_key TEXT PRIMARY KEY,
        is_enabled INTEGER NOT NULL DEFAULT 0 CHECK(is_enabled IN (0, 1)),
        expires_at TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    // 2. Table de suivi temporel des points de synchronisation (Gestion du Delta)
    await db.execute('''
      CREATE TABLE sync_metadata (
        endpoint_key TEXT PRIMARY KEY,
        last_sync_timestamp TEXT NOT NULL
      )
    ''');

    // =====================================================================
    // 🔄 REFACTO REQUIS : ALTER TABLES POUR LE MODE DELTA (MIGRATION COMPATIBLE V2)
    // =====================================================================
    // SQLite local requiert un champ temporel pour savoir si une ligne cloud est plus récente
    await db.execute('ALTER TABLE familles ADD COLUMN updated_at TEXT DEFAULT "1970-01-01 00:00:00"');
    await db.execute('ALTER TABLE articles ADD COLUMN updated_at TEXT DEFAULT "1970-01-01 00:00:00"');

    debugPrint("✅ [DatabaseHelper] Structure SQLite vierge et extensions Sync Engine V2 chargées.");
  // 🔑 LE CORRECTIF DE PURETÉ : TOUTES LES INSERTIONS ONT ÉTÉ SUPPRIMÉES ICI !


}

  
}
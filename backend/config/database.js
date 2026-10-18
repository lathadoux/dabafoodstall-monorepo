const { Pool } = require('pg');

// 🔑 APPLIQUER L'ÉLASTICITÉ : Docker lira le DNS interne, Windows lira l'adresse locale
const pool = new Pool({
  host: process.env.DB_HOST || '127.0.0.1', // 'postgres_db' sous Docker Ubuntu, '127.0.0.1' sous Windows
  user: process.env.DB_USER || 'dabadba',
  password: process.env.DB_PASSWORD || 'dabadbapass',
  database: process.env.DB_NAME || 'dabafoodstall_cloud',
  // À l'intérieur du réseau Docker, le port de communication interne reste 5432
  port: process.env.DB_PORT ? Number.parseInt(process.env.DB_PORT, 10) : 5433, 
});

pool.on('connect', () => {
  console.log('🐘 [PostgreSQL] Liaison dynamique établie avec succès.');
});

module.exports = pool;

/**
 * Database Configuration
 * PostgreSQL connection setup with Sequelize ORM
 */

const { Sequelize } = require('sequelize');
const winston = require('winston');

// Configure logger for database
const dbLogger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'logs/database.log' }),
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

// Determine environment
const env = process.env.NODE_ENV || 'development';

// Database configuration for different environments
const configs = {
  development: {
    dialect: 'postgres',
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'toeic_master',
    username: process.env.DB_USER || 'toeic_user',
    password: process.env.DB_PASSWORD || 'toeic_password_secure',
    logging: (msg) => dbLogger.debug(msg),
    pool: {
      max: 5,
      min: 0,
      acquire: 30000,
      idle: 10000
    },
    define: {
      timestamps: true,
      underscored: true,
      freezeTableName: true
    }
  },
  
  test: {
    dialect: 'postgres',
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5433,
    database: process.env.DB_NAME || 'toeic_master_test',
    username: process.env.DB_USER || 'toeic_user',
    password: process.env.DB_PASSWORD || 'toeic_password_secure',
    logging: false,
    pool: {
      max: 5,
      min: 0,
      acquire: 30000,
      idle: 10000
    },
    define: {
      timestamps: true,
      underscored: true,
      freezeTableName: true
    }
  },
  
  production: {
    dialect: 'postgres',
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME,
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    logging: (msg) => dbLogger.info(msg),
    pool: {
      max: 20,
      min: 5,
      acquire: 60000,
      idle: 30000
    },
    define: {
      timestamps: true,
      underscored: true,
      freezeTableName: true
    },
    dialectOptions: {
      ssl: {
        require: true,
        rejectUnauthorized: false
      }
    }
  }
};

// Get config for current environment
const config = configs[env];

// Create Sequelize instance
const sequelize = new Sequelize(
  config.database,
  config.username,
  config.password,
  {
    host: config.host,
    port: config.port,
    dialect: config.dialect,
    logging: config.logging,
    pool: config.pool,
    define: config.define,
    dialectOptions: config.dialectOptions || {}
  }
);

// Test database connection
async function testConnection() {
  try {
    await sequelize.authenticate();
    dbLogger.info('✅ Database connection established successfully.');
    return true;
  } catch (error) {
    dbLogger.error('❌ Unable to connect to the database:', error);
    return false;
  }
}

// Sync database (use with caution in production)
async function syncDatabase(options = {}) {
  try {
    if (env === 'production' && !options.force) {
      dbLogger.warn('⚠️ Database sync skipped in production without force option');
      return;
    }
    
    dbLogger.info('🔄 Syncing database...');
    await sequelize.sync(options);
    dbLogger.info('✅ Database synced successfully');
  } catch (error) {
    dbLogger.error('❌ Database sync failed:', error);
    throw error;
  }
}

// Close database connection
async function closeConnection() {
  try {
    await sequelize.close();
    dbLogger.info('✅ Database connection closed');
  } catch (error) {
    dbLogger.error('❌ Error closing database connection:', error);
  }
}

// Export functions and instances
module.exports = {
  sequelize,
  testConnection,
  syncDatabase,
  closeConnection,
  connectDatabase: testConnection, // Alias for consistency
  config
};

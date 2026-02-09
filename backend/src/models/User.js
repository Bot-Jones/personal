/**
 * User Model
 * Defines the User table structure and methods for authentication
 */

const { DataTypes } = require('sequelize');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { sequelize } = require('../config/database');

const User = sequelize.define('User', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
    allowNull: false
  },
  
  email: {
    type: DataTypes.STRING(255),
    allowNull: false,
    unique: {
      name: 'users_email_unique',
      msg: 'Email already exists'
    },
    validate: {
      isEmail: {
        msg: 'Please provide a valid email address'
      },
      notEmpty: {
        msg: 'Email is required'
      },
      len: {
        args: [5, 255],
        msg: 'Email must be between 5 and 255 characters'
      }
    },
    set(value) {
      this.setDataValue('email', value.toLowerCase().trim());
    }
  },
  
  password_hash: {
    type: DataTypes.STRING(255),
    allowNull: false,
    validate: {
      notEmpty: {
        msg: 'Password is required'
      }
    }
  },
  
  full_name: {
    type: DataTypes.STRING(100),
    allowNull: true,
    validate: {
      len: {
        args: [2, 100],
        msg: 'Full name must be between 2 and 100 characters'
      }
    }
  },
  
  phone: {
    type: DataTypes.STRING(20),
    allowNull: true,
    validate: {
      is: {
        args: /^[\+]?[1-9][0-9\-\.\s]{9,15}$/,
        msg: 'Please provide a valid phone number'
      }
    }
  },
  
  avatar_url: {
    type: DataTypes.STRING(500),
    allowNull: true,
    validate: {
      isUrl: {
        msg: 'Please provide a valid URL for avatar'
      }
    }
  },
  
  role: {
    type: DataTypes.ENUM('admin', 'teacher', 'student'),
    defaultValue: 'student',
    allowNull: false,
    validate: {
      isIn: {
        args: [['admin', 'teacher', 'student']],
        msg: 'Role must be admin, teacher, or student'
      }
    }
  },
  
  current_level: {
    type: DataTypes.STRING(50),
    defaultValue: 'beginner',
    allowNull: false,
    validate: {
      isIn: {
        args: [['beginner', 'elementary', 'intermediate', 'advanced', 'expert']],
        msg: 'Invalid level'
      }
    }
  },
  
  target_score: {
    type: DataTypes.INTEGER,
    defaultValue: 450,
    allowNull: false,
    validate: {
      min: {
        args: [10],
        msg: 'Target score must be at least 10'
      },
      max: {
        args: [990],
        msg: 'Target score cannot exceed 990'
      },
      isInt: {
        msg: 'Target score must be an integer'
      }
    }
  },
  
  current_score: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    allowNull: false,
    validate: {
      min: {
        args: [0],
        msg: 'Current score cannot be negative'
      },
      max: {
        args: [990],
        msg: 'Current score cannot exceed 990'
      },
      isInt: {
        msg: 'Current score must be an integer'
      }
    }
  },
  
  streak_days: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    allowNull: false,
    validate: {
      min: {
        args: [0],
        msg: 'Streak days cannot be negative'
      },
      isInt: {
        msg: 'Streak days must be an integer'
      }
    }
  },
  
  total_study_minutes: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    allowNull: false,
    validate: {
      min: {
        args: [0],
        msg: 'Study minutes cannot be negative'
      },
      isInt: {
        msg: 'Study minutes must be an integer'
      }
    }
  },
  
  total_questions_answered: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    allowNull: false,
    validate: {
      min: {
        args: [0],
        msg: 'Questions answered cannot be negative'
      },
      isInt: {
        msg: 'Questions answered must be an integer'
      }
    }
  },
  
  correct_answers_count: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    allowNull: false,
    validate: {
      min: {
        args: [0],
        msg: 'Correct answers count cannot be negative'
      },
      isInt: {
        msg: 'Correct answers count must be an integer'
      }
    }
  },
  
  is_email_verified: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    allowNull: false
  },
  
  is_2fa_enabled: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    allowNull: false
  },
  
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
    allowNull: false
  },
  
  last_login_at: {
    type: DataTypes.DATE,
    allowNull: true
  },
  
  email_verification_token: {
    type: DataTypes.STRING(64),
    allowNull: true
  },
  
  email_verification_expires: {
    type: DataTypes.DATE,
    allowNull: true
  },
  
  password_reset_token: {
    type: DataTypes.STRING(64),
    allowNull: true
  },
  
  password_reset_expires: {
    type: DataTypes.DATE,
    allowNull: true
  }
}, {
  tableName: 'users',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at',
  
  hooks: {
    beforeCreate: async (user) => {
      if (user.password_hash) {
        user.password_hash = await bcrypt.hash(user.password_hash, parseInt(process.env.BCRYPT_SALT_ROUNDS) || 12);
      }
    },
    beforeUpdate: async (user) => {
      if (user.changed('password_hash')) {
        user.password_hash = await bcrypt.hash(user.password_hash, parseInt(process.env.BCRYPT_SALT_ROUNDS) || 12);
      }
    }
  },
  
  defaultScope: {
    attributes: {
      exclude: ['password_hash', 'email_verification_token', 'email_verification_expires', 'password_reset_token', 'password_reset_expires']
    }
  },
  
  scopes: {
    withSensitiveData: {
      attributes: {
        include: ['email_verification_token', 'email_verification_expires', 'password_reset_token', 'password_reset_expires']
      }
    },
    withPassword: {
      attributes: {
        include: ['password_hash']
      }
    }
  }
});

// Instance Methods
User.prototype.toJSON = function() {
  const values = Object.assign({}, this.get());
  delete values.password_hash;
  delete values.email_verification_token;
  delete values.email_verification_expires;
  delete values.password_reset_token;
  delete values.password_reset_expires;
  return values;
};

User.prototype.comparePassword = async function(candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password_hash);
};

User.prototype.generateAuthToken = function() {
  const token = jwt.sign(
    {
      userId: this.id,
      email: this.email,
      role: this.role
    },
    process.env.JWT_SECRET,
    {
      expiresIn: process.env.JWT_ACCESS_EXPIRY || '15m',
      issuer: 'toeic-master-api',
      audience: 'toeic-master-users'
    }
  );
  return token;
};

User.prototype.generateRefreshToken = function() {
  const token = jwt.sign(
    {
      userId: this.id,
      email: this.email,
      type: 'refresh'
    },
    process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET,
    {
      expiresIn: process.env.JWT_REFRESH_EXPIRY || '7d',
      issuer: 'toeic-master-api',
      audience: 'toeic-master-users'
    }
  );
  return token;
};

User.prototype.generateEmailVerificationToken = function() {
  const token = crypto.randomBytes(32).toString('hex');
  this.email_verification_token = crypto
    .createHash('sha256')
    .update(token)
    .digest('hex');
  
  this.email_verification_expires = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours
  return token;
};

User.prototype.generatePasswordResetToken = function() {
  const token = crypto.randomBytes(32).toString('hex');
  this.password_reset_token = crypto
    .createHash('sha256')
    .update(token)
    .digest('hex');
  
  this.password_reset_expires = new Date(Date.now() + 60 * 60 * 1000); // 1 hour
  return token;
};

User.prototype.calculateAccuracy = function() {
  if (this.total_questions_answered === 0) return 0;
  return Math.round((this.correct_answers_count / this.total_questions_answered) * 100);
};

User.prototype.updateStreak = function() {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  const lastLogin = this.last_login_at ? new Date(this.last_login_at) : null;
  if (lastLogin) {
    lastLogin.setHours(0, 0, 0, 0);
    
    const diffDays = Math.floor((today - lastLogin) / (1000 * 60 * 60 * 24));
    
    if (diffDays === 1) {
      this.streak_days += 1;
    } else if (diffDays > 1) {
      this.streak_days = 1;
    }
    // diffDays === 0 means same day, keep streak
  } else {
    this.streak_days = 1;
  }
  
  this.last_login_at = new Date();
  return this.streak_days;
};

// Static Methods
User.findByEmail = function(email) {
  return this.findOne({
    where: { email: email.toLowerCase() },
    attributes: { include: ['password_hash'] }
  });
};

User.findByIdWithSensitive = function(id) {
  return this.findByPk(id, {
    attributes: { include: ['password_hash'] }
  });
};

User.verifyEmailToken = async function(token) {
  const hashedToken = crypto
    .createHash('sha256')
    .update(token)
    .digest('hex');
  
  const user = await this.findOne({
    where: {
      email_verification_token: hashedToken,
      email_verification_expires: {
        [sequelize.Op.gt]: new Date()
      }
    }
  });
  
  if (!user) {
    throw new Error('Invalid or expired verification token');
  }
  
  user.is_email_verified = true;
  user.email_verification_token = null;
  user.email_verification_expires = null;
  await user.save();
  
  return user;
};

User.verifyPasswordResetToken = async function(token) {
  const hashedToken = crypto
    .createHash('sha256')
    .update(token)
    .digest('hex');
  
  const user = await this.findOne({
    where: {
      password_reset_token: hashedToken,
      password_reset_expires: {
        [sequelize.Op.gt]: new Date()
      }
    }
  });
  
  if (!user) {
    throw new Error('Invalid or expired password reset token');
  }
  
  return user;
};

module.exports = User;

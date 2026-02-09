-- TOEIC Master Platform Database Schema
-- Version: 1.0.0

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- USERS TABLE
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    phone VARCHAR(20),
    avatar_url VARCHAR(500),
    
    -- User roles: admin, teacher, student
    role VARCHAR(20) DEFAULT 'student' CHECK (role IN ('admin', 'teacher', 'student')),
    
    -- TOEIC proficiency
    current_level VARCHAR(50) DEFAULT 'beginner',
    target_score INTEGER DEFAULT 450,
    current_score INTEGER DEFAULT 0,
    
    -- Learning stats
    streak_days INTEGER DEFAULT 0,
    total_study_minutes INTEGER DEFAULT 0,
    total_questions_answered INTEGER DEFAULT 0,
    correct_answers_count INTEGER DEFAULT 0,
    
    -- Account status
    is_email_verified BOOLEAN DEFAULT FALSE,
    is_2fa_enabled BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes for performance
    INDEX idx_users_email (email),
    INDEX idx_users_role (role),
    INDEX idx_users_created_at (created_at DESC)
);

-- 2FA SETTINGS
CREATE TABLE user_2fa (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    secret_key VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    backup_codes TEXT[],
    is_enabled BOOLEAN DEFAULT FALSE,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_id),
    INDEX idx_user_2fa_user_id (user_id)
);

-- AUDIT LOGS
CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action_type VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id UUID,
    
    -- Change tracking
    old_values JSONB,
    new_values JSONB,
    
    -- Request info
    ip_address INET,
    user_agent TEXT,
    endpoint VARCHAR(500),
    http_method VARCHAR(10),
    
    -- Status
    status_code INTEGER,
    error_message TEXT,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes for querying
    INDEX idx_audit_user_id (user_id),
    INDEX idx_audit_action_type (action_type),
    INDEX idx_audit_created_at (created_at DESC)
);

-- TOEIC QUESTIONS
CREATE TABLE questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- TOEIC Part (1-7)
    part INTEGER NOT NULL CHECK (part BETWEEN 1 AND 7),
    
    -- Question type
    question_type VARCHAR(50) NOT NULL,
    sub_type VARCHAR(50),
    
    -- Content
    content TEXT NOT NULL,
    description TEXT,
    
    -- Media (for listening/visual questions)
    audio_url VARCHAR(500),
    image_url VARCHAR(500),
    transcript TEXT,
    
    -- Options for multiple choice
    options JSONB NOT NULL,
    correct_answer VARCHAR(10) NOT NULL,
    
    -- Explanation and hints
    explanation TEXT,
    hints TEXT[],
    
    -- Difficulty and metadata
    difficulty INTEGER DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 5),
    tags TEXT[],
    estimated_time_seconds INTEGER DEFAULT 60,
    
    -- Statistics
    times_attempted INTEGER DEFAULT 0,
    correct_attempts INTEGER DEFAULT 0,
    
    -- Management
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes
    INDEX idx_questions_part (part),
    INDEX idx_questions_type (question_type),
    INDEX idx_questions_difficulty (difficulty),
    INDEX idx_questions_tags (tags),
    INDEX idx_questions_created_at (created_at DESC)
);

-- TESTS/EXAMS
CREATE TABLE tests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Test configuration
    duration_minutes INTEGER DEFAULT 120,
    total_questions INTEGER DEFAULT 200,
    question_ids UUID[] NOT NULL,
    
    -- Scoring
    passing_score INTEGER DEFAULT 650,
    is_official_test BOOLEAN DEFAULT FALSE,
    
    -- Access control
    is_public BOOLEAN DEFAULT TRUE,
    is_free BOOLEAN DEFAULT TRUE,
    price DECIMAL(10, 2) DEFAULT 0.00,
    
    -- Statistics
    times_taken INTEGER DEFAULT 0,
    average_score DECIMAL(5, 2),
    
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_tests_name (name),
    INDEX idx_tests_is_public (is_public),
    INDEX idx_tests_created_at (created_at DESC)
);

-- TEST SESSIONS (when a user takes a test)
CREATE TABLE test_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    test_id UUID REFERENCES tests(id),
    
    -- Session state
    status VARCHAR(20) DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'abandoned')),
    
    -- Timing
    started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,
    time_spent_seconds INTEGER DEFAULT 0,
    
    -- Answers
    answers JSONB, -- {question_id: "A", question_id: "B", ...}
    
    -- Scores
    score_listening INTEGER DEFAULT 0,
    score_reading INTEGER DEFAULT 0,
    total_score INTEGER DEFAULT 0,
    
    -- Analysis
    weak_parts INTEGER[], -- Parts that need improvement
    strong_parts INTEGER[], -- Parts that are strong
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_test_sessions_user_id (user_id),
    INDEX idx_test_sessions_test_id (test_id),
    INDEX idx_test_sessions_status (status),
    INDEX idx_test_sessions_created_at (created_at DESC)
);

-- USER PROGRESS (tracking per question)
CREATE TABLE user_progress (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    test_session_id UUID REFERENCES test_sessions(id),
    
    -- Attempt details
    user_answer VARCHAR(10),
    is_correct BOOLEAN NOT NULL,
    time_spent_seconds INTEGER,
    
    -- For spaced repetition
    next_review_date DATE,
    mastery_level INTEGER DEFAULT 0 CHECK (mastery_level BETWEEN 0 AND 5),
    review_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_id, question_id, test_session_id),
    INDEX idx_user_progress_user_id (user_id),
    INDEX idx_user_progress_question_id (question_id),
    INDEX idx_user_progress_next_review (next_review_date)
);

-- VOCABULARY
CREATE TABLE vocabulary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    word VARCHAR(100) NOT NULL,
    phonetic TEXT,
    meaning TEXT NOT NULL,
    example_sentence TEXT,
    synonym TEXT[],
    antonym TEXT[],
    
    -- TOEIC specific
    frequency_level VARCHAR(20), -- high, medium, low
    toeic_part INTEGER[], -- Which parts this word appears in
    common_mistakes TEXT[],
    
    -- Media
    audio_url VARCHAR(500),
    image_url VARCHAR(500),
    
    -- Metadata
    tags TEXT[],
    difficulty INTEGER DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 5),
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_vocabulary_word (word),
    INDEX idx_vocabulary_frequency (frequency_level),
    INDEX idx_vocabulary_tags (tags)
);

-- USER VOCABULARY PROGRESS
CREATE TABLE user_vocabulary (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vocab_id UUID NOT NULL REFERENCES vocabulary(id) ON DELETE CASCADE,
    
    -- Spaced repetition system
    status VARCHAR(20) DEFAULT 'learning' CHECK (status IN ('learning', 'reviewing', 'mastered')),
    next_review_date DATE NOT NULL,
    interval_days INTEGER DEFAULT 1,
    ease_factor DECIMAL(4, 2) DEFAULT 2.5,
    review_count INTEGER DEFAULT 0,
    
    -- Performance
    last_review_result VARCHAR(10), -- again, hard, good, easy
    total_review_time_seconds INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_id, vocab_id),
    INDEX idx_user_vocabulary_user_id (user_id),
    INDEX idx_user_vocabulary_next_review (next_review_date),
    INDEX idx_user_vocabulary_status (status)
);

-- GRAMMAR LESSONS
CREATE TABLE grammar_lessons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    content TEXT NOT NULL,
    
    -- Metadata
    level VARCHAR(50),
    topic VARCHAR(100),
    tags TEXT[],
    estimated_study_minutes INTEGER DEFAULT 10,
    
    -- Related questions
    practice_question_ids UUID[],
    
    -- Media
    video_url VARCHAR(500),
    pdf_url VARCHAR(500),
    
    -- Ordering
    display_order INTEGER DEFAULT 0,
    
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_grammar_lessons_slug (slug),
    INDEX idx_grammar_lessons_level (level),
    INDEX idx_grammar_lessons_topic (topic)
);

-- USER GRAMMAR PROGRESS
CREATE TABLE user_grammar_progress (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES grammar_lessons(id) ON DELETE CASCADE,
    
    completion_status VARCHAR(20) DEFAULT 'not_started' CHECK (
        completion_status IN ('not_started', 'in_progress', 'completed')
    ),
    completed_at TIMESTAMPTZ,
    score DECIMAL(5, 2),
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_id, lesson_id),
    INDEX idx_user_grammar_user_id (user_id),
    INDEX idx_user_grammar_lesson_id (lesson_id)
);

-- Create updated_at triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add triggers to all tables with updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_2fa_updated_at BEFORE UPDATE ON user_2fa
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_questions_updated_at BEFORE UPDATE ON questions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tests_updated_at BEFORE UPDATE ON tests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_test_sessions_updated_at BEFORE UPDATE ON test_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vocabulary_updated_at BEFORE UPDATE ON vocabulary
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_vocabulary_updated_at BEFORE UPDATE ON user_vocabulary
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_grammar_lessons_updated_at BEFORE UPDATE ON grammar_lessons
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_grammar_progress_updated_at BEFORE UPDATE ON user_grammar_progress
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

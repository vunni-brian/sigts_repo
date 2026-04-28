-- =====================================================
-- SIGTS DATABASE SCHEMA - 35 NORMALIZED TABLES
-- SMART INFORMATION GUIDE TOUR SYSTEM
-- BWINDI IMPENETRABLE NATIONAL PARK
-- =====================================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- TABLE 1: USER
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('tourist', 'guide', 'it_manager', 'admin')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,
    last_lat DECIMAL(10,8),
    last_lng DECIMAL(11,8),
    language_pref VARCHAR(5) DEFAULT 'en',
    profile_pic_url TEXT
);

-- TABLE 2: TOURIST
CREATE TABLE tourists (
    tourist_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nationality VARCHAR(100),
    date_of_birth DATE,
    passport_number VARCHAR(50),
    interests JSONB DEFAULT '[]',
    last_sync_time TIMESTAMP WITH TIME ZONE,
    offline_data_version INTEGER DEFAULT 1,
    last_inside_park_time TIMESTAMP WITH TIME ZONE,
    total_visits INTEGER DEFAULT 0,
    emergency_contact_name VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE
);

-- TABLE 3: TOUR_GUIDE
CREATE TABLE tour_guides (
    tourguide_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_number VARCHAR(50) UNIQUE NOT NULL,
    specialization JSONB DEFAULT '[]',
    years_of_experience INTEGER DEFAULT 0,
    languages JSONB DEFAULT '[]',
    certification_level VARCHAR(20) CHECK (certification_level IN ('trainee', 'assistant', 'full', 'senior', 'master')),
    certification_date DATE,
    expiry_date DATE,
    employee_id VARCHAR(50) UNIQUE,
    is_active BOOLEAN DEFAULT true,
    max_tour_duration INTEGER DEFAULT 8,
    total_tours_conducted INTEGER DEFAULT 0,
    average_rating DECIMAL(2,1) DEFAULT 0.0,
    emergency_contact_name VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    park_id UUID
);

-- TABLE 4: IT_MANAGER
CREATE TABLE it_managers (
    itmanager_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id VARCHAR(50) UNIQUE NOT NULL,
    department VARCHAR(100) DEFAULT 'IT Administration',
    access_level VARCHAR(20) NOT NULL CHECK (access_level IN ('super_admin', 'admin', 'moderator')),
    can_create_users BOOLEAN DEFAULT true,
    can_delete_users BOOLEAN DEFAULT false,
    can_modify_content BOOLEAN DEFAULT true,
    can_view_reports BOOLEAN DEFAULT true,
    last_action_time TIMESTAMP WITH TIME ZONE,
    action_log JSONB DEFAULT '[]',
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE
);

-- TABLE 5: PARK
CREATE TABLE parks (
    park_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL UNIQUE,
    description TEXT,
    geofence_boundary GEOMETRY(POLYGON, 4326) NOT NULL,
    intranet_server_ip INET,
    established_date DATE,
    area_sqkm DECIMAL(10,2),
    opening_time TIME,
    closing_time TIME,
    emergency_phone VARCHAR(20),
    weather_station_id VARCHAR(50),
    image_url TEXT,
    intranet_subnet CIDR
);

-- TABLE 6: LOCATION
CREATE TABLE locations (
    location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    location_type VARCHAR(50) NOT NULL CHECK (location_type IN ('waterhole', 'viewpoint', 'camp', 'gate', 'trail', 'ranger_post')),
    coordinates GEOMETRY(POINT, 4326) NOT NULL,
    altitude DECIMAL(7,2),
    terrain_type VARCHAR(50),
    image_urls TEXT[],
    audio_guide_url TEXT,
    trigger_radius INTEGER DEFAULT 50,
    facilities JSONB DEFAULT '[]',
    best_viewing_time VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    park_id UUID NOT NULL REFERENCES parks(park_id) ON DELETE CASCADE
);

-- TABLE 7: ANIMAL
CREATE TABLE animals (
    animal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    scientific_name VARCHAR(200),
    description TEXT,
    conservation_status VARCHAR(50) CHECK (conservation_status IN ('endangered', 'vulnerable', 'near_threatened', 'least_concern')),
    habitat TEXT,
    diet VARCHAR(50),
    lifespan VARCHAR(50),
    image_urls TEXT[],
    video_url TEXT,
    fun_facts TEXT[],
    average_size VARCHAR(100),
    gestation_period VARCHAR(50),
    social_structure VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- TABLE 8: ANIMAL_LOCATION
CREATE TABLE animal_locations (
    animallocation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sighting_frequency VARCHAR(20) CHECK (sighting_frequency IN ('common', 'uncommon', 'rare', 'seasonal')),
    best_season VARCHAR(50),
    last_sighted TIMESTAMP WITH TIME ZONE,
    animal_id UUID NOT NULL REFERENCES animals(animal_id) ON DELETE CASCADE,
    location_id UUID NOT NULL REFERENCES locations(location_id) ON DELETE CASCADE
);

-- TABLE 9: SIGHTING
CREATE TABLE sightings (
    sighting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    number_observed INTEGER DEFAULT 1,
    behavior TEXT,
    photo_urls TEXT[],
    video_url TEXT,
    verification_status VARCHAR(20) DEFAULT 'pending' CHECK (verification_status IN ('pending', 'verified', 'flagged')),
    verification_notes TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    animal_id UUID NOT NULL REFERENCES animals(animal_id) ON DELETE CASCADE,
    location_id UUID NOT NULL REFERENCES locations(location_id) ON DELETE CASCADE,
    toursession_id UUID,
    tourguide_id UUID,
    tourist_id UUID,
    reported_by_tourist UUID REFERENCES users(user_id) ON DELETE SET NULL
);

-- TABLE 10: CULTURAL_NARRATIVE
CREATE TABLE cultural_narratives (
    narrative_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_en VARCHAR(500) NOT NULL,
    title_local VARCHAR(500),
    narrative_en TEXT,
    narrative_local TEXT,
    storyteller_name VARCHAR(200) NOT NULL,
    storyteller_photo_url TEXT,
    community VARCHAR(50) NOT NULL CHECK (community IN ('batwa', 'bakiga', 'banyarwanda', 'other')),
    story_type VARCHAR(50) CHECK (story_type IN ('myth', 'history', 'tradition', 'music', 'proverb')),
    audio_url TEXT,
    video_url TEXT,
    duration INTEGER,
    image_urls TEXT[],
    cultural_significance TEXT,
    taboos TEXT,
    verified_by_community BOOLEAN DEFAULT false,
    verification_date DATE,
    view_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    user_id UUID REFERENCES users(user_id) ON DELETE SET NULL
);

-- TABLE 11: CULTURAL_LOCATION
CREATE TABLE cultural_locations (
    narrative_id UUID NOT NULL REFERENCES cultural_narratives(narrative_id) ON DELETE CASCADE,
    location_id UUID NOT NULL REFERENCES locations(location_id) ON DELETE CASCADE,
    PRIMARY KEY (narrative_id, location_id)
);

-- TABLE 12: CULTURAL_ANIMAL
CREATE TABLE cultural_animals (
    narrative_id UUID NOT NULL REFERENCES cultural_narratives(narrative_id) ON DELETE CASCADE,
    animal_id UUID NOT NULL REFERENCES animals(animal_id) ON DELETE CASCADE,
    PRIMARY KEY (narrative_id, animal_id)
);

-- TABLE 13: AI_CONTENT_GENERATION
CREATE TABLE ai_content_generations (
    generation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_type VARCHAR(50) NOT NULL CHECK (content_type IN ('animal', 'location', 'cultural', 'faq')),
    related_entity_id UUID NOT NULL,
    generated_text TEXT NOT NULL,
    ai_model_version VARCHAR(50),
    confidence_score DECIMAL(3,2),
    review_status VARCHAR(20) DEFAULT 'pending' CHECK (review_status IN ('pending', 'approved', 'rejected', 'edited')),
    review_notes TEXT,
    reviewed_by UUID REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP WITH TIME ZONE,
    user_id UUID REFERENCES users(user_id) ON DELETE SET NULL
);

-- TABLE 14: TOUR_ROUTE
CREATE TABLE tour_routes (
    route_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    path_geometry GEOMETRY(LINESTRING, 4326) NOT NULL,
    distance_km DECIMAL(5,2),
    duration_hours DECIMAL(3,1),
    difficulty VARCHAR(20) CHECK (difficulty IN ('easy', 'moderate', 'difficult', 'expert')),
    elevation_profile JSONB,
    image_urls TEXT[]
);

-- TABLE 15: ROUTE_LOCATION
CREATE TABLE route_locations (
    stop_order INTEGER NOT NULL,
    estimated_time_from_prev INTEGER,
    stop_duration INTEGER,
    points_of_interest TEXT,
    route_id UUID NOT NULL REFERENCES tour_routes(route_id) ON DELETE CASCADE,
    location_id UUID NOT NULL REFERENCES locations(location_id) ON DELETE CASCADE,
    PRIMARY KEY (route_id, stop_order)
);

-- TABLE 16: TOUR_SESSION
CREATE TABLE tour_sessions (
    tour_session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scheduled_start TIMESTAMP WITH TIME ZONE NOT NULL,
    actual_start TIMESTAMP WITH TIME ZONE,
    actual_end TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'ongoing', 'completed', 'cancelled')),
    group_size INTEGER,
    vehicle_used VARCHAR(100),
    special_requests TEXT,
    current_lat DECIMAL(10,8),
    current_lng DECIMAL(11,8),
    last_location_update TIMESTAMP WITH TIME ZONE,
    guide_notes TEXT,
    incidents_reported JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    tourguide_id UUID NOT NULL REFERENCES tour_guides(tourguide_id) ON DELETE RESTRICT,
    route_id UUID NOT NULL REFERENCES tour_routes(route_id) ON DELETE RESTRICT,
    park_id UUID NOT NULL REFERENCES parks(park_id) ON DELETE RESTRICT
);

-- TABLE 17: TOUR_PARTICIPANT
CREATE TABLE tour_participants (
    tour_session_id UUID NOT NULL REFERENCES tour_sessions(tour_session_id) ON DELETE CASCADE,
    tourist_id UUID NOT NULL REFERENCES tourists(tourist_id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pickup_location VARCHAR(200),
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    review TEXT,
    feedback_date TIMESTAMP WITH TIME ZONE,
    PRIMARY KEY (tour_session_id, tourist_id)
);

-- TABLE 18: TOUR_CONTENT
CREATE TABLE tour_content (
    content_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_en VARCHAR(200) NOT NULL,
    title_local VARCHAR(200),
    description_en TEXT,
    description_local TEXT,
    image_url TEXT,
    video_url TEXT,
    fun_fact TEXT,
    trigger_radius_meters INTEGER DEFAULT 50,
    display_duration_seconds INTEGER DEFAULT 30,
    content_type VARCHAR(50) CHECK (content_type IN ('flora', 'fauna', 'history', 'conservation', 'geography')),
    order_priority INTEGER DEFAULT 100,
    location_id UUID NOT NULL REFERENCES locations(location_id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(user_id) ON DELETE SET NULL
);

-- TABLE 19: TOURIST_PROGRESS
CREATE TABLE tourist_progress (
    touristprog_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    viewed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed BOOLEAN DEFAULT true,
    time_spent_seconds INTEGER DEFAULT 0,
    viewed_at_lat DECIMAL(10,8),
    viewed_at_lng DECIMAL(11,8),
    tourist_id UUID NOT NULL REFERENCES tourists(tourist_id) ON DELETE CASCADE,
    tour_session_id UUID REFERENCES tour_sessions(tour_session_id) ON DELETE SET NULL,
    content_id UUID NOT NULL REFERENCES tour_content(content_id) ON DELETE CASCADE
);

-- TABLE 20: NAVIGATION_PATH
CREATE TABLE navigation_paths (
    path_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    path_geometry GEOMETRY(LINESTRING, 4326) NOT NULL,
    distance_km DECIMAL(5,2),
    estimated_time_minutes INTEGER,
    difficulty VARCHAR(20) CHECK (difficulty IN ('easy', 'moderate', 'difficult')),
    elevation_gain DECIMAL(6,2),
    terrain_description TEXT,
    navigation_steps JSONB,
    voice_guidance_file TEXT,
    is_active BOOLEAN DEFAULT true,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    location_id UUID REFERENCES locations(location_id) ON DELETE CASCADE
);

-- TABLE 21: AI_QUERY_LOG
CREATE TABLE ai_query_logs (
    query_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query_text TEXT NOT NULL,
    response_text TEXT,
    response_time_ms INTEGER,
    language VARCHAR(5) DEFAULT 'en',
    rated_helpful BOOLEAN,
    user_feedback TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    tourist_id UUID REFERENCES tourists(tourist_id) ON DELETE SET NULL,
    location_id UUID REFERENCES locations(location_id) ON DELETE SET NULL
);

-- TABLE 22: VISITOR_FLOW
CREATE TABLE visitor_flow (
    flow_id BIGSERIAL PRIMARY KEY,
    arrival_time TIMESTAMP WITH TIME ZONE NOT NULL,
    departure_time TIMESTAMP WITH TIME ZONE,
    duration_minutes INTEGER,
    group_size INTEGER,
    tourist_id UUID REFERENCES tourists(tourist_id) ON DELETE SET NULL,
    location_id UUID NOT NULL REFERENCES locations(location_id) ON DELETE CASCADE,
    tour_session_id UUID REFERENCES tour_sessions(tour_session_id) ON DELETE SET NULL
);

-- TABLE 23: CONGESTION_PREDICTION
CREATE TABLE congestion_predictions (
    prediction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    predicted_date DATE NOT NULL,
    predicted_hour INTEGER NOT NULL CHECK (predicted_hour BETWEEN 0 AND 23),
    predicted_visitor_count INTEGER,
    confidence_interval_low INTEGER,
    confidence_interval_high INTEGER,
    day_of_week INTEGER CHECK (day_of_week BETWEEN 0 AND 6),
    is_holiday BOOLEAN DEFAULT false,
    expected_weather VARCHAR(50),
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    location_id UUID NOT NULL REFERENCES locations(location_id) ON DELETE CASCADE,
    UNIQUE (location_id, predicted_date, predicted_hour)
);

-- TABLE 24: PARK_PERFORMANCE_REPORT
CREATE TABLE park_performance_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_type VARCHAR(20) CHECK (report_type IN ('daily', 'weekly', 'monthly', 'custom')),
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    metrics JSONB NOT NULL,
    insights JSONB,
    recommendations JSONB,
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    report_file TEXT,
    user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    generated_by UUID REFERENCES users(user_id) ON DELETE SET NULL
);

-- TABLE 25: FEEDBACK
CREATE TABLE feedback (
    feedback_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    category VARCHAR(50) CHECK (category IN ('tour', 'guide', 'content', 'app', 'general')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    tourist_id UUID REFERENCES tourists(tourist_id) ON DELETE SET NULL,
    tour_session_id UUID REFERENCES tour_sessions(tour_session_id) ON DELETE SET NULL,
    tourguide_id UUID REFERENCES tour_guides(tourguide_id) ON DELETE SET NULL
);

-- TABLE 26: NOTIFICATION
CREATE TABLE notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(50) NOT NULL CHECK (type IN ('tour_reminder', 'sighting_alert', 'system', 'message', 'emergency')),
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE
);

-- TABLE 27: SYNC_QUEUE
CREATE TABLE sync_queue (
    queue_id BIGSERIAL PRIMARY KEY,
    device_id VARCHAR(100),
    action VARCHAR(20) NOT NULL CHECK (action IN ('create', 'update', 'delete')),
    table_name VARCHAR(50) NOT NULL,
    record_id UUID,
    data JSONB,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    attempts INTEGER DEFAULT 0,
    error TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP WITH TIME ZONE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE
);

-- TABLE 28: CONTENT_UPDATE
CREATE TABLE content_updates (
    contentupdate_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id UUID NOT NULL,
    version INTEGER DEFAULT 1,
    checksum VARCHAR(64),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (table_name, record_id)
);

-- TABLE 29: GUIDE_SHIFT
CREATE TABLE guide_shifts (
    shift_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shift_date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    actual_start TIMESTAMP WITH TIME ZONE,
    actual_end TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'active', 'completed', 'absent')),
    notes TEXT,
    tourguide_id UUID NOT NULL REFERENCES tour_guides(tourguide_id) ON DELETE CASCADE,
    UNIQUE (tourguide_id, shift_date, start_time)
);

-- TABLE 30: AUDIT_LOG
CREATE TABLE audit_logs (
    auditlog_id BIGSERIAL PRIMARY KEY,
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(50),
    record_id UUID,
    old_value JSONB,
    new_value JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    user_id UUID REFERENCES users(user_id) ON DELETE SET NULL
);

-- TABLE 31: TOUR_RECOMMENDATION
CREATE TABLE tour_recommendations (
    recommendation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recommendation_score DECIMAL(3,2) CHECK (recommendation_score BETWEEN 0 AND 1),
    recommendation_reason VARCHAR(200),
    shown_to_user BOOLEAN DEFAULT false,
    user_accepted BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE,
    tourist_id UUID NOT NULL REFERENCES tourists(tourist_id) ON DELETE CASCADE,
    route_id UUID NOT NULL REFERENCES tour_routes(route_id) ON DELETE CASCADE
);

-- TABLE 32: SAFETY_TIP
CREATE TABLE safety_tips (
    tip_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(50) CHECK (category IN ('wildlife', 'driving', 'health', 'general', 'weather')),
    priority INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 5),
    image_url TEXT,
    audio_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    park_id UUID NOT NULL REFERENCES parks(park_id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(user_id) ON DELETE SET NULL
);

-- TABLE 33: FAQ
CREATE TABLE faqs (
    faq_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_en TEXT NOT NULL,
    question_local TEXT,
    answer_en TEXT NOT NULL,
    answer_local TEXT,
    category VARCHAR(50),
    view_count INTEGER DEFAULT 0,
    helpful_count INTEGER DEFAULT 0,
    is_published BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    park_id UUID NOT NULL REFERENCES parks(park_id) ON DELETE CASCADE
);

-- TABLE 34: DESTINATION_INFO
CREATE TABLE destination_info (
    destinfo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(50) NOT NULL CHECK (category IN ('entry_fees', 'accommodation', 'weather', 'rules', 'emergency', 'transport', 'health', 'facilities')),
    title VARCHAR(200) NOT NULL,
    content_en TEXT NOT NULL,
    content_local TEXT,
    image_url TEXT,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_emergency BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    park_id UUID NOT NULL REFERENCES parks(park_id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(user_id) ON DELETE SET NULL
);

-- TABLE 35: GUIDE_ACHIEVEMENT
CREATE TABLE guide_achievements (
    achievement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    achievement_type VARCHAR(50) NOT NULL CHECK (achievement_type IN ('monthly_best', 'most_sightings', 'best_rating', 'milestone_tours')),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    date_awarded DATE NOT NULL,
    icon_url TEXT,
    guide_id UUID NOT NULL REFERENCES tour_guides(tourguide_id) ON DELETE CASCADE
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_user_type ON users(user_type);
CREATE INDEX idx_tourists_user_id ON tourists(user_id);
CREATE INDEX idx_tour_guides_user_id ON tour_guides(user_id);
CREATE INDEX idx_tour_guides_park_id ON tour_guides(park_id);
CREATE INDEX idx_locations_park_id ON locations(park_id);
CREATE INDEX idx_locations_coordinates ON locations USING GIST(coordinates);
CREATE INDEX idx_parks_boundary ON parks USING GIST(geofence_boundary);
CREATE INDEX idx_animals_name ON animals(name);
CREATE INDEX idx_sightings_animal_id ON sightings(animal_id);
CREATE INDEX idx_sightings_location_id ON sightings(location_id);
CREATE INDEX idx_sightings_timestamp ON sightings(timestamp DESC);
CREATE INDEX idx_tour_sessions_tourguide_id ON tour_sessions(tourguide_id);
CREATE INDEX idx_tour_sessions_status ON tour_sessions(status);
CREATE INDEX idx_tour_sessions_scheduled_start ON tour_sessions(scheduled_start);
CREATE INDEX idx_tour_participants_tourist_id ON tour_participants(tourist_id);
CREATE INDEX idx_visitor_flow_location_id ON visitor_flow(location_id);
CREATE INDEX idx_visitor_flow_arrival_time ON visitor_flow(arrival_time DESC);
CREATE INDEX idx_congestion_predictions_location_date ON congestion_predictions(location_id, predicted_date);
CREATE INDEX idx_notifications_user_id ON notifications(user_id, is_read);
CREATE INDEX idx_sync_queue_user_id ON sync_queue(user_id);
CREATE INDEX idx_sync_queue_status ON sync_queue(status);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX idx_feedback_tourist_id ON feedback(tourist_id);
CREATE INDEX idx_feedback_tourguide_id ON feedback(tourguide_id);
CREATE INDEX idx_tour_recommendations_tourist_id ON tour_recommendations(tourist_id);
CREATE INDEX idx_tour_recommendations_route_id ON tour_recommendations(route_id);
CREATE INDEX idx_ai_query_logs_tourist_id ON ai_query_logs(tourist_id);
CREATE INDEX idx_ai_query_logs_timestamp ON ai_query_logs(timestamp DESC);
CREATE INDEX idx_tourist_progress_tourist_id ON tourist_progress(tourist_id);
CREATE INDEX idx_tourist_progress_content_id ON tourist_progress(content_id);
CREATE INDEX idx_navigation_paths_location_id ON navigation_paths(location_id);
CREATE INDEX idx_navigation_paths_geometry ON navigation_paths USING GIST(path_geometry);
CREATE INDEX idx_tour_routes_path ON tour_routes USING GIST(path_geometry);
CREATE INDEX idx_route_locations_route_id ON route_locations(route_id);
CREATE INDEX idx_route_locations_location_id ON route_locations(location_id);
CREATE INDEX idx_cultural_narratives_community ON cultural_narratives(community);
CREATE INDEX idx_cultural_narratives_user_id ON cultural_narratives(user_id);
CREATE INDEX idx_content_updates_table_record ON content_updates(table_name, record_id);
CREATE INDEX idx_guide_shifts_tourguide_id ON guide_shifts(tourguide_id);
CREATE INDEX idx_guide_shifts_shift_date ON guide_shifts(shift_date);

-- =====================================================
-- DEFERRED FOREIGN KEYS (DEPENDENT TABLES DEFINED LATER)
-- =====================================================
ALTER TABLE tour_guides
    ADD CONSTRAINT fk_tour_guides_park
    FOREIGN KEY (park_id) REFERENCES parks(park_id) ON DELETE SET NULL;

ALTER TABLE sightings
    ADD CONSTRAINT fk_sightings_tour_session
    FOREIGN KEY (toursession_id) REFERENCES tour_sessions(tour_session_id) ON DELETE SET NULL;

ALTER TABLE sightings
    ADD CONSTRAINT fk_sightings_tour_guide
    FOREIGN KEY (tourguide_id) REFERENCES tour_guides(tourguide_id) ON DELETE SET NULL;

ALTER TABLE sightings
    ADD CONSTRAINT fk_sightings_tourist
    FOREIGN KEY (tourist_id) REFERENCES tourists(tourist_id) ON DELETE SET NULL;
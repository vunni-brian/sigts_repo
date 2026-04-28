-- =====================================================
-- SEED DATA: PARKS TABLE
-- Bwindi Impenetrable National Park
-- =====================================================

-- Insert Bwindi Park data
INSERT INTO parks (park_id, name, description, geofence_boundary, intranet_server_ip, established_date, area_sqkm, entrance_fee, opening_time, closing_time, emergency_phone, image_url, intranet_subnet)
VALUES (
    gen_random_uuid(),
    'Bwindi Impenetrable National Park',
    'Bwindi Impenetrable National Park is a UNESCO World Heritage Site located in southwestern Uganda. It is renowned for its exceptional biodiversity, including over 120 mammal species, 350 bird species, and half of the world''s mountain gorilla population. The park spans 331 square kilometers of dense forest and mountainous terrain.',
    ST_GeomFromText('POLYGON((29.6 -1.0, 29.8 -1.0, 29.8 -1.2, 29.6 -1.2, 29.6 -1.0))', 4326),
    '192.168.100.10',
    '1991-01-01',
    331.00,
    '{"foreign_adult": 50, "foreign_child": 30, "east_african": 20000, "citizen": 5000}',
    '06:00:00',
    '19:00:00',
    '+256-78-XXX-XXXX',
    '/images/bwindi-park.jpg',
    '192.168.100.0/24'
);
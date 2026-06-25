-- =============================================================================
-- Flight Radar RDS PostgreSQL - Schema Initialization
-- Lab schema for DMS data migration testing
-- Run: psql -h <endpoint> -U <user> -d flightradar -f init_schema.sql
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS flight_radar;
SET search_path TO flight_radar;

-- Aircraft registry dimension
CREATE TABLE IF NOT EXISTS flight_radar.aircraft (
    icao24          VARCHAR(6) PRIMARY KEY,
    registration    VARCHAR(20),
    aircraft_type   VARCHAR(10),
    manufacturer    VARCHAR(50),
    model           VARCHAR(50),
    serial_number   VARCHAR(30),
    operator_icao   VARCHAR(3),
    operator_name   VARCHAR(100),
    first_flight_date DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Airport dimension
CREATE TABLE IF NOT EXISTS flight_radar.airports (
    icao_code   VARCHAR(4) PRIMARY KEY,
    iata_code   VARCHAR(3),
    name        VARCHAR(200),
    city        VARCHAR(100),
    country     VARCHAR(100),
    country_code VARCHAR(2),
    latitude    DECIMAL(10,7),
    longitude   DECIMAL(10,7),
    elevation_ft INTEGER,
    timezone    VARCHAR(50),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Airline dimension
CREATE TABLE IF NOT EXISTS flight_radar.airlines (
    icao_code   VARCHAR(3) PRIMARY KEY,
    iata_code   VARCHAR(2),
    name        VARCHAR(200),
    country     VARCHAR(100),
    callsign    VARCHAR(50),
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Flight schedule / instance fact
CREATE TABLE IF NOT EXISTS flight_radar.flights (
    flight_id           BIGSERIAL PRIMARY KEY,
    flight_number       VARCHAR(10),
    airline_icao        VARCHAR(3) REFERENCES flight_radar.airlines(icao_code),
    aircraft_icao24     VARCHAR(6) REFERENCES flight_radar.aircraft(icao24),
    origin_airport      VARCHAR(4) REFERENCES flight_radar.airports(icao_code),
    destination_airport VARCHAR(4) REFERENCES flight_radar.airports(icao_code),
    scheduled_departure TIMESTAMPTZ,
    scheduled_arrival   TIMESTAMPTZ,
    actual_departure    TIMESTAMPTZ,
    actual_arrival      TIMESTAMPTZ,
    status              VARCHAR(20) NOT NULL DEFAULT 'scheduled',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_status CHECK (status IN ('scheduled','active','landed','cancelled','diverted'))
);

-- High-volume position fact (mimics streaming data)
CREATE TABLE IF NOT EXISTS flight_radar.aircraft_positions (
    position_id     BIGSERIAL PRIMARY KEY,
    aircraft_icao24 VARCHAR(6) NOT NULL REFERENCES flight_radar.aircraft(icao24),
    flight_id       BIGINT REFERENCES flight_radar.flights(flight_id),
    latitude        DECIMAL(10,7),
    longitude       DECIMAL(10,7),
    altitude_ft     INTEGER,
    velocity_kts    DECIMAL(7,2),
    heading         DECIMAL(5,2),
    vertical_rate_fpm DECIMAL(7,2),
    on_ground       BOOLEAN,
    recorded_at     TIMESTAMPTZ NOT NULL,
    ingested_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for query performance
CREATE INDEX IF NOT EXISTS idx_positions_aircraft    ON flight_radar.aircraft_positions(aircraft_icao24);
CREATE INDEX IF NOT EXISTS idx_positions_recorded    ON flight_radar.aircraft_positions(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_flights_status        ON flight_radar.flights(status);
CREATE INDEX IF NOT EXISTS idx_flights_aircraft      ON flight_radar.flights(aircraft_icao24);
CREATE INDEX IF NOT EXISTS idx_flights_airline       ON flight_radar.flights(airline_icao);
CREATE INDEX IF NOT EXISTS idx_flights_origin        ON flight_radar.flights(origin_airport);
CREATE INDEX IF NOT EXISTS idx_flights_destination   ON flight_radar.flights(destination_airport);

-- =============================================================================
-- Sample seed data for lab testing
-- =============================================================================

INSERT INTO flight_radar.aircraft (icao24, registration, aircraft_type, manufacturer, model, operator_icao, operator_name) VALUES
    ('a0f1b2', 'N12345', 'B738', 'Boeing', '737-800', 'AAL', 'American Airlines'),
    ('a1b2c3', 'D-ABYT', 'A320', 'Airbus', 'A320-200', 'DLH', 'Lufthansa'),
    ('b2c3d4', 'EC-MQU', 'A333', 'Airbus', 'A330-300', 'VLG', 'Vueling Airlines'),
    ('c3d4e5', 'G-EUUK', 'A320', 'Airbus', 'A320-200', 'BAW', 'British Airways'),
    ('d4e5f6', 'N67890', 'B77W', 'Boeing', '777-300ER', 'DAL', 'Delta Air Lines')
ON CONFLICT (icao24) DO NOTHING;

INSERT INTO flight_radar.airports (icao_code, iata_code, name, city, country, country_code, latitude, longitude, timezone) VALUES
    ('KJFK', 'JFK', 'John F Kennedy International Airport', 'New York', 'United States', 'US', 40.639801, -73.778900, 'America/New_York'),
    ('EGLL', 'LHR', 'London Heathrow Airport', 'London', 'United Kingdom', 'GB', 51.477500, -0.461389, 'Europe/London'),
    ('LFPG', 'CDG', 'Paris Charles de Gaulle Airport', 'Paris', 'France', 'FR', 49.012798, 2.550000, 'Europe/Paris'),
    ('EDDF', 'FRA', 'Frankfurt am Main Airport', 'Frankfurt', 'Germany', 'DE', 50.033333, 8.570556, 'Europe/Berlin'),
    ('SBGR', 'GRU', 'São Paulo/Guarulhos International Airport', 'São Paulo', 'Brazil', 'BR', -23.435556, -46.473056, 'America/Sao_Paulo')
ON CONFLICT (icao_code) DO NOTHING;

INSERT INTO flight_radar.airlines (icao_code, iata_code, name, country, callsign) VALUES
    ('AAL', 'AA', 'American Airlines', 'United States', 'AMERICAN'),
    ('DAL', 'DL', 'Delta Air Lines', 'United States', 'DELTA'),
    ('UAL', 'UA', 'United Airlines', 'United States', 'UNITED'),
    ('BAW', 'BA', 'British Airways', 'United Kingdom', 'SPEEDBIRD'),
    ('DLH', 'LH', 'Lufthansa', 'Germany', 'LUFTHANSA'),
    ('XXX', 'AA', 'American Airlines', 'United States', 'AMERICAN')
ON CONFLICT (icao_code) DO NOTHING;

INSERT INTO flight_radar.flights (flight_number, airline_icao, aircraft_icao24, origin_airport, destination_airport, scheduled_departure, scheduled_arrival, status) VALUES
    ('AA100', 'AAL', 'a0f1b2', 'KJFK', 'EGLL', NOW() + INTERVAL '2 hours', NOW() + INTERVAL '9 hours', 'scheduled'),
    ('BA200', 'BAW', 'c3d4e5', 'EGLL', 'LFPG', NOW() + INTERVAL '1 hour', NOW() + INTERVAL '2 hours', 'scheduled'),
    ('DLH300', 'DLH', 'a1b2c3', 'EDDF', 'SBGR', NOW() + INTERVAL '4 hours', NOW() + INTERVAL '14 hours', 'scheduled'),
    ('DL400', 'DAL', 'd4e5f6', 'KJFK', 'LFPG', NOW() - INTERVAL '2 hours', NOW() + INTERVAL '5 hours', 'active'),
    ('BA500', 'BAW', 'c3d4e5', 'LFPG', 'EGLL', NOW() - INTERVAL '4 hours', NOW() - INTERVAL '3 hours', 'landed')
ON CONFLICT DO NOTHING;

INSERT INTO flight_radar.aircraft_positions (aircraft_icao24, flight_id, latitude, longitude, altitude_ft, velocity_kts, heading, vertical_rate_fpm, on_ground, recorded_at) VALUES
    -- DL400 (Delta, d4e5f6 / B77W) - JFK→CDG, voo ativo, cruising over Atlantic at 37000ft
    ('d4e5f6', (SELECT flight_id FROM flight_radar.flights WHERE flight_number = 'DL400'), 42.5000000, -50.0000000, 37000, 485, 75, 0, FALSE, NOW() - INTERVAL '1 hour'),
    ('d4e5f6', (SELECT flight_id FROM flight_radar.flights WHERE flight_number = 'DL400'), 44.2000000, -40.0000000, 37000, 490, 78, 0, FALSE, NOW() - INTERVAL '45 minutes'),
    ('d4e5f6', (SELECT flight_id FROM flight_radar.flights WHERE flight_number = 'DL400'), 46.1000000, -30.0000000, 37000, 488, 80, 0, FALSE, NOW() - INTERVAL '30 minutes'),
    ('d4e5f6', (SELECT flight_id FROM flight_radar.flights WHERE flight_number = 'DL400'), 47.8000000, -20.0000000, 37000, 492, 82, 0, FALSE, NOW() - INTERVAL '15 minutes'),
    -- climbing out of JFK (departed 2h ago)
    ('d4e5f6', (SELECT flight_id FROM flight_radar.flights WHERE flight_number = 'DL400'), 40.6398010, -73.7789000, 150, 180, 145, 1200, TRUE, NOW() - INTERVAL '2 hours'),
    ('d4e5f6', (SELECT flight_id FROM flight_radar.flights WHERE flight_number = 'DL400'), 41.0000000, -72.5000000, 8500, 250, 90, 1800, FALSE, NOW() - INTERVAL '1 hour 50 minutes'),
    ('c3d4e5', (SELECT flight_id FROM flight_radar.flights WHERE flight_number = 'BA500'), 51.4775000, -0.4613890, 0, 0, 270, 0, TRUE, NOW() - INTERVAL '2 hours'),
    ('c3d4e5', (SELECT flight_id FROM flight_radar.flights WHERE flight_number = 'BA500'), 51.4775000, -0.4613890, 0, 0, 270, 0, TRUE, NOW() - INTERVAL '1 hour'),

    -- AA100 (American, a0f1b2 / B738) - JFK→LHR, scheduled, pushing back from gate
    ('a0f1b2', (SELECT flight_id FROM flight_radar.flights WHERE flight_number = 'AA100'), 40.6398010, -73.7789000, 0, 0, 90, 0, TRUE, NOW() + INTERVAL '10 minutes'),
    ('a0f1b2', (SELECT flight_id FROM flight_radar.flights WHERE flight_number = 'AA100'), 40.6398010, -73.7789000, 0, 0, 90, 0, TRUE, NOW() + INTERVAL '15 minutes'),

    -- BA200 (British Airways, c3d4e5 / A320) - LHR→CDG, scheduled, taxiing
    ('c3d4e5', (SELECT flight_id FROM flight_radar.flights WHERE flight_number = 'BA200'), 51.4775000, -0.4613890, 0, 15, 210, 0, TRUE, NOW() + INTERVAL '30 minutes'),
    ('c3d4e5', (SELECT flight_id FROM flight_radar.flights WHERE flight_number = 'BA200'), 51.4775000, -0.4613890, 0, 5, 180, 0, TRUE, NOW() + INTERVAL '40 minutes'),

    -- DLH300 (Lufthansa, a1b2c3 / A320) - FRA→GRU, scheduled long haul, at gate
    ('a1b2c3', (SELECT flight_id FROM flight_radar.flights WHERE flight_number = 'DLH300'), 50.0333330, 8.5705560, 0, 0, 220, 0, TRUE, NOW() + INTERVAL '3 hours'),
    ('a1b2c3', (SELECT flight_id FROM flight_radar.flights WHERE flight_number = 'DLH300'), 50.0333330, 8.5705560, 0, 0, 220, 0, TRUE, NOW() + INTERVAL '3 hours 30 minutes')
ON CONFLICT DO NOTHING;

-- =============================================================================
-- DMS (Database Migration Service) — Logical Replication Prerequisites
-- O DMS usa o plugin pglogical para captura CDC. Estes comandos preparam
-- o banco para que o DMS possa se conectar e criar seu próprio slot de
-- replicação automaticamente.
-- =============================================================================

-- 1. Cria a extensão pglogical (necessário shared_preload_libraries='pglogical'
--    no parameter group do RDS — já configurado via Terraform).
--    Se falhar com "pglogical is not in shared_preload_libraries", verifique
--    o parameter group e aplique com reboot.
CREATE EXTENSION IF NOT EXISTS pglogical;

-- 2. Garante que o dbadmin tenha o privilégio rds_replication.
--    Necessário para que o DMS crie/gerencie slots de replicação lógica.
GRANT rds_replication TO dbadmin;

-- 3. Cria o pglogical node (necessário para o DMS 3.5.x iniciar o CDC).
--    O DMS 3.6.1+ pode criar o node automaticamente, mas a criação manual
--    é uma salvaguarda. Substitua <rds-endpoint> pelo endpoint do RDS.
--    Este comando DEVE ser executado APÓS o RDS estar acessível e a extensão
--    pglogical instalada.
--
--    SELECT pglogical.create_node(
--        node_name := 'dms_replication_node',
--        dsn       := 'host=<rds-endpoint> port=5432 dbname=flightradar user=dbadmin sslmode=require'
--    );
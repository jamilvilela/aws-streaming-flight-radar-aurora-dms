-- =============================================================================
-- Flight Radar — Consultas SQL
-- Laboratório de migração DMS com dados dos datasets OpenFlights + OurAirports
--
-- Uso:  psql -h <host> -U dbadmin -d flightradar -f sql-consultas.sql
--       ou execute os blocos individualmente no seu query tool favorito.
-- =============================================================================

SET search_path TO flight_radar;

-- #############################################################################
-- 1.  VISÃO GERAL — ESTATÍSTICAS DO BANCO
-- #############################################################################

-- 1.1  Volume de dados por tabela (linhas e tamanho em disco)
SELECT * FROM flight_radar.fn_data_volume_stats();

-- 1.2  Partições de aircraft_positions existentes
SELECT
    relname                                 AS partition_name,
    pg_size_pretty(pg_total_relation_size(oid)) AS total_size,
    n_live_tup                              AS estimated_rows,
    TO_CHAR((INSTR('_', relname) IS NOT NULL)::int, 'FM999') AS dummy
FROM pg_class
WHERE relname LIKE 'aircraft_positions_%'
  AND relkind = 'r'
ORDER BY relname;

-- 1.3  Contagem rápida de todas as tabelas de referência
SELECT 'countries'          AS tabela, COUNT(*) FROM flight_radar.countries
UNION ALL
SELECT 'aircraft_types'     AS tabela, COUNT(*) FROM flight_radar.aircraft_types
UNION ALL
SELECT 'airports'           AS tabela, COUNT(*) FROM flight_radar.airports
UNION ALL
SELECT 'airlines'           AS tabela, COUNT(*) FROM flight_radar.airlines
UNION ALL
SELECT 'routes'             AS tabela, COUNT(*) FROM flight_radar.routes
UNION ALL
SELECT 'aircraft'           AS tabela, COUNT(*) FROM flight_radar.aircraft
UNION ALL
SELECT 'flights'            AS tabela, COUNT(*) FROM flight_radar.flights
UNION ALL
SELECT 'aircraft_positions' AS tabela, COUNT(*) FROM flight_radar.aircraft_positions
ORDER BY 2 DESC;


-- #############################################################################
-- 2.  CONSULTAS EM TABELAS DE REFERÊNCIA (DIMENSIONS)
-- #############################################################################

-- 2.1  Países: todos ordenados por continente
SELECT code, name, continent
FROM flight_radar.countries
ORDER BY continent, name;

-- 2.2  Tipos de aeronave por fabricante
SELECT
    manufacturer,
    COUNT(*)                                   AS qtd_modelos,
    STRING_AGG(icao_code, ', ' ORDER BY name)  AS codigos
FROM flight_radar.aircraft_types
GROUP BY manufacturer
ORDER BY qtd_modelos DESC;

-- 2.3  Fabricantes com mais modelos
SELECT manufacturer, COUNT(*) AS qtd
FROM flight_radar.aircraft_types
GROUP BY manufacturer
ORDER BY qtd DESC
LIMIT 15;

-- 2.4  Aeroportos: scheduled_service por país (top 20)
SELECT
    c.name                              AS pais,
    COUNT(*) FILTER (WHERE a.scheduled_service) AS com_voos_regulares,
    COUNT(*)                            AS total,
    ROUND(100.0 * COUNT(*) FILTER (WHERE a.scheduled_service) / COUNT(*), 1) AS perc_regular
FROM flight_radar.airports a
JOIN flight_radar.countries c ON c.code = a.iso_country
GROUP BY c.name
HAVING COUNT(*) > 50
ORDER BY com_voos_regulares DESC
LIMIT 20;

-- 2.5  Aeroportos tipo "large_airport" por país
SELECT
    c.name AS pais,
    COUNT(*) AS grandes_aeroportos
FROM flight_radar.airports a
JOIN flight_radar.countries c ON c.code = a.iso_country
WHERE a.type = 'large_airport'
GROUP BY c.name
ORDER BY grandes_aeroportos DESC
LIMIT 15;

-- 2.6  Aeroporto específico (ex: Guarulhos)
SELECT *
FROM flight_radar.airports
WHERE municipality ILIKE '%guarulhos%'
   OR municipality ILIKE '%sao paulo%'
   OR icao_code = 'SBGR';

-- 2.7  Buscar aeroporto por código ICAO ou IATA
SELECT *
FROM flight_radar.airports
WHERE icao_code = 'SBGR' OR iata_code = 'GRU';

-- 2.8  Companhias aéreas ativas
SELECT icao_code, iata_code, name, country, callsign
FROM flight_radar.airlines
WHERE is_active = TRUE
ORDER BY country, name;

-- 2.9  Companhias de um país específico (ex: Brasil)
SELECT icao_code, iata_code, name, callsign, is_active
FROM flight_radar.airlines
WHERE country ILIKE '%Brazil%'
ORDER BY is_active DESC, name;

-- 2.10 Rotas de uma companhia (ex: LATAM = TAM)
SELECT
    r.id,
    al.name                                  AS companhia,
    org.name                                 AS origem,
    org.iata_code                            AS origem_iata,
    dst.name                                 AS destino,
    dst.iata_code                            AS destino_iata,
    r.stops,
    r.duration_minutes,
    r.equipment
FROM flight_radar.routes r
JOIN flight_radar.airlines al ON al.id = r.airline_id
JOIN flight_radar.airports org ON org.id = r.src_airport_id
JOIN flight_radar.airports dst ON dst.id = r.dst_airport_id
WHERE al.icao_code = 'TAM'
ORDER BY r.duration_minutes DESC NULLS LAST;

-- 2.11 Rotas entre dois aeroportos específicos
SELECT
    al.name AS companhia,
    r.flight_number,
    r.duration_minutes,
    r.equipment
FROM flight_radar.routes r
JOIN flight_radar.airlines al ON al.id = r.airline_id
WHERE r.src_airport = 'GRU' AND r.dst_airport = 'JFK'
ORDER BY r.duration_minutes;


-- #############################################################################
-- 3.  CONSULTAS EM TABELAS GERADAS (FACTS)
-- #############################################################################

-- 3.1  Aeronaves por operador
SELECT
    al.name AS operador,
    COUNT(*) AS frota
FROM flight_radar.aircraft ac
JOIN flight_radar.airlines al ON al.icao_code = ac.operator_icao
GROUP BY al.name
ORDER BY frota DESC
LIMIT 20;

-- 3.2  Aeronaves de um tipo específico (ex: Boeing 777)
SELECT
    icao24,
    registration,
    ac.aircraft_type,
    aty.name AS modelo,
    ac.operator_icao,
    ac.year_built
FROM flight_radar.aircraft ac
JOIN flight_radar.aircraft_types aty ON aty.icao_code = ac.aircraft_type
WHERE aty.manufacturer ILIKE '%Boeing%'
  AND ac.aircraft_type LIKE 'B77%'
ORDER BY ac.year_built DESC
LIMIT 20;

-- 3.3  Voos ativos no momento (status = 'active')
SELECT
    f.flight_number,
    al.name                                  AS companhia,
    org.iata_code                            AS origem,
    dst.iata_code                            AS destino,
    f.scheduled_departure,
    f.scheduled_arrival,
    f.actual_departure,
    aty.name                                 AS aeronave,
    ac.registration
FROM flight_radar.flights f
JOIN flight_radar.airlines al ON al.icao_code = f.airline_icao
JOIN flight_radar.airports org ON org.icao_code = f.origin_airport
JOIN flight_radar.airports dst ON dst.icao_code = f.destination_airport
JOIN flight_radar.aircraft ac ON ac.icao24 = f.aircraft_icao24
JOIN flight_radar.aircraft_types aty ON aty.icao_code = ac.aircraft_type
WHERE f.status = 'active'
ORDER BY f.scheduled_departure;

-- 3.4  Últimos voos realizados (landed) — últimos 100
SELECT
    f.flight_id,
    f.flight_number,
    al.name                    AS companhia,
    org.iata_code              AS origem,
    dst.iata_code              AS destino,
    f.actual_departure,
    f.actual_arrival,
    aty.name                   AS aeronave
FROM flight_radar.flights f
JOIN flight_radar.airlines al ON al.icao_code = f.airline_icao
JOIN flight_radar.airports org ON org.icao_code = f.origin_airport
JOIN flight_radar.airports dst ON dst.icao_code = f.destination_airport
JOIN flight_radar.aircraft ac ON ac.icao24 = f.aircraft_icao24
JOIN flight_radar.aircraft_types aty ON aty.icao_code = ac.aircraft_type
WHERE f.status = 'landed'
ORDER BY f.actual_arrival DESC
LIMIT 100;

-- 3.5  Voos cancelados ou desviados nas últimas 24h
SELECT
    f.flight_number,
    f.status,
    al.name         AS companhia,
    org.iata_code   AS origem,
    dst.iata_code   AS destino,
    f.scheduled_departure,
    f.scheduled_arrival
FROM flight_radar.flights f
JOIN flight_radar.airlines al ON al.icao_code = f.airline_icao
JOIN flight_radar.airports org ON org.icao_code = f.origin_airport
JOIN flight_radar.airports dst ON dst.icao_code = f.destination_airport
WHERE f.status IN ('cancelled', 'diverted')
  AND f.scheduled_departure > NOW() - INTERVAL '24 hours'
ORDER BY f.scheduled_departure DESC;

-- 3.6  Voos de uma aeronave específica (por ICAO24)
SELECT
    f.flight_id,
    f.flight_number,
    f.status,
    org.iata_code AS origem,
    dst.iata_code AS destino,
    f.scheduled_departure,
    f.actual_departure,
    f.actual_arrival
FROM flight_radar.flights f
JOIN flight_radar.airports org ON org.icao_code = f.origin_airport
JOIN flight_radar.airports dst ON dst.icao_code = f.destination_airport
WHERE f.aircraft_icao24 = 'a0f1b2'
ORDER BY f.scheduled_departure DESC
LIMIT 50;

-- 3.7  Voos entre duas datas específicas
SELECT
    f.flight_id,
    f.flight_number,
    al.name        AS companhia,
    org.iata_code  AS origem,
    dst.iata_code  AS destino,
    f.status,
    f.scheduled_departure,
    f.scheduled_arrival
FROM flight_radar.flights f
JOIN flight_radar.airlines al ON al.icao_code = f.airline_icao
JOIN flight_radar.airports org ON org.icao_code = f.origin_airport
JOIN flight_radar.airports dst ON dst.icao_code = f.destination_airport
WHERE f.scheduled_departure >= '2026-06-01'
  AND f.scheduled_departure <  '2026-07-01'
ORDER BY f.scheduled_departure
LIMIT 200;


-- #############################################################################
-- 4.  CONSULTAS DE POSIÇÕES (TRACKING)
-- #############################################################################

-- 4.1  Posições mais recentes de todas as aeronaves (últimas 2h)
--      Usa a view v_latest_positions criada no schema
SELECT *
FROM flight_radar.v_latest_positions
ORDER BY recorded_at DESC
LIMIT 50;

-- 4.2  Trajetória completa de um voo específico
SELECT
    recorded_at,
    latitude,
    longitude,
    altitude_ft,
    velocity_kts,
    heading,
    vertical_rate_fpm,
    on_ground
FROM flight_radar.aircraft_positions
WHERE flight_id = 12345
ORDER BY recorded_at;

-- 4.3  Últimas posições de uma aeronave específica (por ICAO24)
SELECT
    recorded_at,
    latitude,
    longitude,
    altitude_ft,
    velocity_kts,
    heading,
    on_ground
FROM flight_radar.aircraft_positions
WHERE aircraft_icao24 = 'a0f1b2'
ORDER BY recorded_at DESC
LIMIT 100;

-- 4.4  Aeronaves voando acima de 30.000 pés agora (últimos 15 min)
SELECT DISTINCT ON (ap.aircraft_icao24)
    ap.aircraft_icao24,
    ap.altitude_ft,
    ap.velocity_kts,
    ap.heading,
    ap.latitude,
    ap.longitude,
    ap.recorded_at,
    f.flight_number,
    org.iata_code AS origem,
    dst.iata_code AS destino
FROM flight_radar.aircraft_positions ap
LEFT JOIN flight_radar.flights f ON f.flight_id = ap.flight_id
LEFT JOIN flight_radar.airports org ON org.icao_code = f.origin_airport
LEFT JOIN flight_radar.airports dst ON dst.icao_code = f.destination_airport
WHERE ap.altitude_ft > 30000
  AND ap.recorded_at > NOW() - INTERVAL '15 minutes'
ORDER BY ap.aircraft_icao24, ap.recorded_at DESC;

-- 4.5  Aeronaves em solo (on_ground = true) nos últimos 15 min
SELECT DISTINCT ON (ap.aircraft_icao24)
    ap.aircraft_icao24,
    ap.latitude,
    ap.longitude,
    ap.recorded_at,
    f.flight_number
FROM flight_radar.aircraft_positions ap
JOIN flight_radar.flights f ON f.flight_id = ap.flight_id
WHERE ap.on_ground = TRUE
  AND ap.recorded_at > NOW() - INTERVAL '15 minutes'
ORDER BY ap.aircraft_icao24, ap.recorded_at DESC
LIMIT 30;

-- 4.6  Posições em uma região geográfica (bounding box)
SELECT
    aircraft_icao24,
    recorded_at,
    latitude,
    longitude,
    altitude_ft,
    velocity_kts,
    heading
FROM flight_radar.aircraft_positions
WHERE latitude  BETWEEN -23.8 AND -23.3       -- Grande SP
  AND longitude BETWEEN -47.0 AND -46.0
  AND recorded_at > NOW() - INTERVAL '1 hour'
ORDER BY recorded_at DESC;

-- 4.7  Estatísticas de altitude e velocidade por voo
SELECT
    flight_id,
    COUNT(*)                                    AS posicoes,
    MIN(altitude_ft)                            AS alt_min,
    AVG(altitude_ft)::INT                       AS alt_media,
    MAX(altitude_ft)                            AS alt_max,
    MIN(velocity_kts)::INT                      AS vel_min,
    AVG(velocity_kts)::INT                      AS vel_media,
    MAX(velocity_kts)::INT                      AS vel_max,
    MIN(recorded_at)                            AS inicio,
    MAX(recorded_at)                            AS fim
FROM flight_radar.aircraft_positions
WHERE flight_id IS NOT NULL
GROUP BY flight_id
HAVING COUNT(*) > 10
ORDER BY flight_id DESC
LIMIT 50;


-- #############################################################################
-- 5.  CONSULTAS ANALÍTICAS
-- #############################################################################

-- 5.1  Rotas mais frequentes (top 20)
SELECT
    org.iata_code || ' → ' || dst.iata_code     AS rota,
    COUNT(*)                                     AS total_voos,
    COUNT(*) FILTER (WHERE f.status = 'cancelled') AS cancelados,
    ROUND(100.0 * COUNT(*) FILTER (WHERE f.status = 'cancelled') / COUNT(*), 2) AS perc_cancelamento
FROM flight_radar.flights f
JOIN flight_radar.airports org ON org.icao_code = f.origin_airport
JOIN flight_radar.airports dst ON dst.icao_code = f.destination_airport
GROUP BY org.iata_code, dst.iata_code
ORDER BY total_voos DESC
LIMIT 20;

-- 5.2  Companhias com mais voos
SELECT
    al.name                             AS companhia,
    COUNT(*)                            AS total_voos,
    COUNT(*) FILTER (WHERE f.status = 'landed')   AS realizados,
    COUNT(*) FILTER (WHERE f.status = 'cancelled') AS cancelados
FROM flight_radar.flights f
JOIN flight_radar.airlines al ON al.icao_code = f.airline_icao
GROUP BY al.name
ORDER BY total_voos DESC
LIMIT 20;

-- 5.3  Taxa de cancelamento por companhia
SELECT
    al.name,
    COUNT(*) AS total,
    ROUND(100.0 * COUNT(*) FILTER (WHERE f.status = 'cancelled') / GREATEST(COUNT(*), 1), 2) AS perc_cancelamento
FROM flight_radar.flights f
JOIN flight_radar.airlines al ON al.icao_code = f.airline_icao
GROUP BY al.name
HAVING COUNT(*) > 100
ORDER BY perc_cancelamento DESC
LIMIT 15;

-- 5.4  Atrasos médios por companhia
SELECT
    al.name                                                                  AS companhia,
    COUNT(*)                                                                 AS total_voos,
    ROUND(AVG(EXTRACT(EPOCH FROM (f.actual_departure - f.scheduled_departure)) / 60)::NUMERIC, 1) AS atraso_medio_partida_min,
    ROUND(AVG(EXTRACT(EPOCH FROM (f.actual_arrival   - f.scheduled_arrival))   / 60)::NUMERIC, 1) AS atraso_medio_chegada_min
FROM flight_radar.flights f
JOIN flight_radar.airlines al ON al.icao_code = f.airline_icao
WHERE f.actual_departure IS NOT NULL
  AND f.status = 'landed'
GROUP BY al.name
HAVING COUNT(*) > 50
ORDER BY atraso_medio_chegada_min DESC
LIMIT 15;

-- 5.5  Aeronaves mais utilizadas (por número de voos)
SELECT
    ac.registration,
    ac.aircraft_type,
    aty.name AS modelo,
    COUNT(*) AS voos_realizados
FROM flight_radar.flights f
JOIN flight_radar.aircraft ac ON ac.icao24 = f.aircraft_icao24
JOIN flight_radar.aircraft_types aty ON aty.icao_code = ac.aircraft_type
WHERE f.status = 'landed'
GROUP BY ac.registration, ac.aircraft_type, aty.name
ORDER BY voos_realizados DESC
LIMIT 20;

-- 5.6  Voos por hora do dia (distribuição horária)
SELECT
    EXTRACT(HOUR FROM scheduled_departure)::INT AS hora,
    COUNT(*)                                    AS qtd
FROM flight_radar.flights
GROUP BY hora
ORDER BY hora;

-- 5.7  Voos por dia da semana
SELECT
    TO_CHAR(scheduled_departure, 'Day') AS dia_semana,
    EXTRACT(DOW FROM scheduled_departure)::INT AS dow,
    COUNT(*)                            AS qtd
FROM flight_radar.flights
GROUP BY dia_semana, dow
ORDER BY dow;

-- 5.8  Volume de posições por mês (via partições)
SELECT
    SUBSTRING(c.relname FROM 'aircraft_positions_(\d{4}_\d{2})') AS mes,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS tamanho,
    COALESCE(s.n_live_tup, 0)              AS estimativa_linhas
FROM pg_class c
LEFT JOIN pg_stat_user_tables s ON s.relid = c.oid
WHERE c.relname LIKE 'aircraft_positions_%'
  AND c.relkind = 'r'
ORDER BY c.relname;


-- #############################################################################
-- 6.  CONSULTAS DMS / CDC — MONITORAMENTO DE REPLICAÇÃO
-- #############################################################################

-- 6.1  Verificar extensão pglogical instalada
SELECT * FROM pg_available_extensions
WHERE name = 'pglogical';

-- 6.2  Verificar slots de replicação ativos
SELECT
    slot_name,
    slot_type,
    database,
    active,
    restart_lsn,
    confirmed_flush_lsn
FROM pg_replication_slots
ORDER BY slot_name;

-- 6.3  Estatísticas de WAL gerado
SELECT
    slot_name,
    pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS wal_pendente_bytes
FROM pg_replication_slots
WHERE active = TRUE;

-- 6.4  Identificar linhas com metadados DMS (operações CDC)
SELECT
    dms_operation,
    COUNT(*)                                  AS qtd,
    MIN(dms_timestamp)                        AS primeiro,
    MAX(dms_timestamp)                        AS ultimo
FROM flight_radar.aircraft_positions
WHERE dms_operation IS NOT NULL
GROUP BY dms_operation
ORDER BY dms_operation;

-- 6.5  Últimas linhas replicadas pelo DMS (CDC)
SELECT
    position_id,
    aircraft_icao24,
    flight_id,
    latitude,
    longitude,
    dms_operation,
    dms_timestamp
FROM flight_radar.aircraft_positions
WHERE dms_operation IS NOT NULL
ORDER BY dms_timestamp DESC
LIMIT 50;

-- 6.6  Publicações pglogical existentes
SELECT * FROM pglogical.publication
ORDER BY pub_name;

-- 6.7  Subscription pglogical (no target)
SELECT * FROM pglogical.subscription
ORDER BY sub_name;


-- #############################################################################
-- 7.  MANUTENÇÃO E DIAGNÓSTICO
-- #############################################################################

-- 7.1  Conexões ativas no banco
SELECT
    pid,
    usename         AS usuario,
    application_name AS app,
    client_addr,
    state,
    query_start,
    NOW() - query_start AS tempo_execucao,
    LEFT(query, 120) AS query_resumida
FROM pg_stat_activity
WHERE datname = current_database()
  AND state != 'idle'
ORDER BY query_start;

-- 7.2  Transações abertas há mais tempo
SELECT
    pid,
    usename,
    NOW() - xact_start AS duracao,
    LEFT(query, 150)   AS query
FROM pg_stat_activity
WHERE state IN ('active', 'idle in transaction')
  AND xact_start IS NOT NULL
ORDER BY xact_start
LIMIT 20;

-- 7.3  Tabelas com mais dead tuples (precisam VACUUM)
SELECT
    schemaname,
    relname,
    n_live_tup,
    n_dead_tup,
    ROUND(100.0 * n_dead_tup / GREATEST(n_live_tup + n_dead_tup, 1), 1) AS perc_dead,
    last_autovacuum,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'flight_radar'
ORDER BY n_dead_tup DESC;

-- 7.4  Consultas mais lentas (pg_stat_statements)
SELECT
    queryid,
    ROUND(total_exec_time::NUMERIC, 1) AS total_ms,
    calls,
    ROUND(mean_exec_time::NUMERIC, 1)  AS media_ms,
    ROUND(max_exec_time::NUMERIC, 1)   AS max_ms,
    LEFT(query, 120) AS query
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat%'
ORDER BY total_exec_time DESC
LIMIT 20;

-- 7.5  Tamanho do banco
SELECT
    pg_size_pretty(pg_database_size(current_database())) AS tamanho_total;

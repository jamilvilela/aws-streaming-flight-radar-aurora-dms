"""
Repository Pattern — isolamento de operações no banco PostgreSQL.
"""

from __future__ import annotations

import logging
from contextlib import contextmanager
from typing import Any, Iterator, Optional

import psycopg2
import psycopg2.extras
from .config import DBConfig
from .models import PositionRow

logger = logging.getLogger("repository")


def _normalize_icao(value: str | None) -> str | None:
    """Converte 'N/A', '\\N', strings vazias ou None em None (NULL)."""
    if not value or value in ("N/A", "\\N"):
        return None
    return value


class DatabaseRepository:
    """Camada de acesso a dados. Isola todo SQL do resto da aplicação."""

    def __init__(self, cfg: DBConfig):
        self.cfg = cfg
        self.conn: Optional[psycopg2.extensions.connection] = None

    # ── Conexão ──────────────────────────────────────────────────────────

    def connect(self) -> None:
        logger.info(
            "Conectando ao RDS: %s:%s/%s ...",
            self.cfg.host, self.cfg.port, self.cfg.dbname,
        )
        self.conn = psycopg2.connect(self.cfg.dsn)
        self.conn.autocommit = True
        with self.conn.cursor() as cur:
            cur.execute("SET search_path TO flight_radar;")
        logger.info("Conectado!")

    def close(self) -> None:
        if self.conn:
            self.conn.close()
            self.conn = None

    @contextmanager
    def transaction(self) -> Iterator[psycopg2.extras.RealDictCursor]:
        """Context manager para transação com commit/rollback."""
        if self.conn is None:
            raise RuntimeError("Repositório não conectado. Chame .connect() primeiro.")
        conn = self.conn
        old_autocommit = conn.autocommit
        conn.autocommit = False
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("SET search_path TO flight_radar;")
        try:
            yield cur
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.autocommit = old_autocommit
            cur.close()

    def cursor(self) -> psycopg2.extras.RealDictCursor:
        """Cria cursor autocommit."""
        if self.conn is None:
            raise RuntimeError("Repositório não conectado.")
        cur = self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("SET search_path TO flight_radar;")
        return cur

    # ── Referências ──────────────────────────────────────────────────────

    def insert_countries(self, rows: list[dict]) -> int:
        with self.transaction() as cur:
            psycopg2.extras.execute_values(
                cur,
                "INSERT INTO countries (id, code, name, continent, wikipedia_link) "
                "VALUES %s ON CONFLICT (id) DO NOTHING",
                [(
                    r["id"], r["code"], r["name"],
                    r.get("continent"), r.get("wikipedia_link"),
                ) for r in rows],
                template="(%s, %s, %s, %s::varchar, %s::text)",
            )
        return len(rows)

    def insert_aircraft_types(self, rows: list[dict]) -> int:
        with self.transaction() as cur:
            psycopg2.extras.execute_values(
                cur,
                "INSERT INTO aircraft_types (icao_code, iata_code, name) "
                "VALUES %s ON CONFLICT (icao_code) DO NOTHING",
                [(
                    r.get("icao_code"), r.get("iata_code"), r["name"],
                ) for r in rows if r.get("icao_code")],
                template="(%s, %s, %s)",
            )
        return len(rows)

    def insert_airports(self, rows: list[dict]) -> int:
        with self.transaction() as cur:
            psycopg2.extras.execute_values(
                cur,
                """
                INSERT INTO airports
                    (id, ident, type, name, latitude_deg, longitude_deg,
                     elevation_ft, continent, iso_country, iso_region,
                     municipality, scheduled_service,
                     icao_code, iata_code, gps_code, local_code)
                VALUES %s
                ON CONFLICT (id) DO UPDATE SET
                    name = EXCLUDED.name,
                    scheduled_service = EXCLUDED.scheduled_service
                """,
                [(
                    r["id"], r.get("ident"), r.get("type"), r["name"],
                    r.get("latitude_deg"), r.get("longitude_deg"),
                    r.get("elevation_ft"), r.get("continent"),
                    r.get("iso_country"), r.get("iso_region"),
                    r.get("municipality"), r.get("scheduled_service", False),
                    r.get("icao_code"), r.get("iata_code"),
                    r.get("gps_code"), r.get("local_code"),
                ) for r in rows],
                template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
            )
        return len(rows)

    def insert_airlines(self, rows: list[dict]) -> int:
        with self.transaction() as cur:
            psycopg2.extras.execute_values(
                cur,
                """
                INSERT INTO airlines
                    (id, name, alias, iata_code, icao_code, callsign, country, is_active)
                VALUES %s
                ON CONFLICT (id) DO UPDATE SET
                    name = EXCLUDED.name,
                    is_active = EXCLUDED.is_active
                """,
                [(
                    r["id"], r["name"], r.get("alias"),
                    r.get("iata_code"),
                    # Converte "N/A" ou strings vazias em None (NULL)
                    # para não violar a UNIQUE constraint de icao_code
                    _normalize_icao(r.get("icao_code")),
                    r.get("callsign"), r.get("country"),
                    r.get("is_active", False),
                ) for r in rows],
                template="(%s, %s, %s, %s, %s, %s, %s, %s)",
            )
        return len(rows)

    def insert_routes(self, rows: list[dict]) -> int:
        with self.transaction() as cur:
            psycopg2.extras.execute_values(
                cur,
                """
                INSERT INTO routes
                    (airline_iata, airline_id, src_airport, src_airport_id,
                     dst_airport, dst_airport_id, codeshare, stops, equipment)
                VALUES %s
                ON CONFLICT (id) DO NOTHING
                """,
                [(
                    r.get("airline_iata"), r.get("airline_id"),
                    r.get("src_airport"), r.get("src_airport_id"),
                    r.get("dst_airport"), r.get("dst_airport_id"),
                    r.get("codeshare"), r.get("stops", 0),
                    r.get("equipment"),
                ) for r in rows],
                template="(%s, %s, %s, %s, %s, %s, %s, %s, %s)",
            )
        return len(rows)

    # ── Dados gerados ────────────────────────────────────────────────────

    def insert_aircraft_batch(self, rows: list[dict]) -> int:
        with self.transaction() as cur:
            psycopg2.extras.execute_values(
                cur,
                """
                INSERT INTO aircraft
                    (icao24, registration, aircraft_type, serial_number,
                     operator_icao, operator_name, year_built)
                VALUES %s
                ON CONFLICT (icao24) DO NOTHING
                """,
                [(
                    r["icao24"], r["registration"], r["aircraft_type"],
                    r.get("serial_number"), r.get("operator_icao"),
                    r.get("operator_name"), r.get("year_built"),
                ) for r in rows],
                template="(%s, %s, %s, %s, %s, %s, %s::smallint)",
            )
        return len(rows)

    def insert_flight(self, cur: psycopg2.extras.RealDictCursor, row: dict) -> int:
        cur.execute(
            """
            INSERT INTO flights
                (flight_number, airline_icao, aircraft_icao24,
                 origin_airport, destination_airport,
                 scheduled_departure, scheduled_arrival,
                 actual_departure, actual_arrival, status)
            VALUES (%(flight_number)s, %(airline_icao)s, %(aircraft_icao24)s,
                    %(origin_airport)s, %(destination_airport)s,
                    %(scheduled_departure)s, %(scheduled_arrival)s,
                    %(actual_departure)s, %(actual_arrival)s, %(status)s)
            RETURNING flight_id
            """,
            row,
        )
        return cur.fetchone()["flight_id"]

    def insert_positions_batch(
        self, cur: psycopg2.extras.RealDictCursor, positions: list[PositionRow]
    ) -> int:
        if not positions:
            return 0
        psycopg2.extras.execute_values(
            cur,
            """
            INSERT INTO aircraft_positions
                (aircraft_icao24, flight_id, latitude, longitude,
                 altitude_ft, velocity_kts, heading, vertical_rate_fpm,
                 on_ground, recorded_at)
            VALUES %s
            """,
            [(
                p.aircraft_icao24, p.flight_id,
                p.latitude, p.longitude,
                p.altitude_ft, p.velocity_kts,
                p.heading, p.vertical_rate_fpm,
                p.on_ground, p.recorded_at,
            ) for p in positions],
            template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s::timestamptz)",
            page_size=1000,
        )
        return len(positions)

    def insert_positions_copy(
        self, positions: list[PositionRow]
    ) -> int:
        """
        Insert usando COPY (mais rápido que INSERT para grandes volumes).
        Usa StringIO para construir o buffer em memória.
        """
        import io

        if not positions:
            return 0

        buf = io.StringIO()
        for p in positions:
            buf.write(
                f"{p.aircraft_icao24}\t{p.flight_id}\t{p.latitude}\t{p.longitude}\t"
                f"{p.altitude_ft}\t{p.velocity_kts}\t{p.heading}\t{p.vertical_rate_fpm}\t"
                f"{'t' if p.on_ground else 'f'}\t{p.recorded_at.isoformat()}\n"
            )
        buf.seek(0)

        with self.transaction() as cur:
            cur.copy_from(
                buf,
                "aircraft_positions",
                columns=(
                    "aircraft_icao24", "flight_id", "latitude", "longitude",
                    "altitude_ft", "velocity_kts", "heading", "vertical_rate_fpm",
                    "on_ground", "recorded_at",
                ),
            )
        return len(positions)

    # ── Queries auxiliares ───────────────────────────────────────────────

    def get_icao_airport_map(self) -> dict[str, dict[str, Any]]:
        """Retorna mapa {icao_code: {lat, lon, iata_code}}."""
        with self.cursor() as cur:
            cur.execute(
                "SELECT icao_code, latitude_deg, longitude_deg, iata_code "
                "FROM airports WHERE icao_code IS NOT NULL"
            )
            return {
                r["icao_code"]: {
                    "lat": r["latitude_deg"],
                    "lon": r["longitude_deg"],
                    "iata_code": r["iata_code"],
                }
                for r in cur.fetchall()
            }

    def get_active_airline_icaos(self) -> list[str]:
        with self.cursor() as cur:
            cur.execute(
                "SELECT icao_code FROM airlines WHERE is_active = TRUE AND icao_code IS NOT NULL"
            )
            return [r["icao_code"] for r in cur.fetchall()]

    def get_aircraft_icao24s(self) -> list[str]:
        with self.cursor() as cur:
            cur.execute("SELECT icao24 FROM aircraft")
            return [r["icao24"] for r in cur.fetchall()]

    def get_active_flights_for_positions(
        self, limit: int = 50
    ) -> list[dict[str, Any]]:
        """Retorna voos ativos/scheduled que precisam de posições."""
        with self.cursor() as cur:
            cur.execute(
                """
                SELECT flight_id, aircraft_icao24, origin_airport, destination_airport,
                       actual_departure, actual_arrival, status
                FROM flights
                WHERE status IN ('active', 'scheduled')
                  AND actual_departure IS NOT NULL
                ORDER BY random()
                LIMIT %s
                """,
                (limit,),
            )
            return cur.fetchall()

    def get_route_count(self) -> int:
        with self.cursor() as cur:
            cur.execute("SELECT COUNT(*) AS cnt FROM routes")
            return cur.fetchone()["cnt"]

    def calculate_route_durations(self) -> None:
        """Calcula duration_minutes para rotas baseado nas coordenadas."""
        with self.transaction() as cur:
            cur.execute(
                """
                UPDATE routes r
                SET duration_minutes = (
                    SELECT ROUND(
                        (
                            haversine_km(a1.latitude_deg, a1.longitude_deg,
                                         a2.latitude_deg, a2.longitude_deg)
                            * 0.539957 / 450.0 + 0.5
                        ) * 60
                    )::INTEGER
                    FROM airports a1, airports a2
                    WHERE a1.id = r.src_airport_id
                      AND a2.id = r.dst_airport_id
                )
                WHERE duration_minutes IS NULL
                """
            )

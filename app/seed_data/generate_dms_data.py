#!/usr/bin/env python3
"""
Gera dados de teste no RDS PostgreSQL para o pipeline DMS.

Modos de uso:
  # Massa histórica — 12 meses de dados para full load
  python generate_dms_data.py historical --months 12

  # Streaming CDC — inserts/updates/deletes contínuos
  python generate_dms_data.py stream --interval 30 --duration 300

  # Atalho: gera 12 meses + já inicia stream
  python generate_dms_data.py all

Requer connect string via .env (na raiz do projeto) ou env vars:
  DB_HOST=<aurora_endpoint>
  DB_PORT=5432
  DB_NAME=flightradar
  DB_USER=dbadmin
  DB_PASSWORD=<password>
"""

from __future__ import annotations

import argparse
import logging
import random
import sys
import time
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterator, Optional

from dotenv import load_dotenv

try:
    import psycopg2
    import psycopg2.extras
except ImportError:
    print("❌ psycopg2 não instalado. Execute: pip install psycopg2-binary")
    sys.exit(1)

# Carrega variáveis do arquivo .env na raiz do projeto
env_path = Path(__file__).resolve().parents[2] / ".env"
if env_path.exists():
    load_dotenv(dotenv_path=env_path)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("generate_dms_data")

# =============================================================================
# Configuração de conexão
# =============================================================================

DEFAULT_HOST = "localhost"
DEFAULT_PORT = 5432
DEFAULT_DB = "flightradar"
DEFAULT_USER = "dbadmin"


@dataclass
class DBConfig:
    host: str = DEFAULT_HOST
    port: int = DEFAULT_PORT
    dbname: str = DEFAULT_DB
    user: str = DEFAULT_USER
    password: str = ""

    @classmethod
    def from_env_or_args(cls) -> "DBConfig":
        import os

        return cls(
            host=os.environ.get("DB_HOST", DEFAULT_HOST),
            port=int(os.environ.get("DB_PORT", str(DEFAULT_PORT))),
            dbname=os.environ.get("DB_NAME", DEFAULT_DB),
            user=os.environ.get("DB_USER", DEFAULT_USER),
            password=os.environ.get("DB_PASSWORD", ""),
        )

    @property
    def dsn(self) -> str:
        return (
            f"host={self.host} port={self.port} "
            f"dbname={self.dbname} user={self.user} password={self.password}"
        )


# =============================================================================
# Dados realistas de referência
# =============================================================================

# Aeronaves com características reais
KNOWN_AIRCRAFT: list[dict] = [
    # Boeing
    {"icao24": "a0f1b2", "registration": "N12345", "type": "B738", "manufacturer": "Boeing", "model": "737-800", "operator": "AAL", "operator_name": "American Airlines"},
    {"icao24": "b0c1d3", "registration": "N801NN", "type": "B738", "manufacturer": "Boeing", "model": "737-800", "operator": "AAL", "operator_name": "American Airlines"},
    {"icao24": "b1c2d3", "registration": "TC-JDT", "type": "B739", "manufacturer": "Boeing", "model": "737-900", "operator": "THY", "operator_name": "Turkish Airlines"},
    {"icao24": "a5b6c7", "registration": "PH-BQB", "type": "B739", "manufacturer": "Boeing", "model": "737-900", "operator": "KLM", "operator_name": "KLM"},
    {"icao24": "d4e5f6", "registration": "N67890", "type": "B77W", "manufacturer": "Boeing", "model": "777-300ER", "operator": "DAL", "operator_name": "Delta Air Lines"},
    {"icao24": "e4f5a1", "registration": "VP-BVA", "type": "B77W", "manufacturer": "Boeing", "model": "777-300ER", "operator": "AFL", "operator_name": "Aeroflot"},
    {"icao24": "d0e1f5", "registration": "A6-EWE", "type": "B77W", "manufacturer": "Boeing", "model": "777-300ER", "operator": "UAE", "operator_name": "Emirates"},
    {"icao24": "a0b1c2", "registration": "JA789A", "type": "B789", "manufacturer": "Boeing", "model": "787-9", "operator": "ANA", "operator_name": "All Nippon Airways"},
    {"icao24": "c0d1e4", "registration": "G-VWOR", "type": "B789", "manufacturer": "Boeing", "model": "787-9", "operator": "VIR", "operator_name": "Virgin Atlantic"},
    {"icao24": "e0f1a2", "registration": "HL8001", "type": "B748", "manufacturer": "Boeing", "model": "747-8", "operator": "KAL", "operator_name": "Korean Air"},
    {"icao24": "f1a2b3", "registration": "N456US", "type": "B752", "manufacturer": "Boeing", "model": "757-200", "operator": "DAL", "operator_name": "Delta Air Lines"},
    {"icao24": "a2b3c4", "registration": "OO-ABC", "type": "B763", "manufacturer": "Boeing", "model": "767-300", "operator": "UAL", "operator_name": "United Airlines"},
    # Airbus
    {"icao24": "a1b2c3", "registration": "D-ABYT", "type": "A320", "manufacturer": "Airbus", "model": "A320-200", "operator": "DLH", "operator_name": "Lufthansa"},
    {"icao24": "c3d4e5", "registration": "G-EUUK", "type": "A320", "manufacturer": "Airbus", "model": "A320-200", "operator": "BAW", "operator_name": "British Airways"},
    {"icao24": "e5f6a0", "registration": "PT-TGA", "type": "A320", "manufacturer": "Airbus", "model": "A320-200", "operator": "TAM", "operator_name": "LATAM Brasil"},
    {"icao24": "c2d3e4", "registration": "EI-DCC", "type": "A320", "manufacturer": "Airbus", "model": "A320-200", "operator": "RYR", "operator_name": "Ryanair"},
    {"icao24": "f0a1b3", "registration": "CS-TUJ", "type": "A320", "manufacturer": "Airbus", "model": "A320-200", "operator": "TAP", "operator_name": "TAP Air Portugal"},
    {"icao24": "d3e4f5", "registration": "N1234U", "type": "A321", "manufacturer": "Airbus", "model": "A321-200", "operator": "JBU", "operator_name": "JetBlue"},
    {"icao24": "b2c3d4", "registration": "EC-MQU", "type": "A333", "manufacturer": "Airbus", "model": "A330-300", "operator": "VLG", "operator_name": "Vueling Airlines"},
    {"icao24": "f5a0b2", "registration": "C-FIVM", "type": "A333", "manufacturer": "Airbus", "model": "A330-300", "operator": "ACA", "operator_name": "Air Canada"},
    {"icao24": "f6a0b1", "registration": "F-HPJB", "type": "A359", "manufacturer": "Airbus", "model": "A350-900", "operator": "AFR", "operator_name": "Air France"},
    {"icao24": "a0c1d2", "registration": "9V-SWL", "type": "A359", "manufacturer": "Airbus", "model": "A350-900", "operator": "SIA", "operator_name": "Singapore Airlines"},
    {"icao24": "b3c4d5", "registration": "F-WWAE", "type": "A359", "manufacturer": "Airbus", "model": "A350-1000", "operator": "UAE", "operator_name": "Emirates"},
    {"icao24": "c4d5e6", "registration": "D-AIXE", "type": "A359", "manufacturer": "Airbus", "model": "A350-900", "operator": "DLH", "operator_name": "Lufthansa"},
    {"icao24": "d5e6f7", "registration": "G-XWBE", "type": "A35K", "manufacturer": "Airbus", "model": "A350-1000", "operator": "BAW", "operator_name": "British Airways"},
    {"icao24": "b6c7d8", "registration": "N571UP", "type": "A388", "manufacturer": "Airbus", "model": "A380-800", "operator": "UAE", "operator_name": "Emirates"},
    # Embraer
    {"icao24": "e6f7a0", "registration": "PR-AUA", "type": "E170", "manufacturer": "Embraer", "model": "ERJ-170-100", "operator": "AZU", "operator_name": "Azul Linhas Aéreas"},
    {"icao24": "f7a0b1", "registration": "PS-EAB", "type": "E175", "manufacturer": "Embraer", "model": "ERJ-175-200", "operator": "GLO", "operator_name": "Gol Linhas Aéreas"},
    {"icao24": "a0b3c4", "registration": "N237JQ", "type": "E190", "manufacturer": "Embraer", "model": "ERJ-190-200", "operator": "JBU", "operator_name": "JetBlue"},
    {"icao24": "b3c5d6", "registration": "PT-ENB", "type": "E195", "manufacturer": "Embraer", "model": "ERJ-195-200", "operator": "AZU", "operator_name": "Azul Linhas Aéreas"},
    {"icao24": "c5d7e8", "registration": "N864BC", "type": "E170", "manufacturer": "Embraer", "model": "ERJ-170-200", "operator": "AAL", "operator_name": "American Eagle"},
    {"icao24": "d7e9f0", "registration": "2-ANBA", "type": "E190", "manufacturer": "Embraer", "model": "ERJ-190-100", "operator": "KLM", "operator_name": "KLM Cityhopper"},
    {"icao24": "e9f0a1", "registration": "PR-MBA", "type": "E195", "manufacturer": "Embraer", "model": "ERJ-195-200", "operator": "TAM", "operator_name": "LATAM Brasil"},
    {"icao24": "f0a2b3", "registration": "SP-LNA", "type": "E175", "manufacturer": "Embraer", "model": "ERJ-175-200", "operator": "LOT", "operator_name": "LOT Polish Airlines"},
    {"icao24": "a1b4c5", "registration": "N111LJ", "type": "E135", "manufacturer": "Embraer", "model": "ERJ-135", "operator": "ENY", "operator_name": "Envoy Air"},
    {"icao24": "b4c6d7", "registration": "D-ABJG", "type": "E190", "manufacturer": "Embraer", "model": "ERJ-190-200", "operator": "DLH", "operator_name": "Lufthansa"},
]

AEROPORTOS: list[dict] = [
    # Estados Unidos
    {"icao": "KJFK", "iata": "JFK", "name": "John F Kennedy International", "city": "New York", "country": "United States", "cc": "US", "lat": 40.639801, "lon": -73.778900},
    {"icao": "KLAX", "iata": "LAX", "name": "Los Angeles International", "city": "Los Angeles", "country": "United States", "cc": "US", "lat": 33.942536, "lon": -118.408075},
    {"icao": "KORD", "iata": "ORD", "name": "O'Hare International", "city": "Chicago", "country": "United States", "cc": "US", "lat": 41.974186, "lon": -87.907783},
    {"icao": "KATL", "iata": "ATL", "name": "Hartsfield-Jackson Atlanta", "city": "Atlanta", "country": "United States", "cc": "US", "lat": 33.636699, "lon": -84.427864},
    {"icao": "KDFW", "iata": "DFW", "name": "Dallas/Fort Worth", "city": "Dallas", "country": "United States", "cc": "US", "lat": 32.896828, "lon": -97.037997},
    {"icao": "KMIA", "iata": "MIA", "name": "Miami International", "city": "Miami", "country": "United States", "cc": "US", "lat": 25.795965, "lon": -80.287239},
    {"icao": "KDEN", "iata": "DEN", "name": "Denver International", "city": "Denver", "country": "United States", "cc": "US", "lat": 39.856098, "lon": -104.673737},
    {"icao": "KSEA", "iata": "SEA", "name": "Seattle-Tacoma International", "city": "Seattle", "country": "United States", "cc": "US", "lat": 47.449002, "lon": -122.309303},
    {"icao": "KSFO", "iata": "SFO", "name": "San Francisco International", "city": "San Francisco", "country": "United States", "cc": "US", "lat": 37.621313, "lon": -122.378955},
    {"icao": "KBOS", "iata": "BOS", "name": "Boston Logan International", "city": "Boston", "country": "United States", "cc": "US", "lat": 42.364347, "lon": -71.005181},
    {"icao": "KIAD", "iata": "IAD", "name": "Washington Dulles International", "city": "Washington D.C.", "country": "United States", "cc": "US", "lat": 38.944500, "lon": -77.455803},
    {"icao": "KPHX", "iata": "PHX", "name": "Phoenix Sky Harbor", "city": "Phoenix", "country": "United States", "cc": "US", "lat": 33.434167, "lon": -112.008056},
    # Europa
    {"icao": "EGLL", "iata": "LHR", "name": "London Heathrow", "city": "London", "country": "United Kingdom", "cc": "GB", "lat": 51.477500, "lon": -0.461389},
    {"icao": "EGKK", "iata": "LGW", "name": "London Gatwick", "city": "London", "country": "United Kingdom", "cc": "GB", "lat": 51.148056, "lon": -0.190278},
    {"icao": "LFPG", "iata": "CDG", "name": "Paris Charles de Gaulle", "city": "Paris", "country": "France", "cc": "FR", "lat": 49.012798, "lon": 2.550000},
    {"icao": "EDDF", "iata": "FRA", "name": "Frankfurt am Main", "city": "Frankfurt", "country": "Germany", "cc": "DE", "lat": 50.033333, "lon": 8.570556},
    {"icao": "EDDM", "iata": "MUC", "name": "Munich International", "city": "Munich", "country": "Germany", "cc": "DE", "lat": 48.353783, "lon": 11.786086},
    {"icao": "EHAM", "iata": "AMS", "name": "Amsterdam Schiphol", "city": "Amsterdam", "country": "Netherlands", "cc": "NL", "lat": 52.308056, "lon": 4.764167},
    {"icao": "LEMD", "iata": "MAD", "name": "Madrid Barajas", "city": "Madrid", "country": "Spain", "cc": "ES", "lat": 40.493556, "lon": -3.566764},
    {"icao": "LEBL", "iata": "BCN", "name": "Barcelona El Prat", "city": "Barcelona", "country": "Spain", "cc": "ES", "lat": 41.297078, "lon": 2.078464},
    {"icao": "LIRF", "iata": "FCO", "name": "Rome Fiumicino", "city": "Rome", "country": "Italy", "cc": "IT", "lat": 41.800278, "lon": 12.238889},
    {"icao": "LIMC", "iata": "MXP", "name": "Milan Malpensa", "city": "Milan", "country": "Italy", "cc": "IT", "lat": 45.627405, "lon": 8.712378},
    {"icao": "LSZH", "iata": "ZRH", "name": "Zurich Airport", "city": "Zurich", "country": "Switzerland", "cc": "CH", "lat": 47.458056, "lon": 8.548055},
    {"icao": "EBBR", "iata": "BRU", "name": "Brussels Airport", "city": "Brussels", "country": "Belgium", "cc": "BE", "lat": 50.901485, "lon": 4.484357},
    {"icao": "EKCH", "iata": "CPH", "name": "Copenhagen Kastrup", "city": "Copenhagen", "country": "Denmark", "cc": "DK", "lat": 55.618056, "lon": 12.656111},
    {"icao": "EPWA", "iata": "WAW", "name": "Warsaw Chopin", "city": "Warsaw", "country": "Poland", "cc": "PL", "lat": 52.165833, "lon": 20.967222},
    # Oriente Médio / Ásia / Oceania
    {"icao": "OMDB", "iata": "DXB", "name": "Dubai International", "city": "Dubai", "country": "United Arab Emirates", "cc": "AE", "lat": 25.252778, "lon": 55.364444},
    {"icao": "OTHH", "iata": "DOH", "name": "Hamad International", "city": "Doha", "country": "Qatar", "cc": "QA", "lat": 25.273056, "lon": 51.608056},
    {"icao": "VABB", "iata": "BOM", "name": "Chhatrapati Shivaji Maharaj", "city": "Mumbai", "country": "India", "cc": "IN", "lat": 19.088700, "lon": 72.867897},
    {"icao": "VIDP", "iata": "DEL", "name": "Indira Gandhi International", "city": "Delhi", "country": "India", "cc": "IN", "lat": 28.556159, "lon": 77.099876},
    {"icao": "ZSSS", "iata": "PVG", "name": "Shanghai Pudong", "city": "Shanghai", "country": "China", "cc": "CN", "lat": 31.143400, "lon": 121.805000},
    {"icao": "ZBTJ", "iata": "PEK", "name": "Beijing Capital International", "city": "Beijing", "country": "China", "cc": "CN", "lat": 40.079917, "lon": 116.603079},
    {"icao": "RJTT", "iata": "HND", "name": "Tokyo Haneda", "city": "Tokyo", "country": "Japan", "cc": "JP", "lat": 35.549393, "lon": 139.779838},
    {"icao": "RKSS", "iata": "GMP", "name": "Seoul Gimpo", "city": "Seoul", "country": "South Korea", "cc": "KR", "lat": 37.558310, "lon": 126.794586},
    {"icao": "RKSI", "iata": "ICN", "name": "Seoul Incheon", "city": "Seoul", "country": "South Korea", "cc": "KR", "lat": 37.464064, "lon": 126.440827},
    {"icao": "WSSS", "iata": "SIN", "name": "Singapore Changi", "city": "Singapore", "country": "Singapore", "cc": "SG", "lat": 1.359167, "lon": 103.989442},
    {"icao": "VHHH", "iata": "HKG", "name": "Hong Kong International", "city": "Hong Kong", "country": "Hong Kong", "cc": "HK", "lat": 22.308046, "lon": 113.918480},
    {"icao": "YSSY", "iata": "SYD", "name": "Sydney Kingsford Smith", "city": "Sydney", "country": "Australia", "cc": "AU", "lat": -33.939923, "lon": 151.175276},
    # América Latina
    {"icao": "SBGR", "iata": "GRU", "name": "São Paulo Guarulhos", "city": "São Paulo", "country": "Brazil", "cc": "BR", "lat": -23.435556, "lon": -46.473056},
    {"icao": "SBGL", "iata": "GIG", "name": "Rio de Janeiro Galeão", "city": "Rio de Janeiro", "country": "Brazil", "cc": "BR", "lat": -22.808903, "lon": -43.243647},
    {"icao": "SBBR", "iata": "BSB", "name": "Brasília International", "city": "Brasília", "country": "Brazil", "cc": "BR", "lat": -15.869722, "lon": -47.920834},
    {"icao": "SBCF", "iata": "CNF", "name": "Belo Horizonte Confins", "city": "Belo Horizonte", "country": "Brazil", "cc": "BR", "lat": -19.633333, "lon": -43.971944},
    {"icao": "SBPA", "iata": "POA", "name": "Porto Alegre Salgado Filho", "city": "Porto Alegre", "country": "Brazil", "cc": "BR", "lat": -29.993056, "lon": -51.171389},
    {"icao": "SBSP", "iata": "CGH", "name": "São Paulo Congonhas", "city": "São Paulo", "country": "Brazil", "cc": "BR", "lat": -23.626667, "lon": -46.656111},
    {"icao": "SAEZ", "iata": "EZE", "name": "Buenos Aires Ezeiza", "city": "Buenos Aires", "country": "Argentina", "cc": "AR", "lat": -34.822222, "lon": -58.535833},
    {"icao": "SCEL", "iata": "SCL", "name": "Santiago Arturo Merino Benítez", "city": "Santiago", "country": "Chile", "cc": "CL", "lat": -33.393055, "lon": -70.785833},
    {"icao": "SKBO", "iata": "BOG", "name": "El Dorado International", "city": "Bogotá", "country": "Colombia", "cc": "CO", "lat": 4.701594, "lon": -74.146947},
    {"icao": "MMMX", "iata": "MEX", "name": "Mexico City International", "city": "Mexico City", "country": "Mexico", "cc": "MX", "lat": 19.435278, "lon": -99.072778},
    # África
    {"icao": "FAOR", "iata": "JNB", "name": "Johannesburg OR Tambo", "city": "Johannesburg", "country": "South Africa", "cc": "ZA", "lat": -26.139167, "lon": 28.246111},
    {"icao": "HECA", "iata": "CAI", "name": "Cairo International", "city": "Cairo", "country": "Egypt", "cc": "EG", "lat": 30.121944, "lon": 31.405556},
]

COMPANHIAS: list[dict] = [
    # América do Norte
    {"icao": "AAL", "iata": "AA", "name": "American Airlines", "country": "United States", "callsign": "AMERICAN"},
    {"icao": "DAL", "iata": "DL", "name": "Delta Air Lines", "country": "United States", "callsign": "DELTA"},
    {"icao": "UAL", "iata": "UA", "name": "United Airlines", "country": "United States", "callsign": "UNITED"},
    {"icao": "JBU", "iata": "B6", "name": "JetBlue Airways", "country": "United States", "callsign": "JETBLUE"},
    {"icao": "SWA", "iata": "WN", "name": "Southwest Airlines", "country": "United States", "callsign": "SOUTHWEST"},
    {"icao": "ASA", "iata": "AS", "name": "Alaska Airlines", "country": "United States", "callsign": "ALASKA"},
    {"icao": "ACA", "iata": "AC", "name": "Air Canada", "country": "Canada", "callsign": "AIR CANADA"},
    # Europa
    {"icao": "BAW", "iata": "BA", "name": "British Airways", "country": "United Kingdom", "callsign": "SPEEDBIRD"},
    {"icao": "VIR", "iata": "VS", "name": "Virgin Atlantic", "country": "United Kingdom", "callsign": "VIRGIN"},
    {"icao": "DLH", "iata": "LH", "name": "Lufthansa", "country": "Germany", "callsign": "LUFTHANSA"},
    {"icao": "AFR", "iata": "AF", "name": "Air France", "country": "France", "callsign": "AIRFRANS"},
    {"icao": "KLM", "iata": "KL", "name": "KLM Royal Dutch", "country": "Netherlands", "callsign": "KLM"},
    {"icao": "RYR", "iata": "FR", "name": "Ryanair", "country": "Ireland", "callsign": "RYANAIR"},
    {"icao": "EZY", "iata": "U2", "name": "EasyJet", "country": "United Kingdom", "callsign": "EASY"},
    {"icao": "THY", "iata": "TK", "name": "Turkish Airlines", "country": "Turkey", "callsign": "TURKISH"},
    {"icao": "TAP", "iata": "TP", "name": "TAP Air Portugal", "country": "Portugal", "callsign": "AIR PORTUGAL"},
    {"icao": "IBE", "iata": "IB", "name": "Iberia", "country": "Spain", "callsign": "IBERIA"},
    {"icao": "VLG", "iata": "VY", "name": "Vueling Airlines", "country": "Spain", "callsign": "VUELING"},
    {"icao": "AZA", "iata": "AZ", "name": "IT Airways", "country": "Italy", "callsign": "ITALY"},
    {"icao": "LOT", "iata": "LO", "name": "LOT Polish Airlines", "country": "Poland", "callsign": "POLLOT"},
    {"icao": "SAS", "iata": "SK", "name": "Scandinavian Airlines", "country": "Sweden", "callsign": "SCANDINAVIAN"},
    # Oriente Médio / Ásia
    {"icao": "UAE", "iata": "EK", "name": "Emirates", "country": "United Arab Emirates", "callsign": "EMIRATES"},
    {"icao": "QTR", "iata": "QR", "name": "Qatar Airways", "country": "Qatar", "callsign": "QATARI"},
    {"icao": "ETD", "iata": "EY", "name": "Etihad Airways", "country": "United Arab Emirates", "callsign": "ETIHAD"},
    {"icao": "SIA", "iata": "SQ", "name": "Singapore Airlines", "country": "Singapore", "callsign": "SINGAPORE"},
    {"icao": "ANA", "iata": "NH", "name": "All Nippon Airways", "country": "Japan", "callsign": "ALL NIPPON"},
    {"icao": "JAL", "iata": "JL", "name": "Japan Airlines", "country": "Japan", "callsign": "JAPAN AIR"},
    {"icao": "KAL", "iata": "KE", "name": "Korean Air", "country": "South Korea", "callsign": "KOREAN"},
    {"icao": "AAR", "iata": "OZ", "name": "Asiana Airlines", "country": "South Korea", "callsign": "ASIANA"},
    {"icao": "CCA", "iata": "CA", "name": "Air China", "country": "China", "callsign": "AIR CHINA"},
    {"icao": "CSN", "iata": "CZ", "name": "China Southern", "country": "China", "callsign": "CHINA SOUTHERN"},
    {"icao": "QFA", "iata": "QF", "name": "Qantas Airways", "country": "Australia", "callsign": "QANTAS"},
    {"icao": "AFL", "iata": "SU", "name": "Aeroflot", "country": "Russia", "callsign": "AEROFLOT"},
    # América Latina
    {"icao": "TAM", "iata": "JJ", "name": "LATAM Brasil", "country": "Brazil", "callsign": "TAM"},
    {"icao": "AZU", "iata": "AD", "name": "Azul Linhas Aéreas", "country": "Brazil", "callsign": "AZUL"},
    {"icao": "GLO", "iata": "G3", "name": "Gol Linhas Aéreas", "country": "Brazil", "callsign": "GOL"},
    {"icao": "LAN", "iata": "LA", "name": "LATAM Chile", "country": "Chile", "callsign": "LAN CHILE"},
    {"icao": "AVA", "iata": "AV", "name": "Avianca", "country": "Colombia", "callsign": "AVIANCA"},
    {"icao": "AMX", "iata": "AM", "name": "Aeromexico", "country": "Mexico", "callsign": "AEROMEXICO"},
    {"icao": "ARG", "iata": "AR", "name": "Aerolineas Argentinas", "country": "Argentina", "callsign": "ARGENTINA"},
]

FLIGHT_STATUSES = ["scheduled", "active", "landed", "cancelled", "diverted"]

# Pares de aeroportos com distâncias realistas (origem,destino,duração_horas)
ROUTES = [
    # Rotas internacionais longas
    ("KJFK", "EGLL", 7.0), ("EGLL", "KJFK", 7.5),
    ("KJFK", "LFPG", 7.0), ("LFPG", "KJFK", 7.5),
    ("KJFK", "EHAM", 7.5), ("EHAM", "KJFK", 7.0),
    ("KJFK", "OMDB", 12.5), ("OMDB", "KJFK", 13.0),
    ("KJFK", "SBGR", 9.5), ("SBGR", "KJFK", 9.0),
    ("KJFK", "KLAX", 5.5), ("KLAX", "KJFK", 5.0),
    ("KLAX", "EGLL", 10.0), ("EGLL", "KLAX", 10.5),
    ("KLAX", "WSSS", 16.0), ("WSSS", "KLAX", 15.5),
    ("KLAX", "YSSY", 14.5), ("YSSY", "KLAX", 14.0),
    ("KLAX", "RJTT", 11.0), ("RJTT", "KLAX", 10.5),
    ("KSEA", "WSSS", 15.0), ("WSSS", "KSEA", 14.5),
    ("KSFO", "WSSS", 15.5), ("WSSS", "KSFO", 15.0),
    ("KATL", "LFPG", 8.0), ("LFPG", "KATL", 8.5),
    # Europa ↔ Europa (curtas)
    ("EGLL", "LFPG", 1.5), ("LFPG", "EGLL", 1.5),
    ("EGLL", "EHAM", 1.0), ("EHAM", "EGLL", 1.0),
    ("EGLL", "LEMD", 2.5), ("LEMD", "EGLL", 2.5),
    ("EGLL", "LIRF", 2.5), ("LIRF", "EGLL", 2.5),
    ("EGLL", "LIMC", 2.0), ("LIMC", "EGLL", 2.0),
    ("LFPG", "EHAM", 1.0), ("EHAM", "LFPG", 1.0),
    ("LFPG", "LEMD", 1.5), ("LEMD", "LFPG", 1.5),
    ("LFPG", "EDDF", 1.0), ("EDDF", "LFPG", 1.0),
    ("EDDF", "EPWA", 1.5), ("EPWA", "EDDF", 1.5),
    ("EDDM", "LEMD", 2.0), ("LEMD", "EDDM", 2.0),
    ("EKCH", "EGLL", 2.0), ("EGLL", "EKCH", 2.0),
    ("LSZH", "LFPG", 1.0), ("LFPG", "LSZH", 1.0),
    ("EBBR", "EGLL", 1.0), ("EGLL", "EBBR", 1.0),
    ("LEBL", "EGLL", 2.0), ("EGLL", "LEBL", 2.0),
    # Europa ↔ Oriente Médio / Ásia
    ("EDDF", "OMDB", 6.0), ("OMDB", "EDDF", 6.5),
    ("EGLL", "OMDB", 6.5), ("OMDB", "EGLL", 7.0),
    ("LFPG", "WSSS", 12.5), ("WSSS", "LFPG", 13.0),
    ("EHAM", "WSSS", 12.0), ("WSSS", "EHAM", 12.5),
    ("LEMD", "OMDB", 7.0), ("OMDB", "LEMD", 7.5),
    ("EDDF", "RKSS", 11.0), ("RKSS", "EDDF", 11.5),
    ("LFPG", "VABB", 8.5), ("VABB", "LFPG", 9.0),
    # Europa ↔ América Latina
    ("EDDF", "SBGR", 12.0), ("SBGR", "EDDF", 11.5),
    ("LFPG", "SBGR", 11.5), ("SBGR", "LFPG", 11.0),
    ("LEMD", "SBGR", 10.0), ("SBGR", "LEMD", 9.5),
    ("EGLL", "SBGR", 11.5), ("SBGR", "EGLL", 11.0),
    ("EHAM", "SBGR", 12.0), ("SBGR", "EHAM", 11.5),
    ("LEMD", "SAEZ", 12.0), ("SAEZ", "LEMD", 11.5),
    ("LFPG", "SCEL", 13.0), ("SCEL", "LFPG", 12.5),
    ("EDDF", "SKBO", 11.0), ("SKBO", "EDDF", 10.5),
    ("EBBR", "SBBR", 10.5), ("SBBR", "EBBR", 10.0),
    # América do Norte ↔ América Latina
    ("KMIA", "SBGR", 8.0), ("SBGR", "KMIA", 7.5),
    ("KMIA", "SBGL", 8.5), ("SBGL", "KMIA", 8.0),
    ("KMIA", "SAEZ", 8.5), ("SAEZ", "KMIA", 8.0),
    ("KJFK", "SBGR", 9.5), ("SBGR", "KJFK", 9.0),
    ("KATL", "SBGR", 9.0), ("SBGR", "KATL", 8.5),
    ("KORD", "MMMX", 4.5), ("MMMX", "KORD", 4.5),
    ("KLAX", "MMMX", 4.0), ("MMMX", "KLAX", 4.0),
    # América do Norte ↔ Europa
    ("KBOS", "EGLL", 6.5), ("EGLL", "KBOS", 7.0),
    ("KIAD", "LFPG", 7.5), ("LFPG", "KIAD", 7.0),
    ("KORD", "EDDF", 8.5), ("EDDF", "KORD", 9.0),
    ("KSEA", "EGLL", 9.0), ("EGLL", "KSEA", 9.5),
    ("KSFO", "EGLL", 10.0), ("EGLL", "KSFO", 10.5),
    ("KPHX", "EGLL", 10.0), ("EGLL", "KPHX", 10.5),
    # América Latina ↔ Europa
    ("SBGR", "LIRF", 11.0), ("LIRF", "SBGR", 10.5),
    # América Latina ↔ América Latina
    ("SBGR", "SBGL", 0.75), ("SBGL", "SBGR", 0.75),
    ("SBGR", "SBBR", 1.5), ("SBBR", "SBGR", 1.5),
    ("SBGR", "SBCF", 1.0), ("SBCF", "SBGR", 1.0),
    ("SBGR", "SBPA", 1.5), ("SBPA", "SBGR", 1.5),
    ("SBGR", "SKBO", 5.5), ("SKBO", "SBGR", 5.5),
    ("SBGR", "SAEZ", 3.0), ("SAEZ", "SBGR", 3.0),
    ("SBGR", "SCEL", 4.0), ("SCEL", "SBGR", 4.0),
    ("SBSP", "SBBR", 1.5), ("SBBR", "SBSP", 1.5),
    ("SBSP", "SBGL", 1.0), ("SBGL", "SBSP", 1.0),
    ("SAEZ", "SCEL", 2.0), ("SCEL", "SAEZ", 2.0),
    # Ásia / Oriente Médio ↔ Europa
    ("OMDB", "WSSS", 7.5), ("WSSS", "OMDB", 7.0),
    ("OMDB", "VABB", 3.0), ("VABB", "OMDB", 3.0),
    ("OMDB", "ZSSS", 8.0), ("ZSSS", "OMDB", 8.0),
    ("OTHH", "EGLL", 6.5), ("EGLL", "OTHH", 7.0),
    ("VIDP", "OMDB", 3.5), ("OMDB", "VIDP", 3.5),
    ("RJTT", "WSSS", 7.0), ("WSSS", "RJTT", 7.5),
    ("RKSS", "WSSS", 6.0), ("WSSS", "RKSS", 6.5),
    ("RKSI", "OMDB", 8.5), ("OMDB", "RKSI", 9.0),
    ("VHHH", "WSSS", 3.5), ("WSSS", "VHHH", 3.5),
    ("VHHH", "RJTT", 4.0), ("RJTT", "VHHH", 4.0),
    # Oceania
    ("YSSY", "WSSS", 8.0), ("WSSS", "YSSY", 7.5),
    ("YSSY", "RJTT", 9.5), ("RJTT", "YSSY", 9.0),
    ("YSSY", "VHHH", 9.0), ("VHHH", "YSSY", 9.5),
    # África
    ("FAOR", "EGLL", 11.0), ("EGLL", "FAOR", 11.5),
    ("FAOR", "OMDB", 8.0), ("OMDB", "FAOR", 8.5),
    ("HECA", "LFPG", 4.0), ("LFPG", "HECA", 4.0),
]


# =============================================================================
# Gerador de dados
# =============================================================================

class RDSDataGenerator:
    """Gera dados de teste no RDS para o pipeline DMS."""

    def __init__(self, db_config: DBConfig):
        self.cfg = db_config
        self.conn: Optional[psycopg2.extensions.connection] = None
        self._aircraft_icaos: list[str] = []
        self._airport_icaos: list[str] = []
        self._airline_icaos: list[str] = []

    # ── Gerenciamento de conexão ────────────────────────────────────────

    @contextmanager
    def _cursor(self, *, commit: bool = False) -> Iterator[psycopg2.extras.RealDictCursor]:
        conn = psycopg2.connect(self.cfg.dsn)
        try:
            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cur.execute("SET search_path TO flight_radar;")
            yield cur
            if commit:
                conn.commit()
        finally:
            conn.close()

    def connect(self) -> None:
        logger.info("Conectando ao RDS: %s:%s/%s ...", self.cfg.host, self.cfg.port, self.cfg.dbname)
        self.conn = psycopg2.connect(self.cfg.dsn)
        self.conn.autocommit = True
        with self.conn.cursor() as cur:
            cur.execute("SET search_path TO flight_radar;")
        logger.info("Conectado!")

    def close(self) -> None:
        if self.conn:
            self.conn.close()
            self.conn = None

    # ── Helpers de dados referenciais ────────────────────────────────────

    def _ensure_reference_data(self) -> None:
        """Garante que aeroportos, companhias e aeronaves base existam."""
        self._upsert_airports()
        self._upsert_airlines()
        self._upsert_aircraft()
        # Cache para uso posterior
        with self._cursor() as cur:
            cur.execute("SELECT icao_code FROM airports")
            self._airport_icaos = [r["icao_code"] for r in cur.fetchall()]
            cur.execute("SELECT icao_code FROM airlines")
            self._airline_icaos = [r["icao_code"] for r in cur.fetchall()]
            cur.execute("SELECT icao24 FROM aircraft")
            self._aircraft_icaos = [r["icao24"] for r in cur.fetchall()]
        logger.info(
            "Referências carregadas: %d aeronaves, %d aeroportos, %d companhias",
            len(self._aircraft_icaos), len(self._airport_icaos), len(self._airline_icaos),
        )

    def _upsert_airports(self) -> None:
        with self._cursor(commit=True) as cur:
            for ap in AEROPORTOS:
                cur.execute("""
                    INSERT INTO airports (icao_code, iata_code, name, city, country, country_code, latitude, longitude)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (icao_code) DO UPDATE SET name=EXCLUDED.name
                """, (ap["icao"], ap["iata"], ap["name"], ap["city"], ap["country"],
                      ap["cc"], ap["lat"], ap["lon"]))
        logger.info("Aeroportos inseridos/atualizados: %d", len(AEROPORTOS))

    def _upsert_airlines(self) -> None:
        with self._cursor(commit=True) as cur:
            for al in COMPANHIAS:
                cur.execute("""
                    INSERT INTO airlines (icao_code, iata_code, name, country, callsign)
                    VALUES (%s, %s, %s, %s, %s)
                    ON CONFLICT (icao_code) DO UPDATE SET name=EXCLUDED.name
                """, (al["icao"], al["iata"], al["name"], al["country"], al["callsign"]))
        logger.info("Companhias inseridas/atualizadas: %d", len(COMPANHIAS))

    def _upsert_aircraft(self) -> None:
        with self._cursor(commit=True) as cur:
            for ac in KNOWN_AIRCRAFT:
                cur.execute("""
                    INSERT INTO aircraft (icao24, registration, aircraft_type, manufacturer, model, operator_icao, operator_name)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (icao24) DO UPDATE SET
                        registration=EXCLUDED.registration,
                        operator_icao=EXCLUDED.operator_icao
                """, (ac["icao24"], ac["registration"], ac["type"],
                      ac["manufacturer"], ac["model"],
                      ac["operator"], ac["operator_name"]))
        logger.info("Aeronaves inseridas/atualizadas: %d", len(KNOWN_AIRCRAFT))

    # ── Geração de voos ──────────────────────────────────────────────────

    def _random_route(self) -> tuple[str, str, float]:
        route = random.choice(ROUTES)
        return route  # (origin, dest, duration_hours)

    def _generate_flight_number(self, airline_icao: str) -> str:
        """Gera número de voo realista: AA1234, BA789, etc."""
        airline_map = {al["icao"]: al["iata"] for al in COMPANHIAS}
        prefix = airline_map.get(airline_icao, airline_icao)
        number = random.randint(100, 9999)
        return f"{prefix}{number}"

    def _random_flight_row(self, ref_time: datetime) -> dict:
        """Gera uma linha da tabela flights."""
        icao24 = random.choice(self._aircraft_icaos)
        airline = random.choice(self._airline_icaos)
        origin, dest, duration_h = self._random_route()

        # Evita origem=destino
        while dest == origin:
            _, dest, duration_h = self._random_route()

        flight_number = self._generate_flight_number(airline)
        scheduled_dep = ref_time + timedelta(
            hours=random.uniform(-24, 24)
        )
        scheduled_arr = scheduled_dep + timedelta(hours=duration_h)

        # Status baseado no tempo
        now = datetime.now(timezone.utc)
        if scheduled_arr < now:
            status = random.choices(
                ["landed", "cancelled", "diverted"],
                weights=[0.85, 0.10, 0.05],
            )[0]
        elif scheduled_dep < now < scheduled_arr:
            status = "active"
        else:
            status = "scheduled"

        actual_dep = None
        actual_arr = None
        if status == "active":
            actual_dep = scheduled_dep + timedelta(minutes=random.randint(0, 30))
        elif status == "landed":
            actual_dep = scheduled_dep + timedelta(minutes=random.randint(0, 30))
            actual_arr = scheduled_arr + timedelta(minutes=random.randint(-15, 45))

        return {
            "flight_number": flight_number,
            "airline_icao": airline,
            "aircraft_icao24": icao24,
            "origin_airport": origin,
            "destination_airport": dest,
            "scheduled_departure": scheduled_dep,
            "scheduled_arrival": scheduled_arr,
            "actual_departure": actual_dep,
            "actual_arrival": actual_arr,
            "status": status,
        }

    def _insert_flight(self, cur: psycopg2.extras.RealDictCursor, row: dict) -> int:
        cur.execute("""
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
        """, row)
        return cur.fetchone()["flight_id"]

    # ── Geração de posições ──────────────────────────────────────────────

    @staticmethod
    def _interpolate_position(
        lat1: float, lon1: float, lat2: float, lon2: float, fraction: float
    ) -> tuple[float, float]:
        """Interpola linearmente entre dois pontos."""
        return (
            lat1 + (lat2 - lat1) * fraction,
            lon1 + (lon2 - lon1) * fraction,
        )

    def _generate_positions_for_flight(
        self,
        flight_id: int,
        origin: str,
        dest: str,
        dep_time: datetime,
        arr_time: datetime,
        icao24: str,
        interval_minutes: int = 5,
    ) -> list[dict]:
        """Gera posições para um voo entre origem e destino."""
        if dep_time is None or arr_time is None:
            return []

        # Coordenadas dos aeroportos
        ap_map = {ap["icao"]: ap for ap in AEROPORTOS}
        orig_ap = ap_map.get(origin)
        dest_ap = ap_map.get(dest)
        if not orig_ap or not dest_ap:
            return []

        positions: list[dict] = []
        total_seconds = (arr_time - dep_time).total_seconds()
        if total_seconds <= 0:
            return []

        steps = int(total_seconds / (interval_minutes * 60))
        if steps < 2:
            steps = 2

        for i in range(steps):
            fraction = i / (steps - 1)
            lat, lon = self._interpolate_position(
                orig_ap["lat"], orig_ap["lon"],
                dest_ap["lat"], dest_ap["lon"],
                fraction,
            )
            # Adiciona dispersão aleatória para parecer real
            lat += random.uniform(-0.5, 0.5)
            lon += random.uniform(-0.5, 0.5)

            # Altitude: decolagem/descida nas pontas, cruzeiro no meio
            if fraction < 0.1:
                alt_ft = int(fraction / 0.1 * 35000)
                vel_kts = 150 + fraction / 0.1 * 350
                on_ground = True if fraction < 0.02 else False
            elif fraction > 0.9:
                alt_ft = int((1 - fraction) / 0.1 * 35000)
                vel_kts = 150 + (1 - fraction) / 0.1 * 350
                on_ground = True if fraction > 0.98 else False
            else:
                alt_ft = random.randint(33000, 39000)
                vel_kts = random.uniform(420, 510)
                on_ground = False

            heading = fraction * 360 % 360
            vertical_rate = random.uniform(-500, 500) if not on_ground else 0

            recorded_at = dep_time + timedelta(seconds=int(i * interval_minutes * 60))
            if recorded_at > datetime.now(timezone.utc):
                break

            positions.append({
                "aircraft_icao24": icao24,
                "flight_id": flight_id,
                "latitude": round(lat, 7),
                "longitude": round(lon, 7),
                "altitude_ft": alt_ft,
                "velocity_kts": round(vel_kts, 2),
                "heading": round(heading, 2),
                "vertical_rate_fpm": round(vertical_rate, 2),
                "on_ground": on_ground,
                "recorded_at": recorded_at,
            })

        return positions

    def _insert_positions_batch(
        self, cur: psycopg2.extras.RealDictCursor, positions: list[dict]
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
                p["aircraft_icao24"], p["flight_id"],
                p["latitude"], p["longitude"],
                p["altitude_ft"], p["velocity_kts"],
                p["heading"], p["vertical_rate_fpm"],
                p["on_ground"], p["recorded_at"],
            ) for p in positions],
            template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s::timestamptz)",
            page_size=500,
        )
        return len(positions)

    # ── Histórico (Full Load) ────────────────────────────────────────────

    def generate_historical_data(
        self,
        months: int = 12,
        flights_per_month: int = 200,
        batch_size: int = 100,
    ) -> None:
        """
        Gera massa de dados históricos para DMS full load.

        Cria voos e posições distribuídos pelos últimos N meses,
        com datas variadas para simular um ano de operações.
        """
        logger.info("=" * 60)
        logger.info("GERAÇÃO DE DADOS HISTÓRICOS — %d meses", months)
        logger.info("=" * 60)

        self._ensure_reference_data()

        now = datetime.now(timezone.utc)
        total_flights = 0
        total_positions = 0

        # Distribui voos pelos meses
        for month_offset in range(months):
            # Data base: início de cada mês atrás
            month_start = now - timedelta(days=30 * (months - month_offset))
            flights_this_month = random.randint(
                max(50, flights_per_month - 50),
                flights_per_month + 50,
            )
            logger.info(
                "Mês %d/%d: gerando ~%d voos (ref: %s)",
                month_offset + 1, months, flights_this_month,
                month_start.strftime("%Y-%m"),
            )

            conn = psycopg2.connect(self.cfg.dsn)
            conn.autocommit = False
            try:
                cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                cur.execute("SET search_path TO flight_radar;")

                for i in range(flights_this_month):
                    # Distribui dentro do mês
                    days_offset = random.uniform(0, 30)
                    ref_time = month_start + timedelta(days=days_offset)
                    flight_row = self._random_flight_row(ref_time)

                    flight_id = self._insert_flight(cur, flight_row)
                    total_flights += 1

                    # Gera posições para voos landed/active
                    if flight_row["status"] in ("landed", "active", "scheduled"):
                        dep = flight_row["actual_departure"] or flight_row["scheduled_departure"]
                        arr = flight_row["actual_arrival"] or flight_row["scheduled_arrival"]
                        positions = self._generate_positions_for_flight(
                            flight_id,
                            flight_row["origin_airport"],
                            flight_row["destination_airport"],
                            dep, arr,
                            flight_row["aircraft_icao24"],
                            interval_minutes=random.randint(3, 10),
                        )
                        total_positions += self._insert_positions_batch(cur, positions)

                    # Commit a cada batch_size voos
                    if i > 0 and i % batch_size == 0:
                        conn.commit()
                        logger.debug(
                            "  ... %d/%d voos (%d posições)",
                            i, flights_this_month, total_positions,
                        )

                conn.commit()
                logger.info(
                    "  ✅ Mês concluído: %d voos, %d posições (acumulado)",
                    flights_this_month, total_positions,
                )
            finally:
                conn.close()

        logger.info("")
        logger.info("=" * 60)
        logger.info("RESUMO HISTÓRICO: %d voos, %d posições gerados", total_flights, total_positions)
        logger.info("=" * 60)

    # ── Streaming (CDC) ───────────────────────────────────────────────────

    def generate_stream_data(
        self,
        interval_seconds: int = 30,
        duration_seconds: int = 300,
        delete_probability: float = 0.05,
        update_probability: float = 0.15,
    ) -> None:
        """
        Gera dados contínuos no RDS para simular CDC.

        A cada ciclo:
          1. Cria 1-3 novos voos (INSERT em flights)
          2. Gera posições para voos ativos (INSERT em aircraft_positions)
          3. Atualiza status de alguns voos (UPDATE)
          4. Remove aleatoriamente alguns voos antigos (DELETE — raro)
        """
        logger.info("=" * 60)
        logger.info("STREAMING CDC — intervalo=%ds, duração=%ds", interval_seconds, duration_seconds)
        logger.info("=" * 60)

        self._ensure_reference_data()

        now = datetime.now(timezone.utc)
        end_time = now + timedelta(seconds=duration_seconds)
        cycle = 0

        while datetime.now(timezone.utc) < end_time:
            cycle += 1
            cycle_start = time.perf_counter()
            conn = psycopg2.connect(self.cfg.dsn)
            conn.autocommit = False
            inserted = updated = deleted = 0

            try:
                cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                cur.execute("SET search_path TO flight_radar;")

                # ── 1. INSERT: novos voos ────────────────────────────────
                num_new_flights = random.randint(1, 3)
                new_flight_ids: list[int] = []
                for _ in range(num_new_flights):
                    row = self._random_flight_row(datetime.now(timezone.utc))
                    flight_id = self._insert_flight(cur, row)
                    new_flight_ids.append(flight_id)
                    inserted += 1
                    logger.debug("  INSERT flight_id=%d %s %s->%s",
                                 flight_id, row["flight_number"],
                                 row["origin_airport"], row["destination_airport"])

                # ── 2. INSERT: posições para voos ativos ─────────────────
                cur.execute("""
                    SELECT flight_id, aircraft_icao24, origin_airport, destination_airport,
                           actual_departure, actual_arrival, status
                    FROM flights
                    WHERE status IN ('active', 'scheduled')
                      AND actual_departure IS NOT NULL
                    ORDER BY random()
                    LIMIT 5
                """)
                active_flights = cur.fetchall()
                for f in active_flights:
                    dep = f["actual_departure"] or (datetime.now(timezone.utc) - timedelta(hours=2))
                    arr = f["actual_arrival"] or (dep + timedelta(hours=5))
                    positions = self._generate_positions_for_flight(
                        f["flight_id"],
                        f["origin_airport"],
                        f["destination_airport"],
                        dep, arr,
                        f["aircraft_icao24"],
                        interval_minutes=1,
                    )
                    # Pega apenas a posição mais recente (como se fosse um novo report)
                    if positions:
                        latest_pos = positions[-1]
                        self._insert_positions_batch(cur, [latest_pos])
                        inserted += 1

                # ── 3. UPDATE: transição de status ───────────────────────
                if random.random() < update_probability:
                    cur.execute("""
                        SELECT flight_id, status FROM flights
                        WHERE status IN ('scheduled', 'active')
                        ORDER BY random() LIMIT %s
                    """, (random.randint(1, 3),))
                    for f_up in cur.fetchall():
                        old_status = f_up["status"]
                        if old_status == "scheduled":
                            new_status = "active"
                            actual_dep = datetime.now(timezone.utc) - timedelta(minutes=random.randint(1, 15))
                            cur.execute("""
                                UPDATE flights
                                SET status = %s, actual_departure = %s, updated_at = NOW()
                                WHERE flight_id = %s
                            """, (new_status, actual_dep, f_up["flight_id"]))
                        elif old_status == "active":
                            new_status = random.choice(["landed", "diverted"])
                            actual_arr = datetime.now(timezone.utc) - timedelta(minutes=random.randint(1, 10))
                            cur.execute("""
                                UPDATE flights
                                SET status = %s, actual_arrival = %s, updated_at = NOW()
                                WHERE flight_id = %s
                            """, (new_status, actual_arr, f_up["flight_id"]))
                        else:
                            continue
                        updated += 1
                        logger.debug("  UPDATE flight_id=%d: %s -> %s",
                                     f_up["flight_id"], old_status, new_status)

                # ── 4. DELETE: raro — remove voo antigo já landed ────────
                if random.random() < delete_probability:
                    cur.execute("""
                        SELECT flight_id FROM flights
                        WHERE status IN ('landed', 'cancelled', 'diverted')
                          AND created_at < NOW() - INTERVAL '1 hour'
                        ORDER BY random() LIMIT 1
                    """)
                    row_to_del = cur.fetchone()
                    if row_to_del:
                        # Remove posições primeiro (FK)
                        cur.execute("DELETE FROM aircraft_positions WHERE flight_id = %s",
                                    (row_to_del["flight_id"],))
                        cur.execute("DELETE FROM flights WHERE flight_id = %s",
                                    (row_to_del["flight_id"],))
                        deleted += 1
                        logger.debug("  DELETE flight_id=%d", row_to_del["flight_id"])

                conn.commit()

            except Exception as e:
                conn.rollback()
                logger.error("Erro no ciclo %d: %s", cycle, e)
            finally:
                conn.close()

            elapsed = time.perf_counter() - cycle_start
            logger.info(
                "Ciclo %2d | INSERT=%d UPDATE=%d DELETE=%d | %.1fs",
                cycle, inserted, updated, deleted, elapsed,
            )

            # Aguarda até o próximo ciclo
            sleep_time = interval_seconds - elapsed
            if sleep_time > 0:
                time.sleep(sleep_time)

        logger.info("")
        logger.info("=" * 60)
        logger.info("STREAM ENCERRADO — %d ciclos executados", cycle)
        logger.info("=" * 60)


# =============================================================================
# CLI
# =============================================================================

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Gera dados de teste no RDS para o pipeline DMS",
    )
    p.add_argument("--host", default=None, help=f"RDS host (env: DB_HOST, default: {DEFAULT_HOST})")
    p.add_argument("--port", type=int, default=None, help=f"RDS port (env: DB_PORT)")
    p.add_argument("--db", default=None, help=f"Database name (env: DB_NAME)")
    p.add_argument("--user", default=None, help=f"Database user (env: DB_USER)")
    p.add_argument("--password", default=None, help="Database password (env: DB_PASSWORD)")

    sub = p.add_subparsers(dest="mode", required=True, help="Modo de operação")

    # historical
    h = sub.add_parser("historical", help="Gera massa de dados históricos (full load)")
    h.add_argument("--months", type=int, default=12, help="Quantidade de meses (default: 12)")
    h.add_argument("--flights-per-month", type=int, default=200, help="Voo por mês (default: 200)")

    # stream
    s = sub.add_parser("stream", help="Gera dados contínuos para CDC")
    s.add_argument("--interval", type=int, default=30, help="Intervalo entre ciclos em segundos (default: 30)")
    s.add_argument("--duration", type=int, default=300, help="Duração total em segundos (default: 300)")

    # all
    a = sub.add_parser("all", help="Histórico + stream em sequência")
    a.add_argument("--months", type=int, default=12, help="Quantidade de meses (default: 12)")
    a.add_argument("--interval", type=int, default=30, help="Intervalo stream (default: 30)")
    a.add_argument("--duration", type=int, default=300, help="Duração stream (default: 300)")

    return p


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    # Monta DBConfig a partir de env + CLI (CLI sobrescreve env)
    cfg = DBConfig.from_env_or_args()
    if args.host:
        cfg.host = args.host
    if args.port:
        cfg.port = args.port
    if args.db:
        cfg.dbname = args.db
    if args.user:
        cfg.user = args.user
    if args.password:
        cfg.password = args.password

    gen = RDSDataGenerator(cfg)

    if args.mode == "historical":
        gen.generate_historical_data(
            months=args.months,
            flights_per_month=args.flights_per_month,
        )
    elif args.mode == "stream":
        gen.generate_stream_data(
            interval_seconds=args.interval,
            duration_seconds=args.duration,
        )
    elif args.mode == "all":
        logger.info("🔷 MODO ALL: histórico + stream")
        gen.generate_historical_data(months=args.months)
        logger.info("")
        gen.generate_stream_data(
            interval_seconds=args.interval,
            duration_seconds=args.duration,
        )

    gen.close()


if __name__ == "__main__":
    main()

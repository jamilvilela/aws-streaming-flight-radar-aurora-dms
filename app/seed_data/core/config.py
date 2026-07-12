"""
Configuração — carregamento de .env e parâmetros de conexão.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import ClassVar

from dotenv import load_dotenv

# Carrega .env da raiz do projeto
_env_path = Path(__file__).resolve().parents[2] / ".env"
if _env_path.exists():
    load_dotenv(dotenv_path=_env_path)


@dataclass
class DBConfig:
    """Configuração de conexão com o banco PostgreSQL."""

    host: str = "localhost"
    port: int = 5432
    dbname: str = "flightradar"
    user: str = "dbadmin"
    password: str = ""

    # Caminhos dos datasets
    data_dir: Path = field(
        default_factory=lambda: Path(__file__).resolve().parents[2] / "app" / "data"
    )

    DEFAULT_HOST: ClassVar[str] = "localhost"
    DEFAULT_PORT: ClassVar[int] = 5432
    DEFAULT_DB: ClassVar[str] = "flightradar"
    DEFAULT_USER: ClassVar[str] = "dbadmin"

    @classmethod
    def from_env_or_args(cls) -> "DBConfig":
        return cls(
            host=os.environ.get("DB_HOST", cls.DEFAULT_HOST),
            port=int(os.environ.get("DB_PORT", str(cls.DEFAULT_PORT))),
            dbname=os.environ.get("DB_NAME", cls.DEFAULT_DB),
            user=os.environ.get("DB_USER", cls.DEFAULT_USER),
            password=os.environ.get("DB_PASSWORD", ""),
        )

    @property
    def dsn(self) -> str:
        return (
            f"host={self.host} port={self.port} "
            f"dbname={self.dbname} user={self.user} password={self.password}"
        )

    @property
    def csv_paths(self) -> dict[str, Path]:
        """Retorna os caminhos absolutos de cada CSV."""
        d = self.data_dir
        return {
            "airports": d / "airports.csv",
            "airlines": d / "airlines.csv",
            "airplanes": d / "airplanes.csv",
            "routes": d / "routes.csv",
            "countries": d / "countries.csv",
        }

#!/usr/bin/env python3
"""
Batch Entrypoint Script
Executa diferentes tipos de jobs de carga de dados baseado na variável de ambiente JOB_TYPE.

Tipos de job suportados:
- historical: Gera dados históricos (anos passados)
- stream: Gera streaming CDC contínuo
- load-reference: Carrega dados de referência (CSVs)
- clean: Limpa tabelas de dados gerados
"""

import os
import sys
import subprocess
import logging
from pathlib import Path

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S"
)
logger = logging.getLogger("batch-entrypoint")


def run_command(cmd: list[str], env: dict | None = None) -> int:
    """Executa comando e retorna código de saída."""
    logger.info(f"Executando: {' '.join(cmd)}")
    result = subprocess.run(cmd, env=env or os.environ)
    return result.returncode


def main():
    job_type = os.getenv("JOB_TYPE", "historical").lower()
    logger.info(f"Iniciando job tipo: {job_type}")

    # Configurações comuns
    base_cmd = [
        sys.executable,
        "app/seed_data/cli.py"
    ]

    # Mapeia tipo de job para comando
    if job_type == "historical":
        # Parâmetros padrão para historical
        years = os.getenv("YEARS", "5")
        target_size_gb = os.getenv("TARGET_SIZE_GB", "5")
        years_list = os.getenv("YEARS_LIST", "")
        cmd = base_cmd + [
            "historical",
            "--years", years,
            "--target-size-gb", target_size_gb
        ]
        if years_list:
            cmd.extend(["--years-list", years_list])

    elif job_type == "stream":
        interval = os.getenv("INTERVAL", "1")
        target_mb = os.getenv("TARGET_MB_5MIN", "150")
        duration = os.getenv("DURATION", "")
        cmd = base_cmd + [
            "stream",
            "--interval", interval,
            "--target-mb-5min", target_mb
        ]
        if duration:
            cmd.extend(["--duration", duration])

    elif job_type == "load-reference":
        tables = os.getenv("TABLES", "")
        cmd = base_cmd + ["load-reference"]
        if tables:
            cmd.extend(["--tables", tables])

    elif job_type == "clean":
        cmd = base_cmd + ["clean"]

    elif job_type == "all":
        years = os.getenv("YEARS", "5")
        target_size_gb = os.getenv("TARGET_SIZE_GB", "5")
        cmd = base_cmd + [
            "all",
            "--years", years,
            "--target-size-gb", target_size_gb
        ]

    else:
        logger.error(f"Tipo de job desconhecido: {job_type}")
        logger.info("Tipos válidos: historical, stream, load-reference, clean, all")
        sys.exit(1)

    # Executa o comando
    exit_code = run_command(cmd)
    if exit_code != 0:
        logger.error(f"Job falhou com código {exit_code}")
        sys.exit(exit_code)

    logger.info("Job concluído com sucesso!")


if __name__ == "__main__":
    main()
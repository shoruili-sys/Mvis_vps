#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# Helper - Inicia o MT5 via GE-Proton com Wine Wayland
# Uso: /start_mt5.sh
# ═══════════════════════════════════════════════════════════════════

set -e

PROTON_DIR="${PROTON_DIR:-/proton}"
PREFIX="${STEAM_COMPAT_DATA_PATH:-${HOME}/proton_prefix}"
MT5_EXE="${PREFIX}/pfx/drive_c/Program Files/MetaTrader 5/terminal64.exe"

if [ ! -x "${PROTON_DIR}/proton" ]; then
    echo "❌ Proton não encontrado em ${PROTON_DIR}/proton"
    exit 1
fi

if [ ! -f "${MT5_EXE}" ]; then
    echo "❌ MT5 não instalado em:"
    echo "   ${MT5_EXE}"
    echo ""
    echo "Instale primeiro:"
    echo "  ${PROTON_DIR}/proton run /home/\${USER_NAME}/mt5_installer/mt5setup.exe"
    exit 1
fi

echo "▶ Iniciando MetaTrader 5 (Wine Wayland)..."
exec "${PROTON_DIR}/proton" run "${MT5_EXE}"

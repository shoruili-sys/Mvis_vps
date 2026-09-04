#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# MetaTrader 5 - Start Script (VPS com Xvfb + VNC)
#
# Sobe um display virtual (Xvfb), inicia VNC pra acesso remoto
# e abre shell. Configurado pra rodar em VPS sem GPU/Wayland.
# ═══════════════════════════════════════════════════════════════════

set -uo pipefail

: "${PROTON_DIR:=/proton}"
: "${STEAM_COMPAT_DATA_PATH:=${HOME}/proton_prefix}"
: "${STEAM_COMPAT_CLIENT_INSTALL_PATH:=/proton}"
: "${USER_NAME:=${APP_USER:-$(whoami)}}"
: "${VNC_PORT:=5900}"
: "${NOVNC_PORT:=6080}"
: "${DISPLAY:=:0}"
: "${VNC_PASSWORD:=mt5vps}"
: "${VNC_RESOLUTION:=1920x1080x24}"

export STEAM_COMPAT_DATA_PATH
export STEAM_COMPAT_CLIENT_INSTALL_PATH
export DISPLAY

# ═══════════════════════════════════════════════════════════════════
# X11 + Wine
# ═══════════════════════════════════════════════════════════════════

# Em VPS, sem Wayland. Usa X11 via Xvfb (display virtual).
export WINEDPI="${WINEDPI:-96}"
export WINE_DPI_AWARENESS=1
export WINEESYNC=1
export WINEFSYNC=1

# Force WineD3D (OpenGL) - crítico pro WebView2
export PROTON_USE_WINED3D=1
export PROTON_USE_DXVK=0
export PROTON_NO_D3D11=0
export WINE_D3D_CONFIG="renderer=gl"
export WINEDLLOVERRIDES="d3d11=b,dxgi=b,d3d10core=b,d3d9=b"

# Sem Wayland
unset WAYLAND_DISPLAY
export XDG_SESSION_TYPE=x11

# Wine prefix
export WINEPREFIX="${STEAM_COMPAT_DATA_PATH}/pfx"

mkdir -p "${STEAM_COMPAT_DATA_PATH}" "/home/${USER_NAME}/proton_logs" "${WINEPREFIX}"

# ═══════════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════════

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   MetaTrader 5 - VPS (Xvfb + VNC + noVNC)                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo ">>> PROTON_DIR         = ${PROTON_DIR}"
echo ">>> STEAM_COMPAT_PATH  = ${STEAM_COMPAT_DATA_PATH}"
echo ">>> DISPLAY            = ${DISPLAY} (Xvfb)"
echo ">>> WINEDPI            = ${WINEDPI}"
echo ">>> VNC_PORT           = ${VNC_PORT}"
echo ">>> NOVNC_PORT         = ${NOVNC_PORT}"
echo ">>> VNC_RESOLUTION     = ${VNC_RESOLUTION}"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Inicia Xvfb (display virtual)
# ═══════════════════════════════════════════════════════════════════

if ! pgrep -f "Xvfb :0" > /dev/null 2>&1; then
    echo "▶ Iniciando Xvfb (display virtual ${DISPLAY})..."
    Xvfb ${DISPLAY} -screen 0 ${VNC_RESOLUTION} -ac +extension GLX +render -noreset &
    sleep 2
fi

# Verifica se Xvfb tá rodando
if ! pgrep -f "Xvfb :0" > /dev/null 2>&1; then
    echo "❌ Xvfb falhou ao iniciar"
    exit 1
fi
echo "✓ Xvfb rodando em ${DISPLAY}"

# ═══════════════════════════════════════════════════════════════════
# Inicia x11vnc (VNC server)
# ═══════════════════════════════════════════════════════════════════

if ! pgrep -f "x11vnc" > /dev/null 2>&1; then
    echo "▶ Iniciando x11vnc na porta ${VNC_PORT}..."
    
    # Cria/atualiza senha do VNC
    mkdir -p /home/${USER_NAME}/.vnc
    x11vnc -storepasswd "${VNC_PASSWORD}" /home/${USER_NAME}/.vnc/passwd 2>/dev/null || \
        echo "${VNC_PASSWORD}" > /home/${USER_NAME}/.vnc/passwd
    
    # Inicia x11vnc
    x11vnc -display ${DISPLAY} \
           -rfbport ${VNC_PORT} \
           -rfbauth /home/${USER_NAME}/.vnc/passwd \
           -forever \
           -shared \
           -noxdamage \
           -bg \
           -o /home/${USER_NAME}/logs/x11vnc.log 2>/dev/null
    sleep 1
fi

if pgrep -f "x11vnc" > /dev/null 2>&1; then
    echo "✓ x11vnc rodando (porta ${VNC_PORT}, senha: ${VNC_PASSWORD})"
else
    echo "⚠  x11vnc não está rodando (VNC inacessível)"
fi

# ═══════════════════════════════════════════════════════════════════
# Inicia noVNC (acesso web ao VNC)
# ═══════════════════════════════════════════════════════════════════

if ! pgrep -f "websockify" > /dev/null 2>&1; then
    echo "▶ Iniciando noVNC na porta ${NOVNC_PORT}..."
    
    # Inicia websockify pra expor VNC como web
    websockify --web=/usr/share/novnc ${NOVNC_PORT} localhost:${VNC_PORT} &
    sleep 1
fi

if pgrep -f "websockify" > /dev/null 2>&1; then
    echo "✓ noVNC rodando (porta ${NOVNC_PORT})"
    echo "  Acesse: http://localhost:${NOVNC_PORT}/vnc.html"
else
    echo "⚠  noVNC não está rodando"
fi

# ═══════════════════════════════════════════════════════════════════
# Valida Proton
# ═══════════════════════════════════════════════════════════════════

if [ ! -x "${PROTON_DIR}/proton" ]; then
    echo ""
    echo "❌ ERRO: binário do Proton não encontrado em ${PROTON_DIR}/proton"
    exit 1
fi
echo ""
echo "✓ GE-Proton OK"

# ═══════════════════════════════════════════════════════════════════
# INSTRUÇÕES
# ═══════════════════════════════════════════════════════════════════

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Para instalar o MT5 (primeira vez):"
echo "  1. Coloque o instalador em /home/${USER_NAME}/mt5_installer/mt5setup.exe"
echo "     (faça isso no host, via docker cp ou volume mount)"
echo "  2. Rode:"
echo "     /proton/proton run /home/${USER_NAME}/mt5_installer/mt5setup.exe"
echo ""
echo "Para iniciar o MT5 depois de instalado:"
echo "  /start_mt5.sh"
echo ""
echo "Acesso remoto:"
echo "  VNC:    localhost:${VNC_PORT}  (senha: ${VNC_PASSWORD})"
echo "  Web:    http://localhost:${NOVNC_PORT}/vnc.html"
echo ""
echo "  No Coolify, expõe as portas ${VNC_PORT} e ${NOVNC_PORT}."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Monitora processos em background
while true; do
    sleep 60
    if ! pgrep -f "Xvfb :0" > /dev/null 2>&1; then
        echo "⚠  Xvfb morreu! Reiniciando..."
        Xvfb ${DISPLAY} -screen 0 ${VNC_RESOLUTION} -ac +extension GLX +render -noreset &
    fi
done

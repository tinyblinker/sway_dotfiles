#!/usr/bin/env bash
# Unified entry point for sing-box deployment. Usage: manage.sh <command>
set -euo pipefail
source "$(dirname "$0")/tools/common.sh"
T="$(cd "$(dirname "$0")/tools" && pwd)"

usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  check           Show environment info
  setup           Install + generate + deploy + start on both hosts
  install-server  Install sing-box on the server
  install-client  Install sing-box on the client
  gen-config      Generate client and server config.json
  deploy-server   Upload and validate server config
  deploy-client   Upload and validate client config
  start-server    Start the server service
  stop-server     Stop the server service
  restart-server  Restart the server service
  start-client    Start the client service
  stop-client     Stop the client service
  restart-client  Restart the client service
  start-all       Start both services
  stop-all        Stop both services
  restart-all     Restart both services
  status          Show status and version on both hosts
  logs            Show logs (logs [server|client|both] [lines])
  uninstall       Uninstall sing-box from both hosts
EOF
}

cmd="${1:-}"
[ -z "$cmd" ] && { usage; exit 0; }

case "$cmd" in
  check)
    log "Client: $CLIENT_HOST ($CLIENT_USER)"
    log "Server: $SERVER_HOST ($SERVER_USER)"
    log "Domain: $DOMAIN -> port $SERVER_LISTEN_PORT"
    log "Version: $SINGBOX_VERSION"
    ;;
  setup)
    "$T/install_server.sh"
    "$T/install_client.sh"
    "$T/gen_config.sh"
    "$T/deploy_server.sh"
    "$T/deploy_client.sh"
    "$T/start_server.sh"
    "$T/start_client.sh"
    "$T/status.sh"
    ;;
  install-server)  "$T/install_server.sh" ;;
  install-client)  "$T/install_client.sh" ;;
  gen-config)      "$T/gen_config.sh" ;;
  deploy-server)   "$T/deploy_server.sh" ;;
  deploy-client)   "$T/deploy_client.sh" ;;
  start-server)    "$T/start_server.sh" ;;
  stop-server)     "$T/stop_server.sh" ;;
  restart-server)  "$T/restart_server.sh" ;;
  start-client)    "$T/start_client.sh" ;;
  stop-client)     "$T/stop_client.sh" ;;
  restart-client)  "$T/restart_client.sh" ;;
  start-all)       "$T/start_server.sh"; "$T/start_client.sh" ;;
  stop-all)        "$T/stop_server.sh"; "$T/stop_client.sh" ;;
  restart-all)     "$T/restart_server.sh"; "$T/restart_client.sh" ;;
  status)          "$T/status.sh" ;;
  logs)            "$T/logs.sh" "${2:-both}" "${3:-100}" ;;
  uninstall)       "$T/uninstall.sh" ;;
  *)
    log_err "Unknown command: $cmd"
    usage
    exit 1
    ;;
esac

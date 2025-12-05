api_start() { node $SCRIPT_DIR/api/server.js & echo "API running at http://localhost:4000"; }
api_stop() { pkill -f server.js; echo "API stopped"; }

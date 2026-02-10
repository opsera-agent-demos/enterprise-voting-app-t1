# ════════════════════════════════════════════════════════════════════════════════
# NEW RELIC APM CONFIGURATION
#
# Agent is auto-initialized by newrelic-admin run-program (see Dockerfile)
# Configuration loaded from newrelic.ini with environment variable interpolation
# ════════════════════════════════════════════════════════════════════════════════
import os

# Application version - Explicit NR notice_error + parallel burst sim v25
APP_VERSION = "2026.02.10-v25"

# Log New Relic configuration status at startup
_nr_license = os.getenv('NEW_RELIC_LICENSE_KEY')
_nr_app = os.getenv('NEW_RELIC_APP_NAME', 'vote-app')
_nr_host = os.getenv('NEW_RELIC_HOST', 'collector.newrelic.com')
if _nr_license:
    print(f'[New Relic] Agent enabled - App: {_nr_app}, Collector: {_nr_host}')
else:
    print('[New Relic] Agent disabled (no license key)')

# ════════════════════════════════════════════════════════════════════════════════

from flask import Flask, render_template, request, make_response, g, jsonify
from redis import Redis
import socket
import random
import json
import logging
import traceback

# New Relic explicit error reporting - critical for reliable error capture
try:
    import newrelic.agent
    NR_AVAILABLE = True
except ImportError:
    NR_AVAILABLE = False

option_a = os.getenv('OPTION_A', "Cats")
option_b = os.getenv('OPTION_B', "Dogs")
hostname = socket.gethostname()

app = Flask(__name__)

gunicorn_error_logger = logging.getLogger('gunicorn.error')
app.logger.handlers.extend(gunicorn_error_logger.handlers)
app.logger.setLevel(logging.INFO)

# ═══════════════════════════════════════════════════════════════════════════════
# ERROR SIMULATION - Simple ON/OFF toggle for canary rollback testing
# ═══════════════════════════════════════════════════════════════════════════════

# Simple global state - errors OFF by default
ERROR_SIM_ENABLED = False

def get_redis():
    if not hasattr(g, 'redis'):
        redis_host = os.getenv('REDIS_HOST', 'redis')
        redis_port = int(os.getenv('REDIS_PORT', 6379))
        g.redis = Redis(host=redis_host, port=redis_port, db=0, socket_timeout=5)
    return g.redis

@app.route("/api/error-sim", methods=['GET'])
def get_error_sim_status():
    """Get current error simulation status"""
    global ERROR_SIM_ENABLED
    return jsonify({'enabled': ERROR_SIM_ENABLED})

@app.route("/api/error-sim", methods=['POST'])
def toggle_error_sim():
    """Toggle error simulation ON/OFF"""
    global ERROR_SIM_ENABLED
    ERROR_SIM_ENABLED = not ERROR_SIM_ENABLED
    status = "ENABLED" if ERROR_SIM_ENABLED else "DISABLED"
    app.logger.info('Error simulation %s', status)
    return jsonify({'enabled': ERROR_SIM_ENABLED})

@app.route("/health", methods=['GET'])
def health():
    """Health check - always returns 200"""
    return jsonify({'status': 'healthy', 'hostname': hostname})

def _report_simulated_error(error_msg):
    """Report error explicitly to New Relic AND return a 500 response.
    
    Using notice_error() ensures NR captures it as an error transaction
    regardless of Flask/WSGI middleware ordering. Returns a proper 500
    response instead of raising an unhandled exception (avoids gunicorn
    worker restarts and ensures consistent HTTP 500 status).
    """
    exc = Exception(error_msg)
    app.logger.error('SIMULATED ERROR: %s', error_msg)

    if NR_AVAILABLE:
        # Explicitly record the error in New Relic - this is the reliable path
        newrelic.agent.notice_error(error=exc)
        # Also add a custom attribute so we can filter in NR dashboards
        newrelic.agent.add_custom_parameter('simulated_error', True)
        newrelic.agent.add_custom_parameter('error_source', 'error_simulation')

    return error_msg, 500


@app.route("/", methods=['POST','GET'])
def hello():
    global ERROR_SIM_ENABLED

    voter_id = request.cookies.get('voter_id')
    if not voter_id:
        voter_id = hex(random.getrandbits(64))[2:-1]

    vote = None

    if request.method == 'POST':
        # Header-based error injection (used by GHA error-rate simulation script)
        if request.headers.get('X-Simulate-Error') == 'true':
            return _report_simulated_error(
                'Simulated Error: error rate simulation via GHA script'
            )

        # If error simulation is ON, return 500 (captured by New Relic)
        if ERROR_SIM_ENABLED:
            return _report_simulated_error(
                'Simulated Error: Canary rollback testing'
            )

        # Normal vote processing
        redis = get_redis()
        vote = request.form['vote']
        app.logger.info('Received vote for %s', vote)
        data = json.dumps({'voter_id': voter_id, 'vote': vote})
        redis.rpush('votes', data)

    resp = make_response(render_template(
        'index.html',
        option_a=option_a,
        option_b=option_b,
        hostname=hostname,
        vote=vote,
    ))
    resp.set_cookie('voter_id', voter_id)
    return resp


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80, debug=True, threaded=True)

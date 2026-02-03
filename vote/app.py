from flask import Flask, render_template, request, make_response, g, jsonify
from redis import Redis
import os
import socket
import random
import json
import logging
import threading
import time

option_a = os.getenv('OPTION_A', "Cats")
option_b = os.getenv('OPTION_B', "Dogs")
hostname = socket.gethostname()

app = Flask(__name__)

gunicorn_error_logger = logging.getLogger('gunicorn.error')
app.logger.handlers.extend(gunicorn_error_logger.handlers)
app.logger.setLevel(logging.INFO)

# ═══════════════════════════════════════════════════════════════════════════════
# ERROR SIMULATION FOR CANARY ROLLBACK TESTING
# ═══════════════════════════════════════════════════════════════════════════════

class SimulatedError(Exception):
    """Custom exception for simulated errors tracked by New Relic APM"""
    pass

class ErrorSimulator:
    """Thread-safe error simulation state manager"""

    def __init__(self):
        self._lock = threading.Lock()
        self._enabled = os.getenv('ERROR_SIM_ENABLED', 'false').lower() == 'true'
        self._error_rate = float(os.getenv('ERROR_SIM_RATE', '0.5'))
        self._auto_disable_seconds = int(os.getenv('ERROR_SIM_AUTO_DISABLE_SECONDS', '300'))
        self._enabled_at = None
        self._error_count = 0
        self._request_count = 0

    @property
    def enabled(self):
        with self._lock:
            if self._enabled and self._enabled_at:
                elapsed = time.time() - self._enabled_at
                if elapsed > self._auto_disable_seconds:
                    self._enabled = False
                    self._enabled_at = None
                    app.logger.info('Error simulation auto-disabled after %d seconds', self._auto_disable_seconds)
            return self._enabled

    @property
    def error_rate(self):
        with self._lock:
            return self._error_rate

    @property
    def stats(self):
        with self._lock:
            return {
                'enabled': self._enabled,
                'error_rate': self._error_rate,
                'auto_disable_seconds': self._auto_disable_seconds,
                'enabled_at': self._enabled_at,
                'error_count': self._error_count,
                'request_count': self._request_count,
                'time_remaining': max(0, self._auto_disable_seconds - (time.time() - self._enabled_at)) if self._enabled and self._enabled_at else 0
            }

    def enable(self):
        with self._lock:
            self._enabled = True
            self._enabled_at = time.time()
            self._error_count = 0
            self._request_count = 0
            app.logger.info('Error simulation ENABLED (rate=%.0f%%, auto-disable=%ds)',
                          self._error_rate * 100, self._auto_disable_seconds)

    def disable(self):
        with self._lock:
            self._enabled = False
            self._enabled_at = None
            app.logger.info('Error simulation DISABLED')

    def should_error(self):
        """Determine if this request should simulate an error"""
        if not self.enabled:
            return False

        with self._lock:
            self._request_count += 1
            if random.random() < self._error_rate:
                self._error_count += 1
                return True
            return False

# Global error simulator instance
error_sim = ErrorSimulator()

def get_redis():
    if not hasattr(g, 'redis'):
        redis_host = os.getenv('REDIS_HOST', 'redis')
        redis_port = int(os.getenv('REDIS_PORT', 6379))
        g.redis = Redis(host=redis_host, port=redis_port, db=0, socket_timeout=5)
    return g.redis

# ═══════════════════════════════════════════════════════════════════════════════
# ERROR SIMULATION API ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════════════

@app.route("/api/error-sim", methods=['GET'])
def get_error_sim_status():
    """Get current error simulation status"""
    return jsonify(error_sim.stats)

@app.route("/api/error-sim", methods=['POST'])
def toggle_error_sim():
    """Enable or disable error simulation"""
    data = request.get_json() or {}
    action = data.get('action', 'toggle')

    if action == 'enable':
        error_sim.enable()
    elif action == 'disable':
        error_sim.disable()
    else:  # toggle
        if error_sim.enabled:
            error_sim.disable()
        else:
            error_sim.enable()

    return jsonify(error_sim.stats)

@app.route("/health", methods=['GET'])
def health():
    """Health check endpoint - always returns 200 (unaffected by error simulation)"""
    return jsonify({'status': 'healthy', 'hostname': hostname})

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN APPLICATION ROUTES
# ═══════════════════════════════════════════════════════════════════════════════

@app.route("/", methods=['POST','GET'])
def hello():
    voter_id = request.cookies.get('voter_id')
    if not voter_id:
        voter_id = hex(random.getrandbits(64))[2:-1]

    vote = None
    simulated_error = False

    if request.method == 'POST':
        # Check for simulated error BEFORE processing vote
        if error_sim.should_error():
            simulated_error = True
            app.logger.error('SIMULATED ERROR: Vote processing failed (error simulation active)')
            # Raise exception for New Relic to track
            raise SimulatedError('Simulated error for canary rollback testing')

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
        error_sim_enabled=error_sim.enabled,
        error_sim_stats=error_sim.stats,
    ))
    resp.set_cookie('voter_id', voter_id)
    return resp

@app.errorhandler(SimulatedError)
def handle_simulated_error(error):
    """Handle simulated errors - return 500 with error message"""
    app.logger.error('SimulatedError caught: %s', str(error))
    return jsonify({
        'error': 'Simulated Error',
        'message': str(error),
        'type': 'SimulatedError',
        'hostname': hostname
    }), 500


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80, debug=True, threaded=True)

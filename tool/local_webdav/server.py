"""Run the private LAN WebDAV endpoint; credentials stay in process memory."""

import base64
import binascii
import hmac
import json
import logging
import os
from pathlib import Path
import signal
import sys

from cheroot.ssl.builtin import BuiltinSSLAdapter
from cheroot.wsgi import Server
from wsgidav.default_conf import DEFAULT_CONFIG
from wsgidav.http_authenticator import HTTPAuthenticator
from wsgidav.wsgidav_app import WsgiDAVApp

from atomic_upload import AtomicConditionalPut


def create_dav_app(data, staging, username, password, *, host="localhost", port=8080):
    middleware = list(DEFAULT_CONFIG["middleware_stack"])
    middleware.insert(middleware.index(HTTPAuthenticator) + 1, AtomicConditionalPut)
    return WsgiDAVApp(
        {
            "host": host,
            "port": port,
            "provider_mapping": {"/dav": str(data)},
            "middleware_stack": middleware,
            "atomic_upload": {"root": str(data), "staging": str(staging)},
            "http_authenticator": {
                "accept_basic": True,
                "accept_digest": False,
                "default_to_digest": False,
            },
            "simple_dc": {
                "user_mapping": {
                    "*": {username: {"password": password, "roles": []}}
                }
            },
            "dir_browser": {"enable": False},
            "verbose": 0,
            "logging": {"enable": False},
        }
    )


def credential_match_flags(authorization, username, password):
    """Return comparison booleans, never the submitted or configured values."""
    try:
        scheme, token = authorization.split(" ", 1)
        if scheme.lower() != "basic":
            return {"basicAuth": False}
        decoded = base64.b64decode(token, validate=True).decode("utf-8")
        supplied_user, separator, supplied_password = decoded.partition(":")
        if not separator:
            return {"basicAuth": False}
        return {
            "basicAuth": True,
            "usernameMatches": hmac.compare_digest(supplied_user.encode(), username.encode()),
            "passwordMatches": hmac.compare_digest(supplied_password.encode(), password.encode()),
        }
    except (ValueError, binascii.Error, UnicodeError):
        return {"basicAuth": False}


def restrict_clients(application, allowed_addresses, *, on_denied=None, diagnose_auth=None):
    def restricted(environ, start_response):
        def respond(status, headers, exc_info=None):
            code = status.split(" ", 1)[0]
            if on_denied is not None and code in ("401", "403"):
                # Only status and socket source address: never log headers,
                # paths, credentials or request/response bodies.
                flags = diagnose_auth(environ.get("HTTP_AUTHORIZATION", "")) \
                    if code == "401" and diagnose_auth is not None else {}
                on_denied(code, environ.get("REMOTE_ADDR"), flags)
            if exc_info is None:
                return start_response(status, headers)
            return start_response(status, headers, exc_info)

        if environ.get("REMOTE_ADDR") not in allowed_addresses:
            body = b"This private WebDAV endpoint is limited to its paired devices."
            respond("403 Forbidden", [
                ("Content-Type", "text/plain; charset=utf-8"),
                ("Content-Length", str(len(body))),
            ])
            return [body]
        return application(environ, respond)

    return restricted


def main() -> None:
    if len(sys.argv) != 2:
        raise ValueError("Pass the local service configuration file.")
    config_path = Path(sys.argv[1]).resolve(strict=True)
    state = config_path.parent
    config = json.loads(config_path.read_text(encoding="utf-8-sig"))
    password = os.environ.pop("MYLEDGER_LOCAL_DAV_PASSWORD", "")
    if len(password) < 20:
        raise ValueError("Set MYLEDGER_LOCAL_DAV_PASSWORD in the user environment.")

    data = (state / "data").resolve(strict=True)
    logging.disable(logging.INFO)
    app = create_dav_app(
        data, state / "uploads", config["username"], password,
        host=config["host"], port=config["port"],
    )
    def report_denied(code, address, flags):
        print(json.dumps({"httpStatus": code, "client": address, **flags}),
              file=sys.stderr, flush=True)

    paired_app = restrict_clients(
        app, {config["host"], config["phone"]}, on_denied=report_denied,
        diagnose_auth=lambda header: credential_match_flags(header, config["username"], password),
    )
    server = Server((config["host"], config["port"]), paired_app, numthreads=1)
    server.ssl_adapter = BuiltinSSLAdapter(
        str(state / "certificates" / "server.pem"),
        str(state / "certificates" / "server.key"),
    )
    signal.signal(signal.SIGTERM, lambda *_: server.stop())
    try:
        server.start()
    finally:
        server.stop()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
    except Exception:
        # Configuration errors must not serialize passwords or HTTP headers.
        print("Local WebDAV startup failed; check paths, port and user environment.", file=sys.stderr)
        sys.exit(1)

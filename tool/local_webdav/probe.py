"""Check an isolated probe directory against the actual LAN DAV service."""

import base64
from concurrent.futures import ThreadPoolExecutor
import http.client
import json
import os
from pathlib import Path
import ssl
import sys
from uuid import uuid4


def main() -> None:
    state = Path(sys.argv[1]).resolve(strict=True)
    config = json.loads((state / "config.json").read_text(encoding="utf-8-sig"))
    password = os.environ["MYLEDGER_LOCAL_DAV_PASSWORD"]
    authorization = "Basic " + base64.b64encode(
        (config["username"] + ":" + password).encode()
    ).decode()
    context = ssl.create_default_context(cafile=state / "certificates" / "ca.pem")
    directory = "/dav/.local-probe-" + uuid4().hex + "/"

    def request(method, path, body=None, headers=None, authenticated=True):
        connection = http.client.HTTPSConnection(
            config["host"], config["port"], context=context, timeout=10
        )
        actual_headers = {"Authorization": authorization} if authenticated else {}
        actual_headers.update(headers or {})
        try:
            connection.request(method, path, body=body, headers=actual_headers)
            response = connection.getresponse()
            return response.status, response.read()
        finally:
            connection.close()

    assert request("PROPFIND", "/dav/", authenticated=False)[0] == 401
    assert request("MKCOL", directory)[0] == 201
    successful_rounds = 0
    try:
        for index in range(10):
            name = directory + str(index) + ".json"
            try:
                with ThreadPoolExecutor(max_workers=2) as executor:
                    results = list(executor.map(
                        lambda body: request("PUT", name, body, {"If-None-Match": "*"})[0],
                        [b"first", b"second"],
                    ))
                assert sorted(results) == [201, 412], results
                status, body = request("GET", name)
                assert status == 200 and body in (b"first", b"second")
                successful_rounds += 1
            finally:
                assert request("DELETE", name)[0] in (200, 204, 404)
        assert request("PROPFIND", directory, headers={"Depth": "1"})[0] == 207
    finally:
        assert request("DELETE", directory)[0] in (200, 204, 404)
    result = {
        "tlsVerified": True,
        "anonymousStatus": 401,
        "concurrentConditionalPutRounds": successful_rounds,
        "eachRoundStatus": [201, 412],
        "readbackVerified": True,
        "propfindStatus": 207,
        "probeCleanup": True,
    }
    (state / "protocol-probe.json").write_text(json.dumps(result), encoding="utf-8")
    print(json.dumps(result))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Never print request objects or headers from authentication failures.
        print("Local DAV protocol probe failed; preserve service logs for diagnosis.", file=sys.stderr)
        sys.exit(1)

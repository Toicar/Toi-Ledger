import base64
import hashlib
import http.client
import json
import os
from pathlib import Path
import socket
import ssl
import subprocess
import sys
import tempfile
import time
import unittest

from cryptography import x509
import provision


class ProvisionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="myledger-setup-test-")
        self.state = Path(self.temp.name).resolve()
        self.assertEqual(self.state.parent, Path(tempfile.gettempdir()).resolve())
        self.addCleanup(self.temp.cleanup)

    def test_public_document_has_no_secret_and_keys_are_not_overwritten(self):
        pairing, fingerprint = provision.provision(self.state, "192.168.1.20", "192.168.1.30")
        self.assertEqual(set(pairing), {"version", "endpoint", "username", "caPem"})
        self.assertEqual(fingerprint, hashlib.sha256(pairing["caPem"].encode()).hexdigest())
        ca = x509.load_pem_x509_certificate(pairing["caPem"].encode())
        self.assertTrue(ca.extensions.get_extension_for_class(x509.BasicConstraints).value.ca)
        cert = x509.load_pem_x509_certificate((self.state / "certificates/server.pem").read_bytes())
        self.assertEqual(str(cert.extensions.get_extension_for_class(x509.SubjectAlternativeName).value[0].value), "192.168.1.20")
        before = (self.state / "certificates/ca.key").read_bytes()
        with self.assertRaises(FileExistsError):
            provision.provision(self.state, "192.168.1.20", "192.168.1.30")
        self.assertEqual(before, (self.state / "certificates/ca.key").read_bytes())
        self.assertNotIn("PRIVATE", (self.state / "service-setup.json").read_text())

    def test_invalid_network_is_rejected_before_any_files_are_created(self):
        with self.assertRaises(ValueError):
            provision.provision(self.state, "8.8.8.8", "192.168.1.30")
        self.assertEqual(list(self.state.iterdir()), [])

    def test_generated_https_service_checks_auth_and_atomic_writes(self):
        with socket.socket() as candidate:
            candidate.bind(("127.0.0.1", 0))
            port = candidate.getsockname()[1]
        provision.provision(self.state, "127.0.0.1", "127.0.0.1", port)
        environment = dict(os.environ, MYLEDGER_LOCAL_DAV_PASSWORD="synthetic-setup-password-123")
        process = subprocess.Popen([sys.executable, str(Path(__file__).with_name("server.py")), str(self.state / "config.json")],
                                   env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        def stop():
            process.terminate()
            process.wait(timeout=10)
        self.addCleanup(stop)
        context = ssl.create_default_context(cafile=str(self.state / "certificates/ca.pem"))
        for _ in range(50):
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=.1):
                    break
            except OSError:
                if process.poll() is not None:
                    self.fail("Generated service exited before listening")
                time.sleep(.1)
        connection = http.client.HTTPSConnection("127.0.0.1", port, context=context, timeout=5)
        self.addCleanup(connection.close)
        def request(method, body=None, headers=None):
            connection.request(method, "/dav/setup-check.txt", body, headers or {})
            result = connection.getresponse()
            data = result.read()
            return result.status, data
        self.assertEqual(request("GET")[0], 401)
        credentials = base64.b64encode(b"myledger:synthetic-setup-password-123").decode()
        headers = {"Authorization": f"Basic {credentials}", "If-None-Match": "*"}
        self.assertEqual(request("PUT", b"first", headers)[0], 201)
        self.assertEqual(request("PUT", b"second", headers)[0], 412)
        headers.pop("If-None-Match")
        self.assertEqual(request("GET", headers=headers), (200, b"first"))
        self.assertEqual(request("DELETE", headers=headers)[0], 204)


if __name__ == "__main__":
    unittest.main()

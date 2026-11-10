import base64
from concurrent.futures import ThreadPoolExecutor
import http.client
import io
import logging
import os
from pathlib import Path
import shutil
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
import unittest
from wsgiref.util import setup_testing_defaults

import server


class AtomicUploadTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix=".atomic-upload-test-",
                                                 dir=Path(__file__).parent)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "data"
        self.root.mkdir()
        self.staging = Path(self.temp.name) / "uploads"
        self.addCleanup(logging.disable, logging.root.manager.disable)
        logging.disable(logging.CRITICAL)
        self.app = server.create_dav_app(self.root, self.staging,
                                         "test-user", "test-password")

    def request(self, method, path, body=b"", headers=None, authenticated=True,
                stream=None):
        environ = {}
        setup_testing_defaults(environ)
        environ.update({
            "REQUEST_METHOD": method,
            "PATH_INFO": path,
            "CONTENT_LENGTH": str(len(body)),
            "wsgi.input": stream if stream is not None else io.BytesIO(body),
        })
        if authenticated:
            credentials = base64.b64encode(b"test-user:test-password").decode("ascii")
            environ["HTTP_AUTHORIZATION"] = f"Basic {credentials}"
        for key, value in (headers or {}).items():
            if value is None:
                environ.pop(key, None)
            else:
                environ[key] = value
        responses = []
        result = self.app(environ, lambda status, response_headers, exc_info=None:
                          responses.append((int(status.split()[0]), dict(response_headers))))
        try:
            response_body = b"".join(result)
        finally:
            if hasattr(result, "close"):
                result.close()
        return responses[0][0], responses[0][1], response_body

    def test_interrupted_body_never_publishes_a_final_file(self):
        self.request("PUT", "/dav/interrupted.json", b'{"incomplete":', {
            "CONTENT_LENGTH": "100",
            "HTTP_IF_NONE_MATCH": "*",
        })
        self.assertFalse((self.root / "interrupted.json").exists())

    def test_retry_after_interruption_publishes_exact_complete_content(self):
        content = b'{"complete":true}'
        self.request("PUT", "/dav/retry.json", b"partial", {
            "CONTENT_LENGTH": str(len(content)), "HTTP_IF_NONE_MATCH": "*",
        })
        status, _, _ = self.request("PUT", "/dav/retry.json", content,
                                    {"HTTP_IF_NONE_MATCH": "*"})
        self.assertEqual(status, 201)
        self.assertEqual((self.root / "retry.json").read_bytes(), content)

    def test_concurrent_conditional_writers_create_once_without_overwrite(self):
        barrier = threading.Barrier(2)

        class RacingInput(io.BytesIO):
            def read(self, size):
                barrier.wait(timeout=5)
                return super().read(size)

        def upload(content):
            return self.request("PUT", "/dav/concurrent.json", content,
                                {"HTTP_IF_NONE_MATCH": "*"},
                                stream=RacingInput(content))[0], content

        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(upload, (b"first", b"second")))
        self.assertEqual(sorted(status for status, _ in results), [201, 412])
        winner = next(content for status, content in results if status == 201)
        self.assertEqual((self.root / "concurrent.json").read_bytes(), winner)
        self.assertEqual(list(self.staging.iterdir()), [])

    def test_existing_file_is_unchanged(self):
        (self.root / "existing.json").write_bytes(b"original")
        status, _, _ = self.request("PUT", "/dav/existing.json", b"replacement",
                                    {"HTTP_IF_NONE_MATCH": "*"})
        self.assertEqual(status, 412)
        self.assertEqual((self.root / "existing.json").read_bytes(), b"original")

    def test_nonconditional_upload_is_rejected(self):
        for condition in (None, '"etag"', 'W/"*"', "*, other"):
            with self.subTest(condition=condition):
                status, _, _ = self.request("PUT", "/dav/unsafe.json", b"data", {
                    "HTTP_IF_NONE_MATCH": condition,
                })
                self.assertEqual(status, 428)
                self.assertFalse((self.root / "unsafe.json").exists())

    def test_invalid_length_rejected_without_reading_body(self):
        class UnreadableInput:
            def read(self, size):
                raise AssertionError("A rejected upload must not read its body")

        for length, expected in ((None, 411), ("", 411), ("-1", 400),
                                 ("nan", 400), ("1.5", 400), ("+2", 400),
                                 ("999999999999999999999999", 413),
                                 (str(128 * 1024 + 1), 413)):
            with self.subTest(length=length):
                status, _, _ = self.request("PUT", "/dav/length.json", headers={
                    "CONTENT_LENGTH": length, "HTTP_IF_NONE_MATCH": "*",
                }, stream=UnreadableInput())
                self.assertEqual(status, expected)
                self.assertFalse((self.root / "length.json").exists())

    def test_maximum_length_is_accepted(self):
        content = b"x" * (128 * 1024)
        status, _, _ = self.request("PUT", "/dav/maximum.json", content,
                                    {"HTTP_IF_NONE_MATCH": "*"})
        self.assertEqual(status, 201)
        self.assertEqual((self.root / "maximum.json").read_bytes(), content)

    def test_authentication_precedes_any_upload(self):
        for authenticated in (False, "wrong"):
            with self.subTest(authenticated=authenticated):
                headers = {"HTTP_IF_NONE_MATCH": "*"}
                if authenticated == "wrong":
                    headers["HTTP_AUTHORIZATION"] = "Basic d3Jvbmc6d3Jvbmc="
                status, _, _ = self.request("PUT", "/dav/unauthorized.json", b"data",
                                            headers, authenticated=authenticated)
                self.assertEqual(status, 401)
                self.assertFalse((self.root / "unauthorized.json").exists())
                self.assertFalse(self.staging.exists() and list(self.staging.iterdir()))

    def test_traversal_and_windows_path_aliases_are_rejected(self):
        paths = ("/dav/../escape.json", "/dav/./dot.json", "/dav//empty.json",
                 "/dav/back\\escape.json", "/dav/file.json:stream",
                 "/dav/space /file.json", "/dav/NUL.json", "/dav/trailing.")
        for path in paths:
            with self.subTest(path=path):
                status, _, _ = self.request("PUT", path, b"data",
                                            {"HTTP_IF_NONE_MATCH": "*"})
                self.assertEqual(status, 403)
        self.assertEqual(list(self.root.iterdir()), [])
        self.assertFalse((Path(self.temp.name) / "escape.json").exists())

    def test_symlink_or_junction_ancestor_is_rejected(self):
        outside = Path(self.temp.name) / "outside"
        outside.mkdir()
        link = self.root / "linked"
        try:
            os.symlink(outside, link, target_is_directory=True)
        except OSError:
            if os.name != "nt":
                raise
            import _winapi
            _winapi.CreateJunction(str(outside), str(link))
        status, _, _ = self.request("PUT", "/dav/linked/escape.json", b"data",
                                    {"HTTP_IF_NONE_MATCH": "*"})
        self.assertEqual(status, 403)
        self.assertEqual(list(outside.iterdir()), [])

    def test_missing_parent_and_directory_put_are_rejected(self):
        (self.root / "directory").mkdir()
        for path, expected in (("/dav/missing/file.json", 409),
                               ("/dav/directory", 405), ("/dav/directory/", 405),
                               ("/dav/", 405)):
            with self.subTest(path=path):
                status, _, _ = self.request("PUT", path, b"data",
                                            {"HTTP_IF_NONE_MATCH": "*"})
                self.assertEqual(status, expected)
        self.assertFalse((self.root / "missing").exists())

    def test_staging_is_private_until_complete_and_cleaned_afterwards(self):
        entered = threading.Event()
        release = threading.Event()

        class BlockedInput(io.BytesIO):
            def read(self, size):
                entered.set()
                if not release.wait(timeout=5):
                    raise TimeoutError("Test did not release upload")
                return super().read(size)

        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(self.request, "PUT", "/dav/pending.json", b"data",
                                     {"HTTP_IF_NONE_MATCH": "*"}, True,
                                     BlockedInput(b"data"))
            try:
                self.assertTrue(entered.wait(timeout=5))
                self.assertEqual(list(self.root.iterdir()), [])
                self.assertEqual(len(list(self.staging.iterdir())), 1)
                status, _, body = self.request("PROPFIND", "/dav/", headers={
                    "HTTP_DEPTH": "1",
                })
                self.assertEqual(status, 207)
                self.assertNotIn(b"pending.json", body)
                self.assertNotIn(b"uploads", body)
            finally:
                release.set()
            self.assertEqual(future.result(timeout=5)[0], 201)
        self.assertEqual(list(self.staging.iterdir()), [])

    def test_body_read_error_removes_staging_and_never_publishes(self):
        class DisconnectedInput:
            def read(self, size):
                raise ConnectionResetError("Simulated disconnect")

        status, _, _ = self.request("PUT", "/dav/disconnected.json", b"data",
                                    {"HTTP_IF_NONE_MATCH": "*"}, stream=DisconnectedInput())
        self.assertEqual(status, 400)
        self.assertFalse((self.root / "disconnected.json").exists())
        self.assertEqual(list(self.staging.iterdir()), [])

    def test_other_dav_methods_still_use_wsgidav(self):
        self.assertEqual(self.request("MKCOL", "/dav/folder")[0], 201)
        self.assertEqual(self.request("PUT", "/dav/folder/op.json", b"content",
                                      {"HTTP_IF_NONE_MATCH": "*"})[0], 201)
        self.assertEqual(self.request("GET", "/dav/folder/op.json")[2], b"content")
        self.assertEqual(self.request("PROPFIND", "/dav/folder", headers={
            "HTTP_DEPTH": "1",
        })[0], 207)
        self.assertEqual(self.request("DELETE", "/dav/folder/op.json")[0], 204)
        self.assertEqual(self.request("DELETE", "/dav/folder")[0], 204)

    def test_partial_and_encoded_puts_are_rejected(self):
        for header, value, expected in (("HTTP_CONTENT_RANGE", "bytes 0-3/10", 400),
                                        ("HTTP_CONTENT_ENCODING", "gzip", 415),
                                        ("HTTP_TRANSFER_ENCODING", "chunked", 400)):
            with self.subTest(header=header):
                status, _, _ = self.request("PUT", "/dav/partial.json", b"data", {
                    "HTTP_IF_NONE_MATCH": "*", header: value,
                })
                self.assertEqual(status, expected)
                self.assertFalse((self.root / "partial.json").exists())

    def _socket_disconnect_and_retry(self, ssl_adapter=None, context=None):
        completed = threading.Event()

        def observed_app(environ, start_response):
            try:
                yield from self.app(environ, start_response)
            finally:
                completed.set()

        listener = server.Server(("127.0.0.1", 0), observed_app, numthreads=2, timeout=2)
        listener.ssl_adapter = ssl_adapter
        default_error_log = listener.error_log

        def error_log(*args, **kwargs):
            # This test intentionally closes TLS without sending close_notify.
            if not isinstance(sys.exc_info()[1], ssl.SSLEOFError):
                default_error_log(*args, **kwargs)

        listener.error_log = error_log
        listener.prepare()
        port = listener.socket.getsockname()[1]
        worker = threading.Thread(target=listener.serve, daemon=True)
        worker.start()
        credentials = base64.b64encode(b"test-user:test-password").decode("ascii")
        headers = {"Authorization": f"Basic {credentials}", "If-None-Match": "*"}
        try:
            connection = socket.create_connection(("127.0.0.1", port), timeout=5)
            if context is not None:
                connection = context.wrap_socket(connection, server_hostname="localhost")
            with connection:
                connection.sendall((
                    "PUT /dav/socket.json HTTP/1.1\r\nHost: localhost\r\n"
                    f"Authorization: Basic {credentials}\r\n"
                    "If-None-Match: *\r\nContent-Length: 100\r\n"
                    "Connection: close\r\n\r\npartial"
                ).encode("ascii"))
                connection.shutdown(socket.SHUT_WR)
                try:
                    while connection.recv(8192):
                        pass
                except (OSError, ssl.SSLError):
                    pass
            self.assertTrue(completed.wait(timeout=5))
            self.assertFalse((self.root / "socket.json").exists())
            self.assertEqual(list(self.staging.iterdir()), [])

            if context is None:
                client = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
            else:
                client = http.client.HTTPSConnection("127.0.0.1", port,
                                                     context=context, timeout=5)
            try:
                content = b'{"complete":"after socket disconnect"}'
                client.request("PUT", "/dav/socket.json", content, headers)
                response = client.getresponse()
                self.assertEqual(response.status, 201)
                response.read()
                self.assertEqual((self.root / "socket.json").read_bytes(), content)
                client.request("GET", "/dav/socket.json", headers={
                    "Authorization": headers["Authorization"],
                })
                response = client.getresponse()
                self.assertEqual(response.status, 200)
                self.assertEqual(response.read(), content)
                client.request("PUT", "/dav/socket.json", b"overwrite", headers)
                response = client.getresponse()
                self.assertEqual(response.status, 412)
                response.read()
                self.assertEqual((self.root / "socket.json").read_bytes(), content)
            finally:
                client.close()
        finally:
            listener.stop()
            worker.join(timeout=5)
        self.assertFalse(worker.is_alive())

    def test_loopback_http_socket_disconnect_then_retry(self):
        self._socket_disconnect_and_retry()

    def test_loopback_tls_socket_disconnect_then_retry(self):
        openssl = shutil.which("openssl")
        git = shutil.which("git")
        if openssl is None and git is not None:
            candidate = Path(git).parent.parent / "usr" / "bin" / "openssl.exe"
            if candidate.is_file():
                openssl = str(candidate)
        if openssl is None:
            self.skipTest("OpenSSL is needed to generate an ephemeral test certificate")
        certificate = Path(self.temp.name) / "test-certificate.pem"
        private_key = Path(self.temp.name) / "test-private-key.pem"
        subprocess.run([
            openssl, "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
            "-keyout", str(private_key), "-out", str(certificate),
            "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1",
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
        adapter = server.BuiltinSSLAdapter(str(certificate), str(private_key))
        context = ssl.create_default_context(cafile=str(certificate))
        self._socket_disconnect_and_retry(adapter, context)


if __name__ == "__main__":
    unittest.main()

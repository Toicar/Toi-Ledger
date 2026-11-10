import base64
import unittest

import server


class ClientRestrictionTest(unittest.TestCase):
    def invoke(self, address):
        calls = []
        statuses = []

        def application(environ, start_response):
            calls.append(environ)
            start_response("200 OK", [("Content-Length", "2")])
            return [b"ok"]

        app = server.restrict_clients(application, {"192.168.10.20", "192.168.10.31"})
        body = b"".join(app(
            {} if address is None else {"REMOTE_ADDR": address},
            lambda status, headers: statuses.append(status),
        ))
        return statuses, calls, body

    def test_other_client_rejected_before_dav_or_authentication(self):
        statuses, calls, _ = self.invoke("192.168.10.99")
        self.assertEqual(statuses, ["403 Forbidden"])
        self.assertEqual(calls, [])

    def test_missing_address_rejected(self):
        statuses, calls, _ = self.invoke(None)
        self.assertEqual(statuses, ["403 Forbidden"])
        self.assertEqual(calls, [])

    def test_both_configured_clients_accepted(self):
        for address in ("192.168.10.20", "192.168.10.31"):
            with self.subTest(address=address):
                statuses, calls, body = self.invoke(address)
                self.assertEqual(statuses, ["200 OK"])
                self.assertEqual(len(calls), 1)
                self.assertEqual(body, b"ok")

    def test_denial_diagnostics_distinguish_auth_and_ip_without_credentials(self):
        for address, expected in (("192.168.10.30", "401"),
                                  ("192.168.10.99", "403")):
            with self.subTest(address=address):
                events = []
                statuses = []

                def application(environ, start_response):
                    start_response("401 Unauthorized", [])
                    return [b"unauthorized"]

                app = server.restrict_clients(
                    application, {"192.168.10.30"},
                    on_denied=lambda code, client, flags: events.append((code, client, flags)),
                    diagnose_auth=lambda header: server.credential_match_flags(header, "myledger", "expected-test-password"),
                )
                list(app(
                    {"REMOTE_ADDR": address,
                     "HTTP_AUTHORIZATION": "Basic secret-test-value",
                     "PATH_INFO": "/dav/private-ledger"},
                    lambda status, headers: statuses.append(status),
                ))
                self.assertEqual(events[0][:2], (expected, address))
                self.assertEqual(statuses[0][:3], expected)
                self.assertNotIn("secret-test-value", repr(events))
                self.assertNotIn("private-ledger", repr(events))

    def test_credential_flags_identify_which_field_differs_without_values(self):
        for username, password, expected_user, expected_password in (
            ("myledger", "correct-test-password", True, True),
            ("MyLedger", "correct-test-password", False, True),
            ("myledger", "wrong-test-password", True, False),
        ):
            header = "Basic " + base64.b64encode((username + ":" + password).encode()).decode()
            self.assertEqual(server.credential_match_flags(header, "myledger", "correct-test-password"),
                             {"basicAuth": True, "usernameMatches": expected_user,
                              "passwordMatches": expected_password})


if __name__ == "__main__":
    unittest.main()

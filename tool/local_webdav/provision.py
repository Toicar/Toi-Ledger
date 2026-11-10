"""Provision a new, empty local service; output only public pairing material."""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import ipaddress
import json
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID


def provision(state, host, phone, port=8443):
    state = Path(state).resolve(strict=True)
    addresses = [ipaddress.IPv4Address(value) for value in (host, phone)]
    if not all(address.is_private for address in addresses) or not 1024 <= port <= 65535:
        raise ValueError("Use explicit private IPv4 addresses and port 1024-65535.")
    # A partial previous attempt also requires recovery, never key replacement.
    for name in ("config.json", "certificates", "data", "service-setup.json"):
        if (state / name).exists():
            raise FileExistsError("Existing service material retained; do not overwrite it.")
    now = datetime.now(timezone.utc)
    ca_key = rsa.generate_private_key(public_exponent=65537, key_size=3072)
    server_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    issuer = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "MyLedger private LAN CA")])
    ca = (x509.CertificateBuilder().subject_name(issuer).issuer_name(issuer)
          .public_key(ca_key.public_key()).serial_number(x509.random_serial_number())
          .not_valid_before(now - timedelta(minutes=5)).not_valid_after(now + timedelta(days=3650))
          .add_extension(x509.BasicConstraints(ca=True, path_length=0), critical=True)
          .add_extension(x509.KeyUsage(False, False, False, False, False, True, True, False, False), critical=True)
          .sign(ca_key, hashes.SHA256()))
    server = (x509.CertificateBuilder()
              .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, host)]))
              .issuer_name(issuer).public_key(server_key.public_key())
              .serial_number(x509.random_serial_number())
              .not_valid_before(now - timedelta(minutes=5)).not_valid_after(now + timedelta(days=365))
              .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
              .add_extension(x509.SubjectAlternativeName([x509.IPAddress(addresses[0])]), critical=False)
              .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False)
              .sign(ca_key, hashes.SHA256()))
    certificates = state / "certificates"
    certificates.mkdir()
    for name, key in (("ca.key", ca_key), ("server.key", server_key)):
        (certificates / name).write_bytes(key.private_bytes(
            serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption()))
    ca_pem = ca.public_bytes(serialization.Encoding.PEM)
    (certificates / "ca.pem").write_bytes(ca_pem)
    (certificates / "server.pem").write_bytes(server.public_bytes(serialization.Encoding.PEM))
    (state / "data").mkdir()
    (state / "uploads").mkdir()
    (state / "config.json").write_text(json.dumps({
        "host": host, "phone": phone, "port": port, "username": "myledger", "credentialMode": "dpapi",
    }, indent=2), encoding="utf-8")
    pairing = {"version": 1, "endpoint": f"https://{host}:{port}/dav/",
               "username": "myledger", "caPem": ca_pem.decode("ascii")}
    (state / "service-setup.json").write_text(json.dumps(pairing, indent=2), encoding="utf-8")
    fingerprint = hashlib.sha256(ca_pem).hexdigest()
    (state / "certificate-sha256.txt").write_text(fingerprint, encoding="ascii")
    return pairing, fingerprint


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("state")
    parser.add_argument("host")
    parser.add_argument("phone")
    args = parser.parse_args()
    try:
        public, fingerprint = provision(args.state, args.host, args.phone)
        print(f"HTTPS: {public['endpoint']}\nUsername: {public['username']}\nCA SHA-256: {fingerprint}")
    except Exception as error:
        # No credential input or serialization in this command.
        print(f"Provisioning failed: {type(error).__name__}. Existing files retained.")
        raise SystemExit(1)

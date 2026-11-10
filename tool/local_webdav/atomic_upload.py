"""Publish complete, immutable conditional PUTs without exposing partial files."""

from http import HTTPStatus
import os
from pathlib import Path
import re
import stat
import tempfile

from wsgidav.mw.base_mw import BaseMiddleware


MAX_UPLOAD_BYTES = 128 * 1024
_RESERVED_NAMES = {"CON", "PRN", "AUX", "NUL"} | {
    f"{prefix}{number}" for prefix in ("COM", "LPT") for number in range(1, 10)
}


class _RejectedUpload(Exception):
    def __init__(self, status):
        self.status = status


def _is_reparse_point(path):
    try:
        info = path.lstat()
    except FileNotFoundError:
        return False
    return stat.S_ISLNK(info.st_mode) or bool(
        getattr(info, "st_file_attributes", 0)
        & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
    )


class AtomicConditionalPut(BaseMiddleware):
    """Runs after HTTPAuthenticator, before the default filesystem PUT handler."""

    def __init__(self, wsgidav_app, next_app, config):
        super().__init__(wsgidav_app, next_app, config)
        options = config["atomic_upload"]
        self.root = Path(options["root"]).resolve(strict=True)
        self.staging = Path(options["staging"]).absolute()
        if (not self.root.is_dir() or self.staging.is_relative_to(self.root)
                or self.root.is_relative_to(self.staging)):
            raise ValueError("Upload staging must be outside the published directory.")
        self.staging.mkdir(mode=0o700, exist_ok=True)
        if (not self.staging.is_dir() or _is_reparse_point(self.staging)
                or self.staging.resolve().is_relative_to(self.root)
                or self.staging.stat().st_dev != self.root.stat().st_dev):
            raise ValueError("Upload staging must be a private directory on the same volume.")

    def _target(self, path):
        if path in ("", "/") or path.endswith("/"):
            raise _RejectedUpload(405)
        parts = path[1:].split("/")
        if not path.startswith("/") or any(
            part in ("", ".", "..")
            or part.endswith((".", " "))
            or part.split(".", 1)[0].upper() in _RESERVED_NAMES
            or any(ord(char) < 32 or char in '\\:<>"|?*' for char in part)
            for part in parts
        ):
            raise _RejectedUpload(403)
        target = self.root.joinpath(*parts)
        current = self.root
        for part in (None, *parts):
            if part is not None:
                current /= part
            if _is_reparse_point(current):
                raise _RejectedUpload(403)
            if current != target and not current.is_dir():
                raise _RejectedUpload(409)
        if not target.resolve(strict=False).is_relative_to(self.root):
            raise _RejectedUpload(403)
        if target.is_dir():
            raise _RejectedUpload(405)
        if target.exists():
            raise _RejectedUpload(412)
        return target

    @staticmethod
    def _respond(start_response, status, environ):
        headers = [("Content-Length", "0")]
        if not environ.get("wsgidav.all_input_read"):
            headers.append(("Connection", "close"))
        start_response(f"{status} {HTTPStatus(status).phrase}", headers)
        return [b""]

    def __call__(self, environ, start_response):
        if environ["REQUEST_METHOD"] != "PUT" or environ["SCRIPT_NAME"] != "/dav":
            return self.next_app(environ, start_response)

        # Prevent WsgiDAV's response wrapper from draining a rejected or broken
        # request. Incomplete input always closes the connection instead.
        environ["wsgidav.some_input_read"] = 1
        temporary = None
        try:
            if not environ.get("wsgidav.auth.user_name"):
                raise _RejectedUpload(401)
            if environ.get("HTTP_IF_NONE_MATCH", "").strip() != "*":
                raise _RejectedUpload(428)
            if "HTTP_CONTENT_RANGE" in environ or "HTTP_TRANSFER_ENCODING" in environ:
                raise _RejectedUpload(400)
            if "HTTP_CONTENT_ENCODING" in environ:
                raise _RejectedUpload(415)
            length = environ.get("CONTENT_LENGTH")
            if length in (None, ""):
                raise _RejectedUpload(411)
            if not isinstance(length, str) or not re.fullmatch(r"[0-9]+", length):
                raise _RejectedUpload(400)
            length = length.lstrip("0") or "0"
            if len(length) > len(str(MAX_UPLOAD_BYTES)) or int(length) > MAX_UPLOAD_BYTES:
                raise _RejectedUpload(413)
            target = self._target(environ["PATH_INFO"])
            if _is_reparse_point(self.staging):
                raise _RejectedUpload(500)
            with tempfile.NamedTemporaryFile(dir=self.staging, prefix="put-", delete=False) as upload:
                temporary = Path(upload.name)
                remaining = int(length)
                while remaining:
                    try:
                        chunk = environ["wsgi.input"].read(min(64 * 1024, remaining))
                    except (OSError, EOFError, ValueError):
                        raise _RejectedUpload(400) from None
                    if not isinstance(chunk, bytes) or not chunk or len(chunk) > remaining:
                        raise _RejectedUpload(400)
                    upload.write(chunk)
                    remaining -= len(chunk)
                environ["wsgidav.all_input_read"] = 1
                upload.flush()
                os.fsync(upload.fileno())
            # Recheck after the upload, then use a no-overwrite atomic operation.
            target = self._target(environ["PATH_INFO"])
            try:
                os.link(temporary, target)
            except FileExistsError:
                raise _RejectedUpload(412) from None
            return self._respond(start_response, 201, environ)
        except _RejectedUpload as error:
            return self._respond(start_response, error.status, environ)
        except OSError:
            return self._respond(start_response, 500, environ)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)

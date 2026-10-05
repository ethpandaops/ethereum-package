"""Exercise the rendered downloader with real Alpine curl/tar and a local server.

Run with: python3 -m unittest discover -s tests -v
Requires Docker. Only the test image build needs network access.
"""

import hashlib
import http.server
import io
from pathlib import Path
import re
import socket
import subprocess
import tarfile
import tempfile
import threading
import time
import unittest
import uuid


ROOT = Path(__file__).resolve().parents[1]
CHUNK = 64 * 1024


class SnapshotServer(http.server.ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, archive, mode):
        super().__init__(("127.0.0.1", 0), SnapshotHandler)
        self.archive = archive
        self.mode = mode
        self.ranges = []
        self.seen = {}
        self.lock = threading.Lock()


class SnapshotHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_):
        pass

    def handle(self):
        # Oversized responses are deliberately aborted by curl.
        try:
            super().handle()
        except ConnectionResetError:
            pass

    def redirect(self):
        if self.path.startswith("/redirect/"):
            self.send_response(302)
            self.send_header("Location", "/snapshot.tar.zst")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return True
        return False

    def do_HEAD(self):
        if self.redirect():
            return
        self.send_response(200)
        self.send_header("Content-Length", str(len(self.server.archive)))
        self.end_headers()

    def do_GET(self):
        if self.redirect():
            return
        start, end = map(int, self.headers["Range"].removeprefix("bytes=").split("-"))
        with self.server.lock:
            self.server.ranges.append((start, end))
            key = end // CHUNK
            attempt = self.server.seen.get(key, 0) + 1
            self.server.seen[key] = attempt
            first = attempt == 1
        mode = self.server.mode
        archive = self.server.archive
        body = archive[start : end + 1]
        if mode == "unavailable":
            self.send_response(503)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        if mode == "ignored_range" and first:
            self.send_response(200)
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            try:
                for offset in range(0, len(archive), 4096):
                    piece = archive[offset : offset + 4096]
                    self.wfile.write(f"{len(piece):x}\r\n".encode() + piece + b"\r\n")
                self.wfile.write(b"0\r\n\r\n")
            except (BrokenPipeError, ConnectionResetError):
                pass
            return
        self.send_response(206)
        wrong_range = (mode == "wrong_range" and first) or (
            mode == "resume_bad_range" and attempt == 2
        )
        claimed_start = start + 1 if wrong_range else start
        self.send_header("Content-Range", f"bytes {claimed_start}-{end}/{len(archive)}")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            if (mode in ("disconnect", "resume_bad_range") and first) or mode == "disconnect_many":
                count = 16 * 1024 if mode == "disconnect_many" else max(1, len(body) // 2)
                self.wfile.write(body[:count])
                self.wfile.flush()
                self.close_connection = True
                self.connection.shutdown(socket.SHUT_RDWR)
                return
            if mode == "slow":
                for offset in range(0, len(body), 1024):
                    self.wfile.write(body[offset : offset + 1024])
                    self.wfile.flush()
                    time.sleep(0.04)
                return
            # Deliberately complete chunks out of order.
            time.sleep(0.03 * (3 - key % 4))
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass


class ShadowforkDownloadTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.image = "shadowfork-download-test:" + uuid.uuid4().hex
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, "Dockerfile").write_text(
                "FROM alpine:3.19.1\nRUN apk add --no-cache curl tar zstd\n"
            )
            subprocess.run(
                ["docker", "build", "-q", "-t", cls.image, directory],
                check=True,
                capture_output=True,
            )
        cls.payload = hashlib.shake_256(b"shadowfork-download-test").digest(512 * 1024)
        buffer = io.BytesIO()
        with tarfile.open(fileobj=buffer, mode="w") as tar:
            entry = tarfile.TarInfo("payload")
            entry.size = len(cls.payload)
            tar.addfile(entry, io.BytesIO(cls.payload))
        cls.archive = subprocess.run(
            ["docker", "run", "--rm", "-i", cls.image, "zstd", "-q", "-c"],
            input=buffer.getvalue(),
            check=True,
            capture_output=True,
        ).stdout
        source = (ROOT / "src/network_launcher/shadowfork.star").read_text()
        cls.script = re.search(r'SNAPSHOT_DOWNLOAD_SCRIPT = r"""(.*?)"""', source, re.S)[1]

    @classmethod
    def tearDownClass(cls):
        subprocess.run(["docker", "image", "rm", cls.image], capture_output=True)

    def download(self, mode="fast", workers=4, archive=None):
        server = SnapshotServer(self.archive if archive is None else archive, mode)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        name = "shadowfork-download-test-" + uuid.uuid4().hex
        try:
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory)
                (path / "out").mkdir()
                (path / "shared").mkdir()
                (path / "shared/block_height.txt").write_text("0")
                script = self.script
                replacements = {
                    "__SNAPSHOT_BASE__": f"http://127.0.0.1:{server.server_port}/redirect",
                    "__DATA_DIR__": "/test/out",
                    "__WORKERS__": str(workers),
                    "__CHUNK__": str(CHUNK),
                    "__MAX_ATTEMPTS__": "2",
                    "apk add --no-cache curl tar zstd": ": # Dependencies installed in test image",
                    "/shared/": "/test/shared/",
                    "/tmp/finished": "/test/finished",
                    # Compress only retry timing; preserve curl and worker logic.
                    "speed_time=30": "speed_time=2",
                    "speed_time=120": "speed_time=2",
                    "sleep 5": "sleep 0.02",
                    "tail -f /dev/null &\nwait $!": ": # Exit after completion for tests",
                }
                for old, new in replacements.items():
                    script = script.replace(old, new)
                (path / "download.sh").write_text(script)
                result = subprocess.run(
                    [
                        "docker", "run", "--rm", "--name", name,
                        "--network", "host", "-v", f"{path}:/test",
                        self.image, "sh", "/test/download.sh",
                    ],
                    capture_output=True,
                    timeout=45,
                )
                finished = (path / "finished").exists()
                payload = (path / "out/payload")
                extracted = payload.read_bytes() if payload.exists() else None
                return result, finished, extracted, server.ranges
        finally:
            subprocess.run(["docker", "rm", "-f", name], capture_output=True)
            server.shutdown()
            server.server_close()

    def assert_download(self, mode="fast", workers=4):
        result, finished, extracted, ranges = self.download(mode, workers)
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        self.assertTrue(finished)
        self.assertEqual(extracted, self.payload)
        return result, ranges

    def test_fast_out_of_order(self):
        self.assert_download()

    def test_more_workers_than_chunks(self):
        self.assert_download(workers=16)

    def test_disconnect_resumes_absolute_archive_offset(self):
        _, ranges = self.assert_download("disconnect")
        self.assertTrue(any(start > CHUNK and start % CHUNK for start, _ in ranges))

    def test_progress_does_not_exhaust_retry_budget(self):
        _, ranges = self.assert_download("disconnect_many")
        # The test retry budget is only two; every full chunk needs four requests.
        self.assertGreaterEqual(sum(end == CHUNK - 1 for _, end in ranges), 4)

    def test_slow_workers_preserve_progress_and_relax_threshold(self):
        result, ranges = self.assert_download("slow", workers=16)
        self.assertIn(b"speed threshold 524288 B/s", result.stderr)
        self.assertTrue(any(start % CHUNK for start, _ in ranges))

    def test_slow_threshold_is_retained_across_chunks(self):
        result, _ = self.assert_download("slow", workers=4)
        self.assertIn(b"speed threshold 262144 B/s", result.stderr)

    def test_wrong_content_range_is_discarded(self):
        self.assert_download("wrong_range")

    def test_invalid_resume_response_preserves_saved_bytes(self):
        _, ranges = self.assert_download("resume_bad_range")
        starts = [start for start, end in ranges if end == CHUNK - 1]
        self.assertEqual(starts, [0, CHUNK // 2, CHUNK // 2])

    def test_ignored_range_without_content_length_is_discarded(self):
        self.assert_download("ignored_range")

    def test_no_progress_fails_without_finished_marker(self):
        result, finished, _, _ = self.download("unavailable")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(finished)
        self.assertIn(b"made no progress 2 times", result.stderr)

    def test_extraction_failure_does_not_mark_finished(self):
        result, finished, _, _ = self.download(archive=b"invalid zstd archive")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(finished)


if __name__ == "__main__":
    unittest.main()

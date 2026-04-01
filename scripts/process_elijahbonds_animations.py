#!/usr/bin/env python3
"""
DeepMotion Animate 3D — Process Elijah Bonds Instagram Videos → FBX/BVH Animations.

Uses the DeepMotion REST API directly for maximum control and error handling.
Processes all 10 basketball videos and generates motion capture animation files.

Usage:
  python scripts/process_elijahbonds_animations.py              # Process all videos
  python scripts/process_elijahbonds_animations.py --test-auth  # Test authentication only
  python scripts/process_elijahbonds_animations.py --video 04   # Process specific video
"""
from __future__ import annotations

import argparse
import base64
import json
import logging
import os
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

# Setup
ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT_DIR / "scripts"))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("deepmotion_processor")

# Load .env
try:
    from dotenv import load_dotenv
    load_dotenv(ROOT_DIR / ".env")
except ImportError:
    pass

# Constants
DEEPMOTION_API_BASE = "https://service.deepmotion.com"
SOURCE_DIR = ROOT_DIR / "SourceVideos" / "Instagram" / "basketball"
OUTPUT_DIR = ROOT_DIR / "GeneratedAssets" / "Animations" / "ElijahBonds"
METADATA_FILE = ROOT_DIR / "SourceVideos" / "Instagram" / "video_metadata.json"
PROCESSING_LOG = OUTPUT_DIR / "processing_log.json"
ANIMATION_MANIFEST = ROOT_DIR / "GeneratedAssets" / "Animations" / "animation_manifest.json"


class DeepMotionRESTClient:
    """Direct REST API client for DeepMotion Animate 3D."""

    def __init__(self, client_id: str, client_secret: str, api_base: str = DEEPMOTION_API_BASE):
        self.client_id = client_id
        self.client_secret = client_secret
        self.api_base = api_base.rstrip("/")
        self.session_cookie = None
        self._authenticated = False

    def _basic_auth_header(self) -> str:
        creds = f"{self.client_id}:{self.client_secret}"
        encoded = base64.b64encode(creds.encode()).decode()
        return f"Basic {encoded}"

    def _make_request(self, method: str, endpoint: str, data: dict = None,
                      headers: dict = None, use_auth: bool = True) -> dict:
        """Make an HTTP request to the DeepMotion API."""
        url = f"{self.api_base}{endpoint}"
        hdrs = headers or {}
        hdrs["Content-Type"] = "application/json"

        if use_auth and self.session_cookie:
            hdrs["Cookie"] = f"dmsess={self.session_cookie}"
        elif use_auth and not self._authenticated:
            hdrs["Authorization"] = self._basic_auth_header()

        body = json.dumps(data).encode() if data else None
        req = urllib.request.Request(url, data=body, headers=hdrs, method=method)

        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                # Extract session cookie if present
                for header in resp.headers.get_all("Set-Cookie") or []:
                    if "dmsess=" in header:
                        self.session_cookie = header.split("dmsess=")[1].split(";")[0]
                        self._authenticated = True
                resp_data = resp.read().decode()
                return json.loads(resp_data) if resp_data else {}
        except urllib.error.HTTPError as e:
            error_body = e.read().decode() if e.fp else ""
            logger.error(f"HTTP {e.code} on {method} {endpoint}: {error_body}")
            raise
        except urllib.error.URLError as e:
            logger.error(f"URL Error on {method} {endpoint}: {e.reason}")
            raise

    def authenticate(self) -> bool:
        """Authenticate and get session token."""
        try:
            url = f"{self.api_base}/session/auth"
            req = urllib.request.Request(url, method="GET")
            req.add_header("Authorization", self._basic_auth_header())

            with urllib.request.urlopen(req, timeout=30) as resp:
                for header in resp.headers.get_all("Set-Cookie") or []:
                    if "dmsess=" in header:
                        self.session_cookie = header.split("dmsess=")[1].split(";")[0]
                        self._authenticated = True

                resp_data = resp.read().decode()
                result = json.loads(resp_data) if resp_data else {}
                logger.info(f"Authentication successful. Response: {result}")
                return True
        except urllib.error.HTTPError as e:
            error_body = e.read().decode() if e.fp else ""
            logger.error(f"Authentication failed (HTTP {e.code}): {error_body}")
            return False
        except Exception as e:
            logger.error(f"Authentication error: {e}")
            return False

    def get_credit_balance(self) -> dict:
        """Get current API credit balance."""
        return self._make_request("GET", "/account/credits")

    def get_upload_url(self, filename: str, resumable: bool = False) -> dict:
        """Get a signed URL for uploading a video."""
        params = f"?name={filename}"
        if resumable:
            params += "&resumable=1"
        return self._make_request("GET", f"/upload{params}")

    def upload_video(self, video_path: Path) -> str:
        """Upload a video and return the storage URL."""
        logger.info(f"  Requesting upload URL for {video_path.name}...")
        upload_info = self.get_upload_url(video_path.name)

        if "url" not in upload_info:
            raise RuntimeError(f"No upload URL returned: {upload_info}")

        signed_url = upload_info["url"]
        storage_url = upload_info.get("storage_url", signed_url.split("?")[0])

        # Upload the video file
        logger.info(f"  Uploading {video_path.name} ({video_path.stat().st_size / 1024 / 1024:.1f} MB)...")
        with open(video_path, "rb") as f:
            video_data = f.read()

        req = urllib.request.Request(signed_url, data=video_data, method="PUT")
        req.add_header("Content-Type", "video/mp4")
        req.add_header("Content-Length", str(len(video_data)))

        with urllib.request.urlopen(req, timeout=300) as resp:
            logger.info(f"  Upload complete (HTTP {resp.status})")

        return storage_url

    def start_processing(self, video_url: str, model_id: str = None,
                         formats: list[str] = None) -> str:
        """Start motion capture processing on an uploaded video. Returns RID."""
        params = [
            "config=configDefault",
            f"formats={','.join(formats or ['fbx', 'bvh'])}",
            "trackFace=true",
            "trackHand=true",
            "trackFinger=true",
            "sim=1",
            "rootJointAtOrigin=true",
            "footLockingMode=grounding",
        ]
        if model_id:
            params.append(f"model={model_id}")

        body = {
            "url": video_url,
            "processor": "video2anim",
            "params": params,
        }

        result = self._make_request("POST", "/process", data=body)
        rid = result.get("rid")
        if not rid:
            raise RuntimeError(f"No RID returned from process: {result}")
        logger.info(f"  Processing started. RID: {rid}")
        return rid

    def check_status(self, rid: str) -> dict:
        """Check the status of a processing job."""
        return self._make_request("GET", f"/status/{rid}")

    def wait_for_completion(self, rid: str, timeout: int = 600, poll_interval: int = 10) -> dict:
        """Poll until job completes or times out."""
        start = time.time()
        while time.time() - start < timeout:
            status = self.check_status(rid)
            state = status.get("status", "UNKNOWN")

            if state == "SUCCESS":
                logger.info(f"  Job {rid} completed successfully!")
                return status
            elif state in ("FAILURE", "ERROR"):
                raise RuntimeError(f"Job {rid} failed: {status}")
            elif state == "PROGRESS":
                progress = status.get("progress", "?")
                logger.info(f"  Job {rid}: {progress}% complete...")
            elif state == "RETRY":
                logger.warning(f"  Job {rid}: retrying...")

            time.sleep(poll_interval)

        raise TimeoutError(f"Job {rid} timed out after {timeout}s")

    def get_download_urls(self, rid: str) -> dict:
        """Get download URLs for completed job results."""
        return self._make_request("GET", f"/download/{rid}")

    def download_results(self, rid: str, output_dir: Path) -> list[Path]:
        """Download all result files from a completed job."""
        output_dir.mkdir(parents=True, exist_ok=True)
        download_info = self.get_download_urls(rid)

        downloaded_files = []
        urls = download_info.get("urls", download_info.get("links", []))

        if isinstance(urls, dict):
            urls = list(urls.values()) if all(isinstance(v, str) for v in urls.values()) else []

        if not urls:
            # Try alternate response format
            for key in ("fbx", "bvh", "glb", "mp4"):
                if key in download_info:
                    urls.append({"url": download_info[key], "format": key})

        for item in urls:
            if isinstance(item, str):
                url = item
                ext = url.split(".")[-1].split("?")[0]
                filename = f"{rid}.{ext}"
            elif isinstance(item, dict):
                url = item.get("url", "")
                filename = item.get("name", f"{rid}.{item.get('format', 'fbx')}")
            else:
                continue

            if not url:
                continue

            filepath = output_dir / filename
            logger.info(f"  Downloading {filename}...")
            try:
                urllib.request.urlretrieve(url, str(filepath))
                downloaded_files.append(filepath)
            except Exception as e:
                logger.error(f"  Failed to download {filename}: {e}")

        return downloaded_files

    def list_models(self) -> list:
        """List available character models."""
        try:
            result = self._make_request("GET", "/character/list")
            return result.get("models", result.get("characters", []))
        except Exception as e:
            logger.warning(f"Could not list models: {e}")
            return []


def load_metadata() -> dict:
    """Load the video metadata JSON."""
    with open(METADATA_FILE) as f:
        return json.load(f)


def load_processing_log() -> dict:
    """Load or create the processing log."""
    if PROCESSING_LOG.exists():
        with open(PROCESSING_LOG) as f:
            return json.load(f)
    return {
        "created": datetime.now(timezone.utc).isoformat(),
        "last_updated": None,
        "total_processed": 0,
        "total_success": 0,
        "total_failed": 0,
        "videos": {},
    }


def save_processing_log(log: dict):
    """Save the processing log."""
    PROCESSING_LOG.parent.mkdir(parents=True, exist_ok=True)
    log["last_updated"] = datetime.now(timezone.utc).isoformat()
    with open(PROCESSING_LOG, "w") as f:
        json.dump(log, f, indent=2)


def process_single_video(client: DeepMotionRESTClient, video_info: dict,
                         processing_log: dict) -> dict:
    """Process a single video through the DeepMotion pipeline."""
    filename = video_info["filename"]
    basename = Path(filename).stem
    video_path = SOURCE_DIR / Path(filename).name
    out_dir = OUTPUT_DIR / basename

    result = {
        "video": filename,
        "status": "pending",
        "started_at": datetime.now(timezone.utc).isoformat(),
        "completed_at": None,
        "rid": None,
        "output_dir": str(out_dir),
        "files": [],
        "error": None,
        "movements": video_info.get("movements", []),
        "priority": video_info.get("deepmotion_priority", "medium"),
    }

    if not video_path.exists():
        result["status"] = "error"
        result["error"] = f"Video file not found: {video_path}"
        logger.error(f"  ✗ {result['error']}")
        return result

    try:
        # Step 1: Upload
        result["status"] = "uploading"
        save_processing_log(processing_log)
        storage_url = client.upload_video(video_path)

        # Step 2: Start processing
        result["status"] = "processing"
        rid = client.start_processing(
            storage_url,
            formats=["fbx", "bvh"],
        )
        result["rid"] = rid

        # Step 3: Wait for completion
        status = client.wait_for_completion(rid, timeout=600, poll_interval=15)
        result["status"] = "downloading"

        # Step 4: Download results
        downloaded = client.download_results(rid, out_dir)
        result["files"] = [str(f) for f in downloaded]
        result["status"] = "success"
        result["completed_at"] = datetime.now(timezone.utc).isoformat()
        logger.info(f"  ✓ {basename}: {len(downloaded)} files downloaded to {out_dir}")

    except Exception as e:
        result["status"] = "failed"
        result["error"] = str(e)
        result["completed_at"] = datetime.now(timezone.utc).isoformat()
        logger.error(f"  ✗ {basename}: {e}")

    return result


def process_all_videos(client: DeepMotionRESTClient, target_video: str = None):
    """Process all (or specific) Elijah Bonds videos."""
    metadata = load_metadata()
    processing_log = load_processing_log()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Sort by recommended processing order (critical first)
    priority_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    videos = sorted(
        metadata["videos"],
        key=lambda v: priority_order.get(v.get("deepmotion_priority", "medium"), 2),
    )

    if target_video:
        videos = [v for v in videos if target_video in v["filename"]]
        if not videos:
            logger.error(f"No video matching '{target_video}' found.")
            return

    total = len(videos)
    logger.info(f"Processing {total} videos through DeepMotion Animate 3D...")
    logger.info(f"Output directory: {OUTPUT_DIR}")
    logger.info("=" * 60)

    for i, video_info in enumerate(videos, 1):
        filename = video_info["filename"]
        basename = Path(filename).stem
        priority = video_info.get("deepmotion_priority", "medium")

        # Skip already processed
        if basename in processing_log.get("videos", {}) and \
           processing_log["videos"][basename].get("status") == "success":
            logger.info(f"[{i}/{total}] Skipping {basename} (already processed)")
            continue

        logger.info(f"\n[{i}/{total}] Processing: {basename}")
        logger.info(f"  Priority: {priority}")
        logger.info(f"  Movements: {', '.join(video_info.get('movements', []))}")
        logger.info(f"  Duration: {video_info.get('duration_seconds', '?')}s")

        result = process_single_video(client, video_info, processing_log)
        processing_log["videos"][basename] = result
        processing_log["total_processed"] += 1

        if result["status"] == "success":
            processing_log["total_success"] += 1
        else:
            processing_log["total_failed"] += 1

        save_processing_log(processing_log)

        # Rate limiting: wait between videos
        if i < total:
            logger.info("  Waiting 5s before next video (rate limiting)...")
            time.sleep(5)

    # Summary
    logger.info("\n" + "=" * 60)
    logger.info("PROCESSING SUMMARY")
    logger.info(f"  Total: {processing_log['total_processed']}")
    logger.info(f"  Success: {processing_log['total_success']}")
    logger.info(f"  Failed: {processing_log['total_failed']}")
    logger.info(f"  Log: {PROCESSING_LOG}")


def test_authentication():
    """Test DeepMotion API authentication only."""
    client_id = os.environ.get("DEEPMOTION_CLIENT_ID", "").strip()
    client_secret = os.environ.get("DEEPMOTION_CLIENT_SECRET", "").strip()

    if not client_id or not client_secret:
        logger.error("DEEPMOTION_CLIENT_ID and DEEPMOTION_CLIENT_SECRET must be set in .env")
        logger.error("Get your credentials from: https://portal.deepmotion.com/dashboard/animate-3d")
        return False

    client = DeepMotionRESTClient(client_id, client_secret)
    if client.authenticate():
        logger.info("✓ Authentication successful!")
        try:
            balance = client.get_credit_balance()
            logger.info(f"  Credit balance: {balance}")
        except Exception as e:
            logger.warning(f"  Could not fetch balance: {e}")
        try:
            models = client.list_models()
            logger.info(f"  Available models: {len(models)}")
        except Exception as e:
            logger.warning(f"  Could not list models: {e}")
        return True
    else:
        logger.error("✗ Authentication failed. Check your credentials.")
        return False


def main():
    parser = argparse.ArgumentParser(description="Process Elijah Bonds videos via DeepMotion")
    parser.add_argument("--test-auth", action="store_true", help="Test authentication only")
    parser.add_argument("--video", type=str, help="Process specific video (e.g., '04' or 'reverse_dunk')")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be processed without API calls")
    args = parser.parse_args()

    if args.test_auth:
        sys.exit(0 if test_authentication() else 1)

    if args.dry_run:
        metadata = load_metadata()
        priority_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
        videos = sorted(
            metadata["videos"],
            key=lambda v: priority_order.get(v.get("deepmotion_priority", "medium"), 2),
        )
        logger.info("DRY RUN — Videos to process:")
        for i, v in enumerate(videos, 1):
            logger.info(f"  {i}. [{v.get('deepmotion_priority', '?').upper()}] {v['filename']}")
            logger.info(f"     Movements: {', '.join(v.get('movements', []))}")
            logger.info(f"     Duration: {v.get('duration_seconds', '?')}s | Size: {v.get('file_size_mb', '?')}MB")
        return

    client_id = os.environ.get("DEEPMOTION_CLIENT_ID", "").strip()
    client_secret = os.environ.get("DEEPMOTION_CLIENT_SECRET", "").strip()

    if not client_id or not client_secret:
        logger.error("=" * 60)
        logger.error("DeepMotion API credentials not configured!")
        logger.error("=" * 60)
        logger.error("")
        logger.error("To get your credentials:")
        logger.error("  1. Go to https://portal.deepmotion.com/dashboard/animate-3d")
        logger.error("  2. Sign in to your DeepMotion account")
        logger.error("  3. Navigate to API settings / Developer section")
        logger.error("  4. Copy your Client ID and Client Secret")
        logger.error("  5. Add them to .env:")
        logger.error("     DEEPMOTION_CLIENT_ID=your_client_id")
        logger.error("     DEEPMOTION_CLIENT_SECRET=your_client_secret")
        sys.exit(2)

    client = DeepMotionRESTClient(client_id, client_secret)
    if not client.authenticate():
        logger.error("Authentication failed. Check credentials in .env")
        sys.exit(1)

    process_all_videos(client, target_video=args.video)


if __name__ == "__main__":
    main()

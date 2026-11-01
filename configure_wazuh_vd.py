#!/usr/bin/env python3
"""Configure Wazuh 4.14+ Vulnerability Detection on a Wazuh Manager."""

from __future__ import annotations

import argparse
import logging
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit
import xml.etree.ElementTree as ET


CONFIG_PATH = Path("/var/ossec/etc/ossec.conf")
LOG = logging.getLogger("configure_wazuh_vd")
INTERVAL_RE = re.compile(r"([1-9][0-9]*)([smhd])", re.IGNORECASE)


def parse_yes_no(value: str) -> str:
    """Parse a Wazuh yes/no setting."""
    normalized = value.strip().lower()
    if normalized not in {"yes", "no"}:
        raise argparse.ArgumentTypeError("must be 'yes' or 'no'")
    return normalized


def parse_interval(value: str) -> str:
    """Validate Wazuh's positive integer plus time-unit interval syntax."""
    normalized = value.strip().lower()
    match = INTERVAL_RE.fullmatch(normalized)
    if not match:
        raise argparse.ArgumentTypeError(
            "must be a positive number followed by s, m, h, or d (for example 60m)"
        )

    amount = int(match.group(1))
    seconds_per_unit = {"s": 1, "m": 60, "h": 3600, "d": 86400}
    if amount * seconds_per_unit[match.group(2)] < 3600:
        LOG.warning(
            "Wazuh 4.14+ requires a minimum feed-update-interval of 60m; "
            "Wazuh may reset the supplied value to 60m."
        )
    return normalized


def normalize_offline_url(value: str) -> str:
    """Accept HTTP(S), file:// URLs, and local paths (converted to file URIs)."""
    value = value.strip()
    if not value:
        raise argparse.ArgumentTypeError("must not be empty")

    parsed = urlsplit(value)
    if parsed.scheme.lower() in {"http", "https"}:
        if not parsed.netloc:
            raise argparse.ArgumentTypeError("HTTP(S) URLs must include a host")
        return value
    if parsed.scheme.lower() == "file":
        if not parsed.path:
            raise argparse.ArgumentTypeError("file:// URL must include a path")
        return value
    if parsed.scheme:
        raise argparse.ArgumentTypeError(
            "must be an http://, https://, or file:// URL, or a local filesystem path"
        )

    path = Path(value).expanduser()
    if not path.is_absolute():
        path = path.resolve()
    return path.as_uri()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Enable and configure Wazuh Vulnerability Detection in "
            f"{CONFIG_PATH}. Run this script as root on the Wazuh Manager."
        )
    )
    parser.add_argument(
        "--offline-url",
        type=normalize_offline_url,
        help="Optional HTTP(S)/file:// URL or local path to an offline feed.",
    )
    parser.add_argument(
        "--feed-interval",
        type=parse_interval,
        default="60m",
        metavar="INTERVAL",
        help="Feed update interval (default: 60m; examples: 60m, 2h, 1d).",
    )
    parser.add_argument(
        "--index-status",
        type=parse_yes_no,
        default="yes",
        metavar="yes|no",
        help="Enable or disable vulnerability inventory indexing (default: yes).",
    )
    parser.add_argument(
        "--no-index-status",
        dest="index_status",
        action="store_const",
        const="no",
        help="Shortcut for --index-status no.",
    )
    parser.add_argument(
        "--restart",
        action="store_true",
        help="Restart wazuh-manager after writing the configuration.",
    )
    parser.set_defaults(index_status="yes")
    return parser


def require_root() -> None:
    """Fail clearly unless running with effective root privileges."""
    get_euid = getattr(os, "geteuid", None)
    if get_euid is None or get_euid() != 0:
        raise PermissionError(
            "Root privileges are required. Run with sudo, for example: "
            "sudo python3 configure_wazuh_vd.py"
        )


def local_name(tag: object) -> str | None:
    """Return an XML element's local name, including namespace-aware tags."""
    if not isinstance(tag, str):  # Comments and processing instructions.
        return None
    return tag.rsplit("}", 1)[-1]


def remove_legacy_blocks(parent: ET.Element) -> int:
    """Remove legacy vulnerability-detector elements at any nesting level."""
    removed = 0
    for child in list(parent):
        if local_name(child.tag) == "vulnerability-detector":
            parent.remove(child)
            removed += 1
        else:
            removed += remove_legacy_blocks(child)
    return removed


def get_or_create_vulnerability_block(root: ET.Element) -> tuple[ET.Element, bool]:
    blocks = [
        child
        for child in list(root)
        if local_name(child.tag) == "vulnerability-detection"
    ]
    if blocks:
        block = blocks[0]
        for duplicate in blocks[1:]:
            root.remove(duplicate)
        return block, False

    block = ET.Element("vulnerability-detection")
    root.append(block)
    return block, True


def set_child_text(parent: ET.Element, name: str, value: str) -> None:
    matches = [child for child in list(parent) if local_name(child.tag) == name]
    if matches:
        element = matches[0]
        element.text = value
        for duplicate in matches[1:]:
            parent.remove(duplicate)
    else:
        ET.SubElement(parent, name).text = value


def update_config(
    source: bytes, feed_interval: str, index_status: str, offline_url: str | None
) -> tuple[bytes, int, bool]:
    """Return a validated, updated XML document and change counts."""
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    try:
        root = ET.fromstring(source, parser=parser)
    except ET.ParseError as exc:
        raise ValueError(f"Cannot parse {CONFIG_PATH} as XML: {exc}") from exc

    if root.tag != "ossec_config":
        raise ValueError(
            f"Unexpected XML root <{local_name(root.tag)}>; expected <ossec_config>."
        )

    legacy_removed = remove_legacy_blocks(root)
    block, created = get_or_create_vulnerability_block(root)

    set_child_text(block, "enabled", "yes")
    set_child_text(block, "index-status", index_status)
    set_child_text(block, "feed-update-interval", feed_interval)
    if offline_url is not None:
        set_child_text(block, "offline-url", offline_url)

    # ElementTree provides clean, deterministic formatting while retaining XML comments.
    ET.indent(root, space="  ")
    declaration = source.lstrip().startswith(b"<?xml")
    updated = ET.tostring(
        root,
        encoding="utf-8",
        xml_declaration=declaration,
        short_empty_elements=True,
    )

    # Parse the exact bytes that would be written before touching the original file.
    verify_parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    try:
        verified_root = ET.fromstring(updated, parser=verify_parser)
    except ET.ParseError as exc:
        raise ValueError(f"Generated configuration failed XML validation: {exc}") from exc
    if verified_root.tag != "ossec_config":
        raise ValueError("Generated configuration has an unexpected XML root.")

    return updated, legacy_removed, created


def create_backup(config_path: Path) -> Path:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = config_path.with_name(f"{config_path.name}.bak.{timestamp}")
    suffix = 1
    while backup.exists():
        backup = config_path.with_name(f"{config_path.name}.bak.{timestamp}.{suffix}")
        suffix += 1
    shutil.copy2(config_path, backup)
    return backup


def atomic_replace(config_path: Path, content: bytes, original_stat: os.stat_result) -> None:
    """Atomically replace the config while retaining its owner and mode."""
    fd, temp_name = tempfile.mkstemp(
        prefix=f".{config_path.name}.", suffix=".tmp", dir=str(config_path.parent)
    )
    temp_path = Path(temp_name)
    try:
        with os.fdopen(fd, "wb") as temp_file:
            temp_file.write(content)
            temp_file.flush()
            os.fsync(temp_file.fileno())
        os.chown(temp_path, original_stat.st_uid, original_stat.st_gid)
        os.chmod(temp_path, stat.S_IMODE(original_stat.st_mode))
        os.replace(temp_path, config_path)

        directory_fd = os.open(config_path.parent, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        try:
            temp_path.unlink()
        except FileNotFoundError:
            pass


def restart_manager() -> str:
    """Restart Wazuh Manager and return the reported service status."""
    try:
        result = subprocess.run(
            ["systemctl", "restart", "wazuh-manager"],
            check=False,
            capture_output=True,
            text=True,
            timeout=120,
        )
    except FileNotFoundError as exc:
        raise RuntimeError("systemctl was not found; cannot restart wazuh-manager.") from exc
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError("Timed out while restarting wazuh-manager.") from exc

    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise RuntimeError(
            "systemctl restart wazuh-manager failed "
            f"with return code {result.returncode}"
            + (f": {detail}" if detail else ".")
        )

    try:
        status = subprocess.run(
            ["systemctl", "is-active", "wazuh-manager"],
            check=False,
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        raise RuntimeError(
            "Manager restart returned success, but service status could not be checked."
        ) from exc

    service_status = status.stdout.strip() or status.stderr.strip() or "unknown"
    if status.returncode != 0 or service_status != "active":
        raise RuntimeError(
            "Manager restart returned success, but wazuh-manager status is "
            f"'{service_status}'."
        )
    return service_status


def get_manager_status() -> str:
    """Return systemd's current service status without changing the service."""
    try:
        result = subprocess.run(
            ["systemctl", "is-active", "wazuh-manager"],
            check=False,
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return "unavailable"
    return result.stdout.strip() or result.stderr.strip() or "unknown"


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    args = build_parser().parse_args(argv)

    try:
        require_root()
        if not CONFIG_PATH.is_file():
            raise FileNotFoundError(f"Wazuh configuration file not found: {CONFIG_PATH}")

        original = CONFIG_PATH.read_bytes()
        original_stat = CONFIG_PATH.stat()
        updated, legacy_removed, created = update_config(
            original, args.feed_interval, args.index_status, args.offline_url
        )
        LOG.info("Generated XML passed syntax validation.")

        backup = create_backup(CONFIG_PATH)
        LOG.info("Backup created: %s", backup)
        atomic_replace(CONFIG_PATH, updated, original_stat)

        if legacy_removed:
            LOG.info("Removed %d legacy <vulnerability-detector> block(s).", legacy_removed)
        LOG.info(
            "%s modern <vulnerability-detection> block.",
            "Created" if created else "Updated",
        )
        LOG.info("Vulnerability Detection enabled: yes")
        LOG.info("Feed update interval: %s", args.feed_interval)
        LOG.info("Index status: %s", args.index_status)
        if args.offline_url is not None:
            LOG.info("Offline feed URL configured.")

        if args.restart:
            status = restart_manager()
            LOG.info("wazuh-manager restart succeeded; service status: %s", status)
        else:
            LOG.info(
                "Restart not requested; wazuh-manager was not restarted. "
                "Current service status: %s",
                get_manager_status(),
            )
        return 0
    except (PermissionError, FileNotFoundError, ValueError, RuntimeError, OSError) as exc:
        LOG.error("%s", exc)
        return 1


if __name__ == "__main__":
    sys.exit(main())

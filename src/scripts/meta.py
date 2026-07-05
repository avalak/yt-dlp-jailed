#!/usr/bin/env python3
"""Extract and display video metadata as JSON.

NOTE: python plugin/script example

Usage: ./yt-dlp meta "https://www.youtube.com/watch?v=..."
"""
import sys
import json

import yt_dlp


def get_metadata(url: str) -> dict:
    """Return selected metadata fields for the given URL."""
    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": False, # full
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)

    # Extract useful fields, handle missing gracefully
    meta = {
        "id": info.get("id"),
        "title": info.get("title"),
        "description": info.get("description", ""),
        "duration": info.get("duration"),
        "view_count": info.get("view_count"),
        "like_count": info.get("like_count"),
        "upload_date": info.get("upload_date"),
        "channel": info.get("channel"),
        "channel_url": info.get("channel_url"),
        "thumbnail": info.get("thumbnail"),
        "formats_count": len(info.get("formats") or []),
        "categories": info.get("categories"),
        "tags": info.get("tags"),
    }
    return meta


def main():
    if len(sys.argv) < 2:
        print("Usage: yt-dlp meta URL", file=sys.stderr)
        sys.exit(1)

    url = sys.argv[1]
    try:
        metadata = get_metadata(url)
        json.dump(metadata, sys.stdout, indent=2, ensure_ascii=False)
        print() # newline
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

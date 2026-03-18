# services/exif_service.py
# ============================================================
# Analyzes ALL available EXIF metadata from uploaded images.
# Extracts every readable field and flags suspicious patterns.
#
# AI-generated images typically:
#   - Have no EXIF data at all
#   - Show software like Stable Diffusion, DALL-E, Midjourney
#   - Have mismatched creation/modification timestamps
#   - Lack GPS or camera hardware info
# ============================================================

from PIL import Image
from PIL.ExifTags import TAGS, GPSTAGS
import io
from datetime import datetime


# ── Known AI generation / editing software signatures ────────────
AI_SOFTWARE_SIGNATURES = [
    "stable diffusion", "midjourney", "dall-e", "dalle",
    "firefly", "generative", "ai generated", "deepfake",
    "faceswap", "reface", "facefusion", "simswap",
    "adobe photoshop", "meitu", "facetune", "lightroom",
    "snapseed", "vsco", "afterlight",
]

# ── EXIF fields to skip — binary/unintelligible for users ────────
SKIP_TAGS = {
    "MakerNote", "UserComment", "PrintImageMatching",
    "JPEGThumbnail", "ThumbnailImage", "ComponentsConfiguration",
    "FileSource", "SceneType", "CFAPattern", "DeviceSettingDescription",
}


def analyze_exif(image_bytes: bytes) -> dict:
    """
    Extracts and analyzes ALL available EXIF metadata from the image.

    Returns a dict with:
        - raw_fields:       All human-readable EXIF fields found
        - suspicion_flags:  List of suspicious findings
        - risk_level:       'LOW', 'MEDIUM', or 'HIGH'
        - summary:          One-paragraph summary for LLM context
        - has_exif:         Whether any EXIF data was found
    """
    try:
        img  = Image.open(io.BytesIO(image_bytes))
        exif = _extract_all_exif(img)

        # AFTER:
        if not exif:
            # ── Detect likely image source ─────────────────────────────
            # PNG or RGBA = almost certainly a screenshot or web image
            # These never have EXIF — treat differently from a stripped JPEG
            img_format = img.format  # JPEG, PNG, WEBP etc
            img_mode = img.mode  # RGB, RGBA etc
            is_likely_screenshot = (
                    img_format == "PNG" or
                    img_mode == "RGBA"
            )

            if is_likely_screenshot:
                return {
                    "raw_fields": {},
                    "suspicion_flags": [],
                    "risk_level": "LOW",
                    "summary": (
                        "This appears to be a screenshot or web image. "
                        "These don't contain camera metadata, which is completely normal. "
                        "EXIF analysis is not applicable here."
                    ),
                    "has_exif": False,
                }
            else:
                # JPEG with no EXIF — more genuinely worth flagging
                return {
                    "raw_fields": {},
                    "suspicion_flags": [
                        "No camera metadata found — unusual for a real JPEG photo"
                    ],
                    "risk_level": "MEDIUM",
                    "summary": (
                        "This JPEG has no camera metadata, which is unusual for a "
                        "photo taken on a phone or camera. It may have been "
                        "downloaded, heavily edited, or AI-generated."
                    ),
                    "has_exif": False,
                }

        suspicion_flags = []

        # ── 1. Software check ─────────────────────────────────────
        software = str(exif.get("Software", ""))
        if software:
            for sig in AI_SOFTWARE_SIGNATURES:
                if sig in software.lower():
                    suspicion_flags.append(
                        f"Processed with '{software}' — known AI/editing tool"
                    )
                    break

        # ── 2. Camera hardware check ──────────────────────────────
        make  = exif.get("Make", "")
        model = exif.get("Model", "")
        if not make and not model:
            suspicion_flags.append(
                "No camera make/model — real photos usually have this"
            )

        # ── 3. Timestamp inconsistency check ──────────────────────
        dt_original = exif.get("DateTimeOriginal", "")
        dt_modified = exif.get("DateTime", "")
        if dt_original and dt_modified:
            gap = _timestamp_gap_seconds(dt_original, dt_modified)
            if gap is not None and gap > 86400:
                suspicion_flags.append(
                    "Timestamps inconsistent — modified long after capture"
                )

        # ── 4. No GPS on a phone photo ────────────────────────────
        if "GPS" not in exif:
            suspicion_flags.append(
                "No GPS data — most real smartphone photos contain location"
            )

        # ── 5. Calculate risk level ───────────────────────────────
        risk_level = _calculate_risk(suspicion_flags, exif)

        # ── 6. Build LLM summary ──────────────────────────────────
        summary = _build_summary(exif, suspicion_flags, risk_level)

        return {
            "raw_fields":      exif,
            "suspicion_flags": suspicion_flags,
            "risk_level":      risk_level,
            "summary":         summary,
            "has_exif":        True,
        }

    except Exception as e:
        return {
            "raw_fields":      {},
            "suspicion_flags": [f"Could not read EXIF data: {str(e)}"],
            "risk_level":      "UNKNOWN",
            "summary":         "EXIF analysis could not be completed.",
            "has_exif":        False,
        }


def _extract_all_exif(img: Image.Image) -> dict:
    """
    Extracts ALL readable EXIF fields from a PIL image.
    Handles nested GPS fields, converts values to strings.
    Skips binary/unintelligible tags.
    """
    result = {}

    try:
        raw_exif = img._getexif()
        if not raw_exif:
            return {}

        for tag_id, value in raw_exif.items():
            tag_name = TAGS.get(tag_id, f"Tag_{tag_id}")

            # Skip binary/unintelligible tags
            if tag_name in SKIP_TAGS:
                continue

            # ── Handle GPS data specially ──────────────────────
            if tag_name == "GPSInfo" and isinstance(value, dict):
                gps_data = _parse_gps(value)
                result.update(gps_data)
                continue

            # ── Convert tuples (rational numbers) ─────────────
            if isinstance(value, tuple) and len(value) == 2:
                try:
                    value = f"{value[0]}/{value[1]}"
                except Exception:
                    value = str(value)

            # ── Convert bytes to string ────────────────────────
            if isinstance(value, bytes):
                try:
                    value = value.decode("utf-8", errors="ignore").strip()
                    if not value:
                        continue
                except Exception:
                    continue

            # ── Skip empty values ──────────────────────────────
            if value is None or value == "" or value == 0:
                continue

            # ── Format known fields nicely ─────────────────────
            formatted = _format_field(tag_name, value)
            if formatted is not None:
                result[formatted["label"]] = formatted["value"]

    except Exception:
        pass

    return result


def _parse_gps(gps_info: dict) -> dict:
    """
    Parses raw GPS IFD data into human-readable fields.
    Converts DMS (degrees/minutes/seconds) to decimal coordinates.
    """
    gps_fields = {}

    try:
        # Latitude
        if 2 in gps_info and 1 in gps_info:
            lat     = _dms_to_decimal(gps_info[2])
            lat_ref = gps_info[1]
            if lat is not None:
                if lat_ref == "S":
                    lat = -lat
                gps_fields["GPS Latitude"] = f"{lat:.6f}°"

        # Longitude
        if 4 in gps_info and 3 in gps_info:
            lon     = _dms_to_decimal(gps_info[4])
            lon_ref = gps_info[3]
            if lon is not None:
                if lon_ref == "W":
                    lon = -lon
                gps_fields["GPS Longitude"] = f"{lon:.6f}°"

        # Altitude
        if 6 in gps_info:
            alt = gps_info[6]
            if isinstance(alt, tuple) and len(alt) == 2 and alt[1] != 0:
                gps_fields["GPS Altitude"] = f"{alt[0]/alt[1]:.1f} m"

        # GPS timestamp
        if 7 in gps_info:
            ts = gps_info[7]
            if isinstance(ts, (list, tuple)) and len(ts) == 3:
                try:
                    h = int(ts[0][0] / ts[0][1]) if isinstance(ts[0], tuple) else int(ts[0])
                    m = int(ts[1][0] / ts[1][1]) if isinstance(ts[1], tuple) else int(ts[1])
                    s = int(ts[2][0] / ts[2][1]) if isinstance(ts[2], tuple) else int(ts[2])
                    gps_fields["GPS Timestamp"] = f"{h:02d}:{m:02d}:{s:02d} UTC"
                except Exception:
                    pass

        # GPS date
        if 29 in gps_info:
            gps_fields["GPS Date"] = str(gps_info[29])

        # Mark GPS as present if any GPS fields found
        if gps_fields:
            gps_fields["GPS"] = "Present"

    except Exception:
        gps_fields["GPS"] = "Present (could not parse)"

    return gps_fields


def _dms_to_decimal(dms) -> float | None:
    """Converts degrees/minutes/seconds tuple to decimal degrees."""
    try:
        if isinstance(dms, (list, tuple)) and len(dms) == 3:
            def to_float(v):
                if isinstance(v, tuple) and len(v) == 2:
                    return v[0] / v[1] if v[1] != 0 else 0
                return float(v)
            d = to_float(dms[0])
            m = to_float(dms[1])
            s = to_float(dms[2])
            return d + m / 60 + s / 3600
    except Exception:
        pass
    return None


def _format_field(tag_name: str, value) -> dict | None:
    """
    Formats a raw EXIF field into a user-friendly label/value pair.
    Returns None if the field should be skipped.
    """

    # ── Field label mapping ────────────────────────────────────────
    label_map = {
        "Make":                  "Camera Make",
        "Model":                 "Camera Model",
        "Software":              "Software",
        "DateTime":              "Date Modified",
        "DateTimeOriginal":      "Date Taken",
        "DateTimeDigitized":     "Date Digitized",
        "ImageWidth":            "Image Width",
        "ImageLength":           "Image Height",
        "ExifImageWidth":        "Image Width",
        "ExifImageHeight":       "Image Height",
        "XResolution":           "X Resolution",
        "YResolution":           "Y Resolution",
        "ResolutionUnit":        "Resolution Unit",
        "Orientation":           "Orientation",
        "ColorSpace":            "Color Space",
        "ExposureTime":          "Exposure Time",
        "FNumber":               "F-Number",
        "ISOSpeedRatings":       "ISO Speed",
        "ShutterSpeedValue":     "Shutter Speed",
        "ApertureValue":         "Aperture",
        "BrightnessValue":       "Brightness",
        "ExposureBiasValue":     "Exposure Bias",
        "MaxApertureValue":      "Max Aperture",
        "MeteringMode":          "Metering Mode",
        "Flash":                 "Flash",
        "FocalLength":           "Focal Length",
        "FocalLengthIn35mmFilm": "Focal Length (35mm)",
        "WhiteBalance":          "White Balance",
        "DigitalZoomRatio":      "Digital Zoom",
        "ExposureMode":          "Exposure Mode",
        "ExposureProgram":       "Exposure Program",
        "SensingMethod":         "Sensing Method",
        "SceneCaptureType":      "Scene Type",
        "GainControl":           "Gain Control",
        "Contrast":              "Contrast",
        "Saturation":            "Saturation",
        "Sharpness":             "Sharpness",
        "LightSource":           "Light Source",
        "Artist":                "Artist/Author",
        "Copyright":             "Copyright",
        "ImageDescription":      "Description",
        "LensModel":             "Lens Model",
        "LensMake":              "Lens Make",
        "BodySerialNumber":      "Camera Serial",
        "LensSerialNumber":      "Lens Serial",
        "SubjectDistance":       "Subject Distance",
        "SubjectDistanceRange":  "Subject Distance Range",
    }

    label = label_map.get(tag_name, tag_name)

    # ── Value formatting for specific fields ───────────────────────
    try:
        if tag_name == "Flash":
            value = "Used" if int(str(value)) & 1 else "Not used"

        elif tag_name == "Orientation":
            orientations = {
                1: "Normal", 2: "Mirrored", 3: "Rotated 180°",
                4: "Mirrored + 180°", 5: "Mirrored + 90° CW",
                6: "Rotated 90° CW", 7: "Mirrored + 90° CCW",
                8: "Rotated 90° CCW",
            }
            value = orientations.get(int(str(value)), str(value))

        elif tag_name == "ResolutionUnit":
            units = {1: "No unit", 2: "Inch", 3: "Centimeter"}
            value = units.get(int(str(value)), str(value))

        elif tag_name == "ColorSpace":
            spaces = {1: "sRGB", 65535: "Uncalibrated"}
            value = spaces.get(int(str(value)), str(value))

        elif tag_name == "WhiteBalance":
            value = "Auto" if int(str(value)) == 0 else "Manual"

        elif tag_name == "ExposureMode":
            modes = {0: "Auto", 1: "Manual", 2: "Auto bracket"}
            value = modes.get(int(str(value)), str(value))

        elif tag_name == "MeteringMode":
            modes = {
                0: "Unknown", 1: "Average", 2: "Center-weighted",
                3: "Spot", 4: "Multi-spot", 5: "Pattern", 6: "Partial",
            }
            value = modes.get(int(str(value)), str(value))

        elif tag_name == "ExposureProgram":
            programs = {
                0: "Not defined", 1: "Manual", 2: "Normal",
                3: "Aperture priority", 4: "Shutter priority",
                5: "Creative", 6: "Action", 7: "Portrait", 8: "Landscape",
            }
            value = programs.get(int(str(value)), str(value))

        elif tag_name in ("ExposureTime",):
            # Format as fraction e.g. "1/500"
            if isinstance(value, tuple) and len(value) == 2:
                n, d = value
                if n != 0:
                    value = f"1/{int(d/n)}s" if n == 1 else f"{n}/{d}s"

        elif tag_name in ("FNumber", "ApertureValue"):
            if isinstance(value, tuple) and len(value) == 2:
                n, d = value
                if d != 0:
                    value = f"f/{n/d:.1f}"

        elif tag_name == "FocalLength":
            if isinstance(value, tuple) and len(value) == 2:
                n, d = value
                if d != 0:
                    value = f"{n/d:.1f} mm"

        elif tag_name in ("XResolution", "YResolution"):
            if isinstance(value, tuple) and len(value) == 2:
                n, d = value
                if d != 0:
                    value = f"{int(n/d)} dpi"

    except Exception:
        pass  # Keep original value if formatting fails

    # Skip if value is still empty or 0
    str_val = str(value).strip()
    if not str_val or str_val == "0":
        return None

    return {"label": label, "value": str_val}


def _timestamp_gap_seconds(ts1: str, ts2: str) -> float | None:
    """Calculates gap in seconds between two EXIF timestamps."""
    fmt = "%Y:%m:%d %H:%M:%S"
    try:
        dt1 = datetime.strptime(ts1, fmt)
        dt2 = datetime.strptime(ts2, fmt)
        return abs((dt2 - dt1).total_seconds())
    except Exception:
        return None


def _calculate_risk(suspicion_flags: list, exif: dict) -> str:
    """Calculates overall EXIF risk level based on suspicious findings."""
    count = len(suspicion_flags)
    if count == 0:
        return "LOW"
    elif count == 1:
        return "MEDIUM" if "No EXIF" in suspicion_flags[0] else "LOW"
    elif count == 2:
        return "MEDIUM"
    else:
        return "HIGH"


def _build_summary(exif: dict, flags: list, risk: str) -> str:
    """Builds a concise summary paragraph for the LLM prompt."""
    parts = []

    camera = exif.get("Camera Make", "") or exif.get("Camera Model", "")
    if camera:
        parts.append(f"captured with {camera}")

    software = exif.get("Software", "")
    if software:
        parts.append(f"processed using {software}")

    date = exif.get("Date Taken", "")
    if date:
        parts.append(f"taken on {date}")

    if "GPS Latitude" in exif:
        parts.append("contains GPS location data")

    base = ("The image " + ", ".join(parts) + ".") if parts \
           else "Limited EXIF data was found."

    if flags:
        base += " Suspicious indicators: " + "; ".join(flags) + "."

    base += f" Overall EXIF risk level: {risk}."
    return base
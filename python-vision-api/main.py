import io
import os
from pathlib import Path
from typing import Any, Callable

BASE_DIR = Path(__file__).resolve().parent
YOLO_CONFIG_DIR = BASE_DIR / ".ultralytics"
MPL_CONFIG_DIR = BASE_DIR / ".matplotlib"
YOLO_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
MPL_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
os.environ.setdefault("YOLO_CONFIG_DIR", str(YOLO_CONFIG_DIR))
os.environ.setdefault("MPLCONFIGDIR", str(MPL_CONFIG_DIR))

import numpy as np
from fastapi import FastAPI, UploadFile, File # pyrefly: ignore [missing-import]
from fastapi.middleware.cors import CORSMiddleware # pyrefly: ignore [missing-import]
from PIL import Image
from ultralytics import YOLO # pyrefly: ignore [missing-import]

app = FastAPI(title="CareBike Vision AI API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def _model_path(env_name: str, default_name: str) -> str:
    raw_path = os.getenv(env_name, default_name)
    path = Path(raw_path)
    if path.is_absolute():
        return str(path)
    return str(BASE_DIR / path)


DAMAGE_MODEL_PATH = _model_path("CAREBIKE_DAMAGE_MODEL", "best.pt")
VALIDATOR_MODEL_PATH = _model_path("CAREBIKE_VALIDATOR_MODEL", "tire_validator.pt")
VALID_TIRE_CONFIDENCE = float(os.getenv("CAREBIKE_VALID_TIRE_CONFIDENCE", "0.35"))
INVALID_IMAGE_CONFIDENCE = float(os.getenv("CAREBIKE_INVALID_IMAGE_CONFIDENCE", "0.45"))

VALID_TIRE_LABEL = "valid_tire"
INVALID_LABEL_MESSAGES = {
    "invalid_food": (
        "wrong_component",
        "This photo looks like food. Please upload only the tire, tread, or sidewall.",
    ),
    "invalid_house": (
        "wrong_component",
        "This photo looks like a room, building, or indoor scene. Please capture the tire clearly.",
    ),
    "invalid_person": (
        "person_or_sensitive_content",
        "This photo may contain a person or face. Please upload only the tire area.",
    ),
    "invalid_scenery": (
        "wrong_component",
        "This photo looks like scenery, not a tire. Please capture the tire, tread, or sidewall.",
    ),
}

print(f"Loading CareBike damage model from {DAMAGE_MODEL_PATH}...")
damage_model = YOLO(DAMAGE_MODEL_PATH)
print("CareBike damage model loaded.")

validator_model = None
validator_path = Path(VALIDATOR_MODEL_PATH)
if validator_path.exists():
    print(f"Loading CareBike tire validator model from {VALIDATOR_MODEL_PATH}...")
    validator_model = YOLO(VALIDATOR_MODEL_PATH)
    print("CareBike tire validator model loaded.")
else:
    print(
        f"CareBike tire validator model not found at {VALIDATOR_MODEL_PATH}. "
        "Using heuristic pre-check until the validator model is added."
    )


def _read_image(image_bytes: bytes) -> Image.Image:
    return Image.open(io.BytesIO(image_bytes)).convert("RGB")


def _image_metrics(image: Image.Image) -> dict:
    arr = np.asarray(image.resize((512, 512)), dtype=np.float32)
    r = arr[:, :, 0]
    g = arr[:, :, 1]
    b = arr[:, :, 2]

    maxc = arr.max(axis=2)
    minc = arr.min(axis=2)
    sat = (maxc - minc) / np.maximum(maxc, 1.0)
    gray = (0.299 * r + 0.587 * g + 0.114 * b)

    brightness = float(gray.mean())

    # A small Laplacian-like score catches very blurred photos without OpenCV.
    lap = (
        -4 * gray[1:-1, 1:-1]
        + gray[:-2, 1:-1]
        + gray[2:, 1:-1]
        + gray[1:-1, :-2]
        + gray[1:-1, 2:]
    )
    blur_score = float(lap.var())

    grad_x = np.abs(gray[:, 1:] - gray[:, :-1])
    grad_y = np.abs(gray[1:, :] - gray[:-1, :])
    edge_density = float(((grad_x > 18).mean() + (grad_y > 18).mean()) / 2.0)

    dark_neutral = (maxc < 170) & (sat < 0.46)
    very_dark = maxc < 95
    rubber_like = dark_neutral | very_dark
    rubber_like_ratio = float(rubber_like.mean())
    rubber_block_ratio = 0.0
    for row in range(4):
        for col in range(4):
            block = rubber_like[row * 128:(row + 1) * 128, col * 128:(col + 1) * 128]
            rubber_block_ratio = max(rubber_block_ratio, float(block.mean()))

    # Broad skin-like heuristic. It is intentionally used only as a blocker
    # when the image does not otherwise look tire/rubber-like.
    skin = (
        (r > 95)
        & (g > 40)
        & (b > 20)
        & ((np.maximum.reduce([r, g, b]) - np.minimum.reduce([r, g, b])) > 15)
        & (np.abs(r - g) > 15)
        & (r > g)
        & (r > b)
    )
    skin_ratio = float(skin.mean())

    center = skin[128:384, 128:384]
    center_skin_ratio = float(center.mean())
    skin_block_ratio = 0.0
    for row in range(4):
        for col in range(4):
            block = skin[row * 128:(row + 1) * 128, col * 128:(col + 1) * 128]
            skin_block_ratio = max(skin_block_ratio, float(block.mean()))

    return {
        "width": image.width,
        "height": image.height,
        "brightness": round(brightness, 2),
        "blur_score": round(blur_score, 2),
        "edge_density": round(edge_density, 4),
        "rubber_like_ratio": round(rubber_like_ratio, 4),
        "rubber_block_ratio": round(rubber_block_ratio, 4),
        "skin_ratio": round(skin_ratio, 4),
        "center_skin_ratio": round(center_skin_ratio, 4),
        "skin_block_ratio": round(skin_block_ratio, 4),
    }


def _model_label(yolo_model: YOLO, class_id: int) -> str:
    names = yolo_model.names
    if isinstance(names, dict):
        return str(names.get(class_id, class_id))
    if 0 <= class_id < len(names):
        return str(names[class_id])
    return str(class_id)


def _normalize_label(label: str) -> str:
    return label.strip().lower().replace("-", "_").replace(" ", "_")


def _scalar_value(value):
    if value is None:
        return None
    if hasattr(value, "item"):
        try:
            return value.item()
        except Exception:
            pass
    return value


Detection = dict[str, Any]


def _run_model(image: Image.Image, yolo_model: YOLO) -> list[Detection]:
    results = yolo_model(image, verbose=False)
    detections: list[Detection] = []

    for r in results:
        boxes = getattr(r, "boxes", None)
        if boxes is not None:
            for box in boxes:
                b = box.xyxy[0].tolist()
                raw_conf = _scalar_value(box.conf[0] if box.conf is not None else None)
                raw_class_id = _scalar_value(box.cls[0] if box.cls is not None else None)
                if raw_conf is None or raw_class_id is None:
                    continue
                conf = float(raw_conf)
                class_id = int(raw_class_id)

                detections.append({
                    "label": _model_label(yolo_model, class_id),
                    "confidence": round(conf, 2),
                    "box": {
                        "x_min": round(b[0], 2),
                        "y_min": round(b[1], 2),
                        "x_max": round(b[2], 2),
                        "y_max": round(b[3], 2),
                    },
                })

        probs = getattr(r, "probs", None)
        if probs is not None:
            raw_class_id = _scalar_value(getattr(probs, "top1", None))
            raw_conf = _scalar_value(getattr(probs, "top1conf", None))
            if raw_class_id is None or raw_conf is None:
                continue
            class_id = int(raw_class_id)
            conf = float(raw_conf)
            detections.append({
                "label": _model_label(yolo_model, class_id),
                "confidence": round(conf, 2),
                "box": None,
            })

    return detections


def _top_detection(
    detections: list[Detection],
    predicate: Callable[[str], bool],
) -> Detection | None:
    matches = [
        detection for detection in detections
        if predicate(_normalize_label(str(detection.get("label", ""))))
    ]
    if not matches:
        return None
    return max(matches, key=lambda item: float(item.get("confidence", 0)))


def _precheck_image(image: Image.Image) -> dict:
    metrics = _image_metrics(image)

    if metrics["width"] < 240 or metrics["height"] < 240:
        return _invalid("low_quality", "Photo is too small. Please upload a clearer tire photo.", metrics)

    if metrics["brightness"] < 30:
        return _invalid("low_quality", "Photo is too dark. Please retake it with better lighting.", metrics)

    if metrics["brightness"] > 245:
        return _invalid("low_quality", "Photo is too bright. Please retake it with the tire clearly visible.", metrics)

    if metrics["blur_score"] < 4:
        return _invalid("low_quality", "Photo is too blurry. Please keep the tire sharp and try again.", metrics)

    validator_precheck = _validator_precheck(image, metrics)
    if validator_precheck is not None:
        return validator_precheck

    return _heuristic_precheck(metrics)


def _validator_precheck(image: Image.Image, metrics: dict) -> dict | None:
    if validator_model is None:
        return None

    detections = _run_model(image, validator_model)
    validator_info = {
        "available": True,
        "model_path": VALIDATOR_MODEL_PATH,
        "valid_tire_confidence_threshold": VALID_TIRE_CONFIDENCE,
        "invalid_image_confidence_threshold": INVALID_IMAGE_CONFIDENCE,
        "detections": detections,
    }

    valid_hit = _top_detection(
        detections,
        lambda label: label == VALID_TIRE_LABEL,
    )
    invalid_hit = _top_detection(
        detections,
        lambda label: label.startswith("invalid_"),
    )

    valid_confidence = float(valid_hit.get("confidence", 0)) if valid_hit else 0.0
    invalid_confidence = float(invalid_hit.get("confidence", 0)) if invalid_hit else 0.0

    if valid_confidence >= VALID_TIRE_CONFIDENCE and valid_confidence >= invalid_confidence:
        return _valid(
            "Photo passed the tire validator.",
            metrics,
            validator=validator_info,
        )

    if invalid_hit and invalid_confidence >= INVALID_IMAGE_CONFIDENCE:
        label = _normalize_label(str(invalid_hit.get("label", "")))
        reason, message = INVALID_LABEL_MESSAGES.get(
            label,
            (
                "wrong_component",
                "This photo does not look suitable for tire inspection. Please upload a clear tire photo.",
            ),
        )
        return _invalid(reason, message, metrics, validator=validator_info)

    return _invalid(
        "wrong_component",
        "I could not confidently confirm a tire in this photo. Please capture the tire, tread, or sidewall clearly.",
        metrics,
        validator=validator_info,
    )


def _heuristic_precheck(metrics: dict) -> dict:
    has_model_hit = False
    global_tire_like = (
        metrics["rubber_like_ratio"] >= 0.18
        and metrics["edge_density"] >= 0.012
    )
    local_tire_like = (
        metrics["rubber_block_ratio"] >= 0.30
        and metrics["edge_density"] >= 0.010
    )
    tire_like = global_tire_like or local_tire_like

    strong_tire_like = (
        (metrics["rubber_like_ratio"] >= 0.32 or metrics["rubber_block_ratio"] >= 0.45)
        and metrics["edge_density"] >= 0.015
    )
    high_skin = metrics["skin_ratio"] >= 0.18 or metrics["center_skin_ratio"] >= 0.14
    very_high_skin = (
        metrics["skin_ratio"] >= 0.28
        or metrics["center_skin_ratio"] >= 0.24
        or metrics["skin_block_ratio"] >= 0.42
    )
    concentrated_skin = metrics["skin_block_ratio"] >= 0.24 and metrics["skin_ratio"] >= 0.04
    skin_dominates_rubber = (
        metrics["skin_ratio"] >= 0.06
        and metrics["skin_ratio"] > (metrics["rubber_like_ratio"] * 0.65)
    )
    if (
        (very_high_skin and not strong_tire_like)
        or (high_skin and not tire_like and not has_model_hit)
        or (concentrated_skin and not tire_like and not has_model_hit)
        or (skin_dominates_rubber and not tire_like and not has_model_hit)
    ):
        return _invalid(
            "person_or_sensitive_content",
            "This photo may contain a person or sensitive content. Please upload only the tire area.",
            metrics,
        )

    if not has_model_hit and not tire_like:
        return _invalid(
            "wrong_component",
            "I could not confirm a tire in this photo. Please capture the tire, tread, or sidewall clearly.",
            metrics,
        )

    return _valid(
        "Photo passed the tire heuristic pre-check.",
        metrics,
        validator={"available": False, "model_path": VALIDATOR_MODEL_PATH},
    )


def _valid(message: str, metrics: dict, validator: dict | None = None) -> dict:
    result = {
        "valid": True,
        "reason": "ok",
        "message": message,
        "metrics": metrics,
    }
    if validator is not None:
        result["validator"] = validator
    return result


def _invalid(reason: str, message: str, metrics: dict, validator: dict | None = None) -> dict:
    result = {
        "valid": False,
        "reason": reason,
        "message": message,
        "metrics": metrics,
    }
    if validator is not None:
        result["validator"] = validator
    return result


@app.post("/api/vision/precheck")
async def precheck_image(file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()
        image = _read_image(image_bytes)
        precheck = _precheck_image(image)
        return {
            "status": "success",
            "precheck": precheck,
            "total_defects_found": 0,
        }
    except Exception:
        return {
            "status": "error",
            "message": "Could not read this image. Please choose a valid tire photo.",
        }


@app.post("/api/vision/analyze")
async def analyze_image(file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()
        image = _read_image(image_bytes)

        precheck = _precheck_image(image)

        if not precheck["valid"]:
            return {
                "status": "invalid_photo",
                "message": precheck["message"],
                "precheck": precheck,
                "detections": [],
                "total_defects_found": 0,
            }

        detections = _run_model(image, damage_model)

        return {
            "status": "success",
            "message": "Image analysis completed.",
            "precheck": precheck,
            "total_defects_found": len(detections),
            "detections": detections,
        }

    except Exception:
        return {
            "status": "error",
            "message": "Could not analyze this image. Please choose a valid tire photo.",
        }

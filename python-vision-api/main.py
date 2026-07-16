from fastapi import FastAPI, UploadFile, File # pyrefly: ignore [missing-import]
from fastapi.middleware.cors import CORSMiddleware # pyrefly: ignore [missing-import]
from ultralytics import YOLO # pyrefly: ignore [missing-import]
from PIL import Image
import io
import numpy as np

app = FastAPI(title="CareBike Vision AI API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

print("Loading CareBike vision model...")
model = YOLO("best.pt")
print("CareBike vision model loaded.")


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
    rubber_like_ratio = float((dark_neutral | very_dark).mean())

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

    return {
        "width": image.width,
        "height": image.height,
        "brightness": round(brightness, 2),
        "blur_score": round(blur_score, 2),
        "edge_density": round(edge_density, 4),
        "rubber_like_ratio": round(rubber_like_ratio, 4),
        "skin_ratio": round(skin_ratio, 4),
        "center_skin_ratio": round(center_skin_ratio, 4),
    }


def _run_model(image: Image.Image) -> list:
    results = model(image)
    detections = []

    for r in results:
        boxes = r.boxes
        for box in boxes:
            b = box.xyxy[0].tolist()
            conf = float(box.conf[0])
            class_id = int(box.cls[0])
            label = model.names[class_id]

            detections.append({
                "label": label,
                "confidence": round(conf, 2),
                "box": {
                    "x_min": round(b[0], 2),
                    "y_min": round(b[1], 2),
                    "x_max": round(b[2], 2),
                    "y_max": round(b[3], 2),
                },
            })

    return detections


def _precheck_image(image: Image.Image, detections: list | None = None) -> dict:
    detections = detections or []
    metrics = _image_metrics(image)

    has_model_hit = len(detections) > 0
    tire_like = (
        metrics["rubber_like_ratio"] >= 0.18
        and metrics["edge_density"] >= 0.012
    )

    if metrics["width"] < 240 or metrics["height"] < 240:
        return _invalid("low_quality", "Photo is too small. Please upload a clearer tire photo.", metrics)

    if metrics["brightness"] < 30:
        return _invalid("low_quality", "Photo is too dark. Please retake it with better lighting.", metrics)

    if metrics["brightness"] > 245:
        return _invalid("low_quality", "Photo is too bright. Please retake it with the tire clearly visible.", metrics)

    if metrics["blur_score"] < 4 and not has_model_hit:
        return _invalid("low_quality", "Photo is too blurry. Please keep the tire sharp and try again.", metrics)

    high_skin = metrics["skin_ratio"] >= 0.32 or metrics["center_skin_ratio"] >= 0.28
    person_like = metrics["skin_ratio"] >= 0.18 and metrics["center_skin_ratio"] >= 0.12
    skin_dominates_rubber = metrics["skin_ratio"] > (metrics["rubber_like_ratio"] * 1.2)
    if (high_skin and skin_dominates_rubber) or (person_like and not tire_like):
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

    return {
        "valid": True,
        "reason": "ok",
        "message": "Photo passed the tire pre-check.",
        "metrics": metrics,
    }


def _invalid(reason: str, message: str, metrics: dict) -> dict:
    return {
        "valid": False,
        "reason": reason,
        "message": message,
        "metrics": metrics,
    }


@app.post("/api/vision/precheck")
async def precheck_image(file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()
        image = _read_image(image_bytes)
        precheck = _precheck_image(image)
        return {
            "status": "success",
            "precheck": precheck,
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

        detections = _run_model(image)
        precheck = _precheck_image(image, detections)

        if not precheck["valid"]:
            return {
                "status": "invalid_photo",
                "message": precheck["message"],
                "precheck": precheck,
                "detections": [],
                "total_defects_found": 0,
            }

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

from fastapi import FastAPI, UploadFile, File # pyrefly: ignore [missing-import]
from fastapi.middleware.cors import CORSMiddleware # pyrefly: ignore [missing-import]
from ultralytics import YOLO # pyrefly: ignore [missing-import]
from PIL import Image
import io

# Khởi tạo Server FastAPI
app = FastAPI(title="CareBike Vision AI API")

# Cấu hình CORS để Mobile App (Flutter) gọi API không bị lỗi bảo mật chặn lại
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load "bộ não" AI vào bộ nhớ (Chỉ load 1 lần khi bật Server)
print("Đang nạp mô hình AI...")
model = YOLO("best.pt")
print("Nạp mô hình thành công!")

@app.post("/api/vision/analyze")
async def analyze_image(file: UploadFile = File(...)):
    """
    Nhận ảnh upload từ App, đưa cho AI quét và trả về tọa độ vết rách/mòn.
    """
    try:
        # 1. Đọc dữ liệu ảnh khách hàng gửi lên
        image_bytes = await file.read()
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")

        # 2. Đưa ảnh vào mô hình YOLO để quét
        results = model(image)
        
        detections = []
        # 3. Bóc tách kết quả AI trả về (Tọa độ X-Y, Tên lỗi, Độ tự tin)
        for r in results:
            boxes = r.boxes
            for box in boxes:
                # Lấy tọa độ khung chữ nhật (x_min, y_min, x_max, y_max)
                b = box.xyxy[0].tolist()
                
                # Độ tự tin (Ví dụ: 0.85 nghĩa là AI chắc chắn 85%)
                conf = float(box.conf[0])
                
                # Lấy tên cái nhãn (label) mà lúc trước người ta gán trên Roboflow
                class_id = int(box.cls[0])
                label = model.names[class_id]

                detections.append({
                    "label": label,
                    "confidence": round(conf, 2),
                    "box": {
                        "x_min": round(b[0], 2),
                        "y_min": round(b[1], 2),
                        "x_max": round(b[2], 2),
                        "y_max": round(b[3], 2)
                    }
                })

        # 4. Trả về file JSON gọn gàng cho App Flutter dễ đọc
        return {
            "status": "success",
            "message": "Phân tích hình ảnh hoàn tất",
            "total_defects_found": len(detections),
            "detections": detections
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}
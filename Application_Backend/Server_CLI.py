from fastapi import FastAPI, UploadFile, File, HTTPException, WebSocket
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
import io
import cv2
import numpy as np
import tempfile
import asyncio
import time
from ultralytics import YOLO
import uuid
import os
from datetime import datetime
import re
import easyocr  # Import EasyOCR

app = FastAPI()

# Add CORS middleware for mobile app communication
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Dynamically locate models in project root or current directory
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
smoke_model_path = os.path.join(BASE_DIR, 'smoke.pt')
plate_model_path = os.path.join(BASE_DIR, 'number_plate.pt')

if not os.path.exists(smoke_model_path):
    smoke_model_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'smoke.pt')
if not os.path.exists(plate_model_path):
    plate_model_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'number_plate.pt')

print(f"Loading Smoke model from: {smoke_model_path}")
model = YOLO(smoke_model_path).to('cpu')

print(f"Loading Number Plate model from: {plate_model_path}")
plate_model = YOLO(plate_model_path).to('cpu')

# Initialize EasyOCR reader
# For better performance, specify the languages you need (e.g., ['en'] for English)
# You might want to add more languages if you expect plates in different scripts
reader = easyocr.Reader(['en'])

# Active WebSocket connections
active_connections = set()

def create_image_folder(base_path, image_id):
    """Create a folder for a specific image"""
    folder_path = os.path.join(base_path, f"image-{image_id}")
    os.makedirs(folder_path, exist_ok=True)
    return folder_path

def save_detected_portion(image, bbox, image_folder, detection_num, class_name):
    """Save the detected portion in the image's folder with class name"""
    x1, y1, x2, y2 = map(int, bbox)
    detected_portion = image.crop((x1, y1, x2, y2))
    
    timestamp = datetime.now().strftime("%H%M%S")
    # Remove spaces and special characters from class name for filename
    safe_class_name = "".join(c for c in class_name if c.isalnum())
    filename = f"{image_folder}/{safe_class_name}_{detection_num}_{timestamp}.jpg"
    
    detected_portion.save(filename)
    return filename

def extract_number_plate_text(image, bbox):
    """Extract text from number plate using EasyOCR"""
    x1, y1, x2, y2 = map(int, bbox)
    plate_image = image.crop((x1, y1, x2, y2))
    
    # Convert PIL Image to numpy array for EasyOCR
    plate_np = np.array(plate_image)
    
    try:
        # Perform OCR on the number plate image
        results = reader.readtext(plate_np)
        
        # Combine all detected texts
        plate_text = " ".join([res[1] for res in results])
        
        # Clean up the text (remove special characters, normalize spaces)
        plate_text = re.sub(r'[^a-zA-Z0-9 ]', '', plate_text).strip()
        
        # If no text detected, return a default message
        if not plate_text:
            plate_text = "No text detected"
            
        return plate_text
    except Exception as e:
        print(f"Error in OCR processing: {e}")
        return "OCR processing failed"

# Counter for image IDs
image_counter = 0
video_counter = 0
stream_counter = 0

@app.post("/predict-image")
async def predict_image(file: UploadFile = File(...)):
    global image_counter
    image_counter += 1
    current_image_id = image_counter
    
    image_bytes = await file.read()
    image = Image.open(io.BytesIO(image_bytes))
    
    # Run both models
    results = model(image)
    plate_results = plate_model(image)

    # Create folder for this image
    base_dir = "detections/images"
    os.makedirs(base_dir, exist_ok=True)
    image_folder = create_image_folder(base_dir, current_image_id)
    
    predictions = []
    detection_count = 0
    
    # Process original model detections
    for result in results:
        for box in result.boxes:
            detection_count += 1
            bbox = box.xyxy[0].tolist()
            class_name = model.names[int(box.cls)]
            
            # Save detected portion in the image's folder
            saved_path = save_detected_portion(image, bbox, image_folder, detection_count, class_name)
            
            predictions.append({
                "class_Id": int(box.cls),
                "class_name": class_name,
                "confidence": float(box.conf),
                "bbox": bbox,
                "saved_path": saved_path,
                "image_id": current_image_id,
                "detection_num": detection_count,
                "model_type": "object_detection"
            })

    # Process number plate detections
    plate_detection_count = 0
    for result in plate_results:
        for box in result.boxes:
            detection_count += 1
            plate_detection_count += 1
            bbox = box.xyxy[0].tolist()
            class_name = plate_model.names[int(box.cls)]
            
            # Save detected portion in the image's folder
            saved_path = save_detected_portion(image, bbox, image_folder, detection_count, class_name)
            
            # Extract number plate text using EasyOCR
            plate_text = extract_number_plate_text(image, bbox)
            
            predictions.append({
                "class_Id": int(box.cls),
                "class_name": class_name,
                "confidence": float(box.conf),
                "bbox": bbox,
                "saved_path": saved_path,
                "image_id": current_image_id,
                "detection_num": detection_count,
                "plate_text": plate_text,
                "model_type": "plate_detection"
            })

    return {
        "predictions": predictions,
        "image_id": current_image_id,
        "image_folder": image_folder,
        "plate_detections": plate_detection_count
    }

@app.post("/predict-video")
async def predict_video(file: UploadFile = File(...)):
    global video_counter
    video_counter += 1
    current_video_id = video_counter
    
    with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as temp_video:
        temp_video.write(await file.read())
        video_path = temp_video.name

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise HTTPException(status_code=400, detail="Could not open video file")
    
    # Create folder for this video
    base_dir = "detections/videos"
    os.makedirs(base_dir, exist_ok=True)
    video_folder = create_image_folder(base_dir, current_video_id)
    
    fps = cap.get(cv2.CAP_PROP_FPS)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    duration = total_frames / fps if fps > 0 else 0
    
    frame_count = 0
    predictions = []
    last_time = time.time()
    detection_count = 0
    plate_detection_count = 0
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
            
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        pil_image = Image.fromarray(rgb_frame)
        
        # Run both models
        results = model(rgb_frame)
        plate_results = plate_model(rgb_frame)
        
        frame_preds = []
        for result in results:
            for box in result.boxes:
                detection_count += 1
                bbox = box.xyxy[0].tolist()
                class_name = model.names[int(box.cls)]
                
                # Save detected portion in the video's folder
                saved_path = save_detected_portion(pil_image, bbox, video_folder, detection_count, class_name)
                
                frame_preds.append({
                    "class_Id": int(box.cls),
                    "class_name": class_name,
                    "confidence": float(box.conf),
                    "bbox": bbox,
                    "timestamp": frame_count / fps if fps > 0 else 0,
                    "saved_path": saved_path,
                    "detection_num": detection_count,
                    "model_type": "object_detection"
                })
        
        # Process number plate detections
        for result in plate_results:
            for box in result.boxes:
                detection_count += 1
                plate_detection_count += 1
                bbox = box.xyxy[0].tolist()
                class_name = plate_model.names[int(box.cls)]
                
                # Save detected portion in the video's folder
                saved_path = save_detected_portion(pil_image, bbox, video_folder, detection_count, class_name)
                
                # Extract number plate text using EasyOCR
                plate_text = extract_number_plate_text(pil_image, bbox)
                
                frame_preds.append({
                    "class_Id": int(box.cls),
                    "class_name": class_name,
                    "confidence": float(box.conf),
                    "bbox": bbox,
                    "timestamp": frame_count / fps if fps > 0 else 0,
                    "saved_path": saved_path,
                    "detection_num": detection_count,
                    "plate_text": plate_text,
                    "model_type": "plate_detection"
                })
        
        predictions.append({
            "frame": frame_count,
            "timestamp": frame_count / fps if fps > 0 else 0,
            "detections": frame_preds
        })
        
        frame_count += 1
        
        if time.time() - last_time < 0.033:
            await asyncio.sleep(0.01)
        last_time = time.time()
    
    cap.release()
    os.unlink(video_path)  # Clean up temporary file
    
    return {
        "video_predictions": predictions,
        "fps": fps,
        "total_frames": total_frames,
        "duration": duration,
        "video_id": current_video_id,
        "video_folder": video_folder,
        "plate_detections": plate_detection_count
    }

@app.websocket("/ws-video-stream")
async def websocket_video_stream(websocket: WebSocket):
    global stream_counter
    stream_counter += 1
    current_stream_id = stream_counter
    
    await websocket.accept()
    active_connections.add(websocket)
    client_id = str(uuid.uuid4())
    print(f"Client connected: {client_id}")
    
    # Create folder for this stream
    base_dir = "detections/streams"
    os.makedirs(base_dir, exist_ok=True)
    stream_folder = create_image_folder(base_dir, current_stream_id)
    
    detection_count = 0
    plate_detection_count = 0
    
    try:
        while True:
            # Receive frame data from mobile
            data = await websocket.receive_bytes()
            
            # Convert bytes to numpy array
            nparr = np.frombuffer(data, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if frame is None:
                continue
            
            # Process frame with both models
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            pil_image = Image.fromarray(rgb_frame)
            results = model(rgb_frame)
            plate_results = plate_model(rgb_frame)
            
            # Prepare detections
            detections = []
            for result in results:
                for box in result.boxes:
                    detection_count += 1
                    bbox = box.xyxy[0].tolist()
                    class_name = model.names[int(box.cls)]
                    
                    # Save detected portion in the stream's folder
                    saved_path = save_detected_portion(pil_image, bbox, stream_folder, detection_count, class_name)
                    
                    detections.append({
                        "class_id": int(box.cls),
                        "class_name": class_name,
                        "confidence": float(box.conf),
                        "bbox": bbox,
                        "saved_path": saved_path,
                        "detection_num": detection_count,
                        "model_type": "object_detection"
                    })
            
            # Process number plate detections
            for result in plate_results:
                for box in result.boxes:
                    detection_count += 1
                    plate_detection_count += 1
                    bbox = box.xyxy[0].tolist()
                    class_name = plate_model.names[int(box.cls)]
                    
                    # Save detected portion in the stream's folder
                    saved_path = save_detected_portion(pil_image, bbox, stream_folder, detection_count, class_name)
                    
                    # Extract number plate text using EasyOCR
                    plate_text = extract_number_plate_text(pil_image, bbox)
                    
                    detections.append({
                        "class_id": int(box.cls),
                        "class_name": class_name,
                        "confidence": float(box.conf),
                        "bbox": bbox,
                        "saved_path": saved_path,
                        "detection_num": detection_count,
                        "plate_text": plate_text,
                        "model_type": "plate_detection"
                    })
            
            # Send back results
            await websocket.send_json({
                "detections": detections,
                "timestamp": time.time(),
                "stream_id": current_stream_id,
                "plate_detections": plate_detection_count
            })
            
    except Exception as e:
        print(f"WebSocket error for {client_id}: {e}")
    finally:
        active_connections.remove(websocket)
        print(f"Client disconnected: {client_id}")
        await websocket.close()

@app.get("/")
async def root():
    return {"status": "ok", "message": "Vehicle Smoke & Plate Detection Backend"}

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "smoke_model": os.path.basename(smoke_model_path),
        "plate_model": os.path.basename(plate_model_path)
    }

@app.get("/sample-image")
async def get_sample_image():
    import glob
    from fastapi.responses import FileResponse
    images_dir = os.path.join(BASE_DIR, "images")
    jpg_files = glob.glob(os.path.join(images_dir, "*.jpg"))
    if jpg_files:
        return FileResponse(jpg_files[0], media_type="image/jpeg", filename=os.path.basename(jpg_files[0]))
    raise HTTPException(status_code=404, detail="No sample images found")

if __name__ == "__main__":
    import uvicorn
    print("Starting FastAPI Backend on http://0.0.0.0:8000 ...")
    uvicorn.run("Server_CLI:app", host="0.0.0.0", port=8000, reload=False)
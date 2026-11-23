import customtkinter as ctk
import threading
import asyncio
import uvicorn
from fastapi import FastAPI, UploadFile, File, HTTPException, WebSocket
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, ImageTk
import io
import cv2
import numpy as np
import tempfile
import time
from ultralytics import YOLO
import uuid
import os
from datetime import datetime
import re
import easyocr
import torch
import socket

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

model = None
plate_model = None
reader = easyocr.Reader(['en'])
active_connections = set()
gui_instance = None

image_counter = 0
video_counter = 0
stream_counter = 0

def create_image_folder(base_path, image_id):
    folder_path = os.path.join(base_path, f"image-{image_id}")
    os.makedirs(folder_path, exist_ok=True)
    return folder_path

def save_detected_portion(image, bbox, image_folder, detection_num, class_name):
    x1, y1, x2, y2 = map(int, bbox)
    detected_portion = image.crop((x1, y1, x2, y2))
    timestamp = datetime.now().strftime("%H%M%S")
    safe_class_name = "".join(c for c in class_name if c.isalnum())
    filename = f"{image_folder}/{safe_class_name}{detection_num}{timestamp}.jpg"
    detected_portion.save(filename)
    return filename

def extract_number_plate_text(image, bbox):
    x1, y1, x2, y2 = map(int, bbox)
    plate_image = image.crop((x1, y1, x2, y2))
    plate_np = np.array(plate_image)
    try:
        results = reader.readtext(plate_np)
        plate_text = " ".join([res[1] for res in results])
        plate_text = re.sub(r'[^a-zA-Z0-9 ]', '', plate_text).strip()
        return plate_text if plate_text else "No text detected"
    except Exception:
        return "OCR processing failed"

@app.post("/predict-image")
async def predict_image(file: UploadFile = File(...)):
    global image_counter, gui_instance, model, plate_model
    image_counter += 1
    current_image_id = image_counter
    image_bytes = await file.read()
    image = Image.open(io.BytesIO(image_bytes))
    if model is None or plate_model is None:
        raise HTTPException(status_code=400, detail="Models not loaded")
    results = model(image)
    plate_results = plate_model(image)
    base_dir = "detections/images"
    os.makedirs(base_dir, exist_ok=True)
    image_folder = create_image_folder(base_dir, current_image_id)
    predictions = []
    detection_count = 0
    log_entries = []
    for result in results:
        for box in result.boxes:
            detection_count += 1
            bbox = box.xyxy[0].tolist()
            class_name = model.names[int(box.cls)]
            confidence = float(box.conf)
            saved_path = save_detected_portion(image, bbox, image_folder, detection_count, class_name)
            predictions.append({
                "class_Id": int(box.cls), "class_name": class_name, "confidence": confidence,
                "bbox": bbox, "saved_path": saved_path, "image_id": current_image_id,
                "detection_num": detection_count, "model_type": "object_detection"
            })
            log_entries.append(f"Image ID {current_image_id} - Object: {class_name}, Confidence: {confidence:.2f}")
    plate_detection_count = 0
    for result in plate_results:
        for box in result.boxes:
            detection_count += 1
            plate_detection_count += 1
            bbox = box.xyxy[0].tolist()
            class_name = plate_model.names[int(box.cls)]
            confidence = float(box.conf)
            saved_path = save_detected_portion(image, bbox, image_folder, detection_count, class_name)
            plate_text = extract_number_plate_text(image, bbox)
            predictions.append({
                "class_Id": int(box.cls), "class_name": class_name, "confidence": confidence,
                "bbox": bbox, "saved_path": saved_path, "image_id": current_image_id,
                "detection_num": detection_count, "plate_text": plate_text, "model_type": "plate_detection"
            })
            log_entries.append(f"Image ID {current_image_id} - Plate: {class_name}, Text: {plate_text}, Confidence: {confidence:.2f}")
    if gui_instance:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        for entry in log_entries:
            gui_instance.log_to_gui(f"{timestamp} - {entry}")
    return {"predictions": predictions, "image_id": current_image_id, "image_folder": image_folder, "plate_detections": plate_detection_count}

@app.post("/predict-video")
async def predict_video(file: UploadFile = File(...)):
    global video_counter, gui_instance, model, plate_model
    video_counter += 1
    current_video_id = video_counter
    with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as temp_video:
        temp_video.write(await file.read())
        video_path = temp_video.name
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise HTTPException(status_code=400, detail="Could not open video file")
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
    log_entries = []
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        pil_image = Image.fromarray(rgb_frame)
        results = model(rgb_frame)
        plate_results = plate_model(rgb_frame)
        frame_preds = []
        for result in results:
            for box in result.boxes:
                detection_count += 1
                bbox = box.xyxy[0].tolist()
                class_name = model.names[int(box.cls)]
                confidence = float(box.conf)
                saved_path = save_detected_portion(pil_image, bbox, video_folder, detection_count, class_name)
                frame_preds.append({
                    "class_Id": int(box.cls), "class_name": class_name, "confidence": confidence,
                    "bbox": bbox, "timestamp": frame_count / fps if fps > 0 else 0, "saved_path": saved_path,
                    "detection_num": detection_count, "model_type": "object_detection"
                })
                log_entries.append(f"Video ID {current_video_id}, Frame {frame_count} - Object: {class_name}, Confidence: {confidence:.2f}")
        for result in plate_results:
            for box in result.boxes:
                detection_count += 1
                plate_detection_count += 1
                bbox = box.xyxy[0].tolist()
                class_name = plate_model.names[int(box.cls)]
                confidence = float(box.conf)
                saved_path = save_detected_portion(pil_image, bbox, video_folder, detection_count, class_name)
                plate_text = extract_number_plate_text(pil_image, bbox)
                frame_preds.append({
                    "class_Id": int(box.cls), "class_name": class_name, "confidence": confidence,
                    "bbox": bbox, "timestamp": frame_count / fps if fps > 0 else 0, "saved_path": saved_path,
                    "detection_num": detection_count, "plate_text": plate_text, "model_type": "plate_detection"
                })
                log_entries.append(f"Video ID {current_video_id}, Frame {frame_count} - Plate: {class_name}, Text: {plate_text}, Confidence: {confidence:.2f}")
        predictions.append({"frame": frame_count, "timestamp": frame_count / fps if fps > 0 else 0, "detections": frame_preds})
        frame_count += 1
        if time.time() - last_time < 0.033:
            await asyncio.sleep(0.01)
        last_time = time.time()
    cap.release()
    os.unlink(video_path)
    if gui_instance:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        for entry in log_entries:
            gui_instance.log_to_gui(f"{timestamp} - {entry}")
    return {
        "video_predictions": predictions, "fps": fps, "total_frames": total_frames,
        "duration": duration, "video_id": current_video_id, "video_folder": video_folder,
        "plate_detections": plate_detection_count
    }

@app.websocket("/ws-video-stream")
async def websocket_video_stream(websocket: WebSocket):
    global stream_counter, gui_instance, model, plate_model
    stream_counter += 1
    current_stream_id = stream_counter
    await websocket.accept()
    active_connections.add(websocket)
    client_id = str(uuid.uuid4())
    print(f"Client connected: {client_id}")
    base_dir = "detections/streams"
    os.makedirs(base_dir, exist_ok=True)
    stream_folder = create_image_folder(base_dir, current_stream_id)
    detection_count = 0
    plate_detection_count = 0
    try:
        while True:
            data = await websocket.receive_bytes()
            nparr = np.frombuffer(data, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            if frame is None:
                continue
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            pil_image = Image.fromarray(rgb_frame)
            results = model(rgb_frame)
            plate_results = plate_model(rgb_frame)
            detections = []
            log_entries = []
            for result in results:
                for box in result.boxes:
                    detection_count += 1
                    bbox = box.xyxy[0].tolist()
                    class_name = model.names[int(box.cls)]
                    confidence = float(box.conf)
                    saved_path = save_detected_portion(pil_image, bbox, stream_folder, detection_count, class_name)
                    detections.append({
                        "class_id": int(box.cls), "class_name": class_name, "confidence": confidence,
                        "bbox": bbox, "saved_path": saved_path, "detection_num": detection_count,
                        "model_type": "object_detection"
                    })
                    log_entries.append(f"Stream ID {current_stream_id} - Object: {class_name}, Confidence: {confidence:.2f}")
            for result in plate_results:
                for box in result.boxes:
                    detection_count += 1
                    plate_detection_count += 1
                    bbox = box.xyxy[0].tolist()
                    class_name = plate_model.names[int(box.cls)]
                    confidence = float(box.conf)
                    saved_path = save_detected_portion(pil_image, bbox, stream_folder, detection_count, class_name)
                    plate_text = extract_number_plate_text(pil_image, bbox)
                    detections.append({
                        "class_id": int(box.cls), "class_name": class_name, "confidence": confidence,
                        "bbox": bbox, "saved_path": saved_path, "detection_num": detection_count,
                        "plate_text": plate_text, "model_type": "plate_detection"
                    })
                    log_entries.append(f"Stream ID {current_stream_id} - Plate: {class_name}, Text: {plate_text}, Confidence: {confidence:.2f}")
            if gui_instance:
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                for entry in log_entries:
                    gui_instance.log_to_gui(f"{timestamp} - {entry}")
            await websocket.send_json({
                "detections": detections, "timestamp": time.time(),
                "stream_id": current_stream_id, "plate_detections": plate_detection_count
            })
    except Exception as e:
        print(f"WebSocket error for {client_id}: {e}")
    finally:
        active_connections.remove(websocket)
        print(f"Client disconnected: {client_id}")
        await websocket.close()

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

class ServerGUI:
    def __init__(self, root):
        global gui_instance
        self.root = root
        self.root.title("AI-Powered Real-Time Vehicle Smoke Detection System")
        self.root.geometry("1366x768")
        self.root.minsize(800, 600)
        self.server_thread = None
        self.server_running = False
        self.detection_running = False
        self.cap = None
        self.detection_thread = None
        self.uvicorn_server = None
        self.loop = None
        self.ip_address = get_local_ip()
        self.port = 8000
        self.smoke_device = ctk.IntVar(value=1 if torch.cuda.is_available() else 0)
        self.plate_device = ctk.IntVar(value=1 if torch.cuda.is_available() else 0)
        self.smoke_model_path = ctk.StringVar(value="")
        self.plate_model_path = ctk.StringVar(value="")
        gui_instance = self
        self.setup_gui()

    def setup_gui(self):
        # Main Frame
        self.main_frame = ctk.CTkFrame(self.root)
        self.main_frame.pack(pady=10, padx=10, fill="both", expand=True)

        # Logo and Title Frame
        header_frame = ctk.CTkFrame(self.main_frame)
        header_frame.pack(fill="x", pady=10)

        # Load and display logo
        try:
            logo_image = Image.open("logo.png")
            logo_image = logo_image.resize((100, 100), Image.Resampling.LANCZOS)  # Resize logo to 100x100
            self.logo_photo = ImageTk.PhotoImage(logo_image)
            ctk.CTkLabel(header_frame, image=self.logo_photo, text="").pack(side="left", padx=10)
        except Exception as e:
            print(f"Failed to load logo: {e}")
            ctk.CTkLabel(header_frame, text="Logo not found", font=ctk.CTkFont(family="Archivo", size=16)).pack(side="left", padx=10)

        # Title
        ctk.CTkLabel(header_frame, text="AI-Powered Real-Time Vehicle Smoke Detection System", font=ctk.CTkFont(family="Archivo", size=25, weight="bold")).pack(side="left", padx=10)

        # Connection Details Frame
        conn_frame = ctk.CTkFrame(self.main_frame)
        conn_frame.pack(fill="x", pady=5)
        ctk.CTkLabel(conn_frame, text="Connection Details:", font=ctk.CTkFont(family="Archivo", size=18, weight="bold")).pack(anchor="w", padx=5)
        
        details_frame = ctk.CTkFrame(conn_frame, fg_color="transparent")
        details_frame.pack(anchor="w", padx=5, fill="x")
        ctk.CTkLabel(details_frame, text=f"IP Address: {self.ip_address}", font=ctk.CTkFont(family="Archivo", size=16, weight="bold")).pack(side="left", padx=5)
        ctk.CTkLabel(details_frame, text=f"Port: {self.port}", font=ctk.CTkFont(family="Archivo", size=16, weight="bold")).pack(side="left", padx=5)
        self.status_label = ctk.CTkLabel(details_frame, text="Offline", text_color="red", font=ctk.CTkFont(family="Archivo", size=17, weight="bold"))
        self.status_label.pack(side="left", padx=5)

        button_frame = ctk.CTkFrame(conn_frame, fg_color="transparent")
        button_frame.pack(anchor="e", padx=5)
        self.start_button = ctk.CTkButton(button_frame, text="Start Server", font=ctk.CTkFont(family="Archivo", size=14, weight="bold"), command=self.start_server)
        self.start_button.pack(side="right", padx=5)
        self.stop_button = ctk.CTkButton(button_frame, text="Stop Server", font=ctk.CTkFont(family="Archivo", size=14, weight="bold"), command=self.stop_server, state="disabled")
        self.stop_button.pack(side="right", padx=5)

        # Smoke Detector Frame
        smoke_frame = ctk.CTkFrame(self.main_frame)
        smoke_frame.pack(fill="x", pady=5)
        ctk.CTkLabel(smoke_frame, text="Smoke Detector:").pack(side="left", padx=5)
        self.smoke_entry = ctk.CTkEntry(smoke_frame, textvariable=self.smoke_model_path, width=400)
        self.smoke_entry.pack(side="left", padx=5, fill="x", expand=True)
        self.smoke_entry.configure(state="disabled")
        ctk.CTkButton(smoke_frame, text="Browse", font=ctk.CTkFont(family="Archivo", size=14, weight="bold"), command=self.browse_smoke_model).pack(side="left", padx=5)
        self.smoke_cpu_radio = ctk.CTkRadioButton(smoke_frame, text="CPU", font=ctk.CTkFont(family="Archivo", size=14), variable=self.smoke_device, value=0)
        self.smoke_cpu_radio.pack(side="left", padx=5)
        self.smoke_gpu_radio = ctk.CTkRadioButton(smoke_frame, text="GPU", font=ctk.CTkFont(family="Archivo", size=14), variable=self.smoke_device, value=1)
        self.smoke_gpu_radio.pack(side="left", padx=5)
        if not torch.cuda.is_available():
            self.smoke_gpu_radio.configure(state="disabled")
            self.smoke_device.set(0)
        else:
            self.smoke_cpu_radio.configure(state="disabled")
            self.smoke_device.set(1)

        # Number Plate Detector Frame
        plate_frame = ctk.CTkFrame(self.main_frame)
        plate_frame.pack(fill="x", pady=5)
        ctk.CTkLabel(plate_frame, text="Number Plate Detector:").pack(side="left", padx=5)
        self.plate_entry = ctk.CTkEntry(plate_frame, textvariable=self.plate_model_path, width=400)
        self.plate_entry.pack(side="left", padx=5, fill="x", expand=True)
        self.plate_entry.configure(state="disabled")
        ctk.CTkButton(plate_frame, text="Browse", font=ctk.CTkFont(family="Archivo", size=14, weight="bold"), command=self.browse_plate_model).pack(side="left", padx=5)
        self.plate_cpu_radio = ctk.CTkRadioButton(plate_frame, text="CPU", font=ctk.CTkFont(family="Archivo", size=14), variable=self.plate_device, value=0)
        self.plate_cpu_radio.pack(side="left", padx=5)
        self.plate_gpu_radio = ctk.CTkRadioButton(plate_frame, text="GPU", font=ctk.CTkFont(family="Archivo", size=14), variable=self.plate_device, value=1)
        self.plate_gpu_radio.pack(side="left", padx=5)
        if not torch.cuda.is_available():
            self.plate_gpu_radio.configure(state="disabled")
            self.plate_device.set(0)
        else:
            self.plate_cpu_radio.configure(state="disabled")
            self.plate_device.set(1)

        # Live Detection and Log Frames
        main_content = ctk.CTkFrame(self.main_frame)
        main_content.pack(fill="both", expand=True, pady=5)

        live_frame = ctk.CTkFrame(main_content)
        live_frame.pack(side="left", fill="both", expand=True, padx=5)
        ctk.CTkLabel(live_frame, text="Live Detection", font=ctk.CTkFont(family="Archivo", size=18, weight="bold")).pack(pady=5)
        self.canvas = ctk.CTkCanvas(live_frame, bg="black")
        self.canvas.pack(pady=5, fill="both", expand=True)
        self.detect_button = ctk.CTkButton(live_frame, text="Start Live Detection", font=ctk.CTkFont(family="Archivo", size=14, weight="bold"), command=self.toggle_detection)
        self.detect_button.pack(pady=5)

        log_frame = ctk.CTkFrame(main_content)
        log_frame.pack(side="right", fill="both", expand=True, padx=5)
        ctk.CTkLabel(log_frame, text="Detection Log", font=ctk.CTkFont(family="Archivo", size=18, weight="bold")).pack(pady=5)
        self.log_text = ctk.CTkTextbox(log_frame, wrap="word")
        self.log_text.pack(fill="both", expand=True)
        self.log_text.configure(state="disabled")

    def browse_smoke_model(self):
        global model
        file_path = ctk.filedialog.askopenfilename(filetypes=[("Model Files", "*.pt")])
        if file_path:
            self.smoke_model_path.set(file_path)
            device = 'cuda' if self.smoke_device.get() == 1 and torch.cuda.is_available() else 'cpu'
            model = YOLO(file_path).to(device)
            self.log_to_gui(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Smoke model loaded: {file_path} on {device}")

    def browse_plate_model(self):
        global plate_model
        file_path = ctk.filedialog.askopenfilename(filetypes=[("Model Files", "*.pt")])
        if file_path:
            self.plate_model_path.set(file_path)
            device = 'cuda' if self.plate_device.get() == 1 and torch.cuda.is_available() else 'cpu'
            plate_model = YOLO(file_path).to(device)
            self.log_to_gui(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Number plate model loaded: {file_path} on {device}")

    def log_to_gui(self, message):
        self.log_text.configure(state="normal")
        self.log_text.insert("end", message + "\n")
        self.log_text.see("end")
        self.log_text.configure(state="disabled")

    async def run_uvicorn(self):
        config = uvicorn.Config(app, host="0.0.0.0", port=self.port)
        self.uvicorn_server = uvicorn.Server(config)
        await self.uvicorn_server.serve()

    def start_server(self):
        if not self.server_running:
            self.loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self.loop)
            self.server_thread = threading.Thread(target=self.run_server_loop, daemon=True)
            self.server_thread.start()
            self.server_running = True
            self.status_label.configure(text="Running", text_color="green")
            self.start_button.configure(state="disabled")
            self.stop_button.configure(state="normal")
            self.log_to_gui(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Server started")

    def run_server_loop(self):
        try:
            self.loop.run_until_complete(self.run_uvicorn())
        except Exception as e:
            if self.server_running:
                self.log_to_gui(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Server error: {e}")
        finally:
            self.server_running = False
            self.root.after(0, lambda: self.status_label.configure(text="Offline", text_color="red"))
            self.root.after(0, lambda: self.start_button.configure(state="normal"))
            self.root.after(0, lambda: self.stop_button.configure(state="disabled"))

    def stop_server(self):
        if self.server_running:
            self.log_to_gui(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Stopping server...")
            if self.uvicorn_server:
                self.loop.call_soon_threadsafe(self.loop.stop)
                asyncio.run_coroutine_threadsafe(self.uvicorn_server.shutdown(), self.loop)
            self.server_thread.join(timeout=5.0)
            self.server_running = False
            self.status_label.configure(text="Offline", text_color="red")
            self.start_button.configure(state="normal")
            self.stop_button.configure(state="disabled")
            self.log_to_gui(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Server stopped")
            self.cleanup()

    def toggle_detection(self):
        global model, plate_model
        if not self.detection_running:
            if model is None or plate_model is None:
                self.log_to_gui(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Error: Models not loaded")
                return
            self.cap = cv2.VideoCapture(0)
            if not self.cap.isOpened():
                self.log_to_gui(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Error: Could not open webcam")
                return
            self.detection_running = True
            self.detect_button.configure(text="Stop Live Detection", font=ctk.CTkFont(family="Archivo", size=14, weight="bold"))
            self.detection_thread = threading.Thread(target=self.run_detection, daemon=True)
            self.detection_thread.start()
            device_smoke = "GPU" if self.smoke_device.get() == 1 and torch.cuda.is_available() else "CPU"
            device_plate = "GPU" if self.plate_device.get() == 1 and torch.cuda.is_available() else "CPU"
            self.log_to_gui(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Live detection started (Smoke: {device_smoke}, Plate: {device_plate})")
        else:
            self.detection_running = False
            self.detect_button.configure(text="Start Live Detection")
            if self.cap:
                self.cap.release()
                self.cap = None
            self.canvas.delete("all")
            self.canvas.create_text(self.canvas.winfo_width() // 2, self.canvas.winfo_height() // 2, text="Webcam Stopped", fill="white", font=("Arial", 20))
            self.log_to_gui(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Live detection stopped")

    def run_detection(self):
        global stream_counter, model, plate_model
        stream_counter += 1
        current_stream_id = stream_counter
        base_dir = "detections/streams"
        os.makedirs(base_dir, exist_ok=True)
        stream_folder = create_image_folder(base_dir, current_stream_id)
        detection_count = 0
        plate_detection_count = 0
        device_smoke = 'cuda' if self.smoke_device.get() == 1 and torch.cuda.is_available() else 'cpu'
        device_plate = 'cuda' if self.plate_device.get() == 1 and torch.cuda.is_available() else 'cpu'
        model.to(device_smoke)
        plate_model.to(device_plate)
        while self.detection_running and self.cap.isOpened():
            ret, frame = self.cap.read()
            if not ret:
                break
            canvas_width = self.canvas.winfo_width()
            canvas_height = self.canvas.winfo_height()
            frame = cv2.resize(frame, (canvas_width, canvas_height))
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            pil_image = Image.fromarray(rgb_frame)
            results = model(rgb_frame)
            plate_results = plate_model(rgb_frame)
            log_entries = []
            for result in results:
                for box in result.boxes:
                    detection_count += 1
                    bbox = box.xyxy[0].tolist()
                    class_name = model.names[int(box.cls)]
                    confidence = float(box.conf)
                    x1, y1, x2, y2 = map(int, bbox)
                    cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                    label = f"{class_name}: {confidence:.2f}"
                    cv2.putText(frame, label, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
                    save_detected_portion(pil_image, bbox, stream_folder, detection_count, class_name)
                    log_entries.append(f"Stream ID {current_stream_id} - Object: {class_name}, Confidence: {confidence:.2f}")
            for result in plate_results:
                for box in result.boxes:
                    detection_count += 1
                    plate_detection_count += 1
                    bbox = box.xyxy[0].tolist()
                    class_name = plate_model.names[int(box.cls)]
                    confidence = float(box.conf)
                    x1, y1, x2, y2 = map(int, bbox)
                    cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 0, 255), 2)
                    plate_text = extract_number_plate_text(pil_image, bbox)
                    label = f"{class_name}: {plate_text}"
                    cv2.putText(frame, label, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 2)
                    save_detected_portion(pil_image, bbox, stream_folder, detection_count, class_name)
                    log_entries.append(f"Stream ID {current_stream_id} - Plate: {class_name}, Text: {plate_text}, Confidence: {confidence:.2f}")
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            for entry in log_entries:
                self.log_to_gui(f"{timestamp} - {entry}")
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            img = Image.fromarray(frame_rgb)
            imgtk = ImageTk.PhotoImage(image=img)
            self.canvas.create_image(0, 0, anchor="nw", image=imgtk)
            self.canvas.image = imgtk
            time.sleep(0.033)
        if self.cap:
            self.cap.release()
            self.cap = None
        self.detection_running = False
        self.detect_button.configure(text="Start Live Detection")
        self.canvas.delete("all")
        self.canvas.create_text(self.canvas.winfo_width() // 2, self.canvas.winfo_height() // 2, text="Webcam Stopped", fill="white", font=("Arial", 20))
        self.log_to_gui(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Live detection stopped")

    def cleanup(self):
        if self.detection_running:
            self.toggle_detection()
        self.root.quit()
        self.root.destroy()

def create_gui():
    root = ctk.CTk()
    app = ServerGUI(root)
    root.protocol("WM_DELETE_WINDOW", app.cleanup)
    root.mainloop()

if __name__ == "__main__":
    gui_thread = threading.Thread(target=create_gui, daemon=True)
    gui_thread.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Shutting down...")
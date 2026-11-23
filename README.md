# 🚗 AI-Powered Vehicle Smoke & Number Plate Detection System

[![Python](https://img.shields.io/badge/Python-3.11+-blue.svg)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688.svg)](https://fastapi.tiangolo.com/)
[![YOLOv8](https://img.shields.io/badge/YOLOv8-Ultralytics-orange.svg)](https://docs.ultralytics.com/)
[![EasyOCR](https://img.shields.io/badge/EasyOCR-PyTorch-green.svg)](https://github.com/JaidedAI/EasyOCR)
[![Flutter](https://img.shields.io/badge/Flutter-3.35+-02569B.svg)](https://flutter.dev/)

An end-to-end intelligent traffic monitoring and environmental compliance system. The platform detects vehicles emitting excessive exhaust smoke (black/white smoke) in real-time and concurrently pinpoints and extracts their license plate registration numbers using computer vision and deep learning.

---

## 🌟 Key Features

- **💨 Vehicle Smoke Detection**: Custom YOLOv8 model trained to detect smoke clouds emitted by moving vehicles with high confidence.
- **🏷️ License Plate Localization**: Dedicated YOLOv8 model to pinpoint the exact bounding box of vehicle number plates.
- **🔤 Automated OCR**: Integrated **EasyOCR** engine to read and clean alphanumeric vehicle registration numbers.
- **⚡ Real-Time Streaming**: Low-latency WebSocket video streaming (`/ws-video-stream`) for live CCTV and traffic camera feeds.
- **📱 Cross-Platform Frontend**: Beautiful Flutter client (Web, Desktop, Mobile) featuring 5 modules:
  - **Dashboard**: Live backend telemetry, ping latency, and detection counters.
  - **Image AI**: File upload, bounding box canvas overlay, confidence scores, and plate OCR cards.
  - **Video AI**: Frame-by-frame analysis with emission timelines.
  - **Live Stream**: Real-time camera feed with dynamic bounding box painter at 15+ FPS.
  - **Settings**: Dynamic server endpoint configuration and model health inspector.
- **💾 Automated Evidence Logging**: Automatically crops and saves detected vehicle portions, smoke regions, and license plates to categorized disk directories.

---

## 🏗️ System Architecture

```
┌─────────────────────────────────┐
│     Flutter Client (Frontend)   │
│ (Web / Windows Desktop / Mobile)│
└────────────────┬────────────────┘
                 │ HTTP / WebSocket (Port 8000)
                 ▼
┌─────────────────────────────────┐
│     FastAPI Backend Server      │
│  ├── /predict-image  (REST)     │
│  ├── /predict-video  (REST)     │
│  └── /ws-video-stream (WS)      │
└────────┬──────────────┬─────────┘
         │              │
         ▼              ▼
┌────────────────┐ ┌────────────────┐
│  YOLOv8 Smoke  │ │  YOLOv8 Plate  │
│  Model (CPU)   │ │  Model (CPU)   │
└────────────────┘ └───────┬────────┘
                           ▼
                   ┌────────────────┐
                   │    EasyOCR     │
                   │ (Text Extract) │
                   └────────────────┘
```

---

## 📁 Repository Structure

```
├── Application_Backend/         # FastAPI Python server
│   ├── Server_CLI.py           # Primary REST & WebSocket FastAPI application
│   ├── Server_GUI.py           # CustomTkinter GUI server interface
│   └── requirements.txt        # Python backend dependencies
├── flutter_application_1/      # Flutter cross-platform application
│   ├── lib/
│   │   ├── main.dart           # App entry point & navigation shell
│   │   ├── models/             # Data models for detections & responses
│   │   ├── screens/            # Dashboard, Image AI, Video AI, Live Stream, Settings
│   │   ├── services/           # HTTP API & WebSocket client services
│   │   └── widgets/            # Custom painters (bounding boxes) & cards
│   └── pubspec.yaml            # Flutter package manifest
├── samples/                    # Sample vehicle images for testing
├── smoke.pt                    # Trained YOLOv8 Smoke Detection model weights
├── number_plate.pt             # Trained YOLOv8 Number Plate Detection model weights
└── README.md
```

---

## 🚀 Quick Start Guide

### 1. Prerequisites
- **Python 3.10+** (tested on Python 3.11)
- **Flutter SDK** (3.35+ recommended)
- **Git**

### 2. Backend Setup
```bash
# Clone the repository
git clone https://github.com/nazimali-pro/vehicle-smoke-detection.git
cd vehicle-smoke-detection

# Create and activate virtual environment
python -m venv venv
# On Windows:
.\venv\Scripts\activate
# On Linux / macOS:
source venv/bin/activate

# Install backend dependencies
pip install -r Application_Backend/requirements.txt

# Run the FastAPI server
cd Application_Backend
python Server_CLI.py
```
> The backend server starts at `http://127.0.0.1:8000`. You can inspect the health check at `http://127.0.0.1:8000/health`.

### 3. Frontend Setup (Flutter)
```bash
cd flutter_application_1

# Install Flutter dependencies
flutter pub get

# Run on Chrome (Web)
flutter run -d chrome

# Or run as Windows desktop app
flutter run -d windows
```

---

## 🔌 API Reference

| Endpoint | Method | Type | Description |
|---|---|---|---|
| `/health` | `GET` | REST | Health check, returns model status |
| `/sample-image` | `GET` | REST | Fetches a sample vehicle image for quick testing |
| `/predict-image` | `POST` | REST | Multipart upload of a single vehicle image |
| `/predict-video` | `POST` | REST | Multipart upload of an `.mp4` video for timeline analysis |
| `/ws-video-stream` | `WEBSOCKET` | WebSocket | High-throughput binary frame streaming |

---

## 📜 License
This project is licensed under the MIT License - see the LICENSE file for details.

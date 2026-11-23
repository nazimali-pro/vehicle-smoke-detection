from ultralytics import YOLO
from multiprocessing import freeze_support

def train_model():
    # Initialize the YOLO model with pre-trained weights
    model = YOLO('yolo11n.pt')  # Lightweight model for RTX 3070

    # Define optimized training parameters
    train_params = {
        'data': 'H:\\Final_Year_Project\\YOLO_Datasets\\Data\\data.yaml',
        'epochs': 70,
        'imgsz': 640,  # Standard resolution for YOLOv8
        'batch': 32,  # Increased batch size for RTX 3070 (8GB VRAM)
        'device': 0,  # Explicitly specify GPU (CUDA device 0)
        'workers': 12,  # More workers for faster data loading
        'optimizer': 'AdamW',  # AdamW for better generalization
        'lr0': 0.001,  # Initial learning rate
        'lrf': 0.01,  # Final learning rate factor for cosine annealing
        'momentum': 0.937,  # Default for YOLOv8
        'weight_decay': 0.0005,  # Standard weight decay
        'warmup_epochs': 3,  # Warmup for stable training
        'warmup_momentum': 0.8,
        'amp': True,  # Enable automatic mixed precision
        #'cache': 'disk',  # Cache images to disk for faster training
        'project': 'AI-Powered_Vehicle_Smoke_Detection_System',
        'name': 'Smoke_Model_yoloV11n_70',
        'exist_ok': True,  # Overwrite existing runs
        'patience': 50,  # Early stopping if no improvement
        'cos_lr': True,  # Cosine learning rate scheduler
        'save_period': 10,  # Save checkpoint every 10 epochs
    }

    # Train the model
    model.train(**train_params)

if __name__ == '__main__':
    freeze_support()
    try:
        train_model()
    except Exception as e:
        print(f"Training failed: {e}")
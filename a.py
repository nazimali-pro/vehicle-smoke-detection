from ultralytics import YOLO

def main():
    # Load pre-trained model
    model = YOLO("yolo11n.pt")  # or yolov8s.pt, etc.

    try:
        # Train the model
        model.train(
            data='H:\\Final_Year_Project\\YOLO_Datasets\\Data_with_Blue\\data.yaml',
            epochs=100,
            imgsz=640,
            batch=48,
            project="AI-Powered_Vehicle_Smoke_Detection_System",
            name="Smoke_YOLOv11n(Testing724)",
            device='cuda'  # Use GPU
        )
        print("Training completed successfully!")

        # Validate the model
        val_results = model.val(device='cuda')
        print("Validation completed successfully!")

        # Print validation metrics
        print(f"mAP50-95: {val_results.box.map}")
        print(f"mAP50: {val_results.box.map50}")
        print(f"Precision: {val_results.box.precision}")
        print(f"Recall: {val_results.box.recall}")

    except Exception as e:
        print(f"Training or validation failed: {e}")

if __name__ == '__main__':
    from multiprocessing import freeze_support
    freeze_support()  # Needed only for Windows
    main()

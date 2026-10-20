# TruthLens-AI

TruthLens-AI is an AI-powered deepfake image detection system designed to help users identify manipulated or synthetic images. The project combines deep learning-based image analysis with a simple cross-platform user interface, allowing users to upload images and receive authenticity assessments in real time.

---

## Motivation

With the rapid advancement of generative AI, manipulated media has become increasingly difficult to identify. TruthLens-AI was built to explore how deep learning models can be used to detect visual inconsistencies commonly found in AI-generated or altered images.

The primary goal of the project was to gain hands-on experience with computer vision, model deployment, API development, and mobile application integration while addressing a real-world problem.

---

## Features

- Upload images for deepfake analysis
- Batch processing of multiple images
- Deep learning-powered image classification
- EXIF metadata analysis
- Real-time prediction results
- Fast API-based inference
- Cross-platform mobile application
- Related news feed covering developments in AI-generated media and deepfakes
- Modular architecture for future model upgrades

---

## EXIF Metadata Analysis

In addition to deep learning-based image analysis, TruthLens-AI performs EXIF metadata inspection.

EXIF (Exchangeable Image File Format) metadata can provide useful information about an image, including:

- Device information
- Camera details
- Creation timestamps
- Editing history indicators
- Geolocation data (when available)

While EXIF metadata alone cannot determine whether an image is a deepfake, it serves as an additional signal that can help users assess image authenticity and identify potential anomalies.

The metadata analysis component is designed to complement the model's prediction rather than replace it.

## Batch Processing

TruthLens-AI supports batch image analysis, allowing users to evaluate multiple images in a single workflow.

This feature was introduced to improve usability for scenarios such as:

- Content moderation
- Investigative analysis
- Dataset validation
- Media verification workflows

Batch processing reduces manual effort and provides a more efficient user experience when handling large numbers of images.

## Deepfake News Integration

TruthLens-AI includes a news aggregation component that surfaces recent developments related to:

- Deepfake technology
- AI-generated content
- Misinformation campaigns
- Digital media authenticity
- AI safety and regulation

The purpose of this feature is to provide users with broader context about the rapidly evolving deepfake landscape.

By combining image analysis with relevant news coverage, the platform aims to increase awareness of emerging risks and trends in synthetic media.

## System Architecture

The app runs on the phone by itself — there is no server to deploy or pay for.

```text
                Flutter app (on the phone)
   ┌───────────────────────────────────────────────┐
   │ face check (ML Kit) → TFLite model → EXIF      │
   │                    → explanation (OpenAI*)     │
   │ challenge images bundled in the app            │
   └───────────────┬───────────────────────────────┘
                   │
       Firebase (free Spark plan)        NewsAPI*
       • Auth: accounts, email links     • news feed
       • Firestore: history, badges,
         streaks, leaderboard

   * optional — without a key the app uses built-in text / cached news
```

### Workflow

1. User picks or captures an image in the Flutter app.
2. ML Kit checks that the image contains a face.
3. The image is resized to 224×224 and passed to the TFLite model on the device.
4. The model predicts whether the image appears authentic or manipulated, and the EXIF metadata is analysed alongside it.
5. The result is shown immediately and saved to the user's history in Firestore.

---

## Technology Stack

### Backend

- None at runtime — Firebase Auth + Cloud Firestore (Spark plan)
- `backend/` (Python, FastAPI) is the original server, kept for reference and for model parity checks

### Machine Learning

- Deep Learning
- Computer Vision
- TensorFlow / TensorFlow Lite

### Frontend

- Flutter
- Dart

### Deployment

- On-device TFLite inference (`tflite_flutter`)
- Sideloaded Android APK

---

## Why These Technologies?

### Why FastAPI?

FastAPI was chosen because it provides:

- High performance
- Automatic API documentation
- Easy integration with machine learning models
- Simple deployment workflow

For inference-based applications, FastAPI offers a good balance between developer productivity and performance.

### Why Flutter?

Flutter was selected to enable cross-platform development from a single codebase. This allowed the frontend to target multiple platforms without maintaining separate native applications.

### Why Deep Learning?

Traditional image-processing techniques often struggle to identify sophisticated manipulations. Deep learning models can learn complex visual patterns and are better suited for detecting subtle artifacts introduced during image generation or editing.

---

## Design Decisions

### Mobile-First Approach

The project was designed around a mobile experience because misinformation and manipulated media are commonly consumed through mobile devices.

### API-Based Inference

Instead of embedding the entire model directly into the frontend application, inference is handled through a backend API. This separation improves maintainability and allows future model updates without requiring frontend changes.

### Modular Architecture

The frontend, backend, and machine learning components are loosely coupled, making it easier to upgrade individual parts of the system independently.

---

## Challenges Faced

### Model Deployment

Deploying machine learning models often introduces challenges related to model size, inference speed, and dependency management.

### Latency Optimization

Balancing prediction accuracy with acceptable response times required careful consideration during deployment.

### Mobile Integration

Integrating machine learning workflows with a mobile application required additional attention to API communication and user experience.

---

## Design Tradeoffs

### Deep Learning vs Rule-Based Detection

The project prioritizes deep learning-based detection because modern deepfakes often bypass traditional rule-based approaches. However, this introduces challenges related to explainability and model maintenance.

### Accuracy vs Inference Speed

Higher-capacity models can improve detection quality but increase latency. The system balances responsiveness with predictive performance to provide a practical user experience.

### Metadata Analysis vs Content Analysis

EXIF analysis provides useful contextual signals but can be manipulated or removed entirely. For this reason, metadata analysis is treated as a complementary signal rather than a primary detection mechanism.

### Feature Richness vs Simplicity

The project combines image analysis, metadata inspection, batch processing, and news aggregation. While this creates a more comprehensive platform, it also increases architectural complexity compared to a single-purpose detection application.

---

## Future Improvements

Potential future enhancements include:

- Support for video deepfake detection
- Explainable AI visualizations
- Confidence score interpretation
- Batch image processing
- Improved model architecture
- Cloud deployment for larger-scale usage
- Continuous model retraining pipeline

---

## What I Would Do Differently

If I were rebuilding TruthLens-AI today, I would:

- Incorporate transformer-based vision architectures for improved detection performance
- Add explainable AI visualizations to highlight suspicious image regions
- Introduce confidence calibration and uncertainty estimation
- Expand metadata analysis beyond standard EXIF information
- Build a continuous evaluation pipeline using curated deepfake datasets
- Add support for video deepfake detection
- Implement cloud-based inference for improved scalability
- Develop a feedback mechanism that allows users to flag incorrect predictions

---

## Key Learnings

Through TruthLens-AI, I gained experience with:

- Deep learning workflows
- Computer vision applications
- FastAPI development
- Mobile application integration
- Model deployment considerations
- Designing AI systems for real-world use cases

---

## Repository Structure

```text
TruthLens-AI/
├── frontend/                 Flutter app — everything the user runs
│   ├── lib/services/         detection, EXIF, explanation, news, Firebase auth/data
│   ├── assets/models/        the .tflite model (not in git — add it before building)
│   ├── assets/challenge/     images for the real-vs-fake challenge
│   └── env.example.json      API key template (copy to env.json)
├── firestore.rules           Firestore security rules
└── backend/                  original FastAPI server (legacy reference, not deployed)
```

---

## Run Locally

Everything runs on the phone; there is no server to start.

**1. Model file.** Put `deepfake_detector_fp16.tflite` in `frontend/assets/models/`.
It is not in git. If you only have the Keras model, convert it with
`backend/convert_to_tflite.py`. Then check it on a connected phone:

```bash
cd frontend
flutter test integration_test/on_device_test.dart -d <device-id>
```

This confirms the phone builds exactly the input the model was trained on
(compared with Pillow), that the face check works, and that a face photo gets
a REAL/FAKE verdict.

**2. API keys (optional).**

```bash
cd frontend
cp env.example.json env.json   # gitignored
```

- `OPENAI_API_KEY`: AI-written explanations. Leave it empty to use the built-in text.
  Note that it ships inside the APK, so use a separate OpenAI project with a low usage limit.
- `NEWS_API_KEY`: the news feed (NewsAPI free plan, 100 requests/day per key).

**3. Run** (Flutter, Android device connected):

```bash
flutter pub get
flutter run --dart-define-from-file=env.json
```

**Release APK** (sideload; one APK per CPU type, `app-arm64-v8a-release.apk` fits almost every current phone):

```bash
flutter build apk --release --split-per-abi --dart-define-from-file=env.json
```

Release builds are signed with the keystore named in `android/key.properties`
(gitignored; without it they fall back to debug keys). Keep the keystore safe:
an APK signed with a different key cannot update the installed app.

**Firebase** is already configured (`lib/firebase_options.dart`, project
`truthlens-ai-hd`). To change the security rules:
`firebase deploy --only firestore:rules`.

---

## Disclaimer

TruthLens-AI is an educational and portfolio project intended to explore deepfake detection techniques. Predictions generated by the system should not be considered definitive proof of authenticity or manipulation.

# VisionSaliency 

> **Attention-Based Saliency Detection for iOS**  
> Harness the power of Apple's Vision Framework to detect and visualize attention-grabbing areas in images with advanced computer vision algorithms.

![iOS](https://img.shields.io/badge/iOS-18.4+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![Xcode](https://img.shields.io/badge/Xcode-16.3+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 🌟 Features

### Core Functionality
- **🎯 Attention Detection**: Utilizes Apple's `VNGenerateAttentionBasedSaliencyImageRequest` for state-of-the-art saliency analysis
- **📸 Multi-Input Support**: Capture photos directly or select from photo library
- **🖼️ Multiple Visualizations**: Original, saliency map, and combined overlay views
- **🤖 API-Ready Processing**: Intelligent cropping and resizing for optimal API consumption

### Advanced Image Processing
- **🎨 Dynamic Visualization**: False-color overlay showing attention areas in red
- **📐 Smart Cropping**: Centroid-based region of interest detection
- **🔍 Adaptive Resizing**: Dynamic resolution scaling based on content analysis
- **💾 Export Functionality**: Save processed images directly to Photos library

- ![Uploading Frame 3383@3x.png…]()

### User Experience
- **🚀 Real-time Processing**: Asynchronous image analysis with progress indicators
- **📊 Detailed Analytics**: Confidence scores and processing metrics
- **🎛️ Intuitive Interface**: Clean SwiftUI design with smooth animations
- **🔄 Seamless Workflow**: Gallery selection, camera capture, and instant processing

## 🛠️ Technical Architecture

### Vision Framework Integration
```swift
// Core saliency detection implementation
let request = VNGenerateAttentionBasedSaliencyImageRequest()
let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
try await handler.perform([request])
```

### Advanced Processing Pipeline
1. **Image Acquisition** - Camera or Photo Library
2. **Saliency Analysis** - Vision Framework processing
3. **Centroid Calculation** - Intensity-weighted attention center
4. **ROI Optimization** - Smart bounding box selection
5. **Dynamic Cropping** - Context-aware padding and scaling
6. **Multi-format Export** - Various output resolutions

### Key Components
- **`SaliencyDetector`**: Core processing engine with `@MainActor` optimization
- **`ImagePicker`**: Custom camera interface with `UIViewControllerRepresentable`
- **Smart Algorithms**: Quantile-based cropping and adaptive resolution scaling

## 📱 Screenshots & Demo

| Original Image | Attention Map | Combined View | API-Ready Output |
|:-------------:|:-------------:|:-------------:|:----------------:|
| 🖼️ Source | 🎯 Saliency | 🔴 Overlay | 🤖 Optimized |

## 🚀 Getting Started

### Prerequisites
- **iOS 18.4+** (Required for latest Vision Framework features)
- **Xcode 16.3+**
- **Swift 5.0+**
- **Physical iOS device** (Camera functionality)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/VisionSaliency.git
   cd VisionSaliency
   ```

2. **Open in Xcode**
   ```bash
   open VisionSaliency.xcodeproj
   ```

3. **Configure signing**
   - Update `DEVELOPMENT_TEAM` in project settings
   - Modify `PRODUCT_BUNDLE_IDENTIFIER` to your domain

4. **Build and run** 🎉

### Required Permissions
The app automatically requests:
- 📷 **Camera Access**: `NSCameraUsageDescription`
- 🖼️ **Photo Library**: `NSPhotoLibraryUsageDescription`

## 💡 Usage

### Basic Workflow
1. **Launch** the app on your iOS device
2. **Select source**: Choose camera or photo library
3. **Capture/Select** an image
4. **Analyze**: Watch real-time saliency detection
5. **Review**: Examine attention maps and analytics
6. **Export**: Save API-ready processed images

### Advanced Features
- **Centroid Analysis**: View intensity-weighted attention centers
- **Confidence Metrics**: Detailed processing statistics
- **Dynamic Scaling**: Automatic resolution optimization
- **Context Preservation**: Smart padding based on content analysis

## 🔬 Algorithm Details

### Saliency Detection
- Leverages Apple's cutting-edge attention-based algorithms
- Generates pixel-level confidence maps
- Identifies multiple salient regions with bounding boxes

### Smart Cropping Logic
```swift
// Dynamic padding based on border proximity
let borderMin = min(rect.minX, rect.minY, imageWidth - rect.maxX, imageHeight - rect.maxY)
let closeness = max(0, min(1, borderMin / max(imageWidth, imageHeight)))
let paddingRatio = 0.02 + 0.08 * closeness
```

### Adaptive Resolution
- **Small ROI** (< 15% of image): 512px target
- **Medium ROI** (15-35%): 640px target  
- **Large ROI** (> 35%): 768px target

## 🎯 Use Cases

### Computer Vision Applications
- **Object Detection**: Preprocessing for ML models
- **Content Analysis**: Social media and marketing
- **Accessibility**: Focus area identification
- **Research**: Academic computer vision studies

### Professional Workflows
- **Photography**: Composition analysis
- **UI/UX Design**: Attention heatmaps
- **Medical Imaging**: Region of interest detection
- **Quality Control**: Automated inspection systems

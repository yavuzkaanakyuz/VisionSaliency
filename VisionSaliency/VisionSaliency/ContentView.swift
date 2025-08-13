//
//  ContentView.swift
//  VisionSaliency
//
//  Created by Yavuz Kaan Akyüz on 8/10/25.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var detector = SaliencyDetector()
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var selectedImageType: ImageDisplayType = .original
    @State private var showingSaveSuccess = false
    
    enum ImageDisplayType: String, CaseIterable {
        case original = "Original"
        case saliency = "Attention Map"
        case combined = "Combined View"
        case apiReady = "API Ready"
        
        var icon: String {
            switch self {
            case .original: return "photo"
            case .saliency: return "eye.circle"
            case .combined: return "rectangle.stack"
            case .apiReady: return "square.and.arrow.down"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Modern Header with Gradient
                        headerSection
                            .padding(.bottom, 30)
                        
                        // Main Content Area
                        if detector.originalImage != nil {
                            imageDisplaySection(geometry: geometry)
                                .padding(.horizontal, 20)
                        } else {
                            emptyStateSection(geometry: geometry)
                                .padding(.horizontal, 20)
                        }
                        
                        // Analysis Results Card
                        if !detector.analysisResults.isEmpty {
                            analysisResultsCard
                                .padding(.horizontal, 20)
                                .padding(.top, 25)
                        }
                        
                        Spacer(minLength: 120) // Space for floating buttons
                    }
                }
                .overlay(
                    // Floating Action Buttons
                    floatingActionButtons
                        .padding(.bottom, 30)
                        .padding(.horizontal, 20),
                    alignment: .bottom
                )
            }
            .navigationBarHidden(true)
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: selectedItem) { newItem in
            Task {
                if let newItem = newItem {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        if let image = UIImage(data: data) {
                            await detector.processImage(image)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(image: .constant(nil)) { image in
                if let image = image {
                    Task {
                        await detector.processImage(image)
                    }
                }
            }
        }
        .alert("Image Saved!", isPresented: $showingSaveSuccess) {
            Button("OK") { }
        } message: {
            Text("Your API-ready image has been saved to Photos")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            // App Icon and Title
            HStack(spacing: 15) {
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vision Saliency")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("AI-Powered Attention Detection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Processing Indicator
            if detector.isProcessing {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing image...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Empty State
    private func emptyStateSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 30) {
            // Animated Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("Get Started")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Select a photo or take a new one to detect attention-grabbing areas using advanced Vision AI")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 10)
            }
            
            // Feature highlights
            VStack(spacing: 16) {
                FeatureRow(
                    icon: "eye.circle",
                    title: "Smart Detection",
                    description: "AI identifies what draws attention"
                )
                FeatureRow(
                    icon: "square.and.arrow.down",
                    title: "API Ready",
                    description: "Optimized crops for machine learning"
                )
                FeatureRow(
                    icon: "speedometer",
                    title: "Real-time",
                    description: "Instant processing on-device"
                )
            }
            .padding(.horizontal, 20)
        }
        .frame(minHeight: geometry.size.height * 0.6)
        .padding(.vertical, 40)
    }
    
    // MARK: - Image Display Section
    private func imageDisplaySection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 25) {
            // Image Type Selector
            imageTypeSelector
            
            // Main Image Display
            mainImageDisplay(geometry: geometry)
        }
    }
    
    private var imageTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ImageDisplayType.allCases, id: \.self) { type in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedImageType = type
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.caption)
                            Text(type.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedImageType == type ?
                                      Color.blue : Color(.systemGray5))
                        )
                        .foregroundColor(selectedImageType == type ? .white : .primary)
                    }
                    .disabled(imageForType(type) == nil)
                    .opacity(imageForType(type) == nil ? 0.5 : 1.0)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func mainImageDisplay(geometry: GeometryProxy) -> some View {
        Group {
            if let image = imageForType(selectedImageType) {
                VStack(spacing: 15) {
                    // Image Card
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        VStack(spacing: 15) {
                            // Image Title
                            HStack {
                                Image(systemName: selectedImageType.icon)
                                    .foregroundColor(.blue)
                                Text(selectedImageType.rawValue)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                                
                                if selectedImageType == .apiReady {
                                    Text("\(Int(image.size.width))×\(Int(image.size.height))")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(6)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            
                            // Image
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: geometry.size.height * 0.4)
                                .cornerRadius(15)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Analysis Results Card
    private var analysisResultsCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.green)
                Text("Analysis Results")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(detector.analysisResults, id: \.self) { result in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        
                        Text(result)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Floating Action Buttons
    private var floatingActionButtons: some View {
        HStack(spacing: 15) {
            // Gallery Button
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ActionButton(
                    icon: "photo.stack",
                    label: "Gallery",
                    color: .blue,
                    isEnabled: true
                )
            }
            
            // Camera Button
            Button(action: { showingCamera = true }) {
                ActionButton(
                    icon: "camera",
                    label: "Camera",
                    color: .green,
                    isEnabled: true
                )
            }
            
            // Save Button
            Button(action: {
                Task {
                    await detector.saveAPIImageToPhotos()
                    showingSaveSuccess = true
                }
            }) {
                ActionButton(
                    icon: "square.and.arrow.down",
                    label: "Save",
                    color: .orange,
                    isEnabled: detector.apiReadyImage != nil
                )
            }
            .disabled(detector.apiReadyImage == nil)
        }
    }
    
    // MARK: - Helper Functions
    private func imageForType(_ type: ImageDisplayType) -> UIImage? {
        switch type {
        case .original: return detector.originalImage
        case .saliency: return detector.saliencyImage
        case .combined: return detector.combinedImage
        case .apiReady: return detector.apiReadyImage
        }
    }
}

// MARK: - Supporting Views
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let isEnabled: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .fontWeight(.medium)
            
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    isEnabled ?
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    ) :
                    LinearGradient(
                        colors: [Color.gray, Color.gray.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(
                    color: isEnabled ? color.opacity(0.3) : Color.clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
    }
}

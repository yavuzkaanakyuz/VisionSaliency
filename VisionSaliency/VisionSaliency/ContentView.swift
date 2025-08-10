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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // Header
                Text("Attention-Based Saliency Detection")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                // Main content area
                ZStack {
                    if let originalImage = detector.originalImage {
                        ScrollView([.horizontal, .vertical]) {
                            VStack(spacing: 15) {
                                // Original photo
                                VStack {
                                    Text("Original Photo")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
                                    Image(uiImage: originalImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 300, maxHeight: 300)
                                        .cornerRadius(10)
                                        .shadow(radius: 5)
                                }
                                
                                // Saliency map
                                if let saliencyImage = detector.saliencyImage {
                                    VStack {
                                        Text("Attention Map")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        
                                        Image(uiImage: saliencyImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: 300, maxHeight: 300)
                                            .cornerRadius(10)
                                            .shadow(radius: 5)
                                    }
                                }
                                
                                // Combined image
                                if let combinedImage = detector.combinedImage {
                                    VStack {
                                        Text("Combined View")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        
                                        Image(uiImage: combinedImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: 300, maxHeight: 300)
                                            .cornerRadius(10)
                                            .shadow(radius: 5)
                                    }
                                }

                             // API-ready cropped & resized image
                             if let apiImage = detector.apiReadyImage {
                                 VStack {
                                     Text("API-Ready (Cropped + Resized)")
                                         .font(.headline)
                                         .foregroundColor(.secondary)
                                     Image(uiImage: apiImage)
                                         .resizable()
                                         .scaledToFit()
                                         .frame(maxWidth: 300, maxHeight: 300)
                                         .cornerRadius(10)
                                         .shadow(radius: 5)
                                 }
                             }
                                
                                // Analysis information
                                if detector.isProcessing {
                                    VStack {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                        Text("Analyzing...")
                                            .foregroundColor(.secondary)
                                            .padding(.top, 5)
                                    }
                                    .padding()
                                } else if !detector.analysisResults.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Analysis Results")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        ForEach(detector.analysisResults, id: \.self) { result in
                                            HStack {
                                                Circle()
                                                    .fill(Color.blue)
                                                    .frame(width: 6, height: 6)
                                                Text(result)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                            }
                            .padding()
                        }
                    } else {
                        // Placeholder
                        VStack(spacing: 20) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Select or capture a photo")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text("We'll detect attention-grabbing areas using Vision Framework")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                
                Spacer()
                
                // Bottom buttons
                HStack(spacing: 20) {
                    // Photo selection button
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Gallery", systemImage: "photo.stack")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    // Camera button
                    Button(action: {
                        showingCamera = true
                    }) {
                        Label("Camera", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    // Save API-ready image
                    Button(action: {
                        Task { await detector.saveAPIImageToPhotos() }
                    }) {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(detector.apiReadyImage == nil ? Color.gray : Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(detector.apiReadyImage == nil)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Vision Saliency")
            .navigationBarTitleDisplayMode(.inline)
        }
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
    }
}

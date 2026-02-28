//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI
import PhotosUI

struct BuildingDetailView: View {
    // MARK: - Properties
    let building: Building
    @ObservedObject var viewModel: CityDetailViewModel
    
    // MARK: - Environment & Settings
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorSchemeContrast) var contrast
    @Environment(\.dynamicTypeSize) var dynamicType
    
    @AppStorage("high_contrast_mode") var appHighContrast = false
    @AppStorage("haptics_enabled") var hapticsEnabled = true
    @AppStorage("use_metric_units") var useMetric = true
    
    // MARK: - State
    @State private var showCamera = false
    @State private var showingDeleteConfirmation = false
    @State private var isEditingPhoto = false
    
    // Manipulation State (Zoom/Pan)
    @State private var photoScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var photoOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // MARK: - Computed States
    var isVisited: Bool { GlobalProgressManager.shared.isVisited(building.id) }
    var isHighContrast: Bool { contrast == .increased || appHighContrast }
    var shouldStack: Bool { dynamicType >= .accessibility1 }
    
    var formattedHeight: String {
        if useMetric {
            return "\(Int(building.height)) m"
        } else {
            let feet = Double(building.height) * 3.28084
            return "\(Int(feet)) ft"
        }
    }
    
    // MARK: - Main Body
    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneScrollView
            }
        }
        .background(Color(.systemBackground))
        .toolbarBackground(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(buildingID: building.id)
        }
        .alert("Delete Photo?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                GlobalProgressManager.shared.deleteImage(for: building.id)
                resetManipulation()
                isEditingPhoto = false
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove your custom photo and restore the default image.")
        }
    }
    
    private func resetManipulation() {
        photoScale = 1.0
        lastScale = 1.0
        photoOffset = .zero
        lastOffset = .zero
    }
}

// MARK: - UI Components Extension
extension BuildingDetailView {
    
    private var brandColor: Color { Color.adventureOrange }
    
    // MARK: - Hero Header
    func heroHeader(height: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            let userImage = GlobalProgressManager.shared.userImages[building.id]
            
            ZStack {
                if let uiImage = userImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: height)
                        .scaleEffect(photoScale)
                        .offset(photoOffset)
                } else if let uiImage = UIImage(named: building.assetName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: height)
                } else {
                    placeholderHero
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: sizeClass == .regular ? 32 : 0))
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: sizeClass == .regular ? 32 : 0)
                    .stroke(Color.primary, lineWidth: isHighContrast ? 3 : 0)
            )
            .gesture(userImage != nil && isEditingPhoto ?
                AnyGesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { photoScale = lastScale * $0 }
                            .onEnded { _ in lastScale = photoScale },
                        DragGesture()
                            .onChanged { photoOffset = CGSize(width: lastOffset.width + $0.translation.width, height: lastOffset.height + $0.translation.height) }
                            .onEnded { _ in lastOffset = photoOffset }
                    )
                ) : nil
            )
            
            photoControls
                .padding(.trailing, 20)
                .padding(.bottom, sizeClass == .regular ? 20 : 40)
                .shadow(color: .black.opacity(isHighContrast ? 0 : 0.2), radius: 10, x: 0, y: 5)
        }
    }

    // MARK: - iPad Layout
    private var iPadLayout: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            
            if isLandscape {
                HStack(spacing: 0) {
                    VStack {
                        heroHeader(height: 750)
                            .frame(width: geo.size.width * 0.50)
                        Spacer()
                    }
                    .padding(.leading, 40)
                    .padding(.vertical, 40)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        unifiedToolbar
                            .padding(.top, 10)
                            .padding(.bottom, 34)
                            .padding(.horizontal, 40)
                        
                        ScrollView(showsIndicators: false) {
                            iPadTextContent
                                .padding(.horizontal, 40)
                                .padding(.bottom, 60)
                        }
                    }
                    .padding(.top, 40)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        heroHeader(height: 400)
                            .padding(.horizontal, 40)
                            .padding(.top, 60)

                        unifiedToolbar
                            .padding(.horizontal, 40)
                        
                        Divider()
                            .padding(.horizontal, 40)
                            .opacity(isHighContrast ? 1 : 0.5)
                        
                        iPadTextContent
                            .padding(.horizontal, 40)
                            .padding(.bottom, 60)
                    }
                }
            }
        }
    }
    
    private var placeholderHero: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 60))
                .foregroundStyle(isHighContrast ? Color.primary.gradient : brandColor.gradient)
            
            Text("Capture Your Own Photo")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(isHighContrast ? .primary : brandColor.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isHighContrast ? Color.clear : brandColor.opacity(0.05))
        .cornerRadius(sizeClass == .regular ? 32 : 0)
    }

    private var photoControls: some View {
        let userImage = GlobalProgressManager.shared.userImages[building.id]
        
        return HStack(spacing: 0) {
            if userImage != nil {
                Button {
                    withAnimation(.spring()) {
                        isEditingPhoto.toggle()
                    }
                    if hapticsEnabled { HapticManager.shared.trigger(.selection) }
                } label: {
                    Image(systemName: isEditingPhoto ? "lock.open.fill" : "lock.fill")
                        .frame(width: 44, height: 44)
                        .foregroundColor(isEditingPhoto ? brandColor : .primary)
                }
                Divider().frame(height: 20)
            }

            PhotosPicker(selection: Binding(get: { nil }, set: { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await MainActor.run {
                            GlobalProgressManager.shared.saveImage(img, for: building.id)
                            resetManipulation()
                            isEditingPhoto = true
                        }
                    }
                }
            }), matching: .images) {
                Image(systemName: "photo.fill").frame(width: 44, height: 44)
            }
            
            Divider().frame(height: 20)
            
            Button { showCamera = true } label: {
                Image(systemName: "camera.fill").frame(width: 44, height: 44)
            }
            
            if isEditingPhoto {
                if photoScale != 1.0 || photoOffset != .zero {
                    Divider().frame(height: 20)
                    Button {
                        withAnimation(.spring()) {
                            resetManipulation()
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .frame(width: 44, height: 44)
                            .foregroundColor(brandColor)
                    }
                }
                
                if userImage != nil {
                    Divider().frame(height: 20)
                    Button { showingDeleteConfirmation = true } label: {
                        Image(systemName: "trash.fill")
                            .frame(width: 44, height: 44)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .foregroundColor(.primary)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isEditingPhoto ? brandColor : Color.primary, lineWidth: isHighContrast ? 2 : (isEditingPhoto ? 1 : 0))
        )
    }

    // MARK: - iPhone Layout
    private var iPhoneScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroHeader(height: 300)
                VStack(alignment: .leading, spacing: 24) {
                    titleHeader
                    aboutSection
                    sectionHeader("Building Info")
                    technicalGrid
                    if !building.foodSpots.isEmpty {
                        foodSpotsSection(spots: building.foodSpots)
                    }
                }
                .padding(20)
                .background(Color(.systemBackground))
                .cornerRadius(25)
                .offset(y: -25)
                .padding(.bottom, 60)
            }
        }
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom) {
            stickyBottomBar
        }
    }
    
    private var stickyBottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            bottomActionButton
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }
    
    private var iPadTextContent: some View {
        VStack(alignment: .leading, spacing: 40) {
            titleHeader
            aboutSection
            sectionHeader("Technical Specs")
            technicalGrid
            if !building.foodSpots.isEmpty {
                foodSpotsSection(spots: building.foodSpots)
            }
            bottomActionButton
        }
    }

    // MARK: - Global Components
    private var unifiedToolbar: some View {
        let spacing: CGFloat = sizeClass == .regular ? 20 : 12
        let layout = shouldStack ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing)) : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
        
        return layout {
            if sizeClass == .regular {
                Spacer()
                
                Button(action: handleActionTap) {
                    let color = isVisited ? Color.green : Color.adventureOrange
                    
                    HStack(spacing: 8) {
                        Image(systemName: isVisited ? "checkmark.seal.fill" : "checkmark.seal")
                            .fontWeight(.bold)
                        Text(isVisited ? "Visited" : "Mark Visited")
                    }
                    .font(.headline)
                    .foregroundColor(isHighContrast ? .primary : color)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isHighContrast ? Color.clear : color.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
                    )
                }
            }
        }
    }

    var titleHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(building.name)
                .font(.system(sizeClass == .regular ? .largeTitle : .title, design: .serif))
                .fontWeight(.bold)
            Text("Designed by \(building.architect)")
                .font(.subheadline.italic())
                .foregroundColor(.secondary)
        }
    }

    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Historical Significance")
            Text(building.description).font(.body).lineSpacing(8)
        }
    }

    var technicalGrid: some View {
        VStack(spacing: 12) {
            specCard(label: "Location", value: building.address, icon: "mappin.and.ellipse")
            specCard(label: "Built", value: "\(building.yearBuilt)", icon: "calendar")
            specCard(label: "Height", value: formattedHeight, icon: "arrow.up.and.down")
            specCard(label: "Stories", value: "\(building.numberOfStories)", icon: "building.2")
        }
    }

    func foodSpotsSection(spots: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Local Flavors")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(spots, id: \.self) { spot in
                        foodSpotCard(spot: spot)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func foodSpotCard(spot: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(isHighContrast ? Color.primary.opacity(0.1) : brandColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "fork.knife")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isHighContrast ? .primary : brandColor)
            }
            
            Text(spot)
                .font(.subheadline)
                .fontWeight(.bold)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true) // Prevents truncation
                .multilineTextAlignment(.leading)
                .foregroundColor(.primary)
            
            Spacer(minLength: 4)
            
            Text("Nearby")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .padding(16)
        .frame(width: 160)
        .frame(minHeight: 160)
        .background(isHighContrast ? Color.clear : Color.primary.opacity(0.05))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary, lineWidth: isHighContrast ? 2 : 0)
        )
    }

    var bottomActionButton: some View {
        let activeColor = isVisited ? Color.green : brandColor
        
        return Button(action: handleActionTap) {
            Label(isVisited ? "Visited" : "Mark as Visited", systemImage: isVisited ? "checkmark.seal.fill" : "checkmark.seal")
                .fontWeight(.bold)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .foregroundColor(isHighContrast ? .primary : activeColor)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isHighContrast ? Color.clear : activeColor.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
                )
        }
    }
    
    func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.title3, design: .serif))
                .fontWeight(.bold)
            
            Rectangle()
                .fill(isHighContrast ? Color.primary : brandColor.opacity(0.3))
                .frame(width: 40, height: 4)
                .cornerRadius(2)
        }
    }

    func specCard(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(isHighContrast ? .primary : brandColor)
                .font(.system(size: 18, weight: isHighContrast ? .bold : .regular))
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.callout.monospaced())
                    .fontWeight(.bold)
            }
            Spacer()
        }
        .padding()
        .background(isHighContrast ? Color.clear : Color.primary.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary, lineWidth: isHighContrast ? 2 : 0)
        )
    }

    func handleActionTap() {
        withAnimation(.spring()) { viewModel.toggleVisited(for: building) }
        if hapticsEnabled { HapticManager.shared.trigger(isVisited ? .success : .warning) }
    }
}

import SwiftUI
import AVFoundation

struct CroppingView: View {
    let image: NSImage
    @Binding var croppedImage: NSImage?
    @Environment(\.dismiss) var dismiss
    
    // State for the drag gesture
    @State private var selection: CGRect?
    @State private var dragStart: CGPoint?
    @State private var currentDrag: CGPoint?
    
    // State to hold the size of the view containing the image
    @State private var geometrySize: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Click and drag to select an area")
                .padding(.top)
            
            GeometryReader { geometry in
                ZStack {
                    // Base image
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    
                    // Dimming overlay and "cutout" effect
                    Color.black.opacity(0.6)
                        .overlay(
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: selection?.width ?? 0, height: selection?.height ?? 0)
                                .position(x: selection?.midX ?? .zero, y: selection?.midY ?? .zero)
                                .blendMode(.destinationOut)
                        )
                        .compositingGroup()
                    
                    // Dashed border
                    if let selection = selection {
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundColor(.white)
                            .frame(width: selection.width, height: selection.height)
                            .position(x: selection.midX, y: selection.midY)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragStart == nil {
                                dragStart = value.startLocation
                            }
                            currentDrag = value.location
                            updateSelection()
                        }
                        .onEnded { _ in
                            dragStart = nil
                            currentDrag = nil
                        }
                )
                // Capture the size of the GeometryReader when it appears
                .onAppear {
                    self.geometrySize = geometry.size
                }
            }
            .padding()
            
            // Action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Crop Image") {
                    cropImage()
                    dismiss()
                }
                .disabled(selection == nil)
                .keyboardShortcut(.defaultAction)
            }
            .padding([.bottom, .horizontal])
        }
    }
    
    private func updateSelection() {
        guard let start = dragStart, let end = currentDrag else { return }
        selection = CGRect(x: min(start.x, end.x),
                           y: min(start.y, end.y),
                           width: abs(start.x - end.x),
                           height: abs(start.y - end.y))
    }
    
    /// Performs the final crop with simplified and corrected coordinate space calculations.
    private func cropImage() {
        guard let selection = selection,
              geometrySize != .zero,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return }

        // 1. Calculate the image rect in the view (aspect fit)
        let imageRectInView = AVMakeRect(aspectRatio: image.size, insideRect: CGRect(origin: .zero, size: geometrySize))

        // 2. Calculate scale between displayed image and actual image
        let scaleX = CGFloat(cgImage.width) / imageRectInView.width
        let scaleY = CGFloat(cgImage.height) / imageRectInView.height

        // 3. Convert selection rect from view to image coordinates
        let cropX = ((selection.origin.x - imageRectInView.origin.x) * scaleX).rounded()
        let cropWidth = (selection.width * scaleX).rounded()

        // Y: flip from top-left (view) to bottom-left (CG)
        let selectionOriginYInView = selection.origin.y - imageRectInView.origin.y
        let cropHeight = (selection.height * scaleY).rounded()
        let cropY = (selectionOriginYInView + selection.origin.y).rounded()

        // Clamp crop rect to image bounds
        let cropRect = CGRect(
            x: max(0, min(cropX, CGFloat(cgImage.width - 1))),
            y: max(0, min(cropY, CGFloat(cgImage.height - 1))),
            width: max(1, min(cropWidth, CGFloat(cgImage.width) - cropX)),
            height: max(1, min(cropHeight, CGFloat(cgImage.height) - cropY))
        )

        if let croppedCGImage = cgImage.cropping(to: cropRect) {
            croppedImage = NSImage(cgImage: croppedCGImage, size: cropRect.size)
        }
    }}

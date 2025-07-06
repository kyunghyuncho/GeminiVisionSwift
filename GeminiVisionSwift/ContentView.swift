import SwiftUI

// An enum to define our focusable fields
enum FocusableField: Hashable {
    case prompt, apiKey
}

// Add new notification names for font size
extension Notification.Name {
    static let captureScreen = Notification.Name("captureScreen")
    static let increaseFontSize = Notification.Name("increaseFontSize")
    static let decreaseFontSize = Notification.Name("decreaseFontSize")
}

struct ContentView: View {
    // UI State
    @State private var capturedImage: NSImage?
    @State private var analysisResult: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isShowingCropper = false
    
    // Add state for font size adjustment
    @State private var fontSizeAdjustment: CGFloat = 0

    // API Key and Prompt State
    @State private var apiKey: String = ""
    @State private var prompt: String = "Describe the captured screen in detail using markdown."
    
    // Focus State
    @FocusState private var focusedField: FocusableField?

    // Helpers
    private let capturer = ScreenCapturer()

    var body: some View {
        VStack(spacing: 15) {
            // MARK: - Image Display Area
            if let image = capturedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .windowBackgroundColor))
                    Text(isLoading ? "Capturing..." : "Capture the screen to begin.")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13 + fontSizeAdjustment))
                }
            }
            
            // MARK: - Prompt Editor
            if capturedImage != nil {
                VStack(alignment: .leading) {
                    Text("Prompt")
                        .font(.system(size: 12 + fontSizeAdjustment))
                        .foregroundColor(.secondary)
                    TextEditor(text: $prompt)
                        .font(.system(size: 13 + fontSizeAdjustment))
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        .focused($focusedField, equals: .prompt)
                        .onKeyPress(keys: [.return]) { press in
                            if !press.modifiers.contains(.shift) {
                                handleAnalysis()
                                return .handled
                            } else {
                                return .ignored
                            }
                        }
                }
            }

            // MARK: - Results and Loading Indicator
            if isLoading && capturedImage != nil {
                ProgressView("Analyzing with Gemini...")
            } else if !analysisResult.isEmpty {
                ScrollView {
                    Text(.init(analysisResult))
                        .font(.system(size: 13 + fontSizeAdjustment))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.system(size: 12 + fontSizeAdjustment))
            }
            
            // MARK: - Action Buttons
            HStack {
                Button(action: handleCapture) {
                    Label("Capture Screen", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                // New "Crop" button, visible only when there's an image
                if capturedImage != nil {
                    Button(action: { isShowingCropper = true }) {
                        Label("Crop", systemImage: "crop")
                            .frame(maxWidth: .infinity)
                    }
                }

                Button(action: handleAnalysis) {
                    Label("Analyze", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .disabled(capturedImage == nil || isLoading)
            }
            .controlSize(.large)

            // MARK: - API Key Management
            Divider()
            VStack(alignment: .leading, spacing: 5) {
                Label("Gemini API Key", systemImage: "key.fill")
                    .font(.system(size: 12 + fontSizeAdjustment))
                SecureField("Enter your API key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .apiKey)
                Button("Save Key", action: saveApiKey)
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 600)
        .onAppear(perform: loadApiKey)
        .onReceive(NotificationCenter.default.publisher(for: .captureScreen)) { _ in
            handleCapture()
        }
        .onReceive(NotificationCenter.default.publisher(for: .increaseFontSize)) { _ in
            fontSizeAdjustment += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .decreaseFontSize)) { _ in
            fontSizeAdjustment -= 1
        }
        // This sheet now presents the CroppingView when the "Crop" button is clicked
        .sheet(isPresented: $isShowingCropper) {
            if let imageToCrop = capturedImage {
                CroppingView(image: imageToCrop, croppedImage: $capturedImage)
                    // Add this frame modifier to make the sheet larger
                    .frame(minWidth: 1000, minHeight: 600)
            }
        }
    }

    // This function is now simpler
    func handleCapture() {
        Task {
            isLoading = true
            analysisResult = ""
            errorMessage = nil
            
            do {
                // Captures the full screen and displays it directly
                capturedImage = try await capturer.captureScreen()
                focusedField = .prompt
            } catch {
                errorMessage = "Capture failed: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    // ... all other functions (handleAnalysis, saveApiKey, etc.) remain the same ...
    func handleAnalysis() {
        guard let image = capturedImage else { return }
        Task {
            isLoading = true
            analysisResult = ""
            errorMessage = nil
            
            if let response = await analyzeImageWithGemini(image: image, customPrompt: prompt) {
                analysisResult = parseGeminiResponse(jsonString: response) ?? "Could not parse response."
            } else {
                if errorMessage == nil {
                    analysisResult = "Failed to get a response from Gemini."
                }
            }
            isLoading = false
        }
    }

    private func saveApiKey() {
        let success = KeychainHelper.shared.save(apiKey: apiKey, for: "user_gemini_key")
        print(success ? "API Key saved." : "Failed to save API Key.")
    }

    private func loadApiKey() {
        if let loadedKey = KeychainHelper.shared.load(for: "user_gemini_key") {
            self.apiKey = loadedKey
            print("API Key loaded from Keychain.")
        }
    }

    private func analyzeImageWithGemini(image: NSImage, customPrompt: String) async -> String? {
        guard !apiKey.isEmpty else {
            errorMessage = "Error: API Key is not set. Please enter and save your key."
            return nil
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)") else {
            return nil
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            errorMessage = "Could not convert image to JPEG data."
            return nil
        }
        let base64ImageString = jpegData.base64EncodedString()

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": customPrompt], ["inline_data": ["mime_type": "image/jpeg", "data": base64ImageString]]]]]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return String(data: data, encoding: .utf8)
        } catch {
            errorMessage = "Network request failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    private func parseGeminiResponse(jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                return text
            }
        } catch {
            print("JSON parsing error: \(error)")
        }
        return jsonString
    }
}

import SwiftUI
import UIKit

// MARK: - Native Apple UISearchTextField Representable

/// Wraps Apple's native `UISearchTextField` to deliver 100% native iOS search field
/// appearance and behavior: native system magnifying glass, native placeholder styling,
/// native clear button (`xmark.circle.fill`), native search keyboard, and accessibility.
public struct NativeSearchTextField: UIViewRepresentable {
    @Binding public var text: String
    public var placeholder: String
    public var isFocused: Binding<Bool>?
    public var onCommit: (() -> Void)?
    public var onClear: (() -> Void)?

    public init(
        text: Binding<String>,
        placeholder: String = "Search Odisha locations...",
        isFocused: Binding<Bool>? = nil,
        onCommit: (() -> Void)? = nil,
        onClear: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isFocused = isFocused
        self.onCommit = onCommit
        self.onClear = onClear
    }

    public func makeUIView(context: Context) -> UISearchTextField {
        let field = UISearchTextField(frame: .zero)
        field.placeholder = placeholder
        field.text = text
        field.font = UIFont.systemFont(ofSize: 15.5, weight: .regular)
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.tintColor = UIColor(Theme.Color.bhumitraPrimary)
        field.returnKeyType = .search
        field.autocorrectionType = .no
        field.autocapitalizationType = .words
        field.clearButtonMode = .whileEditing
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        return field
    }

    public func updateUIView(_ uiView: UISearchTextField, context: Context) {
        context.coordinator.parent = self
        
        if uiView.text != text {
            uiView.text = text
        }
        if uiView.placeholder != placeholder {
            uiView.placeholder = placeholder
        }

        if let focusedBinding = isFocused {
            if focusedBinding.wrappedValue && !uiView.isFirstResponder {
                DispatchQueue.main.async {
                    if !uiView.isFirstResponder {
                        uiView.becomeFirstResponder()
                    }
                }
            } else if !focusedBinding.wrappedValue && uiView.isFirstResponder {
                DispatchQueue.main.async {
                    if uiView.isFirstResponder {
                        uiView.resignFirstResponder()
                    }
                }
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, UISearchTextFieldDelegate {
        var parent: NativeSearchTextField

        init(_ parent: NativeSearchTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ sender: UISearchTextField) {
            let currentText = sender.text ?? ""
            if parent.text != currentText {
                parent.text = currentText
            }
        }

        public func textFieldDidBeginEditing(_ textField: UITextField) {
            if parent.isFocused?.wrappedValue != true {
                parent.isFocused?.wrappedValue = true
            }
        }

        public func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isFocused?.wrappedValue != false {
                parent.isFocused?.wrappedValue = false
            }
        }

        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            parent.onCommit?()
            return true
        }

        public func textFieldShouldClear(_ textField: UITextField) -> Bool {
            parent.text = ""
            parent.onClear?()
            return true
        }
    }
}

// MARK: - Native Liquid Glass Search Bar Capsule

/// Bhumitra Native Apple-style Liquid Glass Search Control.
/// Features a native `UISearchTextField`, Apple-style translucent glass material,
/// smooth rounded capsule shape, and an integrated profile/settings button.
public struct BhumitraLiquidGlassSearchBar: View {
    @ObservedObject public var viewModel: MapViewModel
    @Binding public var text: String
    public var isFocusedBinding: Binding<Bool>?
    public var onOpenProfile: () -> Void
    public var onCommit: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var locationSearchService = LocationSearchService.shared
    
    public init(
        viewModel: MapViewModel,
        text: Binding<String>,
        isFocusedBinding: Binding<Bool>? = nil,
        onOpenProfile: @escaping () -> Void = {},
        onCommit: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self._text = text
        self.isFocusedBinding = isFocusedBinding
        self.onOpenProfile = onOpenProfile
        self.onCommit = onCommit
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            NativeSearchTextField(
                text: $text,
                placeholder: "Search village or plot, e.g. Patia 547",
                isFocused: isFocusedBinding,
                onCommit: onCommit,
                onClear: {
                    text = ""
                    locationSearchService.clearSearch()
                }
            )
            .frame(height: 38)
            
            ZStack {
                if locationSearchService.isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.Color.bhumitraPrimary)
                }
            }
            .frame(width: locationSearchService.isSearching ? 20 : 0)
            .padding(.trailing, locationSearchService.isSearching ? 2 : 0)
            
            // Profile & Settings Action Button embedded inside the search capsule
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onOpenProfile()
            }) {
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraPrimary)
                }
                .frame(width: 36, height: 36)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile and Settings")
        }
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .frame(height: 50)
        .contentShape(Capsule())
        .glassEffect(
            .regular.tint(Theme.Color.bhumitraMapSurface).interactive(),
            in: .capsule
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.10),
            radius: 8,
            x: 0,
            y: 3
        )
    }
}


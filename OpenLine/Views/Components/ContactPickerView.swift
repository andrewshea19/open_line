//
//  ContactPickerView.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI
import Contacts
import ContactsUI

/// Utility class to present contact picker directly from UIKit, bypassing SwiftUI's presentation system
class ContactPickerPresenter: NSObject, CNContactPickerDelegate {
    static let shared = ContactPickerPresenter()

    private var onContactSelected: ((CNContact) -> Void)?
    private var onDismiss: (() -> Void)?
    private var isPresenting = false

    /// Present the contact picker from the topmost view controller
    func present(onContactSelected: @escaping (CNContact) -> Void, onDismiss: @escaping () -> Void) {
        guard !isPresenting else { return }

        self.onContactSelected = onContactSelected
        self.onDismiss = onDismiss
        self.isPresenting = true

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            isPresenting = false
            onDismiss()
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let picker = CNContactPickerViewController()
        picker.delegate = self
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")

        topVC.present(picker, animated: true)
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.isPresenting = false
            self.onContactSelected?(contact)
            self.onContactSelected = nil
            self.onDismiss?()
            self.onDismiss = nil
        }
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.isPresenting = false
            self.onDismiss?()
            self.onContactSelected = nil
            self.onDismiss = nil
        }
    }
}

/// A wrapper that presents CNContactPickerViewController from UIKit
/// to avoid SwiftUI sheet dismissal issues.
struct ContactPickerWrapper: UIViewControllerRepresentable {
    let onContactSelected: (CNContact) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = ContactPickerHostController()
        controller.onContactSelected = onContactSelected
        controller.onDismiss = onDismiss
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

/// A UIViewController that presents the contact picker modally
/// This isolates the picker's dismissal from SwiftUI's presentation system
class ContactPickerHostController: UIViewController, CNContactPickerDelegate {
    var onContactSelected: ((CNContact) -> Void)?
    var onDismiss: (() -> Void)?
    private var hasPresented = false
    private var hasCompletedSelection = false
    private var selectedContact: CNContact?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasPresented else {
            // We're back from the picker - check if we need to complete
            completeIfNeeded()
            return
        }
        hasPresented = true

        let picker = CNContactPickerViewController()
        picker.delegate = self
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")

        present(picker, animated: true)
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        selectedContact = contact
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        // Picker will dismiss itself, we'll handle completion in viewDidAppear
    }

    private func completeIfNeeded() {
        guard !hasCompletedSelection else { return }
        hasCompletedSelection = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            if let contact = self.selectedContact {
                self.onContactSelected?(contact)
            }
            self.onDismiss?()
        }
    }
}

// Legacy view for backward compatibility
struct ContactPickerView: UIViewControllerRepresentable {
    let onContactSelected: (CNContact) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {
        // Ensure delegate is always set
        if uiViewController.delegate === nil || !(uiViewController.delegate is Coordinator) {
            uiViewController.delegate = context.coordinator
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPickerView

        init(_ parent: ContactPickerView) {
            self.parent = parent
            super.init()
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            // The picker will dismiss itself automatically
            // Call the callback immediately - the sheet dismissal is handled by SwiftUI
            DispatchQueue.main.async {
                self.parent.onContactSelected(contact)
            }
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            // The picker will dismiss itself
        }
    }
}


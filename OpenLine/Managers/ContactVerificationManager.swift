//
//  ContactVerificationManager.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import Foundation
import Contacts

final class ContactVerificationManager: ObservableObject {
    static let shared = ContactVerificationManager()
    
    private let store = CNContactStore()
    @Published var hasContactsAccess = false
    @Published var lastError: AppError?
    
    init() {
        checkContactsAccess()
    }
    
    func checkContactsAccess() {
        let authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        
        if authorizationStatus == .authorized {
            hasContactsAccess = true
        } else if authorizationStatus == .notDetermined {
            requestContactsAccess()
        } else {
            hasContactsAccess = false
            lastError = .authenticationError("Contacts access denied")
        }
    }
    
    private func requestContactsAccess() {
        store.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                self.hasContactsAccess = granted
                if let error = error {
                    self.lastError = .authenticationError(error.localizedDescription)
                }
            }
        }
    }
    
    // Generic contact verification method to reduce redundancy
    private func isValueInContacts<T>(
        value: String,
        keysToFetch: [CNKeyDescriptor],
        extractor: (CNContact) -> [T],
        valueExtractor: (T) -> String,
        normalizer: (String) -> String
    ) -> Bool {
        guard hasContactsAccess else { return false }
        
        let normalizedValue = normalizer(value)
        
        let predicate = CNContact.predicateForContactsInContainer(
            withIdentifier: store.defaultContainerIdentifier()
        )
        
        do {
            let contacts = try store.unifiedContacts(
                matching: predicate,
                keysToFetch: keysToFetch
            )
            
            for contact in contacts {
                let contactValues = extractor(contact)
                for contactValue in contactValues {
                    let extracted = valueExtractor(contactValue)
                    if normalizer(extracted) == normalizedValue {
                        return true
                    }
                }
            }
        } catch {
            lastError = .dataError("Failed to check contacts: \(error.localizedDescription)")
        }
        
        return false
    }
    
    func isPhoneNumberInContacts(_ phoneNumber: String) -> Bool {
        return isValueInContacts(
            value: phoneNumber,
            keysToFetch: [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor
            ],
            extractor: { $0.phoneNumbers },
            valueExtractor: { $0.value.stringValue },
            normalizer: normalizePhoneNumber
        )
    }
    
    func isEmailInContacts(_ email: String) -> Bool {
        return isValueInContacts(
            value: email,
            keysToFetch: [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor
            ],
            extractor: { $0.emailAddresses },
            valueExtractor: { $0.value as String },
            normalizer: { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        )
    }
    
    func getContactName(for phoneNumber: String) -> String? {
        guard hasContactsAccess else { return nil }
        
        let normalizedPhone = normalizePhoneNumber(phoneNumber)
        
        let predicate = CNContact.predicateForContactsInContainer(
            withIdentifier: store.defaultContainerIdentifier()
        )
        let keysToFetch = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        
        do {
            let contacts = try store.unifiedContacts(
                matching: predicate,
                keysToFetch: keysToFetch
            )
            
            for contact in contacts {
                for phoneNumberObj in contact.phoneNumbers {
                    let contactPhone = normalizePhoneNumber(phoneNumberObj.value.stringValue)
                    if contactPhone == normalizedPhone {
                        return "\(contact.givenName) \(contact.familyName)"
                            .trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        } catch {
            lastError = .dataError("Failed to get contact name: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func normalizePhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-numeric characters
        let digits = phoneNumber.components(
            separatedBy: CharacterSet.decimalDigits.inverted
        ).joined()
        
        // For US numbers, if it starts with 1, remove it (country code)
        if digits.hasPrefix("1") && digits.count == 11 {
            return String(digits.dropFirst())
        }
        
        return digits
    }
}

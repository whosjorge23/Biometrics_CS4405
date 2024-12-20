//
//  ContentView.swift
//  Biometrics_CS4405
//
//  Created by Giorgio Giannotta on 18/12/24.
//

import SwiftUI
import LocalAuthentication
import CoreLocation

// MARK: - User Model
struct User {
    let name: String
    let email: String
    let password: String
}


// MARK: - ContentView
struct ContentView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isRegistered = false
    @State private var isSignedIn = false
    @State private var errorMessage = ""
    @State private var showAlert = false
    @State private var locationManager = LocationManager()
    
    var body: some View {
        NavigationView {
            VStack {
                if !isRegistered {
                    // Signup Screen
                    TextField("Enter your name", text: $name)
                        .padding().textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Enter your email", text: $email)
                        .padding().textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Register") {
                        do {
                            try validateEmail(email)
                            saveUser(User(name: name, email: email, password: "1234"))
                            isRegistered = true
                        } catch {
                            errorMessage = "Invalid email. Please try again."
                            showAlert = true
                        }
                    }
                } else if !isSignedIn {
                    // Sign-in Screen
                    TextField("Email", text: $email)
                        .padding().textFieldStyle(RoundedBorderTextFieldStyle())
                    SecureField("Password", text: $password)
                        .padding().textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Sign In") {
                        if authenticateUser(email: email, password: password) {
                            isSignedIn = true
                        } else {
                            errorMessage = "Invalid credentials. Try again."
                            showAlert = true
                        }
                    }
                } else {
                    // Home Screen
                    Text("Welcome, \(name)!")
                        .font(.headline).padding()
                    Button("Check-In/Out") {
                        authenticateBiometric {
                            print("Proceeding with location check...")
                            locationManager.checkLocation { success, error in
                                if success {
                                    saveCheckInOut()
                                    errorMessage = "Check-in successful!"
                                } else {
                                    errorMessage = error ?? "Location mismatch."
                                }
                                showAlert = true
                            }
                        }
                    }

                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Message"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .navigationTitle("Biometric Attendance")
            .padding()
        }
    }
}



// MARK: - Utility Functions
func validateEmail(_ email: String) throws {
    let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    if !emailPredicate.evaluate(with: email) {
        throw NSError(domain: "InvalidEmail", code: 400, userInfo: nil)
    }
}

func saveUser(_ user: User) {
    UserDefaults.standard.set(user.email, forKey: "email")
    UserDefaults.standard.set(user.password, forKey: "password")
    UserDefaults.standard.set(user.name, forKey: "name")
}

func authenticateUser(email: String, password: String) -> Bool {
    let savedEmail = UserDefaults.standard.string(forKey: "email")
    let savedPassword = UserDefaults.standard.string(forKey: "password")
    return email == savedEmail && password == savedPassword
}

func saveCheckInOut() {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    UserDefaults.standard.set(formatter.string(from: Date()), forKey: "lastCheckIn")
}

func authenticateBiometric(completion: @escaping () -> Void) {
    let context = LAContext()
    var error: NSError?

    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to Check-In/Out") { success, error in
            DispatchQueue.main.async {
                if success {
                    print("Biometric authentication successful")
                    completion()
                } else {
                    print("Biometric authentication failed: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    } else {
        DispatchQueue.main.async {
            print("Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
}


// MARK: - Location Manager
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let officeLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
    private var completion: ((Bool, String?) -> Void)?

    func checkLocation(completion: @escaping (Bool, String?) -> Void) {
        self.completion = completion
        locationManager.delegate = self
        checkLocationAuthorization()
    }
    
    private func checkLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            completion?(false, "Location access is restricted or denied.")
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        @unknown default:
            completion?(false, "Unknown location authorization state.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.first else {
            completion?(false, "Unable to fetch location.")
            return
        }
        let distance = currentLocation.distance(from: officeLocation)
        if distance <= 50 {
            completion?(true, nil)
        } else {
            completion?(false, "Not on office premises.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                completion?(false, "Location access was denied.")
            case .locationUnknown:
                completion?(false, "Unable to determine your location.")
            default:
                completion?(false, clError.localizedDescription)
            }
        } else {
            completion?(false, "An unknown error occurred: \(error.localizedDescription)")
        }
    }
}


#Preview {
    ContentView()
}

import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Security
import UIKit

// MARK: - Auth Service
// Supabase Auth, called over its REST API (no SDK dependency). Three
// sign-in paths, all ending in the same Supabase session and access token,
// which BackendService sends to the Untilt API:
// - Email/password: direct password grant.
// - Sign in with Apple: native sheet, then Supabase's id_token grant. No
//   web flow, so no Apple Services ID or signing key to manage.
// - Google: Supabase's hosted OAuth via ASWebAuthenticationSession + PKCE.
// See docs/adr/0004-leave-aws.md for why this replaced Cognito.
@MainActor
final class AuthService: NSObject, ObservableObject {

    static let shared = AuthService()

    @Published private(set) var isSignedIn: Bool = false
    /// Supabase user id (`sub`) of the signed-in user. ContentView uses it to
    /// erase on-device history when a different person signs in.
    @Published private(set) var userId: String?
    @Published private(set) var email: String?

    private var pendingCodeVerifier: String?
    private var pendingAppleNonce: String?
    private var webAuthSession: ASWebAuthenticationSession?
    /// Supabase rotates refresh tokens, so concurrent API calls must share
    /// one refresh rather than each spending the same refresh token.
    private var refreshTask: Task<String, Error>?

    private override init() {
        super.init()
        let session = KeychainStore.readSession()
        isSignedIn = session != nil
        if let session { updateIdentity(from: session.accessToken) }
    }

    // MARK: - Email / password

    func signIn(email: String, password: String) async throws {
        let session = try await requestSession(
            path: "token",
            query: [URLQueryItem(name: "grant_type", value: "password")],
            body: ["email": email, "password": password]
        )
        completeSignIn(session)
    }

    enum SignUpResult {
        case signedIn
        /// The project requires email confirmation; the user has to tap
        /// the link Supabase emailed before they can sign in.
        case confirmationRequired
    }

    func signUp(email: String, password: String) async throws -> SignUpResult {
        let data = try await post(path: "signup", query: [], body: ["email": email, "password": password])
        // With confirmation off, signup returns a session; with it on, just the user.
        guard let session = try? Self.decodeSession(data) else { return .confirmationRequired }
        completeSignIn(session)
        return .signedIn
    }

    // MARK: - Sign in with Apple (native)

    /// Call from SignInWithAppleButton's onRequest. Returns the SHA-256 of a
    /// fresh nonce for Apple's request; the raw nonce is kept for Supabase,
    /// which checks that the two match.
    func prepareAppleSignIn() -> String {
        let rawNonce = Self.randomURLSafeString()
        pendingAppleNonce = rawNonce
        return SHA256.hash(data: Data(rawNonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func signInWithApple(_ credential: ASAuthorizationAppleIDCredential) async throws {
        guard
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else { throw AuthError.missingCode }
        guard let nonce = pendingAppleNonce else { throw AuthError.missingVerifier }
        pendingAppleNonce = nil

        let session = try await requestSession(
            path: "token",
            query: [URLQueryItem(name: "grant_type", value: "id_token")],
            body: ["provider": "apple", "id_token": idToken, "nonce": nonce]
        )
        completeSignIn(session)
    }

    // MARK: - Google (hosted OAuth + PKCE)

    func signInWithGoogle() async throws {
        let verifier = Self.randomURLSafeString()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
        pendingCodeVerifier = verifier

        var components = URLComponents(
            url: AppConfig.supabaseURL.appendingPathComponent("auth/v1/authorize"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: AppConfig.authRedirectURI),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
        ]
        guard let authURL = components?.url else { throw AuthError.invalidAuthURL }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "untilt"
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: AuthError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? AuthError.cancelled)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session
            session.start()
        }

        try await handleCallback(callbackURL)
    }

    /// Called from UntiltApp's onOpenURL for untilt://auth-callback — handles
    /// the redirect whether it arrives via the ASWebAuthenticationSession
    /// completion handler above or, on some iOS versions/flows, via a
    /// separate onOpenURL delivery.
    func handleCallback(_ url: URL) async throws {
        guard url.scheme == "untilt", url.host == "auth-callback" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            if let errorParam = items.first(where: { $0.name == "error_description" || $0.name == "error" })?.value {
                throw AuthError.provider(errorParam)
            }
            throw AuthError.missingCode
        }
        // The other delivery path may already have used the verifier.
        guard let verifier = pendingCodeVerifier else { return }
        pendingCodeVerifier = nil

        let session = try await requestSession(
            path: "token",
            query: [URLQueryItem(name: "grant_type", value: "pkce")],
            body: ["auth_code": code, "code_verifier": verifier]
        )
        completeSignIn(session)
    }

    private func completeSignIn(_ session: StoredSession) {
        KeychainStore.save(session)
        // A new sign-in may be a different person on the same phone.
        DailyInsightCache.clear()
        updateIdentity(from: session.accessToken)
        isSignedIn = true
    }

    /// Reads `sub` and `email` from the access token's payload. Display and
    /// device-ownership only; the server does the real verification.
    private func updateIdentity(from accessToken: String) {
        let parts = accessToken.split(separator: ".")
        guard parts.count == 3 else { return }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard
            let data = Data(base64Encoded: base64),
            let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        userId = claims["sub"] as? String
        email = claims["email"] as? String
    }

    // MARK: - Token access (used by BackendService on every API call)

    /// Returns a valid access token, refreshing it first if it's expired or
    /// close to expiring. Throws AuthError.signedOut if there's no session —
    /// callers should route the user back to sign-in in that case.
    func validAccessToken() async throws -> String {
        guard let stored = KeychainStore.readSession() else {
            isSignedIn = false
            throw AuthError.signedOut
        }
        // 60s buffer so a token doesn't expire mid-request.
        if stored.expiresAt > Date().addingTimeInterval(60) {
            return stored.accessToken
        }
        if let refreshTask {
            return try await refreshTask.value
        }

        let task = Task { () throws -> String in
            do {
                let session = try await requestSession(
                    path: "token",
                    query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                    body: ["refresh_token": stored.refreshToken]
                )
                KeychainStore.save(session)
                return session.accessToken
            } catch AuthError.server(let status, _) where (400..<500).contains(status) {
                // Refresh token revoked or expired: the session is over.
                // Network errors fall through without signing out.
                signOut()
                throw AuthError.signedOut
            }
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    // MARK: - Sign out

    func signOut() {
        KeychainStore.clear()
        DailyInsightCache.clear()
        isSignedIn = false
        userId = nil
        email = nil
    }

    // MARK: - Supabase Auth REST

    private func requestSession(path: String, query: [URLQueryItem], body: [String: String]) async throws -> StoredSession {
        try Self.decodeSession(try await post(path: path, query: query, body: body))
    }

    private func post(path: String, query: [URLQueryItem], body: [String: String]) async throws -> Data {
        var components = URLComponents(
            url: AppConfig.supabaseURL.appendingPathComponent("auth/v1/\(path)"),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw AuthError.invalidAuthURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else {
            throw AuthError.server(status, Self.errorMessage(from: data))
        }
        return data
    }

    private static func decodeSession(_ data: Data) throws -> StoredSession {
        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String
            let expires_in: Int
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        return StoredSession(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        )
    }

    /// Supabase has returned errors as both `{msg}` and
    /// `{error, error_description}` across versions.
    private static func errorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (json["msg"] ?? json["error_description"] ?? json["message"]) as? String
    }

    // MARK: - Random helpers

    private static func randomURLSafeString() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }
}

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    return keyWindow
                }
            }
        }
        return ASPresentationAnchor()
    }
}

enum AuthError: Error {
    case invalidAuthURL
    case cancelled
    case missingCode
    case missingVerifier
    case signedOut
    /// Non-2xx from Supabase Auth, with its message when it sent one.
    case server(Int, String?)
    case provider(String)
}

private struct StoredSession {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Keychain token storage
private enum KeychainStore {
    private static let service = "com.untilt.auth"
    private static let account = "supabase-session"

    static func save(_ session: StoredSession) {
        let payload: [String: Any] = [
            "accessToken": session.accessToken,
            "refreshToken": session.refreshToken,
            "expiresAt": session.expiresAt.timeIntervalSince1970,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func readSession() -> StoredSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["accessToken"] as? String,
              let refreshToken = json["refreshToken"] as? String,
              let expiresAtRaw = json["expiresAt"] as? Double
        else { return nil }
        return StoredSession(accessToken: accessToken, refreshToken: refreshToken, expiresAt: Date(timeIntervalSince1970: expiresAtRaw))
    }

    /// Removes this session and any token left over from the Cognito era,
    /// which no longer validates against anything.
    static func clear() {
        for account in [account, "cognito-tokens"] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}

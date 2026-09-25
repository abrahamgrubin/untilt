import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Security
import UIKit

// MARK: - Cognito configuration
// Public client identifiers — not secrets (this is a public/native OAuth
// client, generate_secret = false in Infra/cognito.tf). Safe to hardcode.
private enum CognitoConfig {
    static let domain = "untilt-staging.auth.us-east-1.amazoncognito.com"
    static let clientId = "7f4o0dclthufht1hjgrbn8fpkd"
    static let redirectURI = "untilt://auth-callback"
    static let scopes = "openid email profile"
}

// MARK: - Auth Service
// Cognito Hosted UI via ASWebAuthenticationSession + PKCE. Covers all three
// sign-in paths uniformly (Apple, Google, local email/password) since the
// Hosted UI itself presents the provider choice — the app only needs to
// launch one URL and handle one callback shape, regardless of which
// provider the user picks. See Infra/cognito.tf for the federated IdP setup
// and docs/adr/0003-backend-migration.md for why Cognito replaced
// CloudKit-only auth.
@MainActor
final class AuthService: NSObject, ObservableObject {

    static let shared = AuthService()

    @Published private(set) var isSignedIn: Bool = false

    private var pendingCodeVerifier: String?
    private var webAuthSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        isSignedIn = KeychainStore.readAccessToken() != nil
    }

    // MARK: - Sign in

    func signIn() async throws {
        let verifier = Self.generateCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        pendingCodeVerifier = verifier

        var components = URLComponents()
        components.scheme = "https"
        components.host = CognitoConfig.domain
        components.path = "/login"
        components.queryItems = [
            URLQueryItem(name: "client_id", value: CognitoConfig.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: CognitoConfig.scopes),
            URLQueryItem(name: "redirect_uri", value: CognitoConfig.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
        ]
        guard let authURL = components.url else { throw AuthError.invalidAuthURL }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "untilt"
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
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
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            if let errorParam = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "error" })?.value {
                throw AuthError.provider(errorParam)
            }
            throw AuthError.missingCode
        }
        guard let verifier = pendingCodeVerifier else { throw AuthError.missingVerifier }
        pendingCodeVerifier = nil

        try await exchangeCode(code, verifier: verifier)
    }

    private func exchangeCode(_ code: String, verifier: String) async throws {
        let tokens = try await requestTokens(body: [
            "grant_type": "authorization_code",
            "client_id": CognitoConfig.clientId,
            "code": code,
            "redirect_uri": CognitoConfig.redirectURI,
            "code_verifier": verifier,
        ])
        KeychainStore.save(tokens: tokens)
        // A new sign-in may be a different person on the same phone.
        DailyInsightCache.clear()
        isSignedIn = true
    }

    // MARK: - Token access (used by BackendService on every API call)

    /// Returns a valid access token, refreshing it first if it's expired or
    /// close to expiring. Throws AuthError.signedOut if there's no session —
    /// callers should route the user back to sign-in in that case.
    func validAccessToken() async throws -> String {
        guard let stored = KeychainStore.readTokens() else {
            isSignedIn = false
            throw AuthError.signedOut
        }
        // 60s buffer so a token doesn't expire mid-request.
        if stored.expiresAt > Date().addingTimeInterval(60) {
            return stored.accessToken
        }
        guard let refreshToken = stored.refreshToken else {
            isSignedIn = false
            throw AuthError.signedOut
        }
        let tokens = try await requestTokens(body: [
            "grant_type": "refresh_token",
            "client_id": CognitoConfig.clientId,
            "refresh_token": refreshToken,
        ])
        // Cognito's refresh grant doesn't return a new refresh_token — keep
        // the existing one.
        KeychainStore.save(tokens: (
            accessToken: tokens.accessToken,
            idToken: tokens.idToken,
            refreshToken: refreshToken,
            expiresAt: tokens.expiresAt
        ))
        return tokens.accessToken
    }

    private func requestTokens(body: [String: String]) async throws -> (accessToken: String, idToken: String, refreshToken: String?, expiresAt: Date) {
        var request = URLRequest(url: URL(string: "https://\(CognitoConfig.domain)/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
            .map { key, value in "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            isSignedIn = false
            throw AuthError.tokenExchangeFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        struct TokenResponse: Decodable {
            let access_token: String
            let id_token: String
            let refresh_token: String?
            let expires_in: Int
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        return (
            decoded.access_token,
            decoded.id_token,
            decoded.refresh_token,
            Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        )
    }

    // MARK: - Sign out

    func signOut() {
        KeychainStore.clear()
        DailyInsightCache.clear()
        isSignedIn = false
    }

    // MARK: - PKCE helpers

    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hashed = SHA256.hash(data: Data(verifier.utf8))
        return Data(hashed).base64URLEncodedString()
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
    case tokenExchangeFailed(Int)
    case provider(String)
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
    private static let account = "cognito-tokens"

    static func save(tokens: (accessToken: String, idToken: String, refreshToken: String?, expiresAt: Date)) {
        let payload: [String: Any] = [
            "accessToken": tokens.accessToken,
            "idToken": tokens.idToken,
            "refreshToken": tokens.refreshToken as Any,
            "expiresAt": tokens.expiresAt.timeIntervalSince1970,
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

    static func readTokens() -> (accessToken: String, idToken: String, refreshToken: String?, expiresAt: Date)? {
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
              let idToken = json["idToken"] as? String,
              let expiresAtRaw = json["expiresAt"] as? Double
        else { return nil }
        return (accessToken, idToken, json["refreshToken"] as? String, Date(timeIntervalSince1970: expiresAtRaw))
    }

    static func readAccessToken() -> String? {
        readTokens()?.accessToken
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

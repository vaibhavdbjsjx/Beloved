import Foundation
@testable import PLCore
import Testing

@Suite struct AuthModelTests {
    @Test func authUserDisplayTitleAndInitials() {
        let userWithName = AuthUser(
            id: "user-1",
            provider: .apple,
            email: "john.appleseed@example.com",
            displayName: "John Appleseed"
        )
        #expect(userWithName.displayTitle == "John Appleseed")
        #expect(userWithName.initials == "JA")

        let userWithSingleName = AuthUser(
            id: "user-2",
            provider: .apple,
            email: "miriam@example.com",
            displayName: "Miriam"
        )
        #expect(userWithSingleName.displayTitle == "Miriam")
        #expect(userWithSingleName.initials == "MI")

        let userWithOnlyEmail = AuthUser(
            id: "user-3",
            provider: .apple,
            email: "user@example.com",
            displayName: nil
        )
        #expect(userWithOnlyEmail.displayTitle == "user@example.com")
        #expect(userWithOnlyEmail.initials == "US")

        let emptyUser = AuthUser(
            id: "user-4",
            provider: .apple,
            email: nil,
            displayName: "   "
        )
        #expect(emptyUser.displayTitle == "Beloved Member")
        #expect(emptyUser.initials == "B")
    }

    @Test func authProviderDisplayNames() {
        #expect(AuthProvider.apple.displayName == "Apple")
        #expect(AuthProvider.allCases == [.apple], "Sign in with Apple is the only account option")
    }

    @Test func appleCredentialPayloadFormatting() {
        var nameComponents = PersonNameComponents()
        nameComponents.givenName = "Grace"
        nameComponents.familyName = "Hopper"

        let payload = AppleCredentialPayload(
            userIdentifier: "apple-sub-123",
            identityToken: "test-jwt-token".data(using: .utf8),
            authorizationCode: "test-auth-code".data(using: .utf8),
            email: "privaterelay@privaterelay.appleid.com",
            fullName: nameComponents
        )

        #expect(payload.userIdentifier == "apple-sub-123")
        #expect(payload.formattedFullName == "Grace Hopper")
        #expect(payload.identityTokenString == "test-jwt-token")
        #expect(payload.authorizationCodeString == "test-auth-code")
    }

    @Test func authErrorDescriptions() {
        #expect(AuthError.cancelled.errorDescription == "Sign-in was cancelled.")
        #expect(AuthError.invalidCredentials.errorDescription == "Invalid account credentials. Please sign in again.")
        #expect(AuthError.expiredSession.errorDescription == "Your session has expired. Please sign in again.")
        #expect(AuthError.missingConfiguration("client ID missing").errorDescription?.contains("client ID missing") == true)
        #expect(AuthError.reauthenticationRequired.errorDescription?.contains("re-authenticate") == true)
    }
}

@Suite struct SecureStorageTests {
    @Test func inMemoryStorageCrud() throws {
        let storage = InMemorySecureStorage()
        #expect(try storage.read(key: "test") == nil)

        let data = try #require("hello-secret".data(using: .utf8))
        try storage.write(key: "test", data: data)
        #expect(try storage.read(key: "test") == data)

        try storage.delete(key: "test")
        #expect(try storage.read(key: "test") == nil)

        try storage.write(key: "k1", data: data)
        try storage.write(key: "k2", data: data)
        try storage.deleteAll()
        #expect(try storage.read(key: "k1") == nil)
        #expect(try storage.read(key: "k2") == nil)
    }

    @Test func sessionStoreRoundTrips() throws {
        let storage = InMemorySecureStorage()
        let store = AccountSessionStore(storage: storage)

        #expect(store.loadSession() == nil)

        let user = AuthUser(
            id: "apple-id-456",
            provider: .apple,
            email: "devotee@example.com",
            displayName: "Devotee"
        )
        let session = AuthSession(user: user, idToken: "token-abc")
        try store.saveSession(session)

        let loaded = store.loadSession()
        #expect(loaded?.user.id == "apple-id-456")
        #expect(loaded?.user.provider == .apple)
        #expect(loaded?.user.displayName == "Devotee")
        #expect(loaded?.idToken == "token-abc")

        try store.clearSession()
        #expect(store.loadSession() == nil)
    }
}

@Suite struct AuthenticationServiceFlowTests {
    @Test func appleSignInFirstTimeAndSubsequentWithoutName() async throws {
        let storage = InMemorySecureStorage()
        let store = AccountSessionStore(storage: storage)
        let service = StandardAuthenticationService(sessionStore: store)

        // First sign in: Apple provides name & private relay email
        var nameComponents = PersonNameComponents()
        nameComponents.givenName = "Sarah"
        nameComponents.familyName = "Connor"

        let firstPayload = AppleCredentialPayload(
            userIdentifier: "apple-unique-user-1",
            identityToken: "token-1".data(using: .utf8),
            authorizationCode: "code-1".data(using: .utf8),
            email: "sarah@privaterelay.appleid.com",
            fullName: nameComponents
        )

        let firstSession = try await service.signInWithApple(payload: firstPayload)
        #expect(firstSession.user.id == "apple-unique-user-1")
        #expect(firstSession.user.displayName == "Sarah Connor")
        #expect(firstSession.user.isPrivateEmail == true)
        #expect(firstSession.user.email == "sarah@privaterelay.appleid.com")

        // Second sign in: Apple does NOT provide name on subsequent logins
        let secondPayload = AppleCredentialPayload(
            userIdentifier: "apple-unique-user-1",
            identityToken: "token-2".data(using: .utf8),
            authorizationCode: "code-2".data(using: .utf8),
            email: "sarah@privaterelay.appleid.com",
            fullName: nil // nil on subsequent authorizations!
        )

        let secondSession = try await service.signInWithApple(payload: secondPayload)
        #expect(secondSession.user.id == "apple-unique-user-1")
        // Verified: The service preserves the previously captured name!
        #expect(secondSession.user.displayName == "Sarah Connor")
    }

    @Test func updateDisplayNameAndAvatar() async throws {
        let storage = InMemorySecureStorage()
        let store = AccountSessionStore(storage: storage)
        let service = StandardAuthenticationService(sessionStore: store)

        let payload = AppleCredentialPayload(userIdentifier: "user-edit", email: "test@example.com")
        _ = try await service.signInWithApple(payload: payload)

        let updatedUser = try await service.updateDisplayName("Pilgrim Traveler")
        #expect(updatedUser.displayName == "Pilgrim Traveler")

        let updatedAvatarUser = try await service.updateAvatarLocalFilename("avatar-user-edit.jpg")
        #expect(updatedAvatarUser.avatarLocalFilename == "avatar-user-edit.jpg")

        let current = await service.currentSession()
        #expect(current?.user.displayName == "Pilgrim Traveler")
        #expect(current?.user.avatarLocalFilename == "avatar-user-edit.jpg")
    }

    @Test func signOutClearsSession() async throws {
        let storage = InMemorySecureStorage()
        let store = AccountSessionStore(storage: storage)
        let service = StandardAuthenticationService(sessionStore: store)

        let payload = AppleCredentialPayload(userIdentifier: "user-signout", email: "signout@example.com")
        _ = try await service.signInWithApple(payload: payload)
        #expect(await service.currentSession() != nil)

        try await service.signOut()
        #expect(await service.currentSession() == nil)
        #expect(store.loadSession() == nil)
    }

    @Test func deleteAccountRevocationAndWipe() async throws {
        final class RevocationBox: @unchecked Sendable {
            var called = false
        }
        let box = RevocationBox()

        let storage = InMemorySecureStorage()
        let store = AccountSessionStore(storage: storage)
        let service = StandardAuthenticationService(sessionStore: store)

        let payload = AppleCredentialPayload(userIdentifier: "user-delete-me", email: "delete@apple.com")
        _ = try await service.signInWithApple(payload: payload)

        try await service.deleteAccount {
            box.called = true
        }

        #expect(box.called == true)
        #expect(await service.currentSession() == nil)
        #expect(store.loadSession() == nil)
    }

    @Test func sessionRestoration() async throws {
        let storage = InMemorySecureStorage()
        let store = AccountSessionStore(storage: storage)
        let service = StandardAuthenticationService(sessionStore: store)

        #expect(try await service.restorePreviousSignIn() == nil)

        var name = PersonNameComponents()
        name.givenName = "Restore"
        name.familyName = "User"
        let payload = AppleCredentialPayload(userIdentifier: "restore-user-123", email: "restore@example.com", fullName: name)
        _ = try await service.signInWithApple(payload: payload)

        let restored = try await service.restorePreviousSignIn()
        #expect(restored?.user.id == "restore-user-123")
        #expect(restored?.user.displayName == "Restore User")
    }

    @Test func updateDisplayNameWithoutSessionThrowsExpired() async throws {
        let storage = InMemorySecureStorage()
        let store = AccountSessionStore(storage: storage)
        let service = StandardAuthenticationService(sessionStore: store)

        await #expect(throws: AuthError.expiredSession) {
            try await service.updateDisplayName("Ghost")
        }
    }

    @Test func updateAvatarWithoutSessionThrowsExpired() async throws {
        let storage = InMemorySecureStorage()
        let store = AccountSessionStore(storage: storage)
        let service = StandardAuthenticationService(sessionStore: store)

        await #expect(throws: AuthError.expiredSession) {
            try await service.updateAvatarLocalFilename("ghost.jpg")
        }
    }

    @Test func appleIDTokenClaimVerification() async throws {
        let storage = InMemorySecureStorage()
        let store = AccountSessionStore(storage: storage)
        let service = StandardAuthenticationService(sessionStore: store)

        let rawNonce = "super-secret-nonce-12345"
        let hashedNonce = StandardAuthenticationService.sha256(rawNonce)

        func makeJWT(iss: String, sub: String, exp: TimeInterval, nonce: String) -> Data {
            let header = "{\"alg\":\"none\",\"typ\":\"JWT\"}".data(using: .utf8)!.base64EncodedString()
            let claims: [String: Any] = [
                "iss": iss,
                "sub": sub,
                "exp": exp,
                "nonce": nonce
            ]
            let payload = try! JSONSerialization.data(withJSONObject: claims).base64EncodedString()
            return "\(header).\(payload).signature".data(using: .utf8)!
        }

        // 1. Valid token and matching nonce -> Success
        let validJWT = makeJWT(
            iss: "https://appleid.apple.com",
            sub: "apple-user-999",
            exp: Date().timeIntervalSince1970 + 3600,
            nonce: hashedNonce
        )
        let validPayload = AppleCredentialPayload(
            userIdentifier: "apple-user-999",
            identityToken: validJWT,
            email: "verified@example.com",
            rawNonce: rawNonce
        )
        let session = try await service.signInWithApple(payload: validPayload)
        #expect(session.user.id == "apple-user-999")

        // 2. Expired token -> Throws expiredSession
        let expiredJWT = makeJWT(
            iss: "https://appleid.apple.com",
            sub: "apple-user-999",
            exp: Date().timeIntervalSince1970 - 100,
            nonce: hashedNonce
        )
        let expiredPayload = AppleCredentialPayload(
            userIdentifier: "apple-user-999",
            identityToken: expiredJWT,
            rawNonce: rawNonce
        )
        await #expect(throws: AuthError.expiredSession) {
            try await service.signInWithApple(payload: expiredPayload)
        }

        // 3. Mismatched nonce -> Throws invalidCredentials
        let wrongNoncePayload = AppleCredentialPayload(
            userIdentifier: "apple-user-999",
            identityToken: validJWT,
            rawNonce: "wrong-raw-nonce"
        )
        await #expect(throws: AuthError.invalidCredentials) {
            try await service.signInWithApple(payload: wrongNoncePayload)
        }

        // 4. Invalid issuer -> Throws invalidCredentials
        let fakeIssJWT = makeJWT(
            iss: "https://evil.com",
            sub: "apple-user-999",
            exp: Date().timeIntervalSince1970 + 3600,
            nonce: hashedNonce
        )
        let fakeIssPayload = AppleCredentialPayload(
            userIdentifier: "apple-user-999",
            identityToken: fakeIssJWT,
            rawNonce: rawNonce
        )
        await #expect(throws: AuthError.invalidCredentials) {
            try await service.signInWithApple(payload: fakeIssPayload)
        }
    }

    @Test func appleRevocationFailureDoesNotWipeAccount() async throws {
        let storage = InMemorySecureStorage()
        let store = AccountSessionStore(storage: storage)
        let service = StandardAuthenticationService(sessionStore: store)

        let payload = AppleCredentialPayload(userIdentifier: "persistent-user", email: "user@apple.com")
        _ = try await service.signInWithApple(payload: payload)

        struct RevocationError: Error, LocalizedError {
            var errorDescription: String? { "Apple server unavailable" }
        }

        await #expect(throws: AuthError.self) {
            try await service.deleteAccount {
                throw RevocationError()
            }
        }

        // Because revocation failed, the session was preserved and NOT silently wiped!
        #expect(await service.currentSession() != nil)
        #expect(store.loadSession() != nil)
    }
}

@Suite struct MockAuthenticationServiceTests {
    @Test func mockServiceSuccessAndErrorFlows() async throws {
        let mock = MockAuthenticationService()

        // 1. Initial State
        #expect(await mock.currentSession() == nil)

        // 2. Apple Sign In
        let applePayload = AppleCredentialPayload(userIdentifier: "mock-apple-sub", email: "mock@privaterelay.appleid.com")
        let session = try await mock.signInWithApple(payload: applePayload)
        #expect(session.user.id == "mock-apple-sub")
        #expect(session.user.isPrivateEmail == true)

        // 3. Update Display Name
        let updatedUser = try await mock.updateDisplayName("Beloved Mock")
        #expect(updatedUser.displayName == "Beloved Mock")
        #expect(await mock.lastUpdatedDisplayName == "Beloved Mock")

        // 4. Update Avatar
        let avatarUser = try await mock.updateAvatarLocalFilename("mock-avatar.png")
        #expect(avatarUser.avatarLocalFilename == "mock-avatar.png")
        #expect(await mock.lastUpdatedAvatarFilename == "mock-avatar.png")

        // 5. Injected Cancellation
        await mock.setShouldThrowError(.cancelled)
        await #expect(throws: AuthError.cancelled) {
            _ = try await mock.signInWithApple(payload: applePayload)
        }

        // 6. Injected Missing Configuration
        await mock.setShouldThrowError(.missingConfiguration("Apple"))
        await #expect(throws: AuthError.missingConfiguration("Apple")) {
            _ = try await mock.signInWithApple(payload: AppleCredentialPayload(userIdentifier: "x"))
        }

        // 7. Reset Error and Sign Out
        await mock.setShouldThrowError(nil)
        try await mock.signOut()
        #expect(await mock.didSignOut == true)
        #expect(await mock.currentSession() == nil)

        // 8. Delete Account
        let appleSession = try await mock.signInWithApple(payload: AppleCredentialPayload(userIdentifier: "del-user"))
        #expect(appleSession.user.id == "del-user")
        try await mock.deleteAccount()
        #expect(await mock.didDeleteAccount == true)
        #expect(await mock.currentSession() == nil)
    }
}

extension MockAuthenticationService {
    func setShouldThrowError(_ error: AuthError?) {
        self.shouldThrowError = error
    }
}


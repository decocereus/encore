import AppKit
import CommonCrypto
import Foundation
import Security
import SQLite3

/// A Chromium-family browser whose YouTube sign-in Encore can copy.
struct Browser: Hashable, Identifiable {
    var id: String { name }
    var name: String
    /// Folder under ~/Library/Application Support holding "Local State" and the profile folders.
    var supportPath: String
    var keychainService: String
    var keychainAccount: String
    var bundleID: String

    static let all: [Browser] = [
        Browser(name: "Helium", supportPath: "net.imput.helium", keychainService: "Helium Storage Key", keychainAccount: "Helium", bundleID: "net.imput.helium"),
        Browser(name: "Chrome", supportPath: "Google/Chrome", keychainService: "Chrome Safe Storage", keychainAccount: "Chrome", bundleID: "com.google.Chrome"),
        Browser(name: "Arc", supportPath: "Arc/User Data", keychainService: "Arc Safe Storage", keychainAccount: "Arc", bundleID: "company.thebrowser.Browser"),
        Browser(name: "Brave", supportPath: "BraveSoftware/Brave-Browser", keychainService: "Brave Safe Storage", keychainAccount: "Brave", bundleID: "com.brave.Browser"),
        Browser(name: "Edge", supportPath: "Microsoft Edge", keychainService: "Microsoft Edge Safe Storage", keychainAccount: "Microsoft Edge", bundleID: "com.microsoft.edgemac"),
        Browser(name: "Chromium", supportPath: "Chromium", keychainService: "Chromium Safe Storage", keychainAccount: "Chromium", bundleID: "org.chromium.Chromium"),
        Browser(name: "Vivaldi", supportPath: "Vivaldi", keychainService: "Vivaldi Safe Storage", keychainAccount: "Vivaldi", bundleID: "com.vivaldi.Vivaldi"),
    ]

    var root: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support").appending(path: supportPath)
    }

    var icon: NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }
}

/// One browser profile that is signed into YouTube.
struct BrowserProfile: Hashable, Identifiable {
    var id: String { "\(browser.name)/\(directory)" }
    var browser: Browser
    var directory: String
    var name: String

    var title: String { "\(browser.name) · \(name)" }
    var cookiesFile: URL { browser.root.appending(path: directory).appending(path: "Cookies") }
}

enum BrowserSessionError: LocalizedError {
    case keychainDenied(String)
    case unreadable(String)
    case notSignedIn(String)

    var errorDescription: String? {
        switch self {
        case .keychainDenied(let browser): "Encore needs permission to read \(browser)'s cookie key. Choose Allow when macOS asks."
        case .unreadable(let browser): "Couldn't read \(browser)'s cookies. Quit and reopen \(browser), then try again."
        case .notSignedIn(let profile): "\(profile) isn't signed into YouTube. Sign in at music.youtube.com there first."
        }
    }
}

enum BrowserSession {
    /// Browser profiles on this Mac that hold a YouTube sign-in.
    static func signedInProfiles() -> [BrowserProfile] {
        Browser.all.flatMap { browser -> [BrowserProfile] in
            let names = profileNames(browser)
            return names.compactMap { directory, name in
                let profile = BrowserProfile(browser: browser, directory: directory, name: name)
                return hasYouTubeSession(profile) ? profile : nil
            }
        }
    }

    /// Reads the profile's YouTube and Google cookies. Triggers the macOS keychain prompt the first time.
    static func cookies(from profile: BrowserProfile) throws -> [HTTPCookie] {
        let key = try encryptionKey(for: profile.browser)
        let rows = try readRows(profile)
        let cookies = rows.compactMap { row -> HTTPCookie? in
            guard let value = row.plainValue ?? decrypt(row.encrypted, key: key, stripDomainHash: row.version >= 24) else { return nil }
            var props: [HTTPCookiePropertyKey: Any] = [
                .domain: row.host, .path: row.path, .name: row.name, .value: value,
            ]
            if row.secure { props[.secure] = "TRUE" }
            if row.httpOnly { props[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
            if row.expires > 0 {
                props[.expires] = Date(timeIntervalSince1970: Double(row.expires) / 1_000_000 - 11_644_473_600)
            }
            switch row.sameSite {
            case 1: props[.sameSitePolicy] = HTTPCookieStringPolicy.sameSiteLax.rawValue
            case 2: props[.sameSitePolicy] = HTTPCookieStringPolicy.sameSiteStrict.rawValue
            default: break
            }
            return HTTPCookie(properties: props)
        }
        guard cookies.contains(where: { $0.name == "SAPISID" || $0.name == "__Secure-3PAPISID" }) else {
            throw BrowserSessionError.notSignedIn(profile.title)
        }
        return cookies
    }

    // MARK: Profiles

    private static func profileNames(_ browser: Browser) -> [(String, String)] {
        let localState = browser.root.appending(path: "Local State")
        if let data = try? Data(contentsOf: localState),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let cache = (json["profile"] as? [String: Any])?["info_cache"] as? [String: Any] {
            return cache.compactMap { directory, info in
                let name = (info as? [String: Any])?["name"] as? String ?? directory
                return (directory, name)
            }.sorted { $0.0 < $1.0 }
        }
        let defaultProfile = browser.root.appending(path: "Default/Cookies")
        return FileManager.default.fileExists(atPath: defaultProfile.path) ? [("Default", "Default")] : []
    }

    private static func hasYouTubeSession(_ profile: BrowserProfile) -> Bool {
        let sql = "SELECT count(*) FROM cookies WHERE host_key LIKE '%youtube.com' AND name IN ('SAPISID','__Secure-3PAPISID')"
        return (try? withDatabase(profile) { db in
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, sqlite3_step(statement) == SQLITE_ROW else { return false }
            return sqlite3_column_int(statement, 0) > 0
        }) ?? false
    }

    // MARK: Database

    private struct Row {
        var host, name, path: String
        var plainValue: String?
        var encrypted: Data
        var expires: Int64
        var secure, httpOnly: Bool
        var sameSite: Int32
        var version: Int
    }

    private static func readRows(_ profile: BrowserProfile) throws -> [Row] {
        try withDatabase(profile) { db in
            let version = metaVersion(db)
            let sql = """
                SELECT host_key, name, value, encrypted_value, path, expires_utc, is_secure, is_httponly, samesite FROM cookies
                WHERE host_key LIKE '%youtube.com' OR host_key IN ('.google.com', 'google.com', 'accounts.google.com', '.accounts.google.com')
                """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw BrowserSessionError.unreadable(profile.browser.name) }
            var rows: [Row] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let text = { (i: Int32) in sqlite3_column_text(statement, i).map { String(cString: $0) } ?? "" }
                let blob = Data(bytes: sqlite3_column_blob(statement, 3), count: Int(sqlite3_column_bytes(statement, 3)))
                let plain = text(2)
                rows.append(Row(host: text(0), name: text(1), path: text(4),
                                plainValue: plain.isEmpty ? nil : plain, encrypted: blob,
                                expires: sqlite3_column_int64(statement, 5),
                                secure: sqlite3_column_int(statement, 6) != 0,
                                httpOnly: sqlite3_column_int(statement, 7) != 0,
                                sameSite: sqlite3_column_int(statement, 8),
                                version: version))
            }
            return rows
        }
    }

    private static func metaVersion(_ db: OpaquePointer?) -> Int {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, "SELECT value FROM meta WHERE key = 'version'", -1, &statement, nil) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW,
              let text = sqlite3_column_text(statement, 0) else { return 0 }
        return Int(String(cString: text)) ?? 0
    }

    /// The browser keeps the database locked, so read a private copy.
    private static func withDatabase<T>(_ profile: BrowserProfile, _ body: (OpaquePointer?) throws -> T) throws -> T {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appending(path: "encore-cookies-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let source = profile.cookiesFile
        guard fm.fileExists(atPath: source.path) else { throw BrowserSessionError.unreadable(profile.browser.name) }
        for suffix in ["", "-journal", "-wal"] {
            let file = URL(fileURLWithPath: source.path + suffix)
            if fm.fileExists(atPath: file.path) {
                try fm.copyItem(at: file, to: dir.appending(path: "Cookies" + suffix))
            }
        }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dir.appending(path: "Cookies").path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw BrowserSessionError.unreadable(profile.browser.name)
        }
        defer { sqlite3_close(db) }
        return try body(db)
    }

    // MARK: Crypto

    private static func encryptionKey(for browser: Browser) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: browser.keychainService,
            kSecAttrAccount as String: browser.keychainAccount,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let password = item as? Data else {
            throw BrowserSessionError.keychainDenied(browser.name)
        }
        // Chromium on macOS: PBKDF2-SHA1, salt "saltysalt", 1003 rounds, 128-bit AES key.
        var key = Data(count: kCCKeySizeAES128)
        let salt = Data("saltysalt".utf8)
        let status = key.withUnsafeMutableBytes { keyBytes in
            password.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                         passwordBytes.baseAddress?.assumingMemoryBound(to: CChar.self), password.count,
                                         saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                                         CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1), 1003,
                                         keyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), kCCKeySizeAES128)
                }
            }
        }
        guard status == kCCSuccess else { throw BrowserSessionError.keychainDenied(browser.name) }
        return key
    }

    private static func decrypt(_ blob: Data, key: Data, stripDomainHash: Bool) -> String? {
        guard blob.count > 3, blob.prefix(3) == Data("v10".utf8) else { return nil }
        let cipher = blob.dropFirst(3)
        let iv = Data(repeating: 0x20, count: kCCBlockSizeAES128)
        var output = Data(count: cipher.count + kCCBlockSizeAES128)
        var written = 0
        let outputCapacity = output.count
        let status = output.withUnsafeMutableBytes { out in
            cipher.withUnsafeBytes { input in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                                keyBytes.baseAddress, key.count, ivBytes.baseAddress,
                                input.baseAddress, cipher.count, out.baseAddress, outputCapacity, &written)
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        var plain = output.prefix(written)
        // Since cookie DB version 24, Chromium prefixes the value with SHA-256 of the domain.
        if stripDomainHash, plain.count >= 32 { plain = plain.dropFirst(32) }
        return String(data: plain, encoding: .utf8)
    }
}

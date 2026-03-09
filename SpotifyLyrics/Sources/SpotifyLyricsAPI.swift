import Foundation
import CommonCrypto

func debugLog(_ message: String) {
    let logFile = "/tmp/spotify_lyrics_debug.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let handle = FileHandle(forWritingAtPath: logFile) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: logFile, contents: line.data(using: .utf8))
    }
}

// MARK: - TOTP Generator

class SpotifyTOTP {

    // Secret cipher dict — downloaded from upstream; auto-updated at launch
    static var secretCipherDict: [String: [Int]] = [
        "59": [123,105,79,70,110,59,52,125,60,49,80,70,89,75,80,86,63,53,123,37,117,49,52,93,77,62,47,86,48,104,68,72],
        "60": [79,109,69,123,90,65,46,74,94,34,58,48,70,71,92,85,122,63,91,64,87,87],
        "61": [44,55,47,42,70,40,34,114,76,74,50,111,120,97,75,76,94,102,43,69,49,120,118,80,64,78],
    ]

    static var totpVer: Int = 0  // 0 = auto-select highest

    /// Download latest secrets from remote URL
    static func downloadSecrets(completion: @escaping () -> Void) {
        let url = URL(string: "https://github.com/xyloflake/spot-secrets-go/blob/main/secrets/secretDict.json?raw=true")!
        URLSession.shared.dataTask(with: url) { data, _, error in
            defer { completion() }
            guard let data = data, error == nil else {
                debugLog("[TOTP] Failed to download secrets: \(error?.localizedDescription ?? "no data")")
                return
            }
            do {
                if let dict = try JSONSerialization.jsonObject(with: data) as? [String: [Int]] {
                    secretCipherDict = dict
                    let highest = dict.keys.compactMap { Int($0) }.max() ?? 0
                    debugLog("[TOTP] Downloaded secrets, versions: \(dict.keys.sorted()), using v\(highest)")
                }
            } catch {
                debugLog("[TOTP] Failed to parse secrets: \(error)")
            }
        }.resume()
    }

    /// Get the version to use
    static func getVersion() -> Int {
        if totpVer > 0 { return totpVer }
        return secretCipherDict.keys.compactMap { Int($0) }.max() ?? 0
    }

    /// Generate the TOTP secret from cipher bytes
    static func generateSecret(version: Int) -> Data? {
        guard let cipherBytes = secretCipherDict[String(version)] else { return nil }

        // XOR transform: byte ^ ((index % 33) + 9)
        let transformed = cipherBytes.enumerated().map { (i, byte) in
            byte ^ ((i % 33) + 9)
        }

        // Join as decimal strings, convert to hex, then base32 decode
        let joined = transformed.map { String($0) }.joined()
        let hexStr = joined.data(using: .utf8)!.map { String(format: "%02x", $0) }.joined()

        // Base32 encode the hex bytes
        let hexBytes = stride(from: 0, to: hexStr.count, by: 2).compactMap { i -> UInt8? in
            let start = hexStr.index(hexStr.startIndex, offsetBy: i)
            let end = hexStr.index(start, offsetBy: 2, limitedBy: hexStr.endIndex) ?? hexStr.endIndex
            return UInt8(String(hexStr[start..<end]), radix: 16)
        }

        let base32Encoded = base32Encode(Data(hexBytes))
        return base32Decode(base32Encoded)
    }

    /// Generate TOTP value at a given timestamp
    static func generateOTP(at timestamp: Int) -> String? {
        let ver = getVersion()
        guard let secret = generateSecret(version: ver) else {
            debugLog("[TOTP] Failed to generate secret for version \(ver)")
            return nil
        }

        let period: Int = 30
        let digits: Int = 6
        let counter = UInt64(timestamp / period)

        // HMAC-SHA1
        var counterBigEndian = counter.bigEndian
        let counterData = Data(bytes: &counterBigEndian, count: 8)

        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        secret.withUnsafeBytes { secretPtr in
            counterData.withUnsafeBytes { counterPtr in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1),
                        secretPtr.baseAddress!, secret.count,
                        counterPtr.baseAddress!, counterData.count,
                        &hmac)
            }
        }

        // Dynamic truncation
        let offset = Int(hmac[hmac.count - 1] & 0x0f)
        let code = (Int(hmac[offset]) & 0x7f) << 24
            | (Int(hmac[offset + 1]) & 0xff) << 16
            | (Int(hmac[offset + 2]) & 0xff) << 8
            | (Int(hmac[offset + 3]) & 0xff)

        let otp = code % Int(pow(10.0, Double(digits)))
        return String(format: "%0\(digits)d", otp)
    }

    // MARK: - Base32

    private static let base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    static func base32Encode(_ data: Data) -> String {
        var result = ""
        var buffer: UInt64 = 0
        var bitsLeft = 0

        for byte in data {
            buffer = (buffer << 8) | UInt64(byte)
            bitsLeft += 8
            while bitsLeft >= 5 {
                bitsLeft -= 5
                let index = Int((buffer >> UInt64(bitsLeft)) & 0x1f)
                let char = base32Alphabet[base32Alphabet.index(base32Alphabet.startIndex, offsetBy: index)]
                result.append(char)
            }
        }

        if bitsLeft > 0 {
            let index = Int((buffer << UInt64(5 - bitsLeft)) & 0x1f)
            let char = base32Alphabet[base32Alphabet.index(base32Alphabet.startIndex, offsetBy: index)]
            result.append(char)
        }

        return result
    }

    static func base32Decode(_ string: String) -> Data? {
        let cleaned = string.uppercased().replacingOccurrences(of: "=", with: "")
        var buffer: UInt64 = 0
        var bitsLeft = 0
        var result = Data()

        for char in cleaned {
            guard let index = base32Alphabet.firstIndex(of: char) else { return nil }
            let value = UInt64(base32Alphabet.distance(from: base32Alphabet.startIndex, to: index))
            buffer = (buffer << 5) | value
            bitsLeft += 5
            if bitsLeft >= 8 {
                bitsLeft -= 8
                result.append(UInt8((buffer >> UInt64(bitsLeft)) & 0xff))
            }
        }

        return result
    }
}

// MARK: - Spotify Lyrics API

class SpotifyLyricsAPI {

    static let shared = SpotifyLyricsAPI()

    private var spDcCookie: String = ""
    private var accessToken: String?
    private var tokenExpiry: Date?
    private var lyricsCache: [String: [LyricLine]] = [:]

    private init() {}

    // MARK: - Cookie Management

    func setCookie(_ cookie: String) {
        let trimmed = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        spDcCookie = trimmed
        accessToken = nil
        tokenExpiry = nil
        saveCookie(trimmed)
    }

    func getCookie() -> String {
        return spDcCookie
    }

    func hasCookie() -> Bool {
        return !spDcCookie.isEmpty
    }

    func loadSavedCookie() {
        if let cookie = UserDefaults.standard.string(forKey: "sp_dc_cookie"), !cookie.isEmpty {
            spDcCookie = cookie
        }
    }

    private func saveCookie(_ cookie: String) {
        UserDefaults.standard.set(cookie, forKey: "sp_dc_cookie")
    }

    // MARK: - Server Time

    private func fetchServerTime(completion: @escaping (Int?) -> Void) {
        var request = URLRequest(url: URL(string: "https://open.spotify.com/")!)
        request.httpMethod = "HEAD"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { _, response, error in
            guard let httpResponse = response as? HTTPURLResponse,
                  let dateHeader = httpResponse.value(forHTTPHeaderField: "Date") else {
                debugLog("[SpotifyLyricsAPI] Failed to get server time: \(error?.localizedDescription ?? "no Date header")")
                completion(nil)
                return
            }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

            if let date = formatter.date(from: dateHeader) {
                let timestamp = Int(date.timeIntervalSince1970)
                debugLog("[SpotifyLyricsAPI] Server time: \(timestamp) (\(dateHeader))")
                completion(timestamp)
            } else {
                debugLog("[SpotifyLyricsAPI] Failed to parse Date header: \(dateHeader)")
                completion(nil)
            }
        }.resume()
    }

    // MARK: - Access Token

    private func getAccessToken(completion: @escaping (String?) -> Void) {
        // Return cached token if still valid
        if let token = accessToken, let expiry = tokenExpiry, Date() < expiry {
            completion(token)
            return
        }

        guard !spDcCookie.isEmpty else {
            debugLog("[SpotifyLyricsAPI] No sp_dc cookie set")
            completion(nil)
            return
        }

        // First fetch server time, then generate TOTP
        fetchServerTime { [weak self] serverTime in
            guard let self = self, let serverTime = serverTime else {
                debugLog("[SpotifyLyricsAPI] Could not get server time, trying with local time")
                self?.requestToken(serverTime: Int(Date().timeIntervalSince1970), completion: completion)
                return
            }
            self.requestToken(serverTime: serverTime, completion: completion)
        }
    }

    private func requestToken(serverTime: Int, completion: @escaping (String?) -> Void) {
        guard let otp = SpotifyTOTP.generateOTP(at: serverTime) else {
            debugLog("[SpotifyLyricsAPI] Failed to generate TOTP")
            completion(nil)
            return
        }

        let ver = SpotifyTOTP.getVersion()
        debugLog("[SpotifyLyricsAPI] Using TOTP ver=\(ver), otp=\(otp), serverTime=\(serverTime)")

        var components = URLComponents(string: "https://open.spotify.com/api/token")!
        components.queryItems = [
            URLQueryItem(name: "reason", value: "transport"),
            URLQueryItem(name: "productType", value: "web-player"),
            URLQueryItem(name: "totp", value: otp),
            URLQueryItem(name: "totpServer", value: otp),
            URLQueryItem(name: "totpVer", value: String(ver)),
        ]

        guard let url = components.url else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("sp_dc=\(spDcCookie)", forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://open.spotify.com/", forHTTPHeaderField: "Referer")
        request.setValue("WebPlayer", forHTTPHeaderField: "App-Platform")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                debugLog("[SpotifyLyricsAPI] Token request error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? -1
            debugLog("[SpotifyLyricsAPI] Token response status: \(httpStatus)")

            guard let data = data else {
                debugLog("[SpotifyLyricsAPI] Token response: no data")
                completion(nil)
                return
            }

            if let rawString = String(data: data, encoding: .utf8) {
                debugLog("[SpotifyLyricsAPI] Token response body (first 300 chars): \(String(rawString.prefix(300)))")
            }

            do {
                let tokenResponse = try JSONDecoder().decode(AccessTokenResponse.self, from: data)
                let expiry = Date(timeIntervalSince1970: Double(tokenResponse.accessTokenExpirationTimestampMs) / 1000.0)

                self?.accessToken = tokenResponse.accessToken
                self?.tokenExpiry = expiry

                debugLog("[SpotifyLyricsAPI] Got access token, expires: \(expiry)")
                completion(tokenResponse.accessToken)
            } catch {
                debugLog("[SpotifyLyricsAPI] Token decode error: \(error)")
                completion(nil)
            }
        }.resume()
    }

    // MARK: - Fetch Lyrics

    func fetchLyrics(trackId: String, completion: @escaping ([LyricLine]?) -> Void) {
        // Check cache first
        if let cached = lyricsCache[trackId] {
            completion(cached)
            return
        }

        getAccessToken { [weak self] token in
            guard let token = token else {
                debugLog("[SpotifyLyricsAPI] No access token available")
                completion(nil)
                return
            }

            let urlString = "https://spclient.wg.spotify.com/color-lyrics/v2/track/\(trackId)?format=json&vocalRemoval=false&market=from_token"
            guard let url = URL(string: urlString) else {
                completion(nil)
                return
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("WebPlayer", forHTTPHeaderField: "App-Platform")
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            request.setValue("https://open.spotify.com", forHTTPHeaderField: "Origin")
            request.setValue("https://open.spotify.com", forHTTPHeaderField: "Referer")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    debugLog("[SpotifyLyricsAPI] Lyrics request error: \(error.localizedDescription)")
                    completion(nil)
                    return
                }

                let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? -1
                debugLog("[SpotifyLyricsAPI] Lyrics response status: \(httpStatus)")

                guard let data = data else {
                    debugLog("[SpotifyLyricsAPI] Lyrics response: no data")
                    completion(nil)
                    return
                }

                if let rawString = String(data: data, encoding: .utf8) {
                    debugLog("[SpotifyLyricsAPI] Lyrics response body (first 500 chars): \(String(rawString.prefix(500)))")
                }

                // Check for auth errors
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                    // Token expired, clear it and retry once
                    self?.accessToken = nil
                    self?.tokenExpiry = nil
                    self?.getAccessToken { retryToken in
                        guard let retryToken = retryToken else {
                            completion(nil)
                            return
                        }

                        var retryRequest = URLRequest(url: url)
                        retryRequest.setValue("Bearer \(retryToken)", forHTTPHeaderField: "Authorization")
                        retryRequest.setValue("web_player", forHTTPHeaderField: "app-platform")
                        retryRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
                        retryRequest.setValue("https://open.spotify.com", forHTTPHeaderField: "Origin")
                        retryRequest.setValue("https://open.spotify.com", forHTTPHeaderField: "Referer")
                        retryRequest.setValue("application/json", forHTTPHeaderField: "Accept")

                        URLSession.shared.dataTask(with: retryRequest) { data2, _, _ in
                            guard let data2 = data2 else {
                                completion(nil)
                                return
                            }
                            let lines = self?.parseLyrics(data: data2)
                            if let lines = lines {
                                self?.lyricsCache[trackId] = lines
                            }
                            completion(lines)
                        }.resume()
                    }
                    return
                }

                let lines = self?.parseLyrics(data: data)
                if let lines = lines {
                    self?.lyricsCache[trackId] = lines
                }
                completion(lines)
            }.resume()
        }
    }

    private func parseLyrics(data: Data) -> [LyricLine]? {
        do {
            let response = try JSONDecoder().decode(LyricsResponse.self, from: data)
            guard let lyricsData = response.lyrics else {
                debugLog("[SpotifyLyricsAPI] Parse: lyrics field is nil")
                return nil
            }

            debugLog("[SpotifyLyricsAPI] Parse: syncType=\(lyricsData.syncType ?? "nil"), lineCount=\(lyricsData.lines.count)")

            let lines = lyricsData.lines.compactMap { raw -> LyricLine? in
                guard let ms = Int(raw.startTimeMs) else { return nil }
                let words = raw.words.trimmingCharacters(in: .whitespacesAndNewlines)
                if words.isEmpty { return LyricLine(startTimeMs: ms, words: "♪") }
                return LyricLine(startTimeMs: ms, words: words)
            }
            debugLog("[SpotifyLyricsAPI] Parsed \(lines.count) lyric lines")
            return lines.isEmpty ? nil : lines
        } catch {
            debugLog("[SpotifyLyricsAPI] Parse error: \(error)")
            return nil
        }
    }

    // MARK: - Clear Cache

    func clearLyricsCache() {
        lyricsCache.removeAll()
    }

    func invalidateToken() {
        accessToken = nil
        tokenExpiry = nil
    }
}

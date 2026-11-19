import Foundation

public struct ParsedHTTPRequest: Equatable, Sendable {
    public var method: String
    public var path: String
    public var headers: [String: String]
    public var body: Data

    public init(method: String, path: String, headers: [String: String], body: Data) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }
}

public enum LocalHTTPProtocol {
    public static func parse(rawData: Data) -> ParsedHTTPRequest? {
        let separator = Data([0x0D, 0x0A, 0x0D, 0x0A]) // \r\n\r\n
        guard let range = rawData.range(of: separator) else { return nil }

        let headerData = rawData.subdata(in: 0..<range.lowerBound)
        let bodyData = rawData.subdata(in: range.upperBound..<rawData.count)
        guard let headerString = String(data: headerData, encoding: .utf8) else { return nil }

        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0]).uppercased()
        let path = String(parts[1])
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        return ParsedHTTPRequest(method: method, path: path, headers: headers, body: bodyData)
    }

    public static func jsonResponse(statusCode: Int = 200, statusText: String = "OK", body: Data) -> Data {
        let header =
            "HTTP/1.1 \(statusCode) \(statusText)\r\n" +
            "Content-Type: application/json; charset=utf-8\r\n" +
            "Content-Length: \(body.count)\r\n" +
            "Connection: close\r\n\r\n"
        var data = Data(header.utf8)
        data.append(body)
        return data
    }

    public static func jsonObjectResponse(statusCode: Int = 200, statusText: String = "OK", object: [String: Any]) -> Data {
        let body = (try? JSONSerialization.data(withJSONObject: object, options: [])) ?? Data("{}".utf8)
        return jsonResponse(statusCode: statusCode, statusText: statusText, body: body)
    }
}

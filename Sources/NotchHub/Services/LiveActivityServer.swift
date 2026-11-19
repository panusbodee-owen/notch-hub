import Foundation
import Network
import NotchHubCore

/// Loopback-only (127.0.0.1) HTTP server enabling AI Agents, MCP servers, FilmCraft/EffectCraft/Blender
/// scripts, and shell hooks to push Live Activities directly into NotchHub.
final class LiveActivityServer: @unchecked Sendable {
    private let store: LiveActivityStore
    private let port: UInt16
    private let queue = DispatchQueue(label: "NotchHub.LiveActivityServer")
    private var listener: NWListener?
    private let onActivityUpdated: @Sendable () -> Void

    init(store: LiveActivityStore, port: UInt16 = 47890, onActivityUpdated: @escaping @Sendable () -> Void) {
        self.store = store
        self.port = port
        self.onActivityUpdated = onActivityUpdated
    }

    func start() {
        guard listener == nil else { return }
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }

        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: nwPort)

        do {
            let newListener = try NWListener(using: params)
            newListener.newConnectionHandler = { [weak self] conn in
                self?.handle(connection: conn)
            }
            newListener.start(queue: queue)
            listener = newListener
        } catch {
            // Port may already be occupied; fail gracefully without crashing the UI
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self, let data, !data.isEmpty else {
                connection.cancel()
                return
            }
            guard let req = LocalHTTPProtocol.parse(rawData: data) else {
                let resp = LocalHTTPProtocol.jsonObjectResponse(
                    statusCode: 400,
                    statusText: "Bad Request",
                    object: ["ok": false, "error": "Malformed HTTP request"]
                )
                self.sendAndClose(connection, data: resp)
                return
            }

            Task { @MainActor in
                let response = self.route(request: req)
                self.sendAndClose(connection, data: response)
            }
        }
    }

    @MainActor
    private func route(request: ParsedHTTPRequest) -> Data {
        switch (request.method, request.path) {
        case ("GET", "/health"):
            return LocalHTTPProtocol.jsonObjectResponse(object: [
                "ok": true,
                "app": "NotchHub",
                "port": Int(port),
                "activities": store.activities.count
            ])

        case ("GET", "/v1/activities"):
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let body = (try? encoder.encode(store.activities)) ?? Data("[]".utf8)
            return LocalHTTPProtocol.jsonResponse(body: body)

        case ("POST", "/v1/activity"):
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                let activity = try decoder.decode(LiveActivity.self, from: request.body)
                store.upsert(activity)
                onActivityUpdated()
                return LocalHTTPProtocol.jsonObjectResponse(object: [
                    "ok": true,
                    "id": activity.id,
                    "state": activity.state.rawValue
                ])
            } catch {
                return LocalHTTPProtocol.jsonObjectResponse(
                    statusCode: 400,
                    statusText: "Bad Request",
                    object: ["ok": false, "error": "Invalid JSON payload: \(error.localizedDescription)"]
                )
            }

        case ("POST", "/v1/clear"):
            store.clearAll()
            onActivityUpdated()
            return LocalHTTPProtocol.jsonObjectResponse(object: ["ok": true])

        default:
            if request.method == "DELETE", request.path.hasPrefix("/v1/activity/") {
                let id = String(request.path.dropFirst("/v1/activity/".count))
                store.remove(id: id)
                onActivityUpdated()
                return LocalHTTPProtocol.jsonObjectResponse(object: ["ok": true, "deleted": id])
            }
            return LocalHTTPProtocol.jsonObjectResponse(
                statusCode: 404,
                statusText: "Not Found",
                object: ["ok": false, "error": "Route not found: \(request.method) \(request.path)"]
            )
        }
    }

    private func sendAndClose(_ connection: NWConnection, data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

import Foundation
import Network

@MainActor
final class LoopbackWebServer {
    static let shared = LoopbackWebServer()

    private var listener: NWListener?
    private(set) var port: UInt16 = 0
    private var startTask: Task<Void, Error>?

    var origin: String {
        "http://127.0.0.1:\(port)"
    }

    func start() async throws {
        if port != 0 { return }
        if let startTask {
            try await startTask.value
            return
        }

        let task = Task { @MainActor in
            try await self.startServer()
        }
        startTask = task
        defer { startTask = nil }
        try await task.value
    }

    private func startServer() async throws {
        guard listener == nil else { return }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        guard let listenPort = NWEndpoint.Port(rawValue: 0) else {
            throw LoopbackWebServerError.failedToBind
        }

        let listener = try NWListener(using: parameters, on: listenPort)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        self.port = listener.port?.rawValue ?? 0
                        DebugLog.write("Loopback server ready on port \(self.port)")
                        if !resumed {
                            resumed = true
                            continuation.resume()
                        }
                    case .failed(let error):
                        if !resumed {
                            resumed = true
                            continuation.resume(throwing: error)
                        }
                    default:
                        break
                    }
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .global(qos: .userInitiated))
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, _ in
                    guard let self else {
                        connection.cancel()
                        return
                    }
                    let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    Task { @MainActor in
                        let body = self.response(for: request)
                        self.send(response: body, on: connection)
                    }
                }
            }

            listener.start(queue: .global(qos: .userInitiated))
            self.listener = listener
        }
    }

    func playerURL(videoID: String, autoplayMuted: Bool) -> URL? {
        guard port != 0 else { return nil }
        var components = URLComponents(string: "\(origin)/player")
        components?.queryItems = [
            URLQueryItem(name: "v", value: videoID),
            URLQueryItem(name: "mute", value: autoplayMuted ? "1" : "0")
        ]
        return components?.url
    }

    private func response(for request: String) -> String {
        guard let pathLine = request.split(separator: "\r\n").first else {
            return playerHTML(videoID: nil, autoplayMuted: true)
        }

        let parts = pathLine.split(separator: " ")
        guard parts.count >= 2 else {
            return playerHTML(videoID: nil, autoplayMuted: true)
        }

        let path = String(parts[1])
        guard let components = URLComponents(string: path) else {
            return playerHTML(videoID: nil, autoplayMuted: true)
        }

        let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value
        let muted = components.queryItems?.first(where: { $0.name == "mute" })?.value != "0"
        return playerHTML(videoID: videoID, autoplayMuted: muted)
    }

    private func playerHTML(videoID: String?, autoplayMuted: Bool) -> String {
        guard let videoID, !videoID.isEmpty else {
            return "<html><body style='background:#000;color:#fff;font-family:sans-serif;padding:16px'>Missing video ID</body></html>"
        }

        let pageOrigin = origin
        let encodedOrigin = pageOrigin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? pageOrigin
        let muteJS = autoplayMuted ? "1" : "0"
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="referrer" content="strict-origin-when-cross-origin">
          <style>
            html, body { margin:0; padding:0; width:100%; height:100%; background:#000; overflow:hidden; }
            #player { width:100%; height:100%; }
          </style>
        </head>
        <body>
          <div id="player"></div>
          <script>
            var tag = document.createElement('script');
            tag.src = "https://www.youtube.com/iframe_api";
            var firstScriptTag = document.getElementsByTagName('script')[0];
            firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

            var player;
            function onYouTubeIframeAPIReady() {
              player = new YT.Player('player', {
                videoId: '\(videoID)',
                playerVars: {
                  autoplay: 1,
                  playsinline: 1,
                  controls: 1,
                  enablejsapi: 1,
                  modestbranding: 1,
                  rel: 0,
                  mute: \(muteJS),
                  origin: '\(pageOrigin)'
                },
                events: {
                  onReady: function(e) { e.target.playVideo(); }
                }
              });
            }

            window.cumulusSetSize = function(w, h) {
              if (player && player.setSize) {
                player.setSize(w, h);
              }
            };
          </script>
        </body>
        </html>
        """
    }

    private func send(response body: String, on connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Cache-Control: no-store\r
        Connection: close\r
        Access-Control-Allow-Origin: *\r
        Content-Length: \(body.utf8.count)\r
        \r
        \(body)
        """
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

enum LoopbackWebServerError: Error {
    case missingTemplate
    case failedToBind
}

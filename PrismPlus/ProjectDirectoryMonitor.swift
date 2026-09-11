import Darwin
import Dispatch
import Foundation

@MainActor
protocol ProjectDirectoryMonitoring: AnyObject {
    func start(
        watching directoryURLs: Set<URL>,
        onChange: @escaping @MainActor () -> Void
    )
    func stop()
}

@MainActor
final class ProjectDirectoryMonitor: ProjectDirectoryMonitoring {
    private var sources: [URL: DispatchSourceFileSystemObject] = [:]
    private var onChange: (@MainActor () -> Void)?

    func start(
        watching directoryURLs: Set<URL>,
        onChange: @escaping @MainActor () -> Void
    ) {
        self.onChange = onChange

        for directoryURL in sources.keys where !directoryURLs.contains(directoryURL) {
            sources.removeValue(forKey: directoryURL)?.cancel()
        }

        for directoryURL in directoryURLs where sources[directoryURL] == nil {
            let descriptor = open(directoryURL.path, O_EVTONLY)
            guard descriptor >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .delete, .rename, .extend, .attrib, .link, .revoke],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                self?.onChange?()
            }
            source.setCancelHandler {
                close(descriptor)
            }
            sources[directoryURL] = source
            source.resume()
        }
    }

    func stop() {
        for source in sources.values {
            source.cancel()
        }
        sources.removeAll()
        onChange = nil
    }

    deinit {
        for source in sources.values {
            source.cancel()
        }
    }
}

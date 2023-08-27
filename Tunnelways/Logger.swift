import Foundation

class Logger {
    static func debug(_ args: Any...) {
        #if DEBUG
            Logger.info(args)
        #endif
    }

    static func info(_ args: Any...) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        let messageWithTimestamp = "[\(timestamp)] " + args.map { String(describing: $0) }.joined(separator: " ")
        print(messageWithTimestamp)
    }
}

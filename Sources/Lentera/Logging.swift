import os

nonisolated enum Log {
  static let app = Logger(subsystem: "app.lentera.converter", category: "app")
  static let conversion = Logger(subsystem: "app.lentera.converter", category: "conversion")
}

import OSLog

extension Logger {
    /// 便利的全域 logger，避免 capture self 問題
    static func foreman(_ category: String) -> Logger {
        Logger(subsystem: "foreman", category: category)
    }

    //  /// 安全的 logging，先 capture 值再 log，避免 self capture 問題
    //  func safeInfo<T>(_ capturedValue: T, _ messageBuilder: (T) -> String) {
    //    self.info("\(messageBuilder(capturedValue))")
    //  }
    //
    //  func safeError<T>(_ capturedValue: T, _ messageBuilder: (T) -> String) {
    //    self.error("\(messageBuilder(capturedValue))")
    //  }
    //
    //  func safeWarning<T>(_ capturedValue: T, _ messageBuilder: (T) -> String) {
    //    self.warning("\(messageBuilder(capturedValue))")
    //  }
    //
    //  func safeDebug<T>(_ capturedValue: T, _ messageBuilder: (T) -> String) {
    //    self.debug("\(messageBuilder(capturedValue))")
    //  }
}

// 全局 logging 函數，避免 capture self
func logInfo(_ message: String, category: String = "App") {
    Logger.foreman(category).info("\(message)")
}

func logError(_ message: String, category: String = "App") {
    Logger.foreman(category).error("\(message)")
}

func logWarning(_ message: String, category: String = "App") {
    Logger.foreman(category).warning("\(message)")
}

func logDebug(_ message: String, category: String = "App") {
    Logger.foreman(category).debug("\(message)")
}

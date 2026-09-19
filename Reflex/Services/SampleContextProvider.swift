protocol SampleContextProvider: Sendable {
    func currentContext() -> SampleContext
}

struct StaticSampleContextProvider: SampleContextProvider {
    func currentContext() -> SampleContext {
        .debugging
    }
}

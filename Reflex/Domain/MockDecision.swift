enum Activity: String, Sendable {
    case debugging
    case writing
}

struct ActivityDecision: Sendable {
    let selected: Activity
    let confidence: Double
}

struct MockDecision: Sendable {
    let activity: ActivityDecision
    let interventionUsefulness: Double
    let suggestion: String
}

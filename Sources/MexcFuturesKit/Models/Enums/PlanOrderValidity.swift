/// How long a trigger order stays valid before MEXC cancels it.
public enum PlanOrderValidity: Int, Codable, Sendable, CaseIterable {
    /// 24 hours.
    case oneDay = 1

    /// Seven days.
    case sevenDays = 2

    /// Ten years, so the order stays until you cancel it.
    case tenYears = 3
}

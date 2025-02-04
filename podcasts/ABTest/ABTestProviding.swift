import AutomatticTracks

protocol ABTestProviding {
    func variation(for abTest: ABTest) -> Variation
    func start() async
    func reloadExPlat(platform: String, oAuthToken: String?, userAgent: String?, anonId: String?)
}

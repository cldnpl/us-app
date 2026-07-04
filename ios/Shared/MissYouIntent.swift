import AppIntents

/// The App Intent behind the widget's "I miss you" button.
///
/// It runs in the background and **does not open the app** (`openAppWhenRun`
/// is false), sending the nudge to the partner directly. iOS 17+ widgets invoke
/// it via `Button(intent:)`; it's also surfaced to Shortcuts.
@available(iOS 16.0, *)
struct MissYouIntent: AppIntent {
    static var title: LocalizedStringResource = "Send “I miss you”"
    static var description = IntentDescription("Let your partner know you're thinking of them.")

    /// Keep the nudge silent — tapping the widget must not launch the app.
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        await MissYouSender.send()
        return .result()
    }
}

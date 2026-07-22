import SwiftUI

// MARK: - The animated iPhone on the paywall

/// A small iPhone playing through the content behind the lock.
///
/// The screens are not drawings of the app — they are the app: every card, row,
/// ring and toolbar here is the same view the real game renders, fed with sample
/// data and laid out at true iPhone dimensions, then scaled down into the bezel.
/// So the proportions, paddings and type sizes match what you actually get.
struct PaywallPhone: View {
    @State private var index = 0
    @State private var appeared = false

    private let screens = PaywallDemoScreen.allCases
    private let tick = Timer.publish(every: 3.6, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 14) {
            PhoneFrame { size in
                let scale = size.width / PhoneMetrics.logicalWidth
                ZStack {
                    ForEach(Array(screens.enumerated()), id: \.element) { position, screen in
                        if position == index {
                            PaywallDemoScreenView(screen: screen)
                                .frame(width: PhoneMetrics.logicalWidth, height: size.height / scale)
                                .scaleEffect(scale, anchor: .top)
                                .frame(width: size.width, height: size.height, alignment: .top)
                                // Cross-dissolve with a hair of zoom — a slide
                                // would show two screens side by side mid-flight.
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.96)),
                                    removal: .opacity.combined(with: .scale(scale: 1.04))))
                        }
                    }
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.9), value: index)
            }
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 10) {
                Text(screens[index].caption)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .frame(height: 20)
                    .id(screens[index])
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: index)

                HStack(spacing: 6) {
                    ForEach(screens.indices, id: \.self) { position in
                        Capsule()
                            .fill(position == index ? Theme.rose : Color.black.opacity(0.12))
                            .frame(width: position == index ? 18 : 6, height: 6)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
            }
        }
        .onReceive(tick) { _ in index = (index + 1) % screens.count }
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { appeared = true } }
        .accessibilityElement()
        .accessibilityLabel("A preview of the quizzes and games included with Premium")
    }
}

/// Device bezel. Hands its content the screen size so the real-scale app views
/// inside can work out their own scale factor.
private enum PhoneMetrics {
    /// The logical width the demo screens lay themselves out at — a real iPhone.
    static let logicalWidth: CGFloat = 393
}

private struct PhoneFrame<Content: View>: View {
    @ViewBuilder var content: (CGSize) -> Content

    /// Keeps a real iPhone's 0.461 aspect ratio, so the scaled-down screens are
    /// never stretched — 178 / 393 is exactly the scale factor applied inside.
    private let screen = CGSize(width: 178, height: 386)
    private let bezel: CGFloat = 8

    var body: some View {
        let body = CGSize(width: screen.width + bezel * 2, height: screen.height + bezel * 2)
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(Color(white: 0.09))
                .frame(width: body.width, height: body.height)
                .shadow(color: .black.opacity(0.25), radius: 26, y: 16)

            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5)
                .frame(width: body.width, height: body.height)

            ZStack(alignment: .top) {
                Color.white          // the theme gradient is translucent
                content(screen)
                    .allowsHitTesting(false)

                Capsule()
                    .fill(Color(white: 0.09))
                    .frame(width: 56, height: 16)
                    .padding(.top, 7)
            }
            .frame(width: screen.width, height: screen.height)
            .clipShape(RoundedRectangle(cornerRadius: 37, style: .continuous))
        }
        .frame(width: body.width, height: body.height)
    }
}

// MARK: - Which screens play

enum PaywallDemoScreen: String, CaseIterable, Hashable {
    case quizPacks, quizPlay, knowMeScore, draw, snap, debate

    var caption: String {
        switch self {
        case .quizPacks:   return "12 quiz packs, from cute to spicy"
        case .quizPlay:    return "Answer apart, compare after"
        case .knowMeScore: return "See how well you really know each other"
        case .draw:        return "Same prompt, two canvases"
        case .snap:        return "Race around the house and snap it"
        case .debate:      return "An AI judge scores every round"
        }
    }
}

/// Renders one real app screen at iPhone scale, complete with status and nav bar.
private struct PaywallDemoScreenView: View {
    let screen: PaywallDemoScreen
    @State private var play = false

    var body: some View {
        ZStack {
            Theme.softBackground
            VStack(spacing: 0) {
                statusBar
                navBar
                Group {
                    switch screen {
                    case .quizPacks:   quizPacks
                    case .quizPlay:    quizPlay
                    case .knowMeScore: knowMeScore
                    case .draw:        drawPad
                    case .snap:        snapHunt
                    case .debate:      debate
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .onAppear {
            play = false
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) { play = true }
        }
    }

    // MARK: Chrome

    private var statusBar: some View {
        HStack {
            Text("9:41").font(.system(size: 15, weight: .semibold))
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.75")
            }
            .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 28)
        .frame(height: 54, alignment: .bottom)
        .padding(.bottom, 4)
    }

    private var navBar: some View {
        ZStack {
            Text(screen.navTitle).font(.headline).foregroundStyle(Theme.ink)
            HStack {
                Image(systemName: "chevron.left").font(.body.weight(.semibold)).foregroundStyle(Theme.rose)
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
    }

    // MARK: 1 — the real quiz category list

    private var quizPacks: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Answer on your own, then compare your answers.")
                .font(.subheadline).foregroundStyle(.secondary)

            ForEach(Array(PaywallSampleData.categories.enumerated()), id: \.element.id) { i, category in
                CategoryCard(category: category)
                    .opacity(play ? 1 : 0)
                    .offset(y: play ? 0 : 24)
                    .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(Double(i) * 0.07), value: play)
            }
        }
        .padding(20)
    }

    // MARK: 2 — the real quiz play screen

    private var quizPlay: some View {
        let quiz = PaywallSampleData.quiz
        let accent = QuizPalette.accent("red")
        return VStack(spacing: 0) {
            VStack(spacing: 22) {
                QuizIconTile(systemName: "flame.fill", colorKey: "red", size: 60).padding(.top, 8)

                StepDots(total: 6, index: 2, accent: accent) { $0 < 2 }
                Text("Question 3 of 6").font(.caption.bold()).foregroundStyle(.secondary)

                Text(quiz.prompt)
                    .font(.title2.bold()).multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink).padding(.horizontal)

                VStack(spacing: 12) {
                    ForEach(Array(quiz.options.enumerated()), id: \.element.id) { i, option in
                        IconChoiceRow(option: option, colorKey: "red", selected: play && i == 1)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.9), value: play)
                    }
                }
            }
            .padding(20)

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                Label("Back", systemImage: "chevron.left")
                    .font(.subheadline.bold()).foregroundStyle(.secondary)
                Spacer()
                Label("Next", systemImage: "chevron.right")
                    .font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 26).padding(.vertical, 12)
                    .background(accent, in: Capsule())
                    .opacity(play ? 1 : 0.45)
                    .animation(.easeOut(duration: 0.3).delay(1.1), value: play)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(.thinMaterial)
        }
    }

    // MARK: 3 — the real Know Me results

    private var knowMeScore: some View {
        let accent = QuizPalette.accent("pink")
        return VStack(spacing: 18) {
            ScoreRing(score: play ? 87 : 0, color: accent)
                .animation(.easeOut(duration: 1.2), value: play)
                .padding(.top, 12)
            Text("You really know each other! 💖")
                .font(.headline).foregroundStyle(Theme.ink)
            Text("Matched on 7 of 8").font(.subheadline).foregroundStyle(.secondary)

            ForEach(Array(PaywallSampleData.knowMeReveals.enumerated()), id: \.offset) { i, reveal in
                knowMeRevealRow(reveal)
                    .opacity(play ? 1 : 0)
                    .offset(y: play ? 0 : 16)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.7 + Double(i) * 0.12), value: play)
            }
        }
        .padding(20)
    }

    private func knowMeRevealRow(_ reveal: PaywallSampleData.Reveal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reveal.prompt).font(.subheadline.bold()).foregroundStyle(Theme.ink)
            Text("About you").font(.caption2.bold()).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: reveal.matched ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(reveal.matched ? Theme.coral : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Real answer: \(reveal.honest)").font(.footnote).foregroundStyle(Theme.ink)
                    Text("Guess: \(reveal.guess)").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuizPalette.gradient("pink").opacity(reveal.matched ? 0.6 : 0.3),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: 4 — the real drawing pad

    private var drawPad: some View {
        let accent = QuizPalette.accent("purple")
        return VStack(spacing: 0) {
            DrawPromptHeader(prompt: "our first date", remaining: play ? 154 : 158, accent: accent)

            ZStack {
                Color.white
                DoodleStroke()
                    .trim(from: 0, to: play ? 1 : 0)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    .frame(width: 190, height: 170)
                    .animation(.easeInOut(duration: 2.0), value: play)
            }
            .frame(maxHeight: .infinity)
            .overlay(Rectangle().strokeBorder(.black.opacity(0.05)))

            DrawToolbar(palette: [.black, .red, .orange, .green, .blue, .purple],
                        color: .red, isEraser: false, accent: accent)
        }
    }

    // MARK: 5 — the real snap hunt

    private var snapHunt: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            SnapHuntCard {
                SnapClueHeader(clue: "something that smells like home",
                               subtitle: "Race around the house and snap your cleverest find.",
                               accent: QuizPalette.accent("green"))
                SnapCameraTarget(accent: QuizPalette.accent("green"))
                    .scaleEffect(play ? 1 : 0.97)
                    .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: play)
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
    }

    // MARK: 6 — the real debate verdict

    private var debate: some View {
        let accent = QuizPalette.accent("blue")
        return VStack(spacing: 18) {
            VStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 54)).foregroundStyle(accent)
                    .scaleEffect(play ? 1 : 0.7)
                    .animation(.spring(response: 0.55, dampingFraction: 0.6), value: play)
                    .padding(.top, 12)
                Text("You won the debate! 🏆").font(.title2.bold()).foregroundStyle(Theme.ink)
                Text("2–1 · you vs Alex").font(.subheadline).foregroundStyle(.secondary)
            }

            ForEach(Array(PaywallSampleData.debateRounds.enumerated()), id: \.offset) { i, round in
                debateRow(round, accent: accent)
                    .opacity(play ? 1 : 0)
                    .offset(y: play ? 0 : 14)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.25 + Double(i) * 0.2), value: play)
            }
        }
        .padding(20)
    }

    private func debateRow(_ round: PaywallSampleData.Round, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("“\(round.motion)”")
                .font(.subheadline.bold()).foregroundStyle(Theme.ink)

            DebateArgumentBlock(title: "You (\(round.mySide))", text: round.mine,
                                score: round.myScore, highlight: round.iWon, accent: accent)
            DebateArgumentBlock(title: "Alex (\(round.mySide == "for" ? "against" : "for"))",
                                text: round.theirs,
                                score: round.theirScore, highlight: !round.iWon, accent: accent)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: round.iWon ? "trophy.fill" : "flag.checkered").foregroundStyle(accent)
                Text(round.verdict).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuizPalette.gradient("blue").opacity(round.iWon ? 0.6 : 0.3),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension PaywallDemoScreen {
    var navTitle: String {
        switch self {
        case .quizPacks:   return "Quiz"
        case .quizPlay:    return "Spicy Questions"
        case .knowMeScore: return "Deep Cuts"
        case .draw:        return "Draw Together"
        case .snap:        return "Snap Hunt"
        case .debate:      return "Food Fights"
        }
    }
}

// MARK: - Sample content for the demo screens

/// Stand-in data for the demo — shaped like the real catalog so the real views
/// render exactly as they do in the app.
enum PaywallSampleData {
    static let categories: [QuizCategorySummary] = [
        .init(id: "sex_love", title: "Sex & Love", icon: "flame.fill", colorKey: "red",
              quizCount: 10, completedCount: 8, progress: 0.8),
        .init(id: "money_finances", title: "Money & Finances", icon: "banknote.fill", colorKey: "green",
              quizCount: 10, completedCount: 5, progress: 0.5),
        .init(id: "travel", title: "Travel", icon: "airplane", colorKey: "blue",
              quizCount: 10, completedCount: 3, progress: 0.3),
        .init(id: "family", title: "Family", icon: "house.fill", colorKey: "amber",
              quizCount: 10, completedCount: 7, progress: 0.7),
        .init(id: "lifestyle", title: "Lifestyle", icon: "leaf.fill", colorKey: "purple",
              quizCount: 10, completedCount: 4, progress: 0.4),
        .init(id: "moral_values", title: "Moral & Values", icon: "scalemass.fill", colorKey: "pink",
              quizCount: 10, completedCount: 9, progress: 0.9),
        .init(id: "food", title: "Food", icon: "fork.knife", colorKey: "red",
              quizCount: 10, completedCount: 2, progress: 0.2),
    ]

    static let quiz = (
        prompt: "What's your ideal way to end a long day together?",
        options: [
            QuizOption(label: "A long shower, together", icon: "drop.fill", image: nil),
            QuizOption(label: "Sofa, series, no talking", icon: "tv.fill", image: nil),
            QuizOption(label: "Straight to bed", icon: "moon.stars.fill", image: nil),
        ]
    )

    struct Reveal {
        let prompt: String
        let honest: String
        let guess: String
        let matched: Bool
    }

    static let knowMeReveals: [Reveal] = [
        .init(prompt: "What's my comfort food after a bad day?",
              honest: "Pasta al pomodoro", guess: "Pasta al pomodoro", matched: true),
        .init(prompt: "Which of my friends do I complain about most?",
              honest: "Giulia", guess: "Marco", matched: false),
        .init(prompt: "What would I never give up, whatever happens?",
              honest: "My Sunday mornings", guess: "My Sunday mornings", matched: true),
    ]

    struct Round {
        let motion: String
        let mySide: String
        let mine: String
        let theirs: String
        let myScore: Int
        let theirScore: Int
        let iWon: Bool
        let verdict: String
    }

    static let debateRounds: [Round] = [
        .init(motion: "Pineapple belongs on pizza", mySide: "for",
              mine: "Sweet and savoury is the oldest trick in the book — and tomato is a fruit too.",
              theirs: "Texture matters. Warm fruit on molten cheese is a texture crime.",
              myScore: 8, theirScore: 6, iWon: true,
              verdict: "Cleaner argument with a concrete example — your round."),
        .init(motion: "Breakfast in bed is overrated", mySide: "against",
              mine: "It's the one meal nobody is rushing you through. That's the whole point.",
              theirs: "Crumbs. In the sheets. For days. Rest my case.",
              myScore: 7, theirScore: 9, iWon: false,
              verdict: "Short, vivid, and hard to argue with — Alex takes it."),
    ]
}

// MARK: - The doodle drawn on the demo canvas

/// A heart sketched in one stroke, the way you'd actually draw it with a finger.
private struct DoodleStroke: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.92))
        p.addCurve(to: CGPoint(x: w * 0.02, y: h * 0.3),
                   control1: CGPoint(x: w * 0.12, y: h * 0.72),
                   control2: CGPoint(x: w * 0.0, y: h * 0.52))
        p.addArc(center: CGPoint(x: w * 0.26, y: h * 0.3), radius: w * 0.24,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: w * 0.74, y: h * 0.3), radius: w * 0.24,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.92),
                   control1: CGPoint(x: w * 0.98, y: h * 0.52),
                   control2: CGPoint(x: w * 0.88, y: h * 0.72))
        return p
    }
}

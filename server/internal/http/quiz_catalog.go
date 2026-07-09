package httpapi

// Static quiz catalog. Categories → quizzes → questions, all keyed by stable
// string ids that quiz_answers references. Content lives in code so it can grow
// without a DB migration. Icons are SF Symbol names (rendered on iOS); photo
// options carry a loremflickr keyword the app turns into an image. Every quiz
// here is playable (no premium lock yet).

type quizFormat string

const (
	formatThisOrThat       quizFormat = "thisOrThat"
	formatDeepConversation quizFormat = "deepConversation"
	formatWhichDoYouPrefer quizFormat = "whichDoYouPrefer"
)

type quizQuestionType string

const (
	qTypeOpen   quizQuestionType = "open"   // free-text answer
	qTypeChoice quizQuestionType = "choice" // pick one of Options
)

// catalogOption is one selectable answer. Label is stored as the answer. Icon
// is an optional SF Symbol; Image is an optional photo keyword (loremflickr).
type catalogOption struct {
	Label string `json:"label"`
	Icon  string `json:"icon,omitempty"`
	Image string `json:"image,omitempty"`
}

type catalogQuestion struct {
	ID      string           `json:"id"`
	Prompt  string           `json:"prompt"`
	Type    quizQuestionType `json:"type"`
	Options []catalogOption  `json:"options,omitempty"`
}

type catalogQuiz struct {
	ID        string            `json:"id"`
	Title     string            `json:"title"`
	Icon      string            `json:"icon"` // SF Symbol
	Format    quizFormat        `json:"format"`
	Tag       string            `json:"tag,omitempty"` // e.g. "WEDDING", "18+"
	Questions []catalogQuestion `json:"questions"`
}

type catalogCategory struct {
	ID       string        `json:"id"`
	Title    string        `json:"title"`
	Icon     string        `json:"icon"`     // SF Symbol
	ColorKey string        `json:"colorKey"` // drives the card gradient on iOS
	Quizzes  []catalogQuiz `json:"quizzes"`
}

// ---- option builders ----

func opt(label string) catalogOption            { return catalogOption{Label: label} }
func icon(label, sf string) catalogOption       { return catalogOption{Label: label, Icon: sf} }
func photo(label, keyword string) catalogOption { return catalogOption{Label: label, Image: keyword} }

// choice builds a this-or-that / which-do-you-prefer question.
func choice(id, prompt string, options ...catalogOption) catalogQuestion {
	return catalogQuestion{ID: id, Prompt: prompt, Type: qTypeChoice, Options: options}
}

// open builds a free-text (deep conversation) question.
func open(id, prompt string) catalogQuestion {
	return catalogQuestion{ID: id, Prompt: prompt, Type: qTypeOpen}
}

// quizCatalog is the single source of truth for all quiz content.
var quizCatalog = []catalogCategory{
	// ─────────────────────────────── STARTERS ───────────────────────────────
	{
		ID: "starters", Title: "Starters", Icon: "sparkles", ColorKey: "purple",
		Quizzes: []catalogQuiz{
			{
				ID: "starters_favorites", Title: "Favorite Things", Icon: "star.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("starters_favorites_q1", "What's your favorite way to spend a lazy Sunday?"),
					open("starters_favorites_q2", "What's a small thing that instantly makes your day better?"),
					open("starters_favorites_q3", "What's your comfort meal after a hard day?"),
					open("starters_favorites_q4", "What song could you listen to on repeat forever?"),
					open("starters_favorites_q5", "What's your favorite season and why?"),
				},
			},
			{
				ID: "starters_thisorthat", Title: "This or That", Icon: "arrow.left.arrow.right", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("starters_thisorthat_q1", "Which are you?", icon("Morning person", "sunrise.fill"), icon("Night owl", "moon.stars.fill")),
					choice("starters_thisorthat_q2", "Which do you prefer?", photo("Beach", "beach"), photo("Mountains", "mountain")),
					choice("starters_thisorthat_q3", "Which do you prefer?", photo("Coffee", "coffee"), photo("Tea", "tea")),
					choice("starters_thisorthat_q4", "Which do you prefer?", icon("Texting", "message.fill"), icon("Calling", "phone.fill")),
					choice("starters_thisorthat_q5", "Which do you prefer?", icon("Sweet", "birthday.cake.fill"), icon("Salty", "popcorn.fill")),
				},
			},
			{
				ID: "starters_quickfire", Title: "Quickfire Picks", Icon: "bolt.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("starters_quickfire_q1", "Which do you prefer?", photo("Movies", "cinema"), photo("Series", "television")),
					choice("starters_quickfire_q2", "Which do you prefer?", photo("Dogs", "dog"), photo("Cats", "cat")),
					choice("starters_quickfire_q3", "Which do you prefer?", photo("Summer", "summer"), photo("Winter", "snow")),
					choice("starters_quickfire_q4", "Which do you prefer?", photo("Books", "books"), photo("Podcasts", "microphone")),
					choice("starters_quickfire_q5", "Which do you prefer?", icon("Plan ahead", "calendar"), icon("Be spontaneous", "dice.fill")),
				},
			},
			{
				ID: "starters_firsts", Title: "Our Firsts", Icon: "flag.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("starters_firsts_q1", "What was your first impression of me?"),
					open("starters_firsts_q2", "When did you realize you had feelings for me?"),
					open("starters_firsts_q3", "What's your favorite memory of our first date?"),
					open("starters_firsts_q4", "What made you decide to give us a chance?"),
				},
			},
			{
				ID: "starters_wouldyourather", Title: "Would You Rather", Icon: "questionmark.circle.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("starters_wouldyourather_q1", "Would you rather?", icon("Read minds", "brain.head.profile"), icon("See the future", "sparkles")),
					choice("starters_wouldyourather_q2", "Would you rather?", photo("Live by the sea", "sea"), photo("Live in the forest", "forest")),
					choice("starters_wouldyourather_q3", "Would you rather?", icon("Never be late", "clock.fill"), icon("Never get lost", "map.fill")),
					choice("starters_wouldyourather_q4", "Would you rather?", photo("Endless summer", "sunshine"), photo("Cozy winter", "fireplace")),
				},
			},
		},
	},
	// ────────────────────────────── RELATIONSHIP ─────────────────────────────
	{
		ID: "relationship", Title: "Relationship", Icon: "heart.fill", ColorKey: "pink",
		Quizzes: []catalogQuiz{
			{
				ID: "relationship_proposal", Title: "The Perfect Proposal", Icon: "sparkle.magnifyingglass", Format: formatDeepConversation, Tag: "WEDDING",
				Questions: []catalogQuestion{
					open("relationship_proposal_q1", "Where would your dream proposal happen?"),
					open("relationship_proposal_q2", "Public and grand, or private and intimate — and why?"),
					open("relationship_proposal_q3", "Who would you want to be there (if anyone)?"),
					open("relationship_proposal_q4", "What would make it unforgettable for you?"),
				},
			},
			{
				ID: "relationship_rings", Title: "Engagement Rings", Icon: "diamond.fill", Format: formatThisOrThat, Tag: "WEDDING",
				Questions: []catalogQuestion{
					choice("relationship_rings_q1", "Which do you prefer?", photo("Gold", "gold ring"), photo("Silver", "silver ring")),
					choice("relationship_rings_q2", "Which do you prefer?", icon("Classic solitaire", "diamond.fill"), icon("Vintage style", "crown.fill")),
					choice("relationship_rings_q3", "Which do you prefer?", icon("Big statement", "sparkles"), icon("Simple & subtle", "circle")),
					choice("relationship_rings_q4", "Which do you prefer?", photo("Diamond", "diamond"), photo("Colored gemstone", "gemstone")),
				},
			},
			{
				ID: "relationship_wedding", Title: "Dream Wedding", Icon: "party.popper.fill", Format: formatWhichDoYouPrefer, Tag: "WEDDING",
				Questions: []catalogQuestion{
					choice("relationship_wedding_q1", "Which do you prefer?", photo("Beach wedding", "beach wedding"), photo("Garden wedding", "garden wedding")),
					choice("relationship_wedding_q2", "Which do you prefer?", icon("Big celebration", "person.3.fill"), icon("Intimate & small", "person.2.fill")),
					choice("relationship_wedding_q3", "Which do you prefer?", photo("Summer wedding", "summer wedding"), photo("Winter wedding", "winter wedding")),
					choice("relationship_wedding_q4", "Which do you prefer?", icon("Traditional", "building.columns.fill"), icon("Modern & unique", "sparkles")),
				},
			},
			{
				ID: "relationship_love_language", Title: "Love Languages", Icon: "bubble.left.and.heart.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("relationship_love_language_q1", "What makes you feel most loved?", icon("Words of affirmation", "text.bubble.fill"), icon("Quality time", "clock.fill")),
					choice("relationship_love_language_q2", "What means more to you?", icon("A thoughtful gift", "gift.fill"), icon("A helping hand", "hand.raised.fill")),
					choice("relationship_love_language_q3", "Which do you crave more?", icon("Physical touch", "hands.clap.fill"), icon("Undivided attention", "eyes")),
					choice("relationship_love_language_q4", "A perfect evening is…", icon("Deep conversation", "bubble.left.and.bubble.right.fill"), icon("Cuddling in silence", "moon.zzz.fill")),
				},
			},
			{
				ID: "relationship_us", Title: "About Us", Icon: "heart.text.square.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("relationship_us_q1", "What's your favorite thing about our relationship?"),
					open("relationship_us_q2", "When do you feel closest to me?"),
					open("relationship_us_q3", "What's one thing we do really well as a couple?"),
					open("relationship_us_q4", "What's a habit of mine you secretly love?"),
					open("relationship_us_q5", "What's a moment with me you replay in your head?"),
				},
			},
			{
				ID: "relationship_future", Title: "Our Future", Icon: "binoculars.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("relationship_future_q1", "Where do you see us in five years?"),
					open("relationship_future_q2", "What's a dream you want us to chase together?"),
					open("relationship_future_q3", "What tradition do you want us to start?"),
					open("relationship_future_q4", "What does 'growing old together' look like to you?"),
				},
			},
			{
				ID: "relationship_conflict", Title: "When We Argue", Icon: "cloud.bolt.rain.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("relationship_conflict_q1", "How do you prefer to make up after a fight?"),
					open("relationship_conflict_q2", "What helps you feel heard when we disagree?"),
					open("relationship_conflict_q3", "Do you need space or closeness when you're upset?"),
				},
			},
		},
	},
	// ─────────────────────────────── SEX & LOVE ──────────────────────────────
	{
		ID: "sex_love", Title: "Sex & Love", Icon: "flame.fill", ColorKey: "red",
		Quizzes: []catalogQuiz{
			{
				ID: "sex_love_spicy", Title: "Spicy Questions", Icon: "flame.fill", Format: formatWhichDoYouPrefer, Tag: "18+",
				Questions: []catalogQuestion{
					choice("sex_love_spicy_q1", "Which do you prefer?", icon("Lights on", "lightbulb.fill"), icon("Lights off", "lightbulb.slash.fill")),
					choice("sex_love_spicy_q2", "Which do you prefer?", icon("Morning", "sunrise.fill"), icon("Night", "moon.stars.fill")),
					choice("sex_love_spicy_q3", "Which do you prefer?", icon("Slow & tender", "leaf.fill"), icon("Passionate & wild", "flame.fill")),
					choice("sex_love_spicy_q4", "Which do you prefer?", icon("Take the lead", "crown.fill"), icon("Be led", "heart.fill")),
					choice("sex_love_spicy_q5", "Which sets the mood?", photo("Candlelight", "candlelight"), photo("Silk sheets", "silk")),
				},
			},
			{
				ID: "sex_love_sensual", Title: "Sensual Talks", Icon: "heart.circle.fill", Format: formatDeepConversation, Tag: "18+",
				Questions: []catalogQuestion{
					open("sex_love_sensual_q1", "What makes you feel most desired?"),
					open("sex_love_sensual_q2", "Is there something new you'd like us to try?"),
					open("sex_love_sensual_q3", "What's your favorite memory of us being close?"),
					open("sex_love_sensual_q4", "What's a compliment that always turns you on?"),
				},
			},
			{
				ID: "sex_love_preferences", Title: "Preferences", Icon: "slider.horizontal.3", Format: formatThisOrThat, Tag: "18+",
				Questions: []catalogQuestion{
					choice("sex_love_preferences_q1", "Which do you prefer?", icon("Spontaneous", "dice.fill"), icon("Planned", "calendar")),
					choice("sex_love_preferences_q2", "Which do you prefer?", icon("At home", "house.fill"), icon("Somewhere new", "map.fill")),
					choice("sex_love_preferences_q3", "Which do you prefer?", icon("Quiet", "speaker.slash.fill"), icon("Vocal", "speaker.wave.3.fill")),
					choice("sex_love_preferences_q4", "Which sets the mood?", icon("Music", "music.note"), icon("Silence", "moon.zzz.fill")),
				},
			},
			{
				ID: "sex_love_intimacy", Title: "Intimacy & Lifestyle", Icon: "person.2.circle.fill", Format: formatWhichDoYouPrefer, Tag: "18+",
				Questions: []catalogQuestion{
					choice("sex_love_intimacy_q1", "Which matters more to you?", icon("Emotional intimacy", "heart.fill"), icon("Physical intimacy", "flame.fill")),
					choice("sex_love_intimacy_q2", "Which do you prefer?", icon("A long build-up", "hourglass"), icon("Getting straight to it", "bolt.fill")),
					choice("sex_love_intimacy_q3", "After intimacy, you want…", icon("Cuddles & talk", "person.2.fill"), icon("Sleep", "bed.double.fill")),
				},
			},
			{
				ID: "sex_love_fantasies", Title: "Fantasies", Icon: "sparkles", Format: formatDeepConversation, Tag: "18+",
				Questions: []catalogQuestion{
					open("sex_love_fantasies_q1", "What's a fantasy you've never told me about?"),
					open("sex_love_fantasies_q2", "What's the most attractive thing I do without realizing?"),
					open("sex_love_fantasies_q3", "What would make date night unforgettable?"),
				},
			},
		},
	},
	// ────────────────────────────── MORAL VALUES ─────────────────────────────
	{
		ID: "moral_values", Title: "Moral Values", Icon: "hand.raised.fill", ColorKey: "amber",
		Quizzes: []catalogQuiz{
			{
				ID: "moral_values_beliefs", Title: "Core Beliefs", Icon: "location.north.circle.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("moral_values_beliefs_q1", "What value do you refuse to compromise on?"),
					open("moral_values_beliefs_q2", "What does being a 'good person' mean to you?"),
					open("moral_values_beliefs_q3", "When is it okay to break a promise?"),
					open("moral_values_beliefs_q4", "What's a belief you've changed your mind about?"),
				},
			},
			{
				ID: "moral_values_dilemmas", Title: "Would You Rather", Icon: "scalemass.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("moral_values_dilemmas_q1", "Would you rather be…", icon("Always honest", "checkmark.seal.fill"), icon("Always kind", "heart.fill")),
					choice("moral_values_dilemmas_q2", "Which matters more?", icon("Justice", "scalemass.fill"), icon("Mercy", "hands.sparkles.fill")),
					choice("moral_values_dilemmas_q3", "Would you rather…", icon("Follow the rules", "list.bullet.clipboard.fill"), icon("Follow your heart", "heart.fill")),
					choice("moral_values_dilemmas_q4", "Which do you value more?", icon("Loyalty", "shield.fill"), icon("Honesty", "checkmark.seal.fill")),
				},
			},
			{
				ID: "moral_values_life", Title: "Life & Meaning", Icon: "moon.stars.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("moral_values_life_q1", "What do you think gives life meaning?"),
					open("moral_values_life_q2", "What legacy would you want to leave behind?"),
					open("moral_values_life_q3", "What's something you'd stand up for, no matter what?"),
				},
			},
			{
				ID: "moral_values_society", Title: "The Bigger Picture", Icon: "globe.europe.africa.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("moral_values_society_q1", "Which describes you?", icon("Idealist", "star.fill"), icon("Realist", "checkmark.circle.fill")),
					choice("moral_values_society_q2", "Which do you lean toward?", icon("Head", "brain.head.profile"), icon("Heart", "heart.fill")),
					choice("moral_values_society_q3", "Which matters more to you?", icon("Freedom", "bird.fill"), icon("Security", "lock.shield.fill")),
				},
			},
		},
	},
	// ────────────────────────── MONEY & FINANCES ─────────────────────────────
	{
		ID: "money_finances", Title: "Money & Finances", Icon: "dollarsign.circle.fill", ColorKey: "green",
		Quizzes: []catalogQuiz{
			{
				ID: "money_style", Title: "Spender or Saver", Icon: "banknote.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("money_style_q1", "Which are you?", icon("Saver", "banknote.fill"), icon("Spender", "cart.fill")),
					choice("money_style_q2", "Which do you prefer?", photo("Experiences", "adventure"), photo("Things", "shopping")),
					choice("money_style_q3", "Which do you prefer?", icon("Split 50/50", "arrow.left.arrow.right"), icon("One shared pot", "person.2.fill")),
					choice("money_style_q4", "Which are you?", icon("Budget tracker", "chart.pie.fill"), icon("Go with the flow", "wind")),
				},
			},
			{
				ID: "money_priorities", Title: "Priorities", Icon: "target", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("money_priorities_q1", "Which would you rather spend on?", photo("Travel", "travel"), photo("Home", "home interior")),
					choice("money_priorities_q2", "Which is worth it?", photo("Dinner out", "restaurant"), photo("Feast at home", "home cooking")),
					choice("money_priorities_q3", "Which would you pick?", photo("Save for a house", "house"), photo("Trip of a lifetime", "vacation")),
					choice("money_priorities_q4", "Which feels better?", icon("A big splurge", "sparkles"), icon("Small treats", "gift.fill")),
				},
			},
			{
				ID: "money_future", Title: "Financial Future", Icon: "chart.line.uptrend.xyaxis", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("money_future_q1", "What does financial security look like to you?"),
					open("money_future_q2", "How do you feel about sharing finances as a couple?"),
					open("money_future_q3", "What's a big purchase you'd love for us to save toward?"),
				},
			},
			{
				ID: "money_habits", Title: "Money Habits", Icon: "creditcard.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("money_habits_q1", "What did money feel like growing up in your family?"),
					open("money_habits_q2", "What's a purchase you never regret?"),
					open("money_habits_q3", "What's your relationship with saving vs spending?"),
				},
			},
		},
	},
	// ───────────────────────── GET TO KNOW EACH OTHER ────────────────────────
	{
		ID: "get_to_know", Title: "Get to Know Each Other", Icon: "person.2.fill", ColorKey: "pink",
		Quizzes: []catalogQuiz{
			{
				ID: "get_to_know_deep", Title: "Deeper Cuts", Icon: "magnifyingglass", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("get_to_know_deep_q1", "What's something about you I might not fully understand yet?"),
					open("get_to_know_deep_q2", "What's a childhood memory that shaped who you are?"),
					open("get_to_know_deep_q3", "What are you most proud of?"),
					open("get_to_know_deep_q4", "What's something you wish more people knew about you?"),
				},
			},
			{
				ID: "get_to_know_this", Title: "You in a Nutshell", Icon: "person.crop.circle.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("get_to_know_this_q1", "Which are you?", icon("Introvert", "person.fill"), icon("Extrovert", "person.3.fill")),
					choice("get_to_know_this_q2", "Which are you?", icon("Overthinker", "brain.head.profile"), icon("Go-with-the-gut", "bolt.heart.fill")),
					choice("get_to_know_this_q3", "Which are you?", icon("Optimist", "sun.max.fill"), icon("Pessimist", "cloud.rain.fill")),
					choice("get_to_know_this_q4", "Which are you?", icon("Leader", "flag.fill"), icon("Supporter", "hands.clap.fill")),
				},
			},
			{
				ID: "get_to_know_childhood", Title: "Childhood", Icon: "teddybear.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("get_to_know_childhood_q1", "What did you want to be when you grew up?"),
					open("get_to_know_childhood_q2", "What's your happiest childhood memory?"),
					open("get_to_know_childhood_q3", "Who did you look up to as a kid?"),
				},
			},
			{
				ID: "get_to_know_personality", Title: "Personality", Icon: "theatermasks.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("get_to_know_personality_q1", "How do you recharge?", icon("Alone time", "person.fill"), icon("With people", "person.3.fill")),
					choice("get_to_know_personality_q2", "Which describes you?", icon("Planner", "calendar"), icon("Improviser", "dice.fill")),
					choice("get_to_know_personality_q3", "You decide with your…", icon("Logic", "brain.head.profile"), icon("Feelings", "heart.fill")),
				},
			},
			{
				ID: "get_to_know_dreams", Title: "Dreams & Fears", Icon: "cloud.moon.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("get_to_know_dreams_q1", "What's a dream you haven't given up on?"),
					open("get_to_know_dreams_q2", "What's a fear you rarely talk about?"),
					open("get_to_know_dreams_q3", "If you could do anything and not fail, what would it be?"),
				},
			},
		},
	},
	// ─────────────────────────────────── TRAVEL ──────────────────────────────
	{
		ID: "travel", Title: "Travel", Icon: "airplane", ColorKey: "blue",
		Quizzes: []catalogQuiz{
			{
				ID: "travel_style", Title: "Travel Style", Icon: "suitcase.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("travel_style_q1", "Which do you prefer?", icon("Planned itinerary", "list.bullet.clipboard.fill"), icon("Go with the flow", "wind")),
					choice("travel_style_q2", "Which do you prefer?", photo("City break", "city"), photo("Nature escape", "nature")),
					choice("travel_style_q3", "Which do you prefer?", photo("Luxury hotel", "luxury hotel"), photo("Backpacking", "backpacking")),
					choice("travel_style_q4", "Which do you prefer?", icon("Window seat", "window.vertical.closed"), icon("Aisle seat", "chair.fill")),
				},
			},
			{
				ID: "travel_prefer", Title: "Wanderlust", Icon: "map.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("travel_prefer_q1", "Which trip sounds better?", photo("Road trip", "road trip"), photo("Flight abroad", "airplane")),
					choice("travel_prefer_q2", "Which would you pick?", photo("Mountains & snow", "snow mountain"), photo("Beach & sun", "tropical beach")),
					choice("travel_prefer_q3", "Which do you prefer?", photo("Famous landmarks", "landmark"), photo("Hidden gems", "hidden village")),
					choice("travel_prefer_q4", "Which do you prefer?", photo("Street food", "street food"), photo("Fine dining", "fine dining")),
				},
			},
			{
				ID: "travel_bucket", Title: "Bucket List", Icon: "globe.americas.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("travel_bucket_q1", "What's the one place you dream of visiting together?"),
					open("travel_bucket_q2", "What's a trip you'll never forget?"),
					open("travel_bucket_q3", "What kind of adventure would push you out of your comfort zone?"),
				},
			},
			{
				ID: "travel_destinations", Title: "Pick a Destination", Icon: "mappin.and.ellipse", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("travel_destinations_q1", "Which would you choose?", photo("Paris", "paris"), photo("Tokyo", "tokyo")),
					choice("travel_destinations_q2", "Which would you choose?", photo("Bali", "bali"), photo("New York", "new york")),
					choice("travel_destinations_q3", "Which would you choose?", photo("Safari", "safari"), photo("Northern lights", "northern lights")),
					choice("travel_destinations_q4", "Which would you choose?", photo("Greek islands", "santorini"), photo("Swiss Alps", "swiss alps")),
				},
			},
			{
				ID: "travel_memories", Title: "On the Road", Icon: "camera.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("travel_memories_q1", "What's your favorite travel memory with me?"),
					open("travel_memories_q2", "What do you always pack that you can't travel without?"),
					open("travel_memories_q3", "Describe your perfect travel moment."),
				},
			},
		},
	},
	// ─────────────────────────────────── FAMILY ──────────────────────────────
	{
		ID: "family", Title: "Family", Icon: "house.fill", ColorKey: "amber",
		Quizzes: []catalogQuiz{
			{
				ID: "family_future", Title: "Our Future Family", Icon: "house.and.flag.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("family_future_q1", "What tradition from your family do you want to keep?"),
					open("family_future_q2", "How do you picture our home one day?"),
					open("family_future_q3", "What kind of parent do you hope to be?"),
					open("family_future_q4", "What does 'family' mean to you?"),
				},
			},
			{
				ID: "family_kids", Title: "Kids?", Icon: "figure.2.and.child.holdinghands", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("family_kids_q1", "Which sounds more like you?", icon("Want kids", "heart.fill"), icon("Happy without", "leaf.fill")),
					choice("family_kids_q2", "Which do you lean toward?", icon("A big family", "person.3.fill"), icon("A small family", "person.2.fill")),
					choice("family_kids_q3", "Which parenting style?", icon("Structured", "list.bullet.clipboard.fill"), icon("Easygoing", "wind")),
					choice("family_kids_q4", "Which would you rather?", icon("Adopt", "hands.sparkles.fill"), icon("Have biologically", "heart.fill")),
				},
			},
			{
				ID: "family_traditions", Title: "Traditions", Icon: "gift.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("family_traditions_q1", "What's your favorite family tradition?"),
					open("family_traditions_q2", "How do you like to spend the holidays?"),
					open("family_traditions_q3", "What's a new tradition you'd love us to create?"),
				},
			},
			{
				ID: "family_roles", Title: "Home & Roles", Icon: "house.circle.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("family_roles_q1", "Who's more likely to…", icon("Cook", "fork.knife"), icon("Clean", "sparkles")),
					choice("family_roles_q2", "Which are you?", icon("The planner", "calendar"), icon("The doer", "hammer.fill")),
					choice("family_roles_q3", "In a home, you'd rather…", icon("Host guests often", "person.3.fill"), icon("Keep it just us", "person.2.fill")),
				},
			},
		},
	},
	// ─────────────────────────────────── HOBBIES ─────────────────────────────
	{
		ID: "hobbies", Title: "Hobbies", Icon: "paintpalette.fill", ColorKey: "purple",
		Quizzes: []catalogQuiz{
			{
				ID: "hobbies_together", Title: "Things to Try Together", Icon: "target", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("hobbies_together_q1", "Which sounds better?", photo("Cooking class", "cooking class"), photo("Dance class", "dancing")),
					choice("hobbies_together_q2", "Which sounds better?", photo("Hiking", "hiking"), photo("Board game night", "board game")),
					choice("hobbies_together_q3", "Which sounds better?", photo("Painting", "painting"), photo("Rock climbing", "rock climbing")),
					choice("hobbies_together_q4", "Which sounds better?", photo("Concert", "concert"), photo("Museum", "museum")),
				},
			},
			{
				ID: "hobbies_prefer", Title: "Downtime", Icon: "sofa.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("hobbies_prefer_q1", "Which do you prefer?", photo("Gaming", "video game"), photo("Reading", "reading")),
					choice("hobbies_prefer_q2", "Which do you prefer?", photo("Cooking", "cooking"), photo("Ordering in", "takeout")),
					choice("hobbies_prefer_q3", "Which do you prefer?", icon("Being active", "figure.run"), icon("Relaxing", "bed.double.fill")),
					choice("hobbies_prefer_q4", "Which do you prefer?", icon("Creating something", "paintbrush.fill"), icon("Watching something", "tv.fill")),
				},
			},
			{
				ID: "hobbies_interests", Title: "My Interests", Icon: "headphones", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("hobbies_interests_q1", "What hobby could you talk about for hours?"),
					open("hobbies_interests_q2", "What's something you'd love to get better at?"),
					open("hobbies_interests_q3", "What activity makes you lose track of time?"),
				},
			},
			{
				ID: "hobbies_weekend", Title: "Weekend Vibes", Icon: "sun.max.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("hobbies_weekend_q1", "Ideal weekend?", photo("Adventure out", "adventure"), photo("Cozy in", "cozy home")),
					choice("hobbies_weekend_q2", "Saturday night?", photo("Party", "party"), photo("Movie & snacks", "movie night")),
					choice("hobbies_weekend_q3", "Sunday morning?", icon("Sleep in", "bed.double.fill"), icon("Early start", "sunrise.fill")),
				},
			},
		},
	},
	// ────────────────────────────── SCHOOL & WORK ────────────────────────────
	{
		ID: "school_work", Title: "School & Work", Icon: "briefcase.fill", ColorKey: "blue",
		Quizzes: []catalogQuiz{
			{
				ID: "school_work_ambitions", Title: "Ambitions", Icon: "flame.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("school_work_ambitions_q1", "What does success look like to you in five years?"),
					open("school_work_ambitions_q2", "Would you ever quit a stable job to chase a dream?"),
					open("school_work_ambitions_q3", "What's a skill you wish you had time to learn?"),
					open("school_work_ambitions_q4", "What kind of work makes you feel fulfilled?"),
				},
			},
			{
				ID: "school_work_style", Title: "Work Style", Icon: "desktopcomputer", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("school_work_style_q1", "Which are you?", icon("Work from home", "house.fill"), icon("Work from office", "building.2.fill")),
					choice("school_work_style_q2", "Which are you?", icon("Early bird", "sunrise.fill"), icon("Night grinder", "moon.stars.fill")),
					choice("school_work_style_q3", "Which are you?", icon("Team player", "person.3.fill"), icon("Solo worker", "person.fill")),
					choice("school_work_style_q4", "Which matters more?", icon("Passion", "heart.fill"), icon("Paycheck", "dollarsign.circle.fill")),
				},
			},
			{
				ID: "school_work_balance", Title: "Work-Life Balance", Icon: "scalemass.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("school_work_balance_q1", "Which would you choose?", icon("Higher salary, less time", "dollarsign.circle.fill"), icon("Less money, more freedom", "bird.fill")),
					choice("school_work_balance_q2", "Which do you value more?", icon("Career growth", "chart.line.uptrend.xyaxis"), icon("Peace of mind", "leaf.fill")),
					choice("school_work_balance_q3", "Which is you?", icon("Live to work", "briefcase.fill"), icon("Work to live", "beach.umbrella.fill")),
				},
			},
			{
				ID: "school_work_past", Title: "School Days", Icon: "graduationcap.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("school_work_past_q1", "What kind of student were you?"),
					open("school_work_past_q2", "What's your favorite thing you ever studied or learned?"),
					open("school_work_past_q3", "Is there a career path you sometimes wonder about?"),
				},
			},
		},
	},
	// ────────────────────────────────── LIFESTYLE ────────────────────────────
	{
		ID: "lifestyle", Title: "Lifestyle", Icon: "leaf.fill", ColorKey: "green",
		Quizzes: []catalogQuiz{
			{
				ID: "lifestyle_daily", Title: "Daily Rhythm", Icon: "sun.max.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("lifestyle_daily_q1", "Which are you?", icon("Tidy", "sparkles"), icon("Cozy chaos", "shippingbox.fill")),
					choice("lifestyle_daily_q2", "Which do you prefer?", icon("Nights in", "house.fill"), icon("Nights out", "moon.stars.fill")),
					choice("lifestyle_daily_q3", "Which do you prefer?", photo("Gym", "gym"), photo("Long walks", "walking park")),
					choice("lifestyle_daily_q4", "Which are you?", icon("Routine", "repeat"), icon("Variety", "shuffle")),
				},
			},
			{
				ID: "lifestyle_health", Title: "Health & Habits", Icon: "heart.circle.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("lifestyle_health_q1", "Which do you prefer?", photo("Home-cooked", "healthy food"), photo("Takeout", "fast food")),
					choice("lifestyle_health_q2", "Which do you prefer?", photo("Workout together", "couple workout"), icon("Do your own thing", "figure.run")),
					choice("lifestyle_health_q3", "Which do you prefer?", icon("Early to bed", "bed.double.fill"), icon("Night owl", "moon.stars.fill")),
					choice("lifestyle_health_q4", "Which do you value more?", icon("Rest", "zzz"), icon("Productivity", "checklist")),
				},
			},
			{
				ID: "lifestyle_home", Title: "Home Life", Icon: "house.circle.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("lifestyle_home_q1", "Dream home?", photo("City apartment", "apartment"), photo("House in nature", "cabin")),
					choice("lifestyle_home_q2", "Which vibe?", photo("Minimalist", "minimalist interior"), photo("Warm & full", "cozy interior")),
					choice("lifestyle_home_q3", "Which do you prefer?", icon("Pets in the home", "pawprint.fill"), icon("No pets", "house.fill")),
				},
			},
			{
				ID: "lifestyle_values", Title: "How We Live", Icon: "sun.and.horizon.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("lifestyle_values_q1", "What does a good, balanced life look like to you?"),
					open("lifestyle_values_q2", "What's a habit you'd love us to build together?"),
					open("lifestyle_values_q3", "What makes a house feel like home to you?"),
				},
			},
		},
	},
	// ──────────────────────────────────── FOOD ───────────────────────────────
	{
		ID: "food", Title: "Food", Icon: "fork.knife", ColorKey: "red",
		Quizzes: []catalogQuiz{
			{
				ID: "food_tastes", Title: "Taste Test", Icon: "takeoutbag.and.cup.and.straw.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("food_tastes_q1", "Which do you prefer?", icon("Sweet", "birthday.cake.fill"), icon("Savory", "fork.knife")),
					choice("food_tastes_q2", "Which do you prefer?", photo("Pizza", "pizza"), photo("Pasta", "pasta")),
					choice("food_tastes_q3", "Which do you prefer?", photo("Cook at home", "home cooking"), photo("Eat out", "restaurant")),
					choice("food_tastes_q4", "Which do you prefer?", icon("Spicy", "flame.fill"), icon("Mild", "leaf.fill")),
					choice("food_tastes_q5", "Which do you prefer?", photo("Coffee", "coffee"), photo("Dessert", "dessert")),
				},
			},
			{
				ID: "food_cooking", Title: "In the Kitchen", Icon: "frying.pan.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("food_cooking_q1", "Which are you?", icon("Head chef", "crown.fill"), icon("Sous chef", "hand.raised.fill")),
					choice("food_cooking_q2", "Which do you prefer?", icon("Follow the recipe", "book.fill"), icon("Improvise", "dice.fill")),
					choice("food_cooking_q3", "Which do you prefer?", photo("Baking", "baking"), photo("Grilling", "barbecue")),
					choice("food_cooking_q4", "Which are you?", icon("Adventurous eater", "flame.fill"), icon("Stick to favorites", "star.fill")),
				},
			},
			{
				ID: "food_prefer", Title: "Foodie Faceoff", Icon: "flag.2.crossed.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("food_prefer_q1", "Which cuisine?", photo("Italian", "italian food"), photo("Asian", "asian food")),
					choice("food_prefer_q2", "Which do you prefer?", photo("Breakfast", "breakfast"), photo("Dinner", "dinner")),
					choice("food_prefer_q3", "Which do you prefer?", photo("Burgers", "burger"), photo("Sushi", "sushi")),
					choice("food_prefer_q4", "Which do you prefer?", photo("Chocolate", "chocolate"), photo("Fruit", "fruit")),
				},
			},
			{
				ID: "food_date", Title: "Date Night Dining", Icon: "wineglass.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("food_date_q1", "What's your idea of the perfect dinner date?"),
					open("food_date_q2", "What meal reminds you of a special moment for us?"),
					open("food_date_q3", "If we cooked one dish together tonight, what would it be?"),
				},
			},
		},
	},
}

// findQuiz returns the quiz with the given id, and whether it exists.
func findQuiz(quizID string) (catalogQuiz, bool) {
	for _, cat := range quizCatalog {
		for _, q := range cat.Quizzes {
			if q.ID == quizID {
				return q, true
			}
		}
	}
	return catalogQuiz{}, false
}

// questionIDSet returns the set of valid question ids for a quiz.
func (q catalogQuiz) questionIDSet() map[string]bool {
	set := make(map[string]bool, len(q.Questions))
	for _, question := range q.Questions {
		set[question.ID] = true
	}
	return set
}

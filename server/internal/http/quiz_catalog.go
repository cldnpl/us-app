package httpapi

// Static quiz catalog. Categories → quizzes → questions, all keyed by stable
// string ids that quiz_answers references. Content lives in code so it can grow
// without a DB migration. Every quiz here is playable (no premium lock yet).

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

type catalogQuestion struct {
	ID      string           `json:"id"`
	Prompt  string           `json:"prompt"`
	Type    quizQuestionType `json:"type"`
	Options []string         `json:"options,omitempty"`
}

type catalogQuiz struct {
	ID        string            `json:"id"`
	Title     string            `json:"title"`
	Emoji     string            `json:"emoji"`
	Format    quizFormat        `json:"format"`
	Tag       string            `json:"tag,omitempty"` // e.g. "WEDDING", "18+"
	Questions []catalogQuestion `json:"questions"`
}

type catalogCategory struct {
	ID       string        `json:"id"`
	Title    string        `json:"title"`
	Emoji    string        `json:"emoji"`
	ColorKey string        `json:"colorKey"` // drives the card gradient on iOS
	Quizzes  []catalogQuiz `json:"quizzes"`
}

// choice builds a this-or-that / which-do-you-prefer question.
func choice(id, prompt string, options ...string) catalogQuestion {
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
		ID: "starters", Title: "Starters", Emoji: "💜", ColorKey: "purple",
		Quizzes: []catalogQuiz{
			{
				ID: "starters_favorites", Title: "Favorite Things", Emoji: "⭐️", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("starters_favorites_q1", "What's your favorite way to spend a lazy Sunday?"),
					open("starters_favorites_q2", "What's a small thing that instantly makes your day better?"),
					open("starters_favorites_q3", "What's your comfort meal after a hard day?"),
					open("starters_favorites_q4", "What song could you listen to on repeat forever?"),
				},
			},
			{
				ID: "starters_thisorthat", Title: "This or That", Emoji: "🔀", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("starters_thisorthat_q1", "Which are you?", "Morning person", "Night owl"),
					choice("starters_thisorthat_q2", "Which do you prefer?", "Beach", "Mountains"),
					choice("starters_thisorthat_q3", "Which do you prefer?", "Coffee", "Tea"),
					choice("starters_thisorthat_q4", "Which do you prefer?", "Texting", "Calling"),
					choice("starters_thisorthat_q5", "Which do you prefer?", "Sweet", "Salty"),
				},
			},
			{
				ID: "starters_quickfire", Title: "Quickfire", Emoji: "⚡️", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("starters_quickfire_q1", "Which do you prefer?", "Movies", "Series"),
					choice("starters_quickfire_q2", "Which do you prefer?", "Dogs", "Cats"),
					choice("starters_quickfire_q3", "Which do you prefer?", "Summer", "Winter"),
					choice("starters_quickfire_q4", "Which do you prefer?", "Books", "Podcasts"),
					choice("starters_quickfire_q5", "Which do you prefer?", "Plan ahead", "Be spontaneous"),
				},
			},
			{
				ID: "starters_firsts", Title: "Our Firsts", Emoji: "🌱", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("starters_firsts_q1", "What was your first impression of me?"),
					open("starters_firsts_q2", "When did you realize you had feelings for me?"),
					open("starters_firsts_q3", "What's your favorite memory of our first date?"),
				},
			},
		},
	},
	// ────────────────────────────── RELATIONSHIP ─────────────────────────────
	{
		ID: "relationship", Title: "Relationship", Emoji: "💕", ColorKey: "pink",
		Quizzes: []catalogQuiz{
			{
				ID: "relationship_proposal", Title: "The Perfect Proposal", Emoji: "💍", Format: formatDeepConversation, Tag: "WEDDING",
				Questions: []catalogQuestion{
					open("relationship_proposal_q1", "Where would your dream proposal happen?"),
					open("relationship_proposal_q2", "Public and grand, or private and intimate — and why?"),
					open("relationship_proposal_q3", "Who would you want to be there (if anyone)?"),
				},
			},
			{
				ID: "relationship_rings", Title: "Engagement Rings", Emoji: "💎", Format: formatThisOrThat, Tag: "WEDDING",
				Questions: []catalogQuestion{
					choice("relationship_rings_q1", "Which do you prefer?", "Gold", "Silver"),
					choice("relationship_rings_q2", "Which do you prefer?", "Classic solitaire", "Vintage style"),
					choice("relationship_rings_q3", "Which do you prefer?", "Big statement", "Simple & subtle"),
				},
			},
			{
				ID: "relationship_love_language", Title: "Love Languages", Emoji: "🗣️", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("relationship_love_language_q1", "What makes you feel most loved?", "Words of affirmation", "Quality time"),
					choice("relationship_love_language_q2", "What means more to you?", "A thoughtful gift", "A helping hand"),
					choice("relationship_love_language_q3", "Which do you crave more?", "Physical touch", "Undivided attention"),
					choice("relationship_love_language_q4", "A perfect evening is…", "Deep conversation", "Cuddling in silence"),
				},
			},
			{
				ID: "relationship_us", Title: "About Us", Emoji: "🫂", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("relationship_us_q1", "What's your favorite thing about our relationship?"),
					open("relationship_us_q2", "When do you feel closest to me?"),
					open("relationship_us_q3", "What's one thing we do really well as a couple?"),
					open("relationship_us_q4", "What's a habit of mine you secretly love?"),
				},
			},
			{
				ID: "relationship_future", Title: "Our Future", Emoji: "🔮", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("relationship_future_q1", "Where do you see us in five years?"),
					open("relationship_future_q2", "What's a dream you want us to chase together?"),
					open("relationship_future_q3", "What tradition do you want us to start?"),
				},
			},
			{
				ID: "relationship_conflict", Title: "When We Argue", Emoji: "🌦️", Format: formatDeepConversation,
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
		ID: "sex_love", Title: "Sex & Love", Emoji: "🔞", ColorKey: "red",
		Quizzes: []catalogQuiz{
			{
				ID: "sex_love_spicy", Title: "Spicy Questions", Emoji: "🌶️", Format: formatWhichDoYouPrefer, Tag: "18+",
				Questions: []catalogQuestion{
					choice("sex_love_spicy_q1", "Which do you prefer?", "Lights on", "Lights off"),
					choice("sex_love_spicy_q2", "Which do you prefer?", "Morning", "Night"),
					choice("sex_love_spicy_q3", "Which do you prefer?", "Slow & tender", "Passionate & wild"),
					choice("sex_love_spicy_q4", "Which do you prefer?", "Take the lead", "Be led"),
				},
			},
			{
				ID: "sex_love_sensual", Title: "Sensual Talks", Emoji: "💘", Format: formatDeepConversation, Tag: "18+",
				Questions: []catalogQuestion{
					open("sex_love_sensual_q1", "What makes you feel most desired?"),
					open("sex_love_sensual_q2", "Is there something new you'd like us to try?"),
					open("sex_love_sensual_q3", "What's your favorite memory of us being close?"),
					open("sex_love_sensual_q4", "What's a compliment that always turns you on?"),
				},
			},
			{
				ID: "sex_love_preferences", Title: "Preferences", Emoji: "😏", Format: formatThisOrThat, Tag: "18+",
				Questions: []catalogQuestion{
					choice("sex_love_preferences_q1", "Which do you prefer?", "Spontaneous", "Planned"),
					choice("sex_love_preferences_q2", "Which do you prefer?", "Bedroom", "Somewhere new"),
					choice("sex_love_preferences_q3", "Which do you prefer?", "Quiet", "Vocal"),
					choice("sex_love_preferences_q4", "Which sets the mood?", "Music", "Silence"),
				},
			},
			{
				ID: "sex_love_intimacy", Title: "Intimacy & Lifestyle", Emoji: "🧐", Format: formatWhichDoYouPrefer, Tag: "18+",
				Questions: []catalogQuestion{
					choice("sex_love_intimacy_q1", "Which matters more to you?", "Emotional intimacy", "Physical intimacy"),
					choice("sex_love_intimacy_q2", "Which do you prefer?", "A long build-up", "Getting straight to it"),
					choice("sex_love_intimacy_q3", "After intimacy, you want…", "Cuddles & talk", "Sleep"),
				},
			},
			{
				ID: "sex_love_fantasies", Title: "Fantasies", Emoji: "🔥", Format: formatDeepConversation, Tag: "18+",
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
		ID: "moral_values", Title: "Moral Values", Emoji: "🤝", ColorKey: "amber",
		Quizzes: []catalogQuiz{
			{
				ID: "moral_values_beliefs", Title: "Core Beliefs", Emoji: "🧭", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("moral_values_beliefs_q1", "What value do you refuse to compromise on?"),
					open("moral_values_beliefs_q2", "What does being a 'good person' mean to you?"),
					open("moral_values_beliefs_q3", "When is it okay to break a promise?"),
					open("moral_values_beliefs_q4", "What's a belief you've changed your mind about?"),
				},
			},
			{
				ID: "moral_values_dilemmas", Title: "Would You Rather", Emoji: "⚖️", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("moral_values_dilemmas_q1", "Would you rather be…", "Always honest", "Always kind"),
					choice("moral_values_dilemmas_q2", "Which matters more?", "Justice", "Mercy"),
					choice("moral_values_dilemmas_q3", "Would you rather…", "Follow the rules", "Follow your heart"),
					choice("moral_values_dilemmas_q4", "Which do you value more?", "Loyalty", "Honesty"),
				},
			},
			{
				ID: "moral_values_life", Title: "Life & Meaning", Emoji: "🌌", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("moral_values_life_q1", "What do you think gives life meaning?"),
					open("moral_values_life_q2", "What legacy would you want to leave behind?"),
					open("moral_values_life_q3", "What's something you'd stand up for, no matter what?"),
				},
			},
			{
				ID: "moral_values_society", Title: "The Bigger Picture", Emoji: "🌍", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("moral_values_society_q1", "Which describes you?", "Idealist", "Realist"),
					choice("moral_values_society_q2", "Which do you lean toward?", "Head", "Heart"),
					choice("moral_values_society_q3", "Which matters more to you?", "Freedom", "Security"),
				},
			},
		},
	},
	// ────────────────────────── MONEY & FINANCES ─────────────────────────────
	{
		ID: "money_finances", Title: "Money & Finances", Emoji: "💸", ColorKey: "green",
		Quizzes: []catalogQuiz{
			{
				ID: "money_style", Title: "Spender or Saver", Emoji: "🏦", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("money_style_q1", "Which are you?", "Saver", "Spender"),
					choice("money_style_q2", "Which do you prefer?", "Experiences", "Things"),
					choice("money_style_q3", "Which do you prefer?", "Split everything 50/50", "One shared pot"),
					choice("money_style_q4", "Which are you?", "Budget tracker", "Go with the flow"),
				},
			},
			{
				ID: "money_priorities", Title: "Priorities", Emoji: "🎯", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("money_priorities_q1", "Which would you rather spend on?", "Travel", "Home"),
					choice("money_priorities_q2", "Which is worth it?", "Nice dinner out", "Cooking a feast at home"),
					choice("money_priorities_q3", "Which would you pick?", "Save for a house", "Take the trip of a lifetime"),
					choice("money_priorities_q4", "Which feels better?", "A big splurge", "Lots of small treats"),
				},
			},
			{
				ID: "money_future", Title: "Financial Future", Emoji: "📈", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("money_future_q1", "What does financial security look like to you?"),
					open("money_future_q2", "How do you feel about sharing finances as a couple?"),
					open("money_future_q3", "What's a big purchase you'd love for us to save toward?"),
				},
			},
			{
				ID: "money_habits", Title: "Money Habits", Emoji: "🧾", Format: formatDeepConversation,
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
		ID: "get_to_know", Title: "Get to Know Each Other", Emoji: "🫶", ColorKey: "pink",
		Quizzes: []catalogQuiz{
			{
				ID: "get_to_know_deep", Title: "Deeper Cuts", Emoji: "🔍", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("get_to_know_deep_q1", "What's something about you I might not fully understand yet?"),
					open("get_to_know_deep_q2", "What's a childhood memory that shaped who you are?"),
					open("get_to_know_deep_q3", "What are you most proud of?"),
					open("get_to_know_deep_q4", "What's something you wish more people knew about you?"),
				},
			},
			{
				ID: "get_to_know_this", Title: "You in a Nutshell", Emoji: "🥜", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("get_to_know_this_q1", "Which are you?", "Introvert", "Extrovert"),
					choice("get_to_know_this_q2", "Which are you?", "Overthinker", "Go-with-the-gut"),
					choice("get_to_know_this_q3", "Which are you?", "Optimist", "Pessimist"),
					choice("get_to_know_this_q4", "Which are you?", "Leader", "Supporter"),
				},
			},
			{
				ID: "get_to_know_childhood", Title: "Childhood", Emoji: "🧸", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("get_to_know_childhood_q1", "What did you want to be when you grew up?"),
					open("get_to_know_childhood_q2", "What's your happiest childhood memory?"),
					open("get_to_know_childhood_q3", "Who did you look up to as a kid?"),
				},
			},
			{
				ID: "get_to_know_personality", Title: "Personality", Emoji: "🎭", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("get_to_know_personality_q1", "How do you recharge?", "Alone time", "With people"),
					choice("get_to_know_personality_q2", "Which describes you?", "Planner", "Improviser"),
					choice("get_to_know_personality_q3", "You make decisions with your…", "Logic", "Feelings"),
				},
			},
			{
				ID: "get_to_know_dreams", Title: "Dreams & Fears", Emoji: "💭", Format: formatDeepConversation,
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
		ID: "travel", Title: "Travel", Emoji: "✈️", ColorKey: "blue",
		Quizzes: []catalogQuiz{
			{
				ID: "travel_style", Title: "Travel Style", Emoji: "🧳", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("travel_style_q1", "Which do you prefer?", "Planned itinerary", "Go with the flow"),
					choice("travel_style_q2", "Which do you prefer?", "City break", "Nature escape"),
					choice("travel_style_q3", "Which do you prefer?", "Luxury hotel", "Backpacking"),
					choice("travel_style_q4", "Which do you prefer?", "Window seat", "Aisle seat"),
				},
			},
			{
				ID: "travel_prefer", Title: "Wanderlust", Emoji: "🗺️", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("travel_prefer_q1", "Which trip sounds better?", "Road trip", "Flight abroad"),
					choice("travel_prefer_q2", "Which would you pick?", "Mountains & snow", "Beach & sun"),
					choice("travel_prefer_q3", "Which do you prefer?", "Famous landmarks", "Hidden gems"),
					choice("travel_prefer_q4", "Which do you prefer?", "Street food", "Fine dining abroad"),
				},
			},
			{
				ID: "travel_bucket", Title: "Bucket List", Emoji: "🌏", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("travel_bucket_q1", "What's the one place you dream of visiting together?"),
					open("travel_bucket_q2", "What's a trip you'll never forget?"),
					open("travel_bucket_q3", "What kind of adventure would push you out of your comfort zone?"),
				},
			},
			{
				ID: "travel_memories", Title: "On the Road", Emoji: "📸", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("travel_memories_q1", "What's your favorite travel memory with me?"),
					open("travel_memories_q2", "What do you always pack that you can't travel without?"),
					open("travel_memories_q3", "Beach sunset or city lights — describe your perfect travel moment."),
				},
			},
		},
	},
	// ─────────────────────────────────── FAMILY ──────────────────────────────
	{
		ID: "family", Title: "Family", Emoji: "👨‍👩‍👧", ColorKey: "amber",
		Quizzes: []catalogQuiz{
			{
				ID: "family_future", Title: "Our Future Family", Emoji: "🏡", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("family_future_q1", "What tradition from your family do you want to keep?"),
					open("family_future_q2", "How do you picture our home one day?"),
					open("family_future_q3", "What kind of parent do you hope to be?"),
					open("family_future_q4", "What does 'family' mean to you?"),
				},
			},
			{
				ID: "family_kids", Title: "Kids?", Emoji: "🍼", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("family_kids_q1", "Which sounds more like you?", "Want kids", "Happy without"),
					choice("family_kids_q2", "Which do you lean toward?", "A big family", "A small family"),
					choice("family_kids_q3", "Which parenting style?", "Structured", "Easygoing"),
					choice("family_kids_q4", "Which would you rather?", "Adopt", "Have biologically"),
				},
			},
			{
				ID: "family_traditions", Title: "Traditions", Emoji: "🎄", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("family_traditions_q1", "What's your favorite family tradition?"),
					open("family_traditions_q2", "How do you like to spend the holidays?"),
					open("family_traditions_q3", "What's a new tradition you'd love us to create?"),
				},
			},
			{
				ID: "family_roles", Title: "Home & Roles", Emoji: "🧹", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("family_roles_q1", "Who's more likely to…", "Cook", "Clean"),
					choice("family_roles_q2", "Which are you?", "The planner", "The doer"),
					choice("family_roles_q3", "In a home, you'd rather…", "Host guests often", "Keep it just us"),
				},
			},
		},
	},
	// ─────────────────────────────────── HOBBIES ─────────────────────────────
	{
		ID: "hobbies", Title: "Hobbies", Emoji: "🎨", ColorKey: "purple",
		Quizzes: []catalogQuiz{
			{
				ID: "hobbies_together", Title: "Things to Try Together", Emoji: "🎯", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("hobbies_together_q1", "Which sounds better?", "Cooking class", "Dance class"),
					choice("hobbies_together_q2", "Which sounds better?", "Hiking", "Board game night"),
					choice("hobbies_together_q3", "Which sounds better?", "Painting", "Rock climbing"),
					choice("hobbies_together_q4", "Which sounds better?", "Concert", "Museum"),
				},
			},
			{
				ID: "hobbies_prefer", Title: "Downtime", Emoji: "🛋️", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("hobbies_prefer_q1", "Which do you prefer?", "Gaming", "Reading"),
					choice("hobbies_prefer_q2", "Which do you prefer?", "Cooking", "Ordering in"),
					choice("hobbies_prefer_q3", "Which do you prefer?", "Being active", "Relaxing"),
					choice("hobbies_prefer_q4", "Which do you prefer?", "Creating something", "Watching something"),
				},
			},
			{
				ID: "hobbies_interests", Title: "My Interests", Emoji: "🎧", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("hobbies_interests_q1", "What hobby could you talk about for hours?"),
					open("hobbies_interests_q2", "What's something you'd love to get better at?"),
					open("hobbies_interests_q3", "What activity makes you lose track of time?"),
				},
			},
			{
				ID: "hobbies_weekend", Title: "Weekend Vibes", Emoji: "🌈", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("hobbies_weekend_q1", "Ideal weekend?", "Adventure out", "Cozy in"),
					choice("hobbies_weekend_q2", "Saturday night?", "Party", "Movie & snacks"),
					choice("hobbies_weekend_q3", "Sunday morning?", "Sleep in", "Early start"),
				},
			},
		},
	},
	// ────────────────────────────── SCHOOL & WORK ────────────────────────────
	{
		ID: "school_work", Title: "School & Work", Emoji: "💼", ColorKey: "blue",
		Quizzes: []catalogQuiz{
			{
				ID: "school_work_ambitions", Title: "Ambitions", Emoji: "🚀", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("school_work_ambitions_q1", "What does success look like to you in five years?"),
					open("school_work_ambitions_q2", "Would you ever quit a stable job to chase a dream?"),
					open("school_work_ambitions_q3", "What's a skill you wish you had time to learn?"),
					open("school_work_ambitions_q4", "What kind of work makes you feel fulfilled?"),
				},
			},
			{
				ID: "school_work_style", Title: "Work Style", Emoji: "🖥️", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("school_work_style_q1", "Which are you?", "Work from home", "Work from office"),
					choice("school_work_style_q2", "Which are you?", "Early bird at work", "Late-night grinder"),
					choice("school_work_style_q3", "Which are you?", "Team player", "Solo worker"),
					choice("school_work_style_q4", "Which matters more?", "Passion", "Paycheck"),
				},
			},
			{
				ID: "school_work_balance", Title: "Work-Life Balance", Emoji: "⚖️", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("school_work_balance_q1", "Which would you choose?", "Higher salary, less time", "Less money, more freedom"),
					choice("school_work_balance_q2", "Which do you value more?", "Career growth", "Peace of mind"),
					choice("school_work_balance_q3", "Which is you?", "Live to work", "Work to live"),
				},
			},
			{
				ID: "school_work_past", Title: "School Days", Emoji: "🎓", Format: formatDeepConversation,
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
		ID: "lifestyle", Title: "Lifestyle", Emoji: "🌿", ColorKey: "green",
		Quizzes: []catalogQuiz{
			{
				ID: "lifestyle_daily", Title: "Daily Rhythm", Emoji: "☀️", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("lifestyle_daily_q1", "Which are you?", "Tidy", "Cozy chaos"),
					choice("lifestyle_daily_q2", "Which do you prefer?", "Nights in", "Nights out"),
					choice("lifestyle_daily_q3", "Which do you prefer?", "Gym", "Long walks"),
					choice("lifestyle_daily_q4", "Which are you?", "Routine", "Variety"),
				},
			},
			{
				ID: "lifestyle_health", Title: "Health & Habits", Emoji: "🥗", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("lifestyle_health_q1", "Which do you prefer?", "Home-cooked", "Takeout"),
					choice("lifestyle_health_q2", "Which do you prefer?", "Workout together", "Do your own thing"),
					choice("lifestyle_health_q3", "Which do you prefer?", "Early to bed", "Night owl"),
					choice("lifestyle_health_q4", "Which do you value more?", "Rest", "Productivity"),
				},
			},
			{
				ID: "lifestyle_home", Title: "Home Life", Emoji: "🏠", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("lifestyle_home_q1", "Dream home?", "City apartment", "House in nature"),
					choice("lifestyle_home_q2", "Which vibe?", "Minimalist", "Warm & full"),
					choice("lifestyle_home_q3", "Which do you prefer?", "Pets in the home", "No pets"),
				},
			},
			{
				ID: "lifestyle_values", Title: "How We Live", Emoji: "🌻", Format: formatDeepConversation,
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
		ID: "food", Title: "Food", Emoji: "🍽️", ColorKey: "red",
		Quizzes: []catalogQuiz{
			{
				ID: "food_tastes", Title: "Taste Test", Emoji: "🍕", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("food_tastes_q1", "Which do you prefer?", "Sweet", "Savory"),
					choice("food_tastes_q2", "Which do you prefer?", "Pizza", "Pasta"),
					choice("food_tastes_q3", "Which do you prefer?", "Cook at home", "Eat out"),
					choice("food_tastes_q4", "Which do you prefer?", "Spicy", "Mild"),
					choice("food_tastes_q5", "Which do you prefer?", "Coffee", "Dessert"),
				},
			},
			{
				ID: "food_cooking", Title: "In the Kitchen", Emoji: "👩‍🍳", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("food_cooking_q1", "Which are you?", "Head chef", "Sous chef"),
					choice("food_cooking_q2", "Which do you prefer?", "Follow the recipe", "Improvise"),
					choice("food_cooking_q3", "Which do you prefer?", "Baking", "Grilling"),
					choice("food_cooking_q4", "Which are you?", "Adventurous eater", "Stick to favorites"),
				},
			},
			{
				ID: "food_prefer", Title: "Foodie Faceoff", Emoji: "🥊", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("food_prefer_q1", "Which cuisine?", "Italian", "Asian"),
					choice("food_prefer_q2", "Which do you prefer?", "Breakfast", "Dinner"),
					choice("food_prefer_q3", "Which do you prefer?", "Burgers", "Sushi"),
					choice("food_prefer_q4", "Which do you prefer?", "Chocolate", "Fruit"),
				},
			},
			{
				ID: "food_date", Title: "Date Night Dining", Emoji: "🍷", Format: formatDeepConversation,
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

package httpapi

// Static quiz catalog. Categories → quizzes → questions, all keyed by stable
// string ids that quiz_answers references. Content lives in code so it can grow
// without a DB migration. Icons are SF Symbol names (rendered on iOS); photo
// options carry a loremflickr keyword the app turns into an image. Every quiz
// here is playable (no premium lock yet). 12 categories, 10 quizzes each,
// 6+ questions per quiz.

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
	{
		ID: "starters", Title: "Starters", Icon: "sparkles", ColorKey: "purple",
		Quizzes: []catalogQuiz{
			{
				ID: "starters_favorite_things", Title: "Favorite Things", Icon: "star.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("starters_favorite_things_q1", "Which do you prefer?", photo("Beach", "beach"), photo("Mountains", "mountains")),
					choice("starters_favorite_things_q2", "Which do you prefer?", photo("Dogs", "dog"), photo("Cats", "cat")),
					choice("starters_favorite_things_q3", "Which do you prefer?", photo("Coffee", "coffee"), photo("Tea", "tea")),
					choice("starters_favorite_things_q4", "Which do you prefer?", photo("Summer", "summer"), photo("Winter", "winter")),
					choice("starters_favorite_things_q5", "Which do you prefer?", photo("Books", "books"), photo("Movies", "cinema")),
					choice("starters_favorite_things_q6", "Which do you prefer?", photo("Sunrise", "sunrise"), photo("Sunset", "sunset")),
				},
			},
			{
				ID: "starters_this_or_that", Title: "This or That", Icon: "arrow.left.arrow.right", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("starters_this_or_that_q1", "This or that?", icon("Early Bird", "sunrise.fill"), icon("Night Owl", "moon.stars.fill")),
					choice("starters_this_or_that_q2", "This or that?", icon("Planner", "list.bullet.clipboard.fill"), icon("Spontaneous", "shuffle")),
					choice("starters_this_or_that_q3", "This or that?", photo("City", "city"), photo("Countryside", "countryside")),
					choice("starters_this_or_that_q4", "This or that?", icon("Save", "banknote.fill"), icon("Splurge", "cart.fill")),
					choice("starters_this_or_that_q5", "This or that?", photo("Pizza", "pizza"), photo("Tacos", "tacos")),
					choice("starters_this_or_that_q6", "This or that?", icon("Adventure", "map.fill"), icon("Cozy Home", "house.fill")),
				},
			},
			{
				ID: "starters_quickfire_picks", Title: "Quickfire Picks", Icon: "bolt.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("starters_quickfire_picks_q1", "Which do you prefer?", photo("Chocolate", "chocolate"), photo("Ice Cream", "icecream")),
					choice("starters_quickfire_picks_q2", "Which do you prefer?", photo("Pancakes", "pancakes"), photo("Waffles", "waffles")),
					choice("starters_quickfire_picks_q3", "Which do you prefer?", photo("Wine", "wine"), photo("Beer", "beer")),
					choice("starters_quickfire_picks_q4", "Which do you prefer?", photo("Road Trip", "roadtrip"), photo("Flight", "airplane")),
					choice("starters_quickfire_picks_q5", "Which do you prefer?", photo("Ocean", "ocean"), photo("Forest", "forest")),
					choice("starters_quickfire_picks_q6", "Which do you prefer?", photo("Pool", "pool"), photo("Hot Tub", "hottub")),
					choice("starters_quickfire_picks_q7", "Which do you prefer?", photo("Burgers", "burger"), photo("Sushi", "sushi")),
				},
			},
			{
				ID: "starters_our_firsts", Title: "Our Firsts", Icon: "heart.circle.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("starters_our_firsts_q1", "What do you remember most about the first time we met?"),
					open("starters_our_firsts_q2", "When did you first realize you had feelings for me?"),
					open("starters_our_firsts_q3", "What was going through your mind on our first date?"),
					open("starters_our_firsts_q4", "What's the first thing you noticed about me?"),
					open("starters_our_firsts_q5", "Where would you love for us to travel together for the first time?"),
					open("starters_our_firsts_q6", "What's a first we've shared that you'll never forget?"),
				},
			},
			{
				ID: "starters_would_you_rather", Title: "Would You Rather", Icon: "questionmark.circle.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("starters_would_you_rather_q1", "Would you rather?", icon("Fly", "airplane"), icon("Read Minds", "brain.head.profile")),
					choice("starters_would_you_rather_q2", "Would you rather?", icon("More Time", "hourglass"), icon("More Money", "dollarsign.circle.fill")),
					choice("starters_would_you_rather_q3", "Would you rather?", photo("Beach House", "beachhouse"), photo("Cabin", "cabin")),
					choice("starters_would_you_rather_q4", "Would you rather?", icon("Famous", "star.fill"), icon("Anonymous", "hand.raised.fill")),
					choice("starters_would_you_rather_q5", "Would you rather?", icon("Past", "clock.fill"), icon("Future", "sparkles")),
					choice("starters_would_you_rather_q6", "Would you rather?", photo("Sailboat", "sailboat"), photo("Campervan", "campervan")),
				},
			},
			{
				ID: "starters_simple_pleasures", Title: "Simple Pleasures", Icon: "leaf.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("starters_simple_pleasures_q1", "Which do you prefer?", photo("Rainy Day", "rain"), photo("Sunny Day", "sunshine")),
					choice("starters_simple_pleasures_q2", "Which do you prefer?", photo("Fresh Coffee", "coffee"), photo("Fresh Bread", "bread")),
					choice("starters_simple_pleasures_q3", "Which do you prefer?", photo("Cozy Blanket", "blanket"), photo("Warm Fire", "fireplace")),
					choice("starters_simple_pleasures_q4", "Which do you prefer?", photo("Long Bath", "bath"), photo("Morning Walk", "walk")),
					choice("starters_simple_pleasures_q5", "Which do you prefer?", photo("Candles", "candles"), photo("Flowers", "flowers")),
					choice("starters_simple_pleasures_q6", "Which do you prefer?", photo("Fresh Sheets", "sheets"), photo("New Book", "book")),
				},
			},
			{
				ID: "starters_guilty_pleasures", Title: "Guilty Pleasures", Icon: "flame.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("starters_guilty_pleasures_q1", "Own up, this or that?", photo("Junk Food", "junkfood"), photo("Fine Dining", "finedining")),
					choice("starters_guilty_pleasures_q2", "Own up, this or that?", icon("Binge Watch", "tv.fill"), icon("Sleep In", "bed.double.fill")),
					choice("starters_guilty_pleasures_q3", "Own up, this or that?", photo("Online Shopping", "shopping"), photo("Late Snacks", "snacks")),
					choice("starters_guilty_pleasures_q4", "Own up, this or that?", icon("Reality TV", "tv.fill"), icon("Trashy Novels", "book.fill")),
					choice("starters_guilty_pleasures_q5", "Own up, this or that?", photo("Chocolate Stash", "chocolate"), photo("Ice Cream Tub", "icecream")),
					choice("starters_guilty_pleasures_q6", "Own up, this or that?", icon("Gossip", "message.fill"), icon("Daydream", "cloud.fill")),
				},
			},
			{
				ID: "starters_small_talk", Title: "Small Talk", Icon: "bubble.left.and.bubble.right.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("starters_small_talk_q1", "What's the best part of your day, most days?"),
					open("starters_small_talk_q2", "What's something small that always makes you smile?"),
					open("starters_small_talk_q3", "What's a song you can't stop listening to lately?"),
					open("starters_small_talk_q4", "If we had a free afternoon tomorrow, how would you want to spend it?"),
					open("starters_small_talk_q5", "What's the last thing that made you laugh out loud?"),
					open("starters_small_talk_q6", "What's something you're looking forward to right now?"),
				},
			},
			{
				ID: "starters_rapid_fire_favorites", Title: "Rapid Fire Favorites", Icon: "sparkle", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("starters_rapid_fire_favorites_q1", "Which do you prefer?", photo("Sweet", "cake"), photo("Salty", "fries")),
					choice("starters_rapid_fire_favorites_q2", "Which do you prefer?", photo("Morning", "morning"), photo("Night", "night")),
					choice("starters_rapid_fire_favorites_q3", "Which do you prefer?", photo("Concert", "concert"), photo("Museum", "museum")),
					choice("starters_rapid_fire_favorites_q4", "Which do you prefer?", photo("Popcorn", "popcorn"), photo("Candy", "candy")),
					choice("starters_rapid_fire_favorites_q5", "Which do you prefer?", photo("Sneakers", "sneakers"), photo("Boots", "boots")),
					choice("starters_rapid_fire_favorites_q6", "Which do you prefer?", photo("Breakfast", "breakfast"), photo("Dinner", "dinner")),
					choice("starters_rapid_fire_favorites_q7", "Which do you prefer?", photo("Lake", "lake"), photo("River", "river")),
				},
			},
			{
				ID: "starters_icebreakers", Title: "Icebreakers", Icon: "snowflake", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("starters_icebreakers_q1", "If you could have dinner with anyone, living or not, who would it be?"),
					open("starters_icebreakers_q2", "What's a talent or skill you'd love to master someday?"),
					open("starters_icebreakers_q3", "What's the most spontaneous thing you've ever done?"),
					open("starters_icebreakers_q4", "If we won the lottery tomorrow, what's the first thing we'd do?"),
					open("starters_icebreakers_q5", "What's a place you've always dreamed of visiting?"),
					open("starters_icebreakers_q6", "What's one thing on your bucket list you want us to do together?"),
				},
			},
		},
	},
	{
		ID: "relationship", Title: "Relationship", Icon: "heart.fill", ColorKey: "pink",
		Quizzes: []catalogQuiz{
			{
				ID: "relationship_proposal", Title: "The Perfect Proposal", Icon: "diamond.fill", Format: formatDeepConversation, Tag: "WEDDING",
				Questions: []catalogQuestion{
					open("relationship_proposal_q1", "How do you imagine the perfect proposal moment?"),
					open("relationship_proposal_q2", "Would you want a proposal to be private and intimate, or a big surprise?"),
					open("relationship_proposal_q3", "Where in the world would you dream of being asked the big question?"),
					open("relationship_proposal_q4", "Who would you want to be there when we get engaged, if anyone?"),
					open("relationship_proposal_q5", "What would you want to feel in that exact moment?"),
					open("relationship_proposal_q6", "How would you want to tell our families and friends the news?"),
					open("relationship_proposal_q7", "What little detail would make a proposal unforgettable for you?"),
				},
			},
			{
				ID: "relationship_rings", Title: "Engagement Rings", Icon: "diamond.fill", Format: formatThisOrThat, Tag: "WEDDING",
				Questions: []catalogQuestion{
					choice("relationship_rings_q1", "Which ring speaks to you?", photo("Gold band", "goldring"), photo("Silver band", "silverring")),
					choice("relationship_rings_q2", "Which stone would you choose?", photo("Diamond", "diamond"), photo("Emerald", "emerald")),
					choice("relationship_rings_q3", "Which style fits you?", icon("Classic", "crown.fill"), icon("Modern", "sparkles")),
					choice("relationship_rings_q4", "Which do you lean toward?", photo("Vintage ring", "vintagering"), photo("Minimal ring", "ring")),
					choice("relationship_rings_q5", "Which matters more?", icon("Big statement", "sparkle"), icon("Subtle elegance", "leaf.fill")),
					choice("relationship_rings_q6", "Which band metal?", photo("Rose gold", "rosegold"), photo("Platinum", "platinum")),
				},
			},
			{
				ID: "relationship_wedding", Title: "Dream Wedding", Icon: "sparkles", Format: formatWhichDoYouPrefer, Tag: "WEDDING",
				Questions: []catalogQuestion{
					choice("relationship_wedding_q1", "Which do you prefer?", photo("Beach wedding", "beach"), photo("Garden wedding", "garden")),
					choice("relationship_wedding_q2", "Which do you prefer?", photo("Big celebration", "wedding,crowd"), photo("Small gathering", "intimate,dinner")),
					choice("relationship_wedding_q3", "Which do you prefer?", photo("Summer wedding", "sunshine"), photo("Winter wedding", "snow")),
					choice("relationship_wedding_q4", "Which do you prefer?", icon("Elegant black tie", "crown.fill"), icon("Relaxed casual", "leaf.fill")),
					choice("relationship_wedding_q5", "Which do you prefer?", photo("City venue", "city"), photo("Countryside venue", "countryside")),
					choice("relationship_wedding_q6", "Which do you prefer?", photo("Live band", "band"), photo("DJ party", "dj")),
					choice("relationship_wedding_q7", "Which do you prefer?", icon("Traditional vows", "book.fill"), icon("Personal vows", "text.bubble.fill")),
				},
			},
			{
				ID: "relationship_love_languages", Title: "Love Languages", Icon: "heart.circle.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("relationship_love_languages_q1", "Which means more to you?", icon("Kind words", "text.bubble.fill"), icon("Quality time", "clock.fill")),
					choice("relationship_love_languages_q2", "Which feels like love?", icon("A thoughtful gift", "gift.fill"), icon("A helping hand", "hands.clap.fill")),
					choice("relationship_love_languages_q3", "Which do you crave more?", icon("Physical closeness", "heart.fill"), icon("Words of praise", "message.fill")),
					choice("relationship_love_languages_q4", "Which fills your heart?", icon("Undivided attention", "person.2.fill"), icon("A surprise treat", "sparkles")),
					choice("relationship_love_languages_q5", "Which matters more?", icon("Being listened to", "headphones"), icon("Being held", "heart.circle.fill")),
					choice("relationship_love_languages_q6", "Which speaks to you?", icon("Acts of service", "checkmark.seal.fill"), icon("Affectionate touch", "hand.raised.fill")),
				},
			},
			{
				ID: "relationship_about_us", Title: "About Us", Icon: "person.2.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("relationship_about_us_q1", "What was the exact moment you knew you had feelings for me?"),
					open("relationship_about_us_q2", "What's your favorite memory of us so far?"),
					open("relationship_about_us_q3", "What's something small I do that you secretly love?"),
					open("relationship_about_us_q4", "How have we grown together since we first met?"),
					open("relationship_about_us_q5", "What's a moment you felt closest to me?"),
					open("relationship_about_us_q6", "What do you think makes us work so well together?"),
				},
			},
			{
				ID: "relationship_future", Title: "Our Future", Icon: "sunrise.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("relationship_future_q1", "Where do you picture us living five years from now?"),
					open("relationship_future_q2", "What's a dream you'd love for us to chase together?"),
					open("relationship_future_q3", "What kind of home do you imagine us building one day?"),
					open("relationship_future_q4", "What tradition would you love for us to start?"),
					open("relationship_future_q5", "What adventure do you hope we take together someday?"),
					open("relationship_future_q6", "When we're old and grey, what do you hope we're still doing together?"),
				},
			},
			{
				ID: "relationship_arguments", Title: "When We Argue", Icon: "cloud.rain.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("relationship_arguments_q1", "What helps you feel calm again after we disagree?"),
					open("relationship_arguments_q2", "How do you prefer I approach you when something is wrong?"),
					open("relationship_arguments_q3", "What's the best way for us to make up after a fight?"),
					open("relationship_arguments_q4", "What do you need most from me when you're upset?"),
					open("relationship_arguments_q5", "How can we disagree without hurting each other?"),
					open("relationship_arguments_q6", "What's something you wish I understood about how you handle conflict?"),
				},
			},
			{
				ID: "relationship_date_nights", Title: "Date Nights", Icon: "moon.stars.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("relationship_date_nights_q1", "Which do you prefer?", photo("Movie night", "cinema"), photo("Dinner out", "restaurant")),
					choice("relationship_date_nights_q2", "Which do you prefer?", photo("Cozy night in", "blanket"), photo("Night on the town", "nightlife")),
					choice("relationship_date_nights_q3", "Which do you prefer?", photo("Picnic in the park", "picnic"), photo("Rooftop drinks", "rooftop")),
					choice("relationship_date_nights_q4", "Which do you prefer?", icon("Spontaneous plans", "shuffle"), icon("Planned evening", "calendar")),
					choice("relationship_date_nights_q5", "Which do you prefer?", photo("Dancing together", "dancing"), photo("Stargazing", "stars")),
					choice("relationship_date_nights_q6", "Which do you prefer?", photo("Cooking together", "cooking"), photo("Ordering takeout", "takeout")),
				},
			},
			{
				ID: "relationship_romance", Title: "Romance Style", Icon: "flame.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("relationship_romance_q1", "Which is more you?", icon("Grand gestures", "sparkles"), icon("Quiet moments", "moon.stars.fill")),
					choice("relationship_romance_q2", "Which sounds sweeter?", photo("Handwritten love note", "loveletter"), photo("Surprise flowers", "flowers")),
					choice("relationship_romance_q3", "Which do you love more?", icon("Slow dancing", "music.note"), icon("Long walks", "figure.walk")),
					choice("relationship_romance_q4", "Which melts your heart?", photo("Candlelit dinner", "candlelight"), photo("Sunset walk", "sunset")),
					choice("relationship_romance_q5", "Which is your style?", icon("Playful teasing", "sparkle"), icon("Tender affection", "heart.fill")),
					choice("relationship_romance_q6", "Which do you prefer?", photo("Morning cuddles", "cuddle"), photo("Late night talks", "night")),
				},
			},
			{
				ID: "relationship_trust", Title: "Trust & Closeness", Icon: "shield.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("relationship_trust_q1", "What makes you feel truly safe with me?"),
					open("relationship_trust_q2", "When do you feel the most emotionally close to me?"),
					open("relationship_trust_q3", "What's something you've never told anyone that you feel you could tell me?"),
					open("relationship_trust_q4", "How can I show up for you when life gets hard?"),
					open("relationship_trust_q5", "What builds trust between us more than anything?"),
					open("relationship_trust_q6", "What does feeling deeply understood by me look like to you?"),
				},
			},
		},
	},
	{
		ID: "sex_love", Title: "Sex & Love", Icon: "flame.fill", ColorKey: "red",
		Quizzes: []catalogQuiz{
			{
				ID: "sex_love_spicy_questions", Title: "Spicy Questions", Icon: "flame.fill", Format: formatDeepConversation, Tag: "18+",
				Questions: []catalogQuestion{
					open("sex_love_spicy_questions_q1", "What's the first thing you noticed about me that made your pulse quicken?"),
					open("sex_love_spicy_questions_q2", "When do you feel most desired by me?"),
					open("sex_love_spicy_questions_q3", "What's a moment between us you replay in your mind?"),
					open("sex_love_spicy_questions_q4", "What makes you feel instantly closer to me?"),
					open("sex_love_spicy_questions_q5", "If we had one uninterrupted evening, how would you want it to unfold?"),
					open("sex_love_spicy_questions_q6", "What's something you've been wanting to whisper but haven't yet?"),
				},
			},
			{
				ID: "sex_love_sensual_talks", Title: "Sensual Talks", Icon: "text.bubble.fill", Format: formatDeepConversation, Tag: "18+",
				Questions: []catalogQuestion{
					open("sex_love_sensual_talks_q1", "How do you like to be touched when you want to feel comforted?"),
					open("sex_love_sensual_talks_q2", "What words from me make you melt a little?"),
					open("sex_love_sensual_talks_q3", "Where on your body do you most love being kissed?"),
					open("sex_love_sensual_talks_q4", "What's your favorite way for us to reconnect after a long day?"),
					open("sex_love_sensual_talks_q5", "When has a simple gesture from me felt surprisingly intimate?"),
					open("sex_love_sensual_talks_q6", "What does 'taking it slow' feel like at its best for you?"),
					open("sex_love_sensual_talks_q7", "How do you like me to let you know I want you closer?"),
				},
			},
			{
				ID: "sex_love_preferences", Title: "Preferences", Icon: "heart.circle.fill", Format: formatWhichDoYouPrefer, Tag: "18+",
				Questions: []catalogQuestion{
					choice("sex_love_preferences_q1", "Which do you prefer?", icon("Slow", "leaf.fill"), icon("Passionate", "flame.fill")),
					choice("sex_love_preferences_q2", "Which do you prefer?", icon("Morning", "sunrise.fill"), icon("Late night", "moon.stars.fill")),
					choice("sex_love_preferences_q3", "Which do you prefer?", icon("Candlelight", "flame.fill"), icon("Moonlight", "moon.stars.fill")),
					choice("sex_love_preferences_q4", "Which do you prefer?", icon("Playful", "sparkles"), icon("Tender", "heart.fill")),
					choice("sex_love_preferences_q5", "Which do you prefer?", icon("Whispered words", "text.bubble.fill"), icon("Quiet closeness", "moon.zzz.fill")),
					choice("sex_love_preferences_q6", "Which do you prefer?", icon("Lead", "crown.fill"), icon("Be led", "hand.raised.fill")),
				},
			},
			{
				ID: "sex_love_intimacy_lifestyle", Title: "Intimacy & Lifestyle", Icon: "house.fill", Format: formatDeepConversation, Tag: "18+",
				Questions: []catalogQuestion{
					open("sex_love_intimacy_lifestyle_q1", "How do you like intimacy to fit into our everyday rhythm?"),
					open("sex_love_intimacy_lifestyle_q2", "What small daily habit makes you feel most connected to me?"),
					open("sex_love_intimacy_lifestyle_q3", "How do you like us to keep the spark alive on busy weeks?"),
					open("sex_love_intimacy_lifestyle_q4", "What does a perfect lazy morning together look like to you?"),
					open("sex_love_intimacy_lifestyle_q5", "How important is spontaneity versus anticipation for you?"),
					open("sex_love_intimacy_lifestyle_q6", "What ritual would you love us to make our own?"),
				},
			},
			{
				ID: "sex_love_fantasies", Title: "Fantasies", Icon: "sparkles", Format: formatThisOrThat, Tag: "18+",
				Questions: []catalogQuestion{
					choice("sex_love_fantasies_q1", "This or that?", icon("A getaway", "airplane"), icon("A staycation", "house.fill")),
					choice("sex_love_fantasies_q2", "This or that?", photo("Candlelight", "candlelight"), photo("Sunset", "sunset")),
					choice("sex_love_fantasies_q3", "This or that?", icon("Planned surprise", "gift.fill"), icon("Spontaneous", "dice.fill")),
					choice("sex_love_fantasies_q4", "This or that?", icon("Dressed up", "diamond.fill"), icon("Cozy comfort", "moon.zzz.fill")),
					choice("sex_love_fantasies_q5", "This or that?", photo("Fireplace", "fireplace"), photo("Under the stars", "stars")),
					choice("sex_love_fantasies_q6", "This or that?", icon("A secret", "lock.fill"), icon("An adventure", "map.fill")),
				},
			},
			{
				ID: "sex_love_turn_ons", Title: "Turn-Ons", Icon: "bolt.fill", Format: formatWhichDoYouPrefer, Tag: "18+",
				Questions: []catalogQuestion{
					choice("sex_love_turn_ons_q1", "Which draws you in more?", icon("Confidence", "crown.fill"), icon("Playfulness", "sparkles")),
					choice("sex_love_turn_ons_q2", "Which draws you in more?", icon("A lingering look", "sparkle"), icon("A soft touch", "hand.raised.fill")),
					choice("sex_love_turn_ons_q3", "Which draws you in more?", icon("Sweet words", "text.bubble.fill"), icon("Quiet presence", "moon.zzz.fill")),
					choice("sex_love_turn_ons_q4", "Which draws you in more?", icon("A great laugh", "sparkles"), icon("A deep talk", "brain.head.profile")),
					choice("sex_love_turn_ons_q5", "Which draws you in more?", icon("Anticipation", "hourglass"), icon("Surprise", "gift.fill")),
					choice("sex_love_turn_ons_q6", "Which draws you in more?", icon("Music together", "music.note"), icon("Dancing close", "heart.fill")),
					choice("sex_love_turn_ons_q7", "Which draws you in more?", icon("A warm whisper", "wind"), icon("A knowing smile", "sparkle")),
				},
			},
			{
				ID: "sex_love_mood_setting", Title: "Mood & Setting", Icon: "moon.stars.fill", Format: formatThisOrThat, Tag: "18+",
				Questions: []catalogQuestion{
					choice("sex_love_mood_setting_q1", "Set the scene:", photo("Roses", "roses"), photo("Wine", "wine")),
					choice("sex_love_mood_setting_q2", "Set the scene:", photo("Silk", "silk"), photo("Bath", "bath")),
					choice("sex_love_mood_setting_q3", "Set the scene:", icon("Soft music", "music.note"), icon("Gentle rain", "cloud.fill")),
					choice("sex_love_mood_setting_q4", "Set the scene:", photo("Fireplace", "fireplace"), photo("Candlelight", "candlelight")),
					choice("sex_love_mood_setting_q5", "Set the scene:", icon("City lights", "sparkles"), icon("Starry sky", "moon.stars.fill")),
					choice("sex_love_mood_setting_q6", "Set the scene:", icon("Warm cabin", "house.fill"), icon("Ocean breeze", "wind")),
				},
			},
			{
				ID: "sex_love_communication", Title: "Communication", Icon: "bubble.left.and.bubble.right.fill", Format: formatDeepConversation, Tag: "18+",
				Questions: []catalogQuestion{
					open("sex_love_communication_q1", "How do you like me to tell you what I want?"),
					open("sex_love_communication_q2", "What makes it easy for you to open up about intimacy?"),
					open("sex_love_communication_q3", "How can I better read what you need in the moment?"),
					open("sex_love_communication_q4", "What's a way I could ask for closeness that you'd love?"),
					open("sex_love_communication_q5", "When do you feel safest being vulnerable with me?"),
					open("sex_love_communication_q6", "How do you like us to reconnect after a disagreement?"),
				},
			},
			{
				ID: "sex_love_adventurous_or_cozy", Title: "Adventurous or Cozy", Icon: "dice.fill", Format: formatThisOrThat, Tag: "18+",
				Questions: []catalogQuestion{
					choice("sex_love_adventurous_or_cozy_q1", "Which is more you tonight?", icon("Adventurous", "map.fill"), icon("Cozy", "house.fill")),
					choice("sex_love_adventurous_or_cozy_q2", "Which is more you tonight?", icon("Try something new", "sparkles"), icon("A favorite ritual", "repeat")),
					choice("sex_love_adventurous_or_cozy_q3", "Which is more you tonight?", icon("Bold", "flame.fill"), icon("Gentle", "leaf.fill")),
					choice("sex_love_adventurous_or_cozy_q4", "Which is more you tonight?", icon("Spontaneous", "shuffle"), icon("Planned", "calendar")),
					choice("sex_love_adventurous_or_cozy_q5", "Which is more you tonight?", icon("Out on the town", "airplane"), icon("Wrapped in blankets", "bed.double.fill")),
					choice("sex_love_adventurous_or_cozy_q6", "Which is more you tonight?", icon("Surprise me", "gift.fill"), icon("Just us, still", "moon.zzz.fill")),
				},
			},
			{
				ID: "sex_love_desires", Title: "Desires", Icon: "heart.fill", Format: formatDeepConversation, Tag: "18+",
				Questions: []catalogQuestion{
					open("sex_love_desires_q1", "What's a desire you've never quite put into words for me?"),
					open("sex_love_desires_q2", "What would make you feel utterly adored?"),
					open("sex_love_desires_q3", "What's something you'd love us to try together someday?"),
					open("sex_love_desires_q4", "When do you feel most wanted by me?"),
					open("sex_love_desires_q5", "What's a little indulgence you wish we made more time for?"),
					open("sex_love_desires_q6", "If you could design our perfect night, how would it end?"),
					open("sex_love_desires_q7", "What do you want more of from us this year?"),
				},
			},
		},
	},
	{
		ID: "moral_values", Title: "Moral Values", Icon: "hand.raised.fill", ColorKey: "amber",
		Quizzes: []catalogQuiz{
			{
				ID: "moral_values_core_beliefs", Title: "Core Beliefs", Icon: "brain.head.profile", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("moral_values_core_beliefs_q1", "What value do you refuse to compromise on, no matter what?"),
					open("moral_values_core_beliefs_q2", "What belief did you inherit from your family that you still hold?"),
					open("moral_values_core_beliefs_q3", "What belief have you changed your mind about as you've grown?"),
					open("moral_values_core_beliefs_q4", "What does being a good person mean to you?"),
					open("moral_values_core_beliefs_q5", "Where do you think your sense of right and wrong came from?"),
					open("moral_values_core_beliefs_q6", "What conviction of yours do most people disagree with?"),
				},
			},
			{
				ID: "moral_values_would_you_rather", Title: "Would You Rather", Icon: "shuffle", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("moral_values_would_you_rather_q1", "Would you rather be?", icon("Always honest", "checkmark.seal.fill"), icon("Always kind", "heart.fill")),
					choice("moral_values_would_you_rather_q2", "Would you rather live by?", icon("The rules", "list.bullet.clipboard.fill"), icon("Your gut", "sparkles")),
					choice("moral_values_would_you_rather_q3", "Would you rather be seen as?", icon("Fair", "scalemass.fill"), icon("Forgiving", "hands.clap.fill")),
					choice("moral_values_would_you_rather_q4", "Would you rather protect?", icon("The truth", "checkmark.seal.fill"), icon("Someone's feelings", "heart.circle.fill")),
					choice("moral_values_would_you_rather_q5", "Would you rather have?", icon("A clear conscience", "leaf.fill"), icon("A winning outcome", "crown.fill")),
					choice("moral_values_would_you_rather_q6", "Would you rather follow?", icon("Your head", "brain.head.profile"), icon("Your heart", "heart.fill")),
				},
			},
			{
				ID: "moral_values_life_and_meaning", Title: "Life & Meaning", Icon: "lightbulb.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("moral_values_life_and_meaning_q1", "What gives your life the most meaning right now?"),
					open("moral_values_life_and_meaning_q2", "What do you hope people say about you when you're gone?"),
					open("moral_values_life_and_meaning_q3", "What would you want to have stood for by the end of your life?"),
					open("moral_values_life_and_meaning_q4", "When have you felt most at peace with who you are?"),
					open("moral_values_life_and_meaning_q5", "What does a life well lived look like to you?"),
					open("moral_values_life_and_meaning_q6", "What legacy do you hope we build together?"),
				},
			},
			{
				ID: "moral_values_bigger_picture", Title: "The Bigger Picture", Icon: "globe.americas.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("moral_values_bigger_picture_q1", "Which do you value more?", icon("The individual", "person.fill"), icon("The community", "person.3.fill")),
					choice("moral_values_bigger_picture_q2", "Which matters more to you?", icon("The planet", "leaf.fill"), icon("The people", "person.2.fill")),
					choice("moral_values_bigger_picture_q3", "Which do you focus on?", icon("The present", "clock.fill"), icon("The future", "hourglass")),
					choice("moral_values_bigger_picture_q4", "Which drives progress?", icon("Bold change", "bolt.fill"), icon("Steady tradition", "shield.fill")),
					choice("moral_values_bigger_picture_q5", "Which do you trust more?", icon("Human nature", "person.fill"), icon("Good systems", "gearshape.fill")),
					choice("moral_values_bigger_picture_q6", "Which shapes us more?", icon("Our choices", "target"), icon("Our circumstances", "map.fill")),
				},
			},
			{
				ID: "moral_values_honesty_and_trust", Title: "Honesty & Trust", Icon: "checkmark.seal.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("moral_values_honesty_and_trust_q1", "When, if ever, is a white lie the kind thing to do?"),
					open("moral_values_honesty_and_trust_q2", "What does trust have to look like for you to feel safe?"),
					open("moral_values_honesty_and_trust_q3", "What's a truth you think couples should always tell each other?"),
					open("moral_values_honesty_and_trust_q4", "How do you rebuild trust once it's been broken?"),
					open("moral_values_honesty_and_trust_q5", "Is a secret ever a betrayal? Where's your line?"),
					open("moral_values_honesty_and_trust_q6", "When has honesty cost you something, and was it worth it?"),
				},
			},
			{
				ID: "moral_values_right_and_wrong", Title: "Right & Wrong", Icon: "scalemass.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("moral_values_right_and_wrong_q1", "What decides if an act is good?", icon("The intention", "heart.fill"), icon("The outcome", "target")),
					choice("moral_values_right_and_wrong_q2", "Which is worse?", icon("A harmful lie", "flame.fill"), icon("A cruel truth", "bolt.fill")),
					choice("moral_values_right_and_wrong_q3", "Which guides you?", icon("Fixed principles", "lock.fill"), icon("The situation", "shuffle")),
					choice("moral_values_right_and_wrong_q4", "Which is more moral?", icon("Justice", "scalemass.fill"), icon("Mercy", "hands.clap.fill")),
					choice("moral_values_right_and_wrong_q5", "Which weighs more?", icon("Doing no harm", "hand.raised.fill"), icon("Doing good", "gift.fill")),
					choice("moral_values_right_and_wrong_q6", "Which is truly good?", icon("The quiet deed", "moon.stars.fill"), icon("The seen deed", "sun.max.fill")),
				},
			},
			{
				ID: "moral_values_what_matters_most", Title: "What Matters Most", Icon: "star.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("moral_values_what_matters_most_q1", "Which matters more?", icon("Family", "house.fill"), icon("Freedom", "bird.fill")),
					choice("moral_values_what_matters_most_q2", "Which do you value?", icon("Loyalty", "shield.fill"), icon("Honesty", "checkmark.seal.fill")),
					choice("moral_values_what_matters_most_q3", "Which would you choose?", icon("Love", "heart.fill"), icon("Ambition", "flag.fill")),
					choice("moral_values_what_matters_most_q4", "Which comes first?", icon("Security", "lock.fill"), icon("Adventure", "airplane")),
					choice("moral_values_what_matters_most_q5", "Which is richer?", icon("Time", "hourglass"), icon("Money", "dollarsign.circle.fill")),
					choice("moral_values_what_matters_most_q6", "Which do you crave?", icon("Peace", "leaf.fill"), icon("Passion", "flame.fill")),
				},
			},
			{
				ID: "moral_values_kindness", Title: "Kindness", Icon: "hands.clap.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("moral_values_kindness_q1", "What's the kindest thing anyone has ever done for you?"),
					open("moral_values_kindness_q2", "When is kindness hardest for you to give?"),
					open("moral_values_kindness_q3", "How do you show love to people who can't repay you?"),
					open("moral_values_kindness_q4", "Is there such a thing as being too kind? Where's the limit?"),
					open("moral_values_kindness_q5", "What small act of kindness do you wish was more common?"),
					open("moral_values_kindness_q6", "How do you want us to treat strangers as a couple?"),
				},
			},
			{
				ID: "moral_values_principles", Title: "Principles", Icon: "flag.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("moral_values_principles_q1", "Which do you lead with?", icon("Discipline", "target"), icon("Compassion", "heart.circle.fill")),
					choice("moral_values_principles_q2", "Which do you respect more?", icon("Courage", "flame.fill"), icon("Wisdom", "book.fill")),
					choice("moral_values_principles_q3", "Which do you hold higher?", icon("Duty", "shield.fill"), icon("Happiness", "sun.max.fill")),
					choice("moral_values_principles_q4", "Which defines strength?", icon("Standing firm", "lock.fill"), icon("Letting go", "wind")),
					choice("moral_values_principles_q5", "Which matters more?", icon("Being right", "checkmark.seal.fill"), icon("Being at peace", "leaf.fill")),
					choice("moral_values_principles_q6", "Which do you keep?", icon("Your word", "hand.raised.fill"), icon("Your options", "shuffle")),
				},
			},
			{
				ID: "moral_values_ethics_dilemmas", Title: "Ethics Dilemmas", Icon: "questionmark.circle.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("moral_values_ethics_dilemmas_q1", "Would you break a small rule to prevent a bigger harm? When?"),
					open("moral_values_ethics_dilemmas_q2", "If a loved one did something wrong, would you cover for them?"),
					open("moral_values_ethics_dilemmas_q3", "Is it ever right to keep money you weren't meant to receive?"),
					open("moral_values_ethics_dilemmas_q4", "Would you tell a hard truth that could end a friendship?"),
					open("moral_values_ethics_dilemmas_q5", "When is loyalty to a person wrong to honor?"),
					open("moral_values_ethics_dilemmas_q6", "Where's the line between a favor and a bribe for you?"),
				},
			},
		},
	},
	{
		ID: "money_finances", Title: "Money & Finances", Icon: "dollarsign.circle.fill", ColorKey: "green",
		Quizzes: []catalogQuiz{
			{
				ID: "money_spender_saver", Title: "Spender or Saver", Icon: "banknote.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("money_spender_saver_q1", "Which are you?", icon("Saver", "banknote.fill"), icon("Spender", "cart.fill")),
					choice("money_spender_saver_q2", "When money comes in, you...", icon("Stash it away", "lock.fill"), icon("Enjoy it now", "sun.max.fill")),
					choice("money_spender_saver_q3", "Which feels more like you?", icon("Track every penny", "chart.pie.fill"), icon("Go with the flow", "wind")),
					choice("money_spender_saver_q4", "Your ideal balance is...", icon("Comfortable cushion", "shield.fill"), icon("Live for today", "sparkles")),
					choice("money_spender_saver_q5", "A surprise bonus lands. You...", icon("Save most of it", "banknote.fill"), icon("Treat yourself", "gift.fill")),
					choice("money_spender_saver_q6", "Which describes your wallet?", icon("Tightly managed", "checkmark.seal.fill"), icon("Easy come, easy go", "shuffle")),
					choice("money_spender_saver_q7", "Sales and deals make you...", icon("Buy only what's needed", "list.bullet.clipboard.fill"), icon("Grab the bargain", "bag.fill")),
				},
			},
			{
				ID: "money_priorities", Title: "Priorities", Icon: "target", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("money_priorities_q1", "Which would you rather spend on?", photo("Travel", "travel"), photo("Home", "house")),
					choice("money_priorities_q2", "What matters more right now?", photo("A nicer car", "car"), photo("A dream vacation", "vacation")),
					choice("money_priorities_q3", "Where should extra money go?", icon("Experiences", "airplane"), icon("Savings", "banknote.fill")),
					choice("money_priorities_q4", "Which do you value more?", photo("Eating out", "restaurant"), photo("Cooking at home", "kitchen")),
					choice("money_priorities_q5", "Bigger priority for you?", icon("Comfort today", "sun.max.fill"), icon("Security tomorrow", "shield.fill")),
					choice("money_priorities_q6", "Which would you fund first?", photo("A home upgrade", "renovation"), photo("A weekend getaway", "getaway")),
					choice("money_priorities_q7", "What feels more important?", icon("Family needs", "person.3.fill"), icon("Personal goals", "star.fill")),
				},
			},
			{
				ID: "money_financial_future", Title: "Financial Future", Icon: "chart.line.uptrend.xyaxis", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("money_financial_future_q1", "Where do you hope we'll be financially in five years?"),
					open("money_financial_future_q2", "What does financial security mean to you?"),
					open("money_financial_future_q3", "Is there a money goal you've been afraid to say out loud?"),
					open("money_financial_future_q4", "How did your family talk about money when you were growing up?"),
					open("money_financial_future_q5", "What would you want to do if money were no object?"),
					open("money_financial_future_q6", "What's one financial habit you'd like us to build together?"),
					open("money_financial_future_q7", "How do you feel about the way we handle money right now?"),
				},
			},
			{
				ID: "money_habits", Title: "Money Habits", Icon: "repeat", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("money_habits_q1", "Which are you?", icon("Budget tracker", "chart.pie.fill"), icon("Guess and hope", "questionmark.circle.fill")),
					choice("money_habits_q2", "Bills get paid...", icon("The moment they arrive", "bolt.fill"), icon("Right before they're due", "hourglass")),
					choice("money_habits_q3", "Your receipts are...", icon("Filed and tracked", "list.bullet.clipboard.fill"), icon("Long gone", "wind")),
					choice("money_habits_q4", "How do you shop?", icon("With a list", "checkmark.seal.fill"), icon("On a whim", "sparkles")),
					choice("money_habits_q5", "Do you check your balance?", icon("All the time", "clock.fill"), icon("Rarely", "moon.stars.fill")),
					choice("money_habits_q6", "Which are you?", icon("Automate everything", "gearshape.fill"), icon("Handle it manually", "hand.raised.fill")),
					choice("money_habits_q7", "Your saving style is...", icon("Steady and planned", "calendar"), icon("Whatever's left over", "shuffle")),
				},
			},
			{
				ID: "money_big_purchases", Title: "Big Purchases", Icon: "cart.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("money_big_purchases_q1", "Bigger splurge for you?", photo("A new car", "car"), photo("A home renovation", "renovation")),
					choice("money_big_purchases_q2", "Which would you buy first?", photo("A house", "house"), photo("An investment property", "apartment")),
					choice("money_big_purchases_q3", "Which is worth it?", photo("A luxury watch", "watch"), photo("A designer bag", "handbag")),
					choice("money_big_purchases_q4", "Where would you splurge?", photo("A dream kitchen", "kitchen"), photo("A backyard oasis", "garden")),
					choice("money_big_purchases_q5", "Which tech upgrade?", photo("A new laptop", "laptop"), photo("A big TV", "television")),
					choice("money_big_purchases_q6", "Bigger celebration buy?", photo("A luxury vacation", "resort"), photo("A special piece of jewelry", "jewelry")),
					choice("money_big_purchases_q7", "How do you decide on big buys?", icon("Research for weeks", "book.fill"), icon("Trust your gut", "bolt.fill")),
				},
			},
			{
				ID: "money_splurge_save", Title: "Splurge or Save", Icon: "sparkles", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("money_splurge_save_q1", "Which feels better?", icon("Big splurge", "sparkles"), icon("Small treats", "gift.fill")),
					choice("money_splurge_save_q2", "On a date night, you...", icon("Go all out", "crown.fill"), icon("Keep it simple", "leaf.fill")),
					choice("money_splurge_save_q3", "Coffee run habit?", icon("Daily fancy latte", "sun.max.fill"), icon("Brew it at home", "house.fill")),
					choice("money_splurge_save_q4", "Which do you value?", icon("Save now", "banknote.fill"), icon("Enjoy now", "star.fill")),
					choice("money_splurge_save_q5", "Vacation style?", icon("Splurge on luxury", "diamond.fill"), icon("Save with budget travel", "map.fill")),
					choice("money_splurge_save_q6", "Gift giving is...", icon("Generous and grand", "gift.fill"), icon("Thoughtful and modest", "heart.fill")),
					choice("money_splurge_save_q7", "When treating yourself, you feel...", icon("Zero guilt", "checkmark.seal.fill"), icon("A little guilty", "hand.raised.fill")),
				},
			},
			{
				ID: "money_dreams_goals", Title: "Dreams & Goals", Icon: "star.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("money_dreams_goals_q1", "If we saved for one big dream together, what would it be?"),
					open("money_dreams_goals_q2", "What's a purchase you've always dreamed of making?"),
					open("money_dreams_goals_q3", "Where in the world would you love for us to go together?"),
					open("money_dreams_goals_q4", "What would our ideal home look like someday?"),
					open("money_dreams_goals_q5", "What does 'enough money' look like to you?"),
					open("money_dreams_goals_q6", "Is there a goal we could start working toward this year?"),
					open("money_dreams_goals_q7", "What legacy or gift would you want to leave for people we love?"),
				},
			},
			{
				ID: "money_sharing_finances", Title: "Sharing Finances", Icon: "person.2.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("money_sharing_finances_q1", "Which do you prefer?", icon("Split 50/50", "arrow.left.arrow.right"), icon("Shared pot", "person.2.fill")),
					choice("money_sharing_finances_q2", "How should accounts work?", icon("Fully combined", "person.2.fill"), icon("Yours, mine, ours", "person.3.fill")),
					choice("money_sharing_finances_q3", "Who handles the bills?", icon("One of us leads", "person.fill"), icon("We take turns", "repeat")),
					choice("money_sharing_finances_q4", "Big purchase decisions?", icon("Always discuss first", "person.2.fill"), icon("Trust each other's calls", "checkmark.seal.fill")),
					choice("money_sharing_finances_q5", "Which do you prefer?", icon("One shared budget", "chart.pie.fill"), icon("Separate spending money", "creditcard.fill")),
					choice("money_sharing_finances_q6", "How open should money talk be?", icon("Full transparency", "sparkle"), icon("Some privacy is fine", "lock.fill")),
					choice("money_sharing_finances_q7", "Which feels fair?", icon("Split by income", "scalemass.fill"), icon("Split evenly", "arrow.left.arrow.right")),
				},
			},
			{
				ID: "money_risk_security", Title: "Risk & Security", Icon: "shield.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("money_risk_security_q1", "Which are you?", icon("Play it safe", "shield.fill"), icon("Take the risk", "bolt.fill")),
					choice("money_risk_security_q2", "Investing style?", icon("Steady and slow", "leaf.fill"), icon("Bold and fast", "chart.line.uptrend.xyaxis")),
					choice("money_risk_security_q3", "Emergency fund is...", icon("A must-have", "lock.fill"), icon("Nice to have", "wind")),
					choice("money_risk_security_q4", "Which appeals more?", icon("Guaranteed small return", "checkmark.seal.fill"), icon("Big maybe payoff", "sparkles")),
					choice("money_risk_security_q5", "Your comfort zone is...", icon("Rock-solid stability", "building.2.fill"), icon("Room to gamble", "shuffle")),
					choice("money_risk_security_q6", "Debt makes you feel...", icon("Anxious, avoid it", "shield.fill"), icon("Fine if it's strategic", "target")),
					choice("money_risk_security_q7", "Which are you?", icon("Insure everything", "shield.fill"), icon("Roll with it", "wind")),
				},
			},
			{
				ID: "money_everyday_money", Title: "Everyday Money", Icon: "creditcard.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("money_everyday_money_q1", "How do you pay?", icon("Tap to pay", "creditcard.fill"), icon("Good old cash", "banknote.fill")),
					choice("money_everyday_money_q2", "Grocery run?", photo("Big weekly shop", "groceries"), photo("Little trips as needed", "market")),
					choice("money_everyday_money_q3", "Lunch on a workday?", photo("Grab takeout", "takeout"), photo("Pack from home", "lunchbox")),
					choice("money_everyday_money_q4", "Which do you prefer?", icon("Rewards points", "star.fill"), icon("Cash back", "dollarsign.circle.fill")),
					choice("money_everyday_money_q5", "Weekend treat?", photo("Brunch out", "brunch"), photo("Cozy at home", "livingroom")),
					choice("money_everyday_money_q6", "Subscriptions are...", icon("Worth every penny", "checkmark.seal.fill"), icon("Something to cut", "wind")),
					choice("money_everyday_money_q7", "Tipping style?", icon("Always generous", "heart.fill"), icon("By the book", "list.bullet.clipboard.fill")),
				},
			},
		},
	},
	{
		ID: "get_to_know", Title: "Get to Know Each Other", Icon: "person.2.fill", ColorKey: "pink",
		Quizzes: []catalogQuiz{
			{
				ID: "get_to_know_deeper_cuts", Title: "Deeper Cuts", Icon: "brain.head.profile", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("get_to_know_deeper_cuts_q1", "What's something about you that I might not fully understand yet?"),
					open("get_to_know_deeper_cuts_q2", "When do you feel most like yourself around me?"),
					open("get_to_know_deeper_cuts_q3", "What's a part of your heart you've never shown anyone?"),
					open("get_to_know_deeper_cuts_q4", "What do you wish I would ask you more often?"),
					open("get_to_know_deeper_cuts_q5", "What does feeling truly loved look like to you?"),
					open("get_to_know_deeper_cuts_q6", "What's a truth about yourself you're still learning to accept?"),
					open("get_to_know_deeper_cuts_q7", "When have you felt the most seen by someone?"),
				},
			},
			{
				ID: "get_to_know_nutshell", Title: "You in a Nutshell", Icon: "person.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("get_to_know_nutshell_q1", "Which are you?", icon("Introvert", "person.fill"), icon("Extrovert", "person.3.fill")),
					choice("get_to_know_nutshell_q2", "Which are you?", icon("Optimist", "sun.max.fill"), icon("Realist", "checkmark.seal.fill")),
					choice("get_to_know_nutshell_q3", "Which are you?", icon("Planner", "calendar"), icon("Improviser", "dice.fill")),
					choice("get_to_know_nutshell_q4", "Which are you?", icon("Early bird", "sunrise.fill"), icon("Night owl", "moon.stars.fill")),
					choice("get_to_know_nutshell_q5", "Which are you?", icon("Head", "brain.head.profile"), icon("Heart", "heart.fill")),
					choice("get_to_know_nutshell_q6", "Which are you?", icon("Loud", "bolt.fill"), icon("Quiet", "moon.zzz.fill")),
					choice("get_to_know_nutshell_q7", "Which are you?", icon("Leader", "flag.fill"), icon("Supporter", "hands.clap.fill")),
				},
			},
			{
				ID: "get_to_know_childhood", Title: "Childhood", Icon: "book.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("get_to_know_childhood_q1", "What childhood memory shaped who you are today?"),
					open("get_to_know_childhood_q2", "Who did you look up to most as a kid, and why?"),
					open("get_to_know_childhood_q3", "What did your younger self dream of becoming?"),
					open("get_to_know_childhood_q4", "What's a smell or sound that instantly takes you back home?"),
					open("get_to_know_childhood_q5", "What's something from your childhood you wish you could relive with me?"),
					open("get_to_know_childhood_q6", "What did home feel like when you were growing up?"),
					open("get_to_know_childhood_q7", "What's a lesson from your childhood you still carry?"),
				},
			},
			{
				ID: "get_to_know_personality", Title: "Personality", Icon: "sparkles", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("get_to_know_personality_q1", "Which are you?", icon("Adventurous", "airplane"), icon("Cautious", "shield.fill")),
					choice("get_to_know_personality_q2", "Which are you?", icon("Spontaneous", "shuffle"), icon("Steady", "repeat")),
					choice("get_to_know_personality_q3", "Which are you?", icon("Dreamer", "cloud.fill"), icon("Doer", "figure.run")),
					choice("get_to_know_personality_q4", "Which are you?", icon("Talker", "message.fill"), icon("Listener", "headphones")),
					choice("get_to_know_personality_q5", "Which are you?", icon("Bold", "flame.fill"), icon("Gentle", "leaf.fill")),
					choice("get_to_know_personality_q6", "Which are you?", icon("Curious", "questionmark.circle.fill"), icon("Content", "heart.circle.fill")),
					choice("get_to_know_personality_q7", "Which are you?", icon("Fast", "bolt.fill"), icon("Slow", "hourglass")),
				},
			},
			{
				ID: "get_to_know_dreams_fears", Title: "Dreams & Fears", Icon: "moon.stars.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("get_to_know_dreams_fears_q1", "What's a dream you haven't given up on?"),
					open("get_to_know_dreams_fears_q2", "What's a fear you rarely talk about out loud?"),
					open("get_to_know_dreams_fears_q3", "Where do you hope we'll be five years from now?"),
					open("get_to_know_dreams_fears_q4", "What would you attempt if you knew you couldn't fail?"),
					open("get_to_know_dreams_fears_q5", "What worries you most about the future, and how can I help?"),
					open("get_to_know_dreams_fears_q6", "What's a dream you'd love for us to chase together?"),
					open("get_to_know_dreams_fears_q7", "What does a life well lived look like to you?"),
				},
			},
			{
				ID: "get_to_know_your_world", Title: "Your World", Icon: "map.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("get_to_know_your_world_q1", "Which do you prefer?", photo("Mountains", "mountains"), photo("Ocean", "ocean")),
					choice("get_to_know_your_world_q2", "Which do you prefer?", photo("City", "city"), photo("Countryside", "countryside")),
					choice("get_to_know_your_world_q3", "Which do you prefer?", photo("Coffee", "coffee"), photo("Tea", "tea")),
					choice("get_to_know_your_world_q4", "Which do you prefer?", photo("Sunrise", "sunrise"), photo("Sunset", "sunset")),
					choice("get_to_know_your_world_q5", "Which do you prefer?", photo("Books", "books"), photo("Movies", "cinema")),
					choice("get_to_know_your_world_q6", "Which do you prefer?", photo("Rain", "rain"), photo("Snow", "snow")),
					choice("get_to_know_your_world_q7", "Which do you prefer?", photo("Dogs", "dog"), photo("Cats", "cat")),
				},
			},
			{
				ID: "get_to_know_habits_quirks", Title: "Habits & Quirks", Icon: "shuffle", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("get_to_know_habits_quirks_q1", "Which are you?", icon("Neat", "checkmark.seal.fill"), icon("Messy", "wind")),
					choice("get_to_know_habits_quirks_q2", "Which are you?", icon("Always early", "clock.fill"), icon("Always late", "hourglass")),
					choice("get_to_know_habits_quirks_q3", "Which are you?", icon("Texter", "text.bubble.fill"), icon("Caller", "phone.fill")),
					choice("get_to_know_habits_quirks_q4", "Which are you?", icon("Saver", "lock.fill"), icon("Spender", "sparkles")),
					choice("get_to_know_habits_quirks_q5", "Which are you?", icon("Snooze", "moon.zzz.fill"), icon("Jump up", "sunrise.fill")),
					choice("get_to_know_habits_quirks_q6", "Which are you?", icon("Music on", "music.note"), icon("Silence", "moon.zzz.fill")),
					choice("get_to_know_habits_quirks_q7", "Which are you?", icon("List maker", "book.fill"), icon("Wing it", "dice.fill")),
				},
			},
			{
				ID: "get_to_know_what_shaped_you", Title: "What Shaped You", Icon: "flag.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("get_to_know_what_shaped_you_q1", "What's a moment that changed the direction of your life?"),
					open("get_to_know_what_shaped_you_q2", "Who taught you the most about love?"),
					open("get_to_know_what_shaped_you_q3", "What hardship made you stronger than you expected?"),
					open("get_to_know_what_shaped_you_q4", "What belief of yours has changed the most over the years?"),
					open("get_to_know_what_shaped_you_q5", "What are you most proud of surviving?"),
					open("get_to_know_what_shaped_you_q6", "What experience do you wish you could share with me firsthand?"),
					open("get_to_know_what_shaped_you_q7", "What's something you had to unlearn to grow?"),
				},
			},
			{
				ID: "get_to_know_comfort_zone", Title: "Comfort Zone", Icon: "house.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("get_to_know_comfort_zone_q1", "Which do you prefer?", icon("Night in", "house.fill"), icon("Night out", "sparkles")),
					choice("get_to_know_comfort_zone_q2", "Which do you prefer?", icon("Big party", "person.3.fill"), icon("Close friends", "person.2.fill")),
					choice("get_to_know_comfort_zone_q3", "Which do you prefer?", icon("Plan ahead", "calendar"), icon("Go with flow", "wind")),
					choice("get_to_know_comfort_zone_q4", "Which do you prefer?", icon("Familiar", "heart.circle.fill"), icon("New adventure", "airplane")),
					choice("get_to_know_comfort_zone_q5", "Which do you prefer?", icon("Cozy blanket", "bed.double.fill"), icon("Long walk", "figure.walk")),
					choice("get_to_know_comfort_zone_q6", "Which do you prefer?", icon("Deep talk", "bubble.left.and.bubble.right.fill"), icon("Easy silence", "moon.zzz.fill")),
					choice("get_to_know_comfort_zone_q7", "Which do you prefer?", icon("Quiet book", "book.fill"), icon("Loud game", "gamecontroller.fill")),
				},
			},
			{
				ID: "get_to_know_little_things", Title: "Little Things", Icon: "heart.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("get_to_know_little_things_q1", "What's a small thing I do that makes your whole day better?"),
					open("get_to_know_little_things_q2", "What tiny ritual would you love us to start together?"),
					open("get_to_know_little_things_q3", "What's the little luxury that always feels worth it to you?"),
					open("get_to_know_little_things_q4", "What small gesture makes you feel instantly cared for?"),
					open("get_to_know_little_things_q5", "What everyday moment with me do you secretly treasure?"),
					open("get_to_know_little_things_q6", "What's a simple pleasure you could never give up?"),
					open("get_to_know_little_things_q7", "What tiny detail about me do you hope I never change?"),
				},
			},
		},
	},
	{
		ID: "travel", Title: "Travel", Icon: "airplane", ColorKey: "blue",
		Quizzes: []catalogQuiz{
			{
				ID: "travel_style", Title: "Travel Style", Icon: "map.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("travel_style_q1", "Which describes you more?", icon("Plan every day", "list.bullet.clipboard.fill"), icon("Go with the flow", "wind")),
					choice("travel_style_q2", "Which describes you more?", icon("Carry-on only", "bag.fill"), icon("Pack it all", "briefcase.fill")),
					choice("travel_style_q3", "Which describes you more?", icon("Early riser", "sunrise.fill"), icon("Sleep in", "moon.stars.fill")),
					choice("travel_style_q4", "Which describes you more?", icon("Guided tour", "person.3.fill"), icon("Wander solo", "figure.walk")),
					choice("travel_style_q5", "Which describes you more?", icon("Budget trip", "bag.fill"), icon("Splurge stay", "star.fill")),
					choice("travel_style_q6", "Which describes you more?", icon("Same spot yearly", "repeat"), icon("Somewhere new", "shuffle")),
				},
			},
			{
				ID: "travel_wanderlust", Title: "Wanderlust", Icon: "sparkles", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("travel_wanderlust_q1", "Which calls to you?", photo("Beach", "beach"), photo("Mountains", "mountains")),
					choice("travel_wanderlust_q2", "Which calls to you?", photo("Desert", "desert"), photo("Jungle", "jungle")),
					choice("travel_wanderlust_q3", "Which calls to you?", photo("Iceland", "iceland"), photo("Bali", "bali")),
					choice("travel_wanderlust_q4", "Which calls to you?", photo("Northern lights", "northern,lights"), photo("Tropical sunset", "tropical,sunset")),
					choice("travel_wanderlust_q5", "Which calls to you?", photo("Ocean", "ocean"), photo("Forest", "forest")),
					choice("travel_wanderlust_q6", "Which calls to you?", photo("Waterfall", "waterfall"), photo("Volcano", "volcano")),
					choice("travel_wanderlust_q7", "Which calls to you?", photo("Snowy peaks", "snowy,peaks"), photo("Sunny coast", "sunny,coast")),
				},
			},
			{
				ID: "travel_bucket_list", Title: "Bucket List", Icon: "star.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("travel_bucket_list_q1", "What's the one place you dream of visiting together?"),
					open("travel_bucket_list_q2", "What's a bucket-list adventure you want us to check off?"),
					open("travel_bucket_list_q3", "If we had a year to travel the world, where would we start?"),
					open("travel_bucket_list_q4", "What's a country you've always been curious about and why?"),
					open("travel_bucket_list_q5", "What's an experience you want to have before we settle down?"),
					open("travel_bucket_list_q6", "Which wonder of the world do you most want to see with me?"),
				},
			},
			{
				ID: "travel_pick_destination", Title: "Pick a Destination", Icon: "mappin.and.ellipse", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("travel_pick_destination_q1", "Where to next?", photo("Paris", "paris"), photo("Tokyo", "tokyo")),
					choice("travel_pick_destination_q2", "Where to next?", photo("Rome", "rome"), photo("Barcelona", "barcelona")),
					choice("travel_pick_destination_q3", "Where to next?", photo("New York", "new,york"), photo("London", "london")),
					choice("travel_pick_destination_q4", "Where to next?", photo("Venice", "venice"), photo("Santorini", "santorini")),
					choice("travel_pick_destination_q5", "Where to next?", photo("Marrakech", "marrakech"), photo("Cairo", "cairo")),
					choice("travel_pick_destination_q6", "Where to next?", photo("Sydney", "sydney"), photo("Rio", "rio")),
					choice("travel_pick_destination_q7", "Where to next?", photo("Bangkok", "bangkok"), photo("Istanbul", "istanbul")),
				},
			},
			{
				ID: "travel_on_the_road", Title: "On the Road", Icon: "car.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("travel_on_the_road_q1", "Which do you choose?", icon("Road trip", "car.fill"), icon("Flight abroad", "airplane")),
					choice("travel_on_the_road_q2", "Which do you choose?", icon("Train ride", "tram.fill"), icon("Rental car", "car.fill")),
					choice("travel_on_the_road_q3", "Which do you choose?", icon("Window seat", "sun.max.fill"), icon("Aisle seat", "arrow.left.arrow.right")),
					choice("travel_on_the_road_q4", "Which do you choose?", icon("Playlist ready", "sparkles"), icon("Podcast queued", "book.fill")),
					choice("travel_on_the_road_q5", "Which do you choose?", icon("Bike everywhere", "bicycle"), icon("Walk everywhere", "figure.walk")),
					choice("travel_on_the_road_q6", "Which do you choose?", icon("Scenic route", "leaf.fill"), icon("Fastest route", "bolt.fill")),
				},
			},
			{
				ID: "travel_city_nature", Title: "City vs Nature", Icon: "building.2.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("travel_city_nature_q1", "Which is your happy place?", photo("City skyline", "city,skyline"), photo("Countryside", "countryside")),
					choice("travel_city_nature_q2", "Which is your happy place?", photo("Busy market", "market"), photo("Quiet lake", "lake")),
					choice("travel_city_nature_q3", "Which is your happy place?", photo("Rooftop bar", "rooftop"), photo("Mountain cabin", "cabin")),
					choice("travel_city_nature_q4", "Which is your happy place?", photo("Museum", "museum"), photo("National park", "national,park")),
					choice("travel_city_nature_q5", "Which is your happy place?", photo("Neon nightlife", "nightlife"), photo("Starry campsite", "campsite")),
					choice("travel_city_nature_q6", "Which is your happy place?", photo("Subway rush", "subway"), photo("Hiking trail", "hiking,trail")),
				},
			},
			{
				ID: "travel_adventure_level", Title: "Adventure Level", Icon: "flame.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("travel_adventure_level_q1", "How bold are you?", icon("Skydive", "bird.fill"), icon("Feet on ground", "hand.raised.fill")),
					choice("travel_adventure_level_q2", "How bold are you?", icon("Try anything", "target"), icon("Play it safe", "shield.fill")),
					choice("travel_adventure_level_q3", "How bold are you?", icon("Camp wild", "leaf.fill"), icon("Cozy hotel", "house.fill")),
					choice("travel_adventure_level_q4", "How bold are you?", icon("Street eats", "fork.knife"), icon("Familiar food", "cup.and.saucer.fill")),
					choice("travel_adventure_level_q5", "How bold are you?", icon("Off the map", "map.fill"), icon("Tourist trail", "mappin.and.ellipse")),
					choice("travel_adventure_level_q6", "How bold are you?", icon("Dawn hike", "sunrise.fill"), icon("Late brunch", "clock.fill")),
				},
			},
			{
				ID: "travel_dream_trips", Title: "Dream Trips", Icon: "moon.stars.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("travel_dream_trips_q1", "Which dream trip wins?", photo("African safari", "safari"), photo("Amazon jungle", "amazon")),
					choice("travel_dream_trips_q2", "Which dream trip wins?", photo("Greek islands", "greek,islands"), photo("Maldives", "maldives")),
					choice("travel_dream_trips_q3", "Which dream trip wins?", photo("Machu Picchu", "machu,picchu"), photo("Great Wall", "great,wall")),
					choice("travel_dream_trips_q4", "Which dream trip wins?", photo("Norway fjords", "fjords"), photo("Swiss Alps", "swiss,alps")),
					choice("travel_dream_trips_q5", "Which dream trip wins?", photo("Kyoto temples", "kyoto"), photo("Petra", "petra")),
					choice("travel_dream_trips_q6", "Which dream trip wins?", photo("Antarctica", "antarctica"), photo("Sahara", "sahara")),
					choice("travel_dream_trips_q7", "Which dream trip wins?", photo("Patagonia", "patagonia"), photo("New Zealand", "new,zealand")),
				},
			},
			{
				ID: "travel_habits", Title: "Travel Habits", Icon: "calendar", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("travel_habits_q1", "What's the one thing you always pack that you can't travel without?"),
					open("travel_habits_q2", "Are you the planner or the free spirit when we travel, and why?"),
					open("travel_habits_q3", "What's your favorite ritual on the first day of a trip?"),
					open("travel_habits_q4", "How do you like to spend a lazy morning on vacation?"),
					open("travel_habits_q5", "What souvenir or keepsake do you always want to bring home?"),
					open("travel_habits_q6", "What makes a trip feel truly relaxing for you?"),
				},
			},
			{
				ID: "travel_around_the_world", Title: "Around the World", Icon: "globe.americas.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("travel_around_the_world_q1", "What's the most beautiful place you've ever seen together?"),
					open("travel_around_the_world_q2", "What's a travel memory with me you'll never forget?"),
					open("travel_around_the_world_q3", "If we could live abroad for a year, where would we go?"),
					open("travel_around_the_world_q4", "What culture or tradition do you most want to experience?"),
					open("travel_around_the_world_q5", "Where would you want us to retire if we could live anywhere?"),
					open("travel_around_the_world_q6", "What's a place from your childhood you want to show me one day?"),
				},
			},
		},
	},
	{
		ID: "family", Title: "Family", Icon: "house.fill", ColorKey: "amber",
		Quizzes: []catalogQuiz{
			{
				ID: "family_future", Title: "Our Future Family", Icon: "house.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("family_future_q1", "How do you picture our home ten years from now?"),
					open("family_future_q2", "What kind of family life do you dream of building together?"),
					open("family_future_q3", "What does a perfect family Sunday look like to you?"),
					open("family_future_q4", "What does the word 'family' mean to you?"),
					open("family_future_q5", "What do you most look forward to about our future together?"),
					open("family_future_q6", "How do you hope our family will feel to the people in it?"),
				},
			},
			{
				ID: "family_kids", Title: "Kids?", Icon: "person.3.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("family_kids_q1", "Which sounds more like you?", icon("Want kids", "heart.fill"), icon("Happy without", "leaf.fill")),
					choice("family_kids_q2", "Which do you lean toward?", icon("Big family", "person.3.fill"), icon("Small family", "person.2.fill")),
					choice("family_kids_q3", "When feels right to start?", icon("Sooner", "bolt.fill"), icon("Later", "hourglass")),
					choice("family_kids_q4", "Which path speaks to you?", icon("Adopt", "hands.clap.fill"), icon("Biological", "heart.fill")),
					choice("family_kids_q5", "Which do you prefer?", icon("Only child", "person.fill"), icon("Siblings", "person.2.fill")),
					choice("family_kids_q6", "How would you raise them?", icon("Near family", "house.fill"), icon("Our own way", "figure.walk")),
				},
			},
			{
				ID: "family_traditions", Title: "Traditions", Icon: "gift.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("family_traditions_q1", "What tradition from your childhood do you want to keep alive?"),
					open("family_traditions_q2", "What new tradition would you love to start with me?"),
					open("family_traditions_q3", "Which family ritual always makes you feel at home?"),
					open("family_traditions_q4", "What tradition do you hope our kids remember one day?"),
					open("family_traditions_q5", "How did your family mark special occasions growing up?"),
					open("family_traditions_q6", "What small everyday habit would you want us to make ours?"),
				},
			},
			{
				ID: "family_roles", Title: "Home & Roles", Icon: "list.bullet.clipboard.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("family_roles_q1", "Who tends to plan things?", icon("The planner", "calendar"), icon("The go-with-flow", "wind")),
					choice("family_roles_q2", "In our home you'd rather?", icon("Cook", "fork.knife"), icon("Clean up", "sparkles")),
					choice("family_roles_q3", "Who handles the budget?", icon("Me", "person.fill"), icon("You", "person.2.fill")),
					choice("family_roles_q4", "Chores should be?", icon("Split evenly", "arrow.left.arrow.right"), icon("By strength", "target")),
					choice("family_roles_q5", "Decisions are best?", icon("Together", "person.2.fill"), icon("Whoever cares most", "heart.circle.fill")),
					choice("family_roles_q6", "Your home vibe?", icon("Tidy", "checkmark.seal.fill"), icon("Lived-in", "leaf.fill")),
				},
			},
			{
				ID: "family_holidays", Title: "Holidays", Icon: "snowflake", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("family_holidays_q1", "Where would you spend the holidays?", photo("At home", "home"), photo("Away", "beach")),
					choice("family_holidays_q2", "Which do you prefer?", photo("Christmas", "christmas"), icon("New Year", "sparkles")),
					choice("family_holidays_q3", "Holiday feeling?", icon("Cozy and quiet", "moon.stars.fill"), icon("Big and lively", "flame.fill")),
					choice("family_holidays_q4", "Whose family first?", icon("Mine", "person.fill"), icon("Yours", "person.2.fill")),
					choice("family_holidays_q5", "The best part is?", icon("The food", "fork.knife"), icon("The company", "person.3.fill")),
					choice("family_holidays_q6", "Gifts should be?", icon("Thoughtful", "gift.fill"), icon("Surprising", "sparkle")),
				},
			},
			{
				ID: "family_parenting", Title: "Parenting Style", Icon: "heart.circle.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("family_parenting_q1", "Your parenting leans?", icon("Structured", "list.bullet.clipboard.fill"), icon("Easygoing", "wind")),
					choice("family_parenting_q2", "Discipline is?", icon("Firm", "shield.fill"), icon("Gentle", "leaf.fill")),
					choice("family_parenting_q3", "You'd rather be?", icon("The fun one", "gamecontroller.fill"), icon("The steady one", "hand.raised.fill")),
					choice("family_parenting_q4", "Screen time is?", icon("Limited", "clock.fill"), icon("Relaxed", "tv.fill")),
					choice("family_parenting_q5", "When they fall?", icon("Let them try", "figure.walk"), icon("Step in", "hands.clap.fill")),
					choice("family_parenting_q6", "Bedtime is?", icon("On schedule", "moon.stars.fill"), icon("Flexible", "shuffle")),
				},
			},
			{
				ID: "family_values", Title: "Family Values", Icon: "heart.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("family_values_q1", "What value matters most to you in a family?"),
					open("family_values_q2", "What lesson from your parents do you want to pass on?"),
					open("family_values_q3", "How should a family handle disagreements?"),
					open("family_values_q4", "What do you hope our children learn from watching us?"),
					open("family_values_q5", "What does unconditional love look like to you?"),
					open("family_values_q6", "How do you want our home to feel when someone walks in?"),
				},
			},
			{
				ID: "family_growingup", Title: "Growing Up", Icon: "book.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("family_growingup_q1", "What is your happiest memory from childhood?"),
					open("family_growingup_q2", "Who shaped you most while you were growing up?"),
					open("family_growingup_q3", "What was your family like around the dinner table?"),
					open("family_growingup_q4", "What did home smell or sound like when you were young?"),
					open("family_growingup_q5", "What is something you want to do differently than your parents?"),
					open("family_growingup_q6", "What childhood tradition do you miss the most?"),
				},
			},
			{
				ID: "family_home", Title: "Our Home", Icon: "building.2.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("family_home_q1", "Where would you rather live?", photo("City", "city"), photo("Countryside", "countryside")),
					choice("family_home_q2", "Your dream home is?", photo("House", "house"), icon("Apartment", "building.2.fill")),
					choice("family_home_q3", "Which do you want?", photo("Garden", "garden"), icon("Balcony view", "sun.max.fill")),
					choice("family_home_q4", "A home needs?", icon("Pets", "pawprint.fill"), icon("Plants", "leaf.fill")),
					choice("family_home_q5", "Which feels like home?", photo("By the beach", "beach"), photo("In the mountains", "mountains")),
					choice("family_home_q6", "Your ideal space is?", icon("Cozy", "flame.fill"), icon("Spacious", "wind")),
				},
			},
			{
				ID: "family_celebrations", Title: "Celebrations", Icon: "sparkles", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("family_celebrations_q1", "Birthdays should be?", icon("Big party", "flame.fill"), icon("Just us", "heart.fill")),
					choice("family_celebrations_q2", "You'd rather?", icon("Throw the party", "sparkles"), icon("Be a guest", "person.fill")),
					choice("family_celebrations_q3", "Anniversaries are?", icon("A must", "calendar"), icon("Low-key", "wind")),
					choice("family_celebrations_q4", "Celebration style?", icon("Plan ahead", "list.bullet.clipboard.fill"), icon("Spontaneous", "shuffle")),
					choice("family_celebrations_q5", "The perfect toast is?", icon("Heartfelt", "heart.circle.fill"), icon("Funny", "music.note")),
					choice("family_celebrations_q6", "Best celebration?", photo("Dinner out", "restaurant"), photo("Home party", "home")),
				},
			},
		},
	},
	{
		ID: "hobbies", Title: "Hobbies", Icon: "paintpalette.fill", ColorKey: "purple",
		Quizzes: []catalogQuiz{
			{
				ID: "hobbies_try", Title: "Things to Try Together", Icon: "target", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("hobbies_try_q1", "Which sounds better?", photo("Cooking class", "cooking"), photo("Pottery", "pottery")),
					choice("hobbies_try_q2", "Which sounds better?", photo("Hiking", "hiking"), photo("Kayaking", "kayaking")),
					choice("hobbies_try_q3", "Which sounds better?", photo("Painting", "painting"), photo("Photography", "photography")),
					choice("hobbies_try_q4", "Which sounds better?", photo("Rock climbing", "climbing"), photo("Surfing", "surfing")),
					choice("hobbies_try_q5", "Which sounds better?", photo("Dance class", "dancing"), photo("Yoga", "yoga")),
					choice("hobbies_try_q6", "Which sounds better?", photo("Gardening", "gardening"), photo("Baking", "baking")),
				},
			},
			{
				ID: "hobbies_downtime", Title: "Downtime", Icon: "bed.double.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("hobbies_downtime_q1", "Pick your unwind style", photo("Reading a book", "reading"), photo("Video games", "gaming")),
					choice("hobbies_downtime_q2", "Which is more you?", photo("Movie night", "movie"), photo("Podcast walk", "walking")),
					choice("hobbies_downtime_q3", "How do you relax?", photo("Long bath", "bath"), photo("Afternoon nap", "napping")),
					choice("hobbies_downtime_q4", "Pick your evening", photo("Puzzle time", "puzzle"), photo("Knitting", "knitting")),
					choice("hobbies_downtime_q5", "Which sounds cozier?", photo("Coloring book", "coloring"), photo("Journaling", "journaling")),
					choice("hobbies_downtime_q6", "Choose your chill", icon("Do nothing", "moon.stars.fill"), icon("Tinker with a project", "bolt.fill")),
				},
			},
			{
				ID: "hobbies_interests", Title: "My Interests", Icon: "star.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("hobbies_interests_q1", "What hobby could you talk about for hours?"),
					open("hobbies_interests_q2", "What's something you'd love to get better at?"),
					open("hobbies_interests_q3", "What activity makes you lose track of time?"),
					open("hobbies_interests_q4", "What's a hobby you've always wanted to try?"),
					open("hobbies_interests_q5", "What did you love doing as a kid that you miss?"),
					open("hobbies_interests_q6", "What hobby would you love for us to share?"),
				},
			},
			{
				ID: "hobbies_weekend", Title: "Weekend Vibes", Icon: "sun.max.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("hobbies_weekend_q1", "Ideal Saturday?", photo("Farmers market", "market"), photo("Sleeping in", "sleeping")),
					choice("hobbies_weekend_q2", "Which weekend wins?", photo("Road trip", "roadtrip"), photo("Beach day", "beach")),
					choice("hobbies_weekend_q3", "Pick your Sunday", photo("Brunch out", "brunch"), photo("Cooking at home", "cooking")),
					choice("hobbies_weekend_q4", "Better afternoon?", photo("Bike ride", "cycling"), photo("Museum visit", "museum")),
					choice("hobbies_weekend_q5", "Which sounds better?", photo("Picnic in the park", "picnic"), photo("Movie marathon", "movie")),
					choice("hobbies_weekend_q6", "Choose your outing", photo("Flea market", "fleamarket"), photo("Botanical garden", "garden")),
				},
			},
			{
				ID: "hobbies_creative_active", Title: "Creative or Active", Icon: "paintbrush.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("hobbies_creative_active_q1", "Which are you?", icon("Creative", "paintpalette.fill"), icon("Active", "figure.run")),
					choice("hobbies_creative_active_q2", "Pick your energy", photo("Sketching", "sketching"), photo("Running", "running")),
					choice("hobbies_creative_active_q3", "Which calls to you?", photo("Playing guitar", "guitar"), photo("Boxing", "boxing")),
					choice("hobbies_creative_active_q4", "Choose one", photo("Writing", "writing"), photo("Swimming", "swimming")),
					choice("hobbies_creative_active_q5", "Which feels right?", photo("Crafting", "crafting"), photo("Dancing", "dancing")),
					choice("hobbies_creative_active_q6", "Pick your flow", icon("Make something", "paintbrush.fill"), icon("Move your body", "figure.walk")),
				},
			},
			{
				ID: "hobbies_indoor_outdoor", Title: "Indoor vs Outdoor", Icon: "leaf.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("hobbies_indoor_outdoor_q1", "Where's your happy place?", icon("Indoors", "house.fill"), icon("Outdoors", "leaf.fill")),
					choice("hobbies_indoor_outdoor_q2", "Pick your scene", photo("Camping", "camping"), photo("Board games", "boardgame")),
					choice("hobbies_indoor_outdoor_q3", "Which sounds better?", photo("Fishing", "fishing"), photo("Baking bread", "baking")),
					choice("hobbies_indoor_outdoor_q4", "Choose your day", photo("Trail walk", "hiking"), photo("Home spa", "spa")),
					choice("hobbies_indoor_outdoor_q5", "Which fits you?", photo("Stargazing", "stargazing"), photo("Movie night", "movie")),
					choice("hobbies_indoor_outdoor_q6", "Pick a vibe", photo("Gardening", "gardening"), photo("Video games", "gaming")),
				},
			},
			{
				ID: "hobbies_passions", Title: "Passions", Icon: "flame.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("hobbies_passions_q1", "What's a passion you wish more people knew about you?"),
					open("hobbies_passions_q2", "What could you happily spend a whole day doing?"),
					open("hobbies_passions_q3", "What's something you're proud you got good at?"),
					open("hobbies_passions_q4", "If money were no object, how would you spend your time?"),
					open("hobbies_passions_q5", "What hobby lights you up the most right now?"),
					open("hobbies_passions_q6", "What's a dream project you'd love to start?"),
				},
			},
			{
				ID: "hobbies_games", Title: "Fun & Games", Icon: "gamecontroller.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("hobbies_games_q1", "Game night pick?", photo("Board games", "boardgame"), photo("Video games", "gaming")),
					choice("hobbies_games_q2", "Which is more fun?", photo("Card games", "cards"), photo("Trivia night", "trivia")),
					choice("hobbies_games_q3", "Pick your challenge", photo("Chess", "chess"), photo("Darts", "darts")),
					choice("hobbies_games_q4", "Which do you choose?", photo("Bowling", "bowling"), photo("Mini golf", "minigolf")),
					choice("hobbies_games_q5", "Better night out?", photo("Arcade", "arcade"), photo("Escape room", "escaperoom")),
					choice("hobbies_games_q6", "Pick a pastime", photo("Jigsaw puzzle", "puzzle"), photo("Pool table", "billiards")),
				},
			},
			{
				ID: "hobbies_learn", Title: "Learn Something New", Icon: "book.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("hobbies_learn_q1", "What skill have you always wanted to learn?"),
					open("hobbies_learn_q2", "What's a class you'd sign up for tomorrow?"),
					open("hobbies_learn_q3", "What language or instrument tempts you most?"),
					open("hobbies_learn_q4", "What's something new you'd love us to learn together?"),
					open("hobbies_learn_q5", "What's a skill you admire in other people?"),
					open("hobbies_learn_q6", "If you had a free tutor for a month, what would you study?"),
				},
			},
			{
				ID: "hobbies_chill", Title: "Chill Time", Icon: "moon.stars.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("hobbies_chill_q1", "Coziest evening?", photo("Reading nook", "reading"), photo("Music and tea", "tea")),
					choice("hobbies_chill_q2", "Which relaxes you?", photo("Yoga", "yoga"), photo("Meditation", "meditation")),
					choice("hobbies_chill_q3", "Pick your calm", photo("Nature walk", "walking"), photo("Bubble bath", "bath")),
					choice("hobbies_chill_q4", "Which sounds nicer?", photo("Sketching quietly", "sketching"), photo("Listening to vinyl", "vinyl")),
					choice("hobbies_chill_q5", "Choose your wind-down", photo("Journaling", "journaling"), photo("Watching the sunset", "sunset")),
					choice("hobbies_chill_q6", "Pick a lazy hobby", photo("Bird watching", "birdwatching"), photo("Cloud gazing", "clouds")),
				},
			},
		},
	},
	{
		ID: "school_work", Title: "School & Work", Icon: "briefcase.fill", ColorKey: "blue",
		Quizzes: []catalogQuiz{
			{
				ID: "school_work_ambitions", Title: "Ambitions", Icon: "flame.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("school_work_ambitions_q1", "Where do you dream of being in five years?"),
					open("school_work_ambitions_q2", "Would you ever leave a steady job to chase something bigger?"),
					open("school_work_ambitions_q3", "What kind of work makes you feel truly alive?"),
					open("school_work_ambitions_q4", "What's an ambition of mine you'd love to help me reach?"),
					open("school_work_ambitions_q5", "What did you want to be when you were a kid?"),
					open("school_work_ambitions_q6", "If money were no object, what would you spend your days doing?"),
				},
			},
			{
				ID: "school_work_work_style", Title: "Work Style", Icon: "gearshape.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("school_work_work_style_q1", "Which are you?", icon("Planner", "calendar"), icon("Improviser", "shuffle")),
					choice("school_work_work_style_q2", "Which are you?", icon("Early bird", "sunrise.fill"), icon("Night grinder", "moon.stars.fill")),
					choice("school_work_work_style_q3", "Which are you?", icon("Team player", "person.3.fill"), icon("Solo focus", "person.fill")),
					choice("school_work_work_style_q4", "Which are you?", icon("Big picture", "sparkles"), icon("Fine details", "checkmark.seal.fill")),
					choice("school_work_work_style_q5", "Which are you?", icon("Deadline sprinter", "hourglass"), icon("Steady pacer", "clock.fill")),
					choice("school_work_work_style_q6", "Which are you?", icon("Lead the room", "crown.fill"), icon("Support the team", "hand.raised.fill")),
				},
			},
			{
				ID: "school_work_balance", Title: "Work-Life Balance", Icon: "leaf.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("school_work_balance_q1", "Which do you prefer?", icon("Passion project", "heart.fill"), icon("Bigger paycheck", "dollarsign.circle.fill")),
					choice("school_work_balance_q2", "Which do you prefer?", icon("More free time", "hourglass"), icon("Faster promotion", "chart.line.uptrend.xyaxis")),
					choice("school_work_balance_q3", "Which do you prefer?", icon("Work to live", "leaf.fill"), icon("Live to work", "flame.fill")),
					choice("school_work_balance_q4", "Which do you prefer?", icon("Quiet weekends", "moon.stars.fill"), icon("Side hustle", "bolt.fill")),
					choice("school_work_balance_q5", "Which do you prefer?", icon("Unplug fully", "wind"), icon("Always on", "message.fill")),
					choice("school_work_balance_q6", "Which do you prefer?", icon("Long vacation", "airplane"), icon("Short getaways", "map.fill")),
				},
			},
			{
				ID: "school_work_school_days", Title: "School Days", Icon: "graduationcap.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("school_work_school_days_q1", "What kind of student were you back in school?"),
					open("school_work_school_days_q2", "Who was the teacher who changed how you see the world?"),
					open("school_work_school_days_q3", "What's a school memory that still makes you laugh?"),
					open("school_work_school_days_q4", "Were you more the class clown or the quiet achiever?"),
					open("school_work_school_days_q5", "What subject did you secretly love the most?"),
					open("school_work_school_days_q6", "What's something school never taught you that you wish it had?"),
				},
			},
			{
				ID: "school_work_dream_job", Title: "Dream Job", Icon: "star.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("school_work_dream_job_q1", "Which sounds more you?", icon("Creative studio", "sparkles"), icon("Corner office", "building.2.fill")),
					choice("school_work_dream_job_q2", "Which sounds more you?", icon("Travel the world", "airplane"), icon("Rooted at home", "house.fill")),
					choice("school_work_dream_job_q3", "Which sounds more you?", icon("Be your own boss", "crown.fill"), icon("Great team behind you", "person.3.fill")),
					choice("school_work_dream_job_q4", "Which sounds more you?", icon("Fame and spotlight", "star.fill"), icon("Quiet impact", "leaf.fill")),
					choice("school_work_dream_job_q5", "Which sounds more you?", icon("Build something new", "bolt.fill"), icon("Perfect something old", "checkmark.seal.fill")),
					choice("school_work_dream_job_q6", "Which sounds more you?", icon("Hands-on craft", "hand.raised.fill"), icon("Big ideas", "brain.head.profile")),
				},
			},
			{
				ID: "school_work_success", Title: "Success & Goals", Icon: "target", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("school_work_success_q1", "What does a successful life actually look like to you?"),
					open("school_work_success_q2", "What's one goal we could chase together as a team?"),
					open("school_work_success_q3", "How do you handle it when a plan falls apart?"),
					open("school_work_success_q4", "What's an achievement you're quietly proud of?"),
					open("school_work_success_q5", "Would you rather be respected or admired?"),
					open("school_work_success_q6", "What's a goal you gave up on that you'd love to revisit?"),
				},
			},
			{
				ID: "school_work_office_or_home", Title: "Office or Home", Icon: "house.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("school_work_office_or_home_q1", "Where would you rather work?", photo("At the office", "office"), photo("From home", "home")),
					choice("school_work_office_or_home_q2", "Where would you rather work?", photo("Cozy library", "library"), photo("Buzzing cafe", "cafe")),
					choice("school_work_office_or_home_q3", "Which desk is yours?", photo("Laptop anywhere", "laptop"), photo("Fixed workspace", "desk")),
					choice("school_work_office_or_home_q4", "Where do ideas flow?", photo("Downtown city", "city"), photo("Quiet countryside", "countryside")),
					choice("school_work_office_or_home_q5", "Which do you prefer?", icon("Commute and go", "map.fill"), icon("Roll out of bed", "house.fill")),
					choice("school_work_office_or_home_q6", "Which do you prefer?", icon("Open office buzz", "person.3.fill"), icon("Quiet corner", "person.fill")),
				},
			},
			{
				ID: "school_work_learning", Title: "Learning", Icon: "book.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("school_work_learning_q1", "What's a skill you wish you had time to learn?"),
					open("school_work_learning_q2", "Would you rather teach me something or learn something from me?"),
					open("school_work_learning_q3", "What's the best lesson life taught you the hard way?"),
					open("school_work_learning_q4", "What could we learn together that would be fun?"),
					open("school_work_learning_q5", "Are you a read-the-manual or figure-it-out kind of person?"),
					open("school_work_learning_q6", "What's a book or idea that genuinely changed you?"),
				},
			},
			{
				ID: "school_work_career_choices", Title: "Career Choices", Icon: "flag.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("school_work_career_choices_q1", "Which would you pick?", icon("Stable and safe", "shield.fill"), icon("Risky and exciting", "flame.fill")),
					choice("school_work_career_choices_q2", "Which would you pick?", icon("One deep career", "target"), icon("Many different paths", "shuffle")),
					choice("school_work_career_choices_q3", "Which would you pick?", icon("Climb the ladder", "chart.line.uptrend.xyaxis"), icon("Blaze your own trail", "bird.fill")),
					choice("school_work_career_choices_q4", "Which would you pick?", icon("Change the world", "sparkles"), icon("Change one life", "heart.fill")),
					choice("school_work_career_choices_q5", "Which would you pick?", icon("Follow the money", "dollarsign.circle.fill"), icon("Follow your heart", "heart.fill")),
					choice("school_work_career_choices_q6", "Which would you pick?", icon("Same job for life", "lock.fill"), icon("Reinvent often", "repeat")),
				},
			},
			{
				ID: "school_work_daily_grind", Title: "Daily Grind", Icon: "clock.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("school_work_daily_grind_q1", "Which do you prefer?", icon("Early start", "sunrise.fill"), icon("Late finish", "moon.stars.fill")),
					choice("school_work_daily_grind_q2", "Which do you prefer?", icon("To-do list", "list.bullet.clipboard.fill"), icon("Go with the flow", "wind")),
					choice("school_work_daily_grind_q3", "Which do you prefer?", icon("Coffee fuel", "flame.fill"), icon("Calm and steady", "leaf.fill")),
					choice("school_work_daily_grind_q4", "Which do you prefer?", icon("One big task", "target"), icon("Many small wins", "checkmark.seal.fill")),
					choice("school_work_daily_grind_q5", "Which do you prefer?", icon("Music on", "music.note"), icon("Total silence", "wind")),
					choice("school_work_daily_grind_q6", "Which do you prefer?", icon("Power through", "bolt.fill"), icon("Frequent breaks", "hourglass")),
				},
			},
		},
	},
	{
		ID: "lifestyle", Title: "Lifestyle", Icon: "leaf.fill", ColorKey: "green",
		Quizzes: []catalogQuiz{
			{
				ID: "lifestyle_daily_rhythm", Title: "Daily Rhythm", Icon: "sun.max.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("lifestyle_daily_rhythm_q1", "Which are you?", icon("Early riser", "sunrise.fill"), icon("Night owl", "moon.stars.fill")),
					choice("lifestyle_daily_rhythm_q2", "Which are you?", icon("Plan the day", "calendar"), icon("Go with the flow", "wind")),
					choice("lifestyle_daily_rhythm_q3", "Which do you prefer?", photo("Morning coffee", "coffee"), photo("Evening tea", "tea")),
					choice("lifestyle_daily_rhythm_q4", "Which are you?", icon("Fast mornings", "bolt.fill"), icon("Slow mornings", "hourglass")),
					choice("lifestyle_daily_rhythm_q5", "Which do you prefer?", photo("Quiet breakfast", "breakfast"), photo("Busy kitchen", "kitchen")),
					choice("lifestyle_daily_rhythm_q6", "Which are you?", icon("One big task", "target"), icon("Many small tasks", "shuffle")),
				},
			},
			{
				ID: "lifestyle_health_habits", Title: "Health & Habits", Icon: "figure.run", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("lifestyle_health_habits_q1", "Which do you prefer?", photo("Gym session", "gym"), photo("Morning yoga", "yoga")),
					choice("lifestyle_health_habits_q2", "Which do you prefer?", photo("Long run", "running"), photo("Long walk", "walking")),
					choice("lifestyle_health_habits_q3", "Which do you prefer?", photo("Home cooking", "cooking"), photo("Eating out", "restaurant")),
					choice("lifestyle_health_habits_q4", "Which do you prefer?", photo("Bike ride", "cycling"), photo("Swim laps", "swimming")),
					choice("lifestyle_health_habits_q5", "Which do you prefer?", photo("Green smoothie", "smoothie"), photo("Fresh salad", "salad")),
					choice("lifestyle_health_habits_q6", "Which do you prefer?", photo("Early workout", "workout"), photo("Evening stretch", "stretching")),
				},
			},
			{
				ID: "lifestyle_home_life", Title: "Home Life", Icon: "house.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("lifestyle_home_life_q1", "Which do you prefer?", photo("Cozy apartment", "apartment"), photo("Big house", "house")),
					choice("lifestyle_home_life_q2", "Which do you prefer?", photo("Home garden", "garden"), photo("Balcony plants", "balcony")),
					choice("lifestyle_home_life_q3", "Which do you prefer?", photo("Living room movie", "livingroom"), photo("Kitchen table talk", "kitchen")),
					choice("lifestyle_home_life_q4", "Which do you prefer?", photo("Warm fireplace", "fireplace"), photo("Sunny window", "window")),
					choice("lifestyle_home_life_q5", "Which do you prefer?", photo("Bookshelf corner", "bookshelf"), photo("Comfy couch", "couch")),
					choice("lifestyle_home_life_q6", "Which do you prefer?", photo("Backyard evening", "backyard"), photo("Rooftop view", "rooftop")),
				},
			},
			{
				ID: "lifestyle_how_we_live", Title: "How We Live", Icon: "leaf.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("lifestyle_how_we_live_q1", "What does a good, balanced life look like to you?"),
					open("lifestyle_how_we_live_q2", "What's a habit you'd love us to build together?"),
					open("lifestyle_how_we_live_q3", "What makes a house feel like home to you?"),
					open("lifestyle_how_we_live_q4", "How do you like to unwind after a hard week?"),
					open("lifestyle_how_we_live_q5", "What's a small daily ritual that grounds you?"),
					open("lifestyle_how_we_live_q6", "What would your ideal ordinary day look like?"),
				},
			},
			{
				ID: "lifestyle_morning_night", Title: "Morning or Night", Icon: "moon.stars.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("lifestyle_morning_night_q1", "Which are you?", icon("Sunrise person", "sunrise.fill"), icon("Sunset person", "moon.stars.fill")),
					choice("lifestyle_morning_night_q2", "Which do you prefer?", photo("Morning jog", "jogging"), photo("Late night snack", "snack")),
					choice("lifestyle_morning_night_q3", "Which are you?", icon("Up with the sun", "sun.max.fill"), icon("Best after dark", "moon.zzz.fill")),
					choice("lifestyle_morning_night_q4", "Which do you prefer?", photo("Dawn walk", "sunrise"), photo("Night drive", "nightdrive")),
					choice("lifestyle_morning_night_q5", "Which are you?", icon("Morning ideas", "sparkles"), icon("Midnight ideas", "moon.stars.fill")),
					choice("lifestyle_morning_night_q6", "Which do you prefer?", photo("Early bedtime", "bedroom"), photo("Late movie night", "cinema")),
				},
			},
			{
				ID: "lifestyle_tidy_cozy", Title: "Tidy or Cozy", Icon: "sparkles", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("lifestyle_tidy_cozy_q1", "Which are you?", icon("Tidy", "sparkles"), icon("Cozy chaos", "wind")),
					choice("lifestyle_tidy_cozy_q2", "Which are you?", icon("Everything in place", "target"), icon("Lived-in mess", "shuffle")),
					choice("lifestyle_tidy_cozy_q3", "Which are you?", icon("Clean as you go", "repeat"), icon("Big weekend clean", "calendar")),
					choice("lifestyle_tidy_cozy_q4", "Which are you?", icon("Minimalist", "leaf.fill"), icon("Full of things", "gift.fill")),
					choice("lifestyle_tidy_cozy_q5", "Which are you?", icon("Made bed daily", "bed.double.fill"), icon("Never make it", "moon.zzz.fill")),
					choice("lifestyle_tidy_cozy_q6", "Which are you?", icon("Label everything", "book.fill"), icon("Just remember it", "sparkle")),
				},
			},
			{
				ID: "lifestyle_wellness", Title: "Wellness", Icon: "heart.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("lifestyle_wellness_q1", "Which do you prefer?", photo("Meditation", "meditation"), photo("Journaling", "journaling")),
					choice("lifestyle_wellness_q2", "Which do you prefer?", photo("Spa day", "spa"), photo("Nature hike", "hiking")),
					choice("lifestyle_wellness_q3", "Which do you prefer?", photo("Warm bath", "bath"), photo("Cold plunge", "coldplunge")),
					choice("lifestyle_wellness_q4", "Which do you prefer?", photo("Beach day", "beach"), photo("Forest walk", "forest")),
					choice("lifestyle_wellness_q5", "Which do you prefer?", photo("Deep sleep", "sleeping"), photo("Power nap", "napping")),
					choice("lifestyle_wellness_q6", "Which do you prefer?", photo("Sunny park", "park"), photo("Quiet library", "library")),
				},
			},
			{
				ID: "lifestyle_routines", Title: "Routines", Icon: "repeat", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("lifestyle_routines_q1", "What's one routine you could never give up?"),
					open("lifestyle_routines_q2", "How do you like to start your weekends?"),
					open("lifestyle_routines_q3", "What's a routine from your childhood you still miss?"),
					open("lifestyle_routines_q4", "How do you recharge when you're running on empty?"),
					open("lifestyle_routines_q5", "What's a shared routine that makes you feel close to me?"),
					open("lifestyle_routines_q6", "What would our perfect Sunday routine look like?"),
				},
			},
			{
				ID: "lifestyle_city_country", Title: "City or Country", Icon: "building.2.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("lifestyle_city_country_q1", "Which do you prefer?", photo("Busy city", "city"), photo("Quiet countryside", "countryside")),
					choice("lifestyle_city_country_q2", "Which do you prefer?", photo("Cozy cabin", "cabin"), photo("High-rise flat", "skyscraper")),
					choice("lifestyle_city_country_q3", "Which do you prefer?", photo("Mountain town", "mountain"), photo("Seaside village", "seaside")),
					choice("lifestyle_city_country_q4", "Which do you prefer?", photo("Street cafe", "cafe"), photo("Farm morning", "farm")),
					choice("lifestyle_city_country_q5", "Which do you prefer?", photo("Subway commute", "subway"), photo("Country road", "countryroad")),
					choice("lifestyle_city_country_q6", "Which do you prefer?", photo("City lights", "citylights"), photo("Starry sky", "stars")),
				},
			},
			{
				ID: "lifestyle_everyday_choices", Title: "Everyday Choices", Icon: "sparkle", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("lifestyle_everyday_choices_q1", "What small daily choice makes the biggest difference for you?"),
					open("lifestyle_everyday_choices_q2", "What's a simple pleasure you never want to give up?"),
					open("lifestyle_everyday_choices_q3", "How do you decide how to spend a free afternoon?"),
					open("lifestyle_everyday_choices_q4", "What everyday thing feels like a treat to you?"),
					open("lifestyle_everyday_choices_q5", "What's one change that would make your days feel lighter?"),
					open("lifestyle_everyday_choices_q6", "What ordinary moment with me do you cherish most?"),
				},
			},
		},
	},
	{
		ID: "food", Title: "Food", Icon: "fork.knife", ColorKey: "red",
		Quizzes: []catalogQuiz{
			{
				ID: "food_taste_test", Title: "Taste Test", Icon: "cup.and.saucer.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("food_taste_test_q1", "Which do you prefer?", photo("Pizza", "pizza"), photo("Pasta", "pasta")),
					choice("food_taste_test_q2", "Which do you prefer?", photo("Sushi", "sushi"), photo("Tacos", "tacos")),
					choice("food_taste_test_q3", "Which do you prefer?", photo("Ramen", "ramen"), photo("Burgers", "burger")),
					choice("food_taste_test_q4", "Which do you prefer?", photo("Steak", "steak"), photo("Salad", "salad")),
					choice("food_taste_test_q5", "Which do you prefer?", photo("Pancakes", "pancakes"), photo("Waffles", "waffles")),
					choice("food_taste_test_q6", "Which do you prefer?", photo("Ice Cream", "icecream"), photo("Chocolate", "chocolate")),
				},
			},
			{
				ID: "food_in_the_kitchen", Title: "In the Kitchen", Icon: "flame.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("food_in_the_kitchen_q1", "What dish do you love making from scratch?"),
					open("food_in_the_kitchen_q2", "What's a recipe you'd love to master with me?"),
					open("food_in_the_kitchen_q3", "Who's the better cook between us, and why?"),
					open("food_in_the_kitchen_q4", "What's your go-to meal when you want to impress someone?"),
					open("food_in_the_kitchen_q5", "What kitchen disaster do we still laugh about?"),
					open("food_in_the_kitchen_q6", "If we opened a little restaurant together, what would we serve?"),
				},
			},
			{
				ID: "food_foodie_faceoff", Title: "Foodie Faceoff", Icon: "flame.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("food_foodie_faceoff_q1", "Pick a side:", photo("Fries", "fries"), photo("Onion Rings", "onionrings")),
					choice("food_foodie_faceoff_q2", "Pick a side:", photo("Bacon", "bacon"), photo("Avocado", "avocado")),
					choice("food_foodie_faceoff_q3", "Pick a side:", photo("Cheese", "cheese"), photo("Chocolate", "chocolate")),
					choice("food_foodie_faceoff_q4", "Pick a side:", photo("Noodles", "noodles"), photo("Rice", "rice")),
					choice("food_foodie_faceoff_q5", "Pick a side:", photo("Donuts", "donuts"), photo("Cupcakes", "cupcakes")),
					choice("food_foodie_faceoff_q6", "Pick a side:", photo("Mango", "mango"), photo("Strawberry", "strawberry")),
				},
			},
			{
				ID: "food_date_night_dining", Title: "Date Night Dining", Icon: "heart.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("food_date_night_dining_q1", "What's your idea of the perfect dinner date?"),
					open("food_date_night_dining_q2", "What meal reminds you of a special moment for us?"),
					open("food_date_night_dining_q3", "What restaurant would you love to take me to?"),
					open("food_date_night_dining_q4", "Candlelit dinner in or a night out — what sounds better tonight?"),
					open("food_date_night_dining_q5", "What food always puts you in a good mood?"),
					open("food_date_night_dining_q6", "If we planned a picnic together, what would we pack?"),
				},
			},
			{
				ID: "food_sweet_or_savory", Title: "Sweet or Savory", Icon: "sparkles", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("food_sweet_or_savory_q1", "Which do you prefer?", icon("Sweet", "sparkles"), icon("Savory", "fork.knife")),
					choice("food_sweet_or_savory_q2", "Which do you prefer?", photo("Croissant", "croissant"), photo("Bagel", "bagel")),
					choice("food_sweet_or_savory_q3", "Which do you prefer?", photo("Honey", "honey"), photo("Cheese", "cheese")),
					choice("food_sweet_or_savory_q4", "Which do you prefer?", photo("Cake", "cake"), photo("Pretzel", "pretzel")),
					choice("food_sweet_or_savory_q5", "Which do you prefer?", icon("Dessert First", "star.fill"), icon("Save Room", "hourglass")),
					choice("food_sweet_or_savory_q6", "Which do you prefer?", photo("Maple Syrup", "maplesyrup"), photo("Butter", "butter")),
				},
			},
			{
				ID: "food_cuisine_clash", Title: "Cuisine Clash", Icon: "map.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("food_cuisine_clash_q1", "Which cuisine wins tonight?", photo("Italian", "lasagna"), photo("Mexican", "burrito")),
					choice("food_cuisine_clash_q2", "Which cuisine wins tonight?", photo("Japanese", "sushi"), photo("Thai", "padthai")),
					choice("food_cuisine_clash_q3", "Which cuisine wins tonight?", photo("Indian", "curry"), photo("Chinese", "dumplings")),
					choice("food_cuisine_clash_q4", "Which cuisine wins tonight?", photo("Greek", "gyro"), photo("French", "baguette")),
					choice("food_cuisine_clash_q5", "Which cuisine wins tonight?", photo("Korean", "kimchi"), photo("Vietnamese", "pho")),
					choice("food_cuisine_clash_q6", "Which cuisine wins tonight?", photo("Spanish", "paella"), photo("American", "burger")),
				},
			},
			{
				ID: "food_cooking_style", Title: "Cooking Style", Icon: "flame.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("food_cooking_style_q1", "Which is more you?", icon("Recipe To The Letter", "book.fill"), icon("Wing It", "shuffle")),
					choice("food_cooking_style_q2", "Which is more you?", icon("Spicy", "flame.fill"), icon("Mild", "leaf.fill")),
					choice("food_cooking_style_q3", "Which is more you?", icon("Grill Master", "flame.fill"), icon("Slow Cooker", "clock.fill")),
					choice("food_cooking_style_q4", "Which is more you?", icon("Meal Prep", "calendar"), icon("Cook Fresh Daily", "sun.max.fill")),
					choice("food_cooking_style_q5", "Which is more you?", icon("Loads Of Garlic", "sparkle"), icon("Keep It Simple", "leaf.fill")),
					choice("food_cooking_style_q6", "Which is more you?", icon("Clean As You Go", "checkmark.seal.fill"), icon("Big Pile Of Dishes", "bag.fill")),
				},
			},
			{
				ID: "food_comfort_food", Title: "Comfort Food", Icon: "heart.fill", Format: formatDeepConversation,
				Questions: []catalogQuestion{
					open("food_comfort_food_q1", "What's the ultimate comfort meal for you?"),
					open("food_comfort_food_q2", "What food instantly reminds you of home?"),
					open("food_comfort_food_q3", "What dish from your childhood do you still crave?"),
					open("food_comfort_food_q4", "What do you like to eat when you've had a rough day?"),
					open("food_comfort_food_q5", "What snack could you happily share with me on the couch?"),
					open("food_comfort_food_q6", "What meal would you want me to make when you're feeling down?"),
				},
			},
			{
				ID: "food_drinks_and_treats", Title: "Drinks & Treats", Icon: "cup.and.saucer.fill", Format: formatWhichDoYouPrefer,
				Questions: []catalogQuestion{
					choice("food_drinks_and_treats_q1", "Which do you prefer?", photo("Coffee", "coffee"), photo("Tea", "tea")),
					choice("food_drinks_and_treats_q2", "Which do you prefer?", photo("Wine", "wine"), photo("Beer", "beer")),
					choice("food_drinks_and_treats_q3", "Which do you prefer?", photo("Smoothie", "smoothie"), photo("Milkshake", "milkshake")),
					choice("food_drinks_and_treats_q4", "Which do you prefer?", photo("Cookies", "cookies"), photo("Brownies", "brownies")),
					choice("food_drinks_and_treats_q5", "Which do you prefer?", photo("Lemonade", "lemonade"), photo("Iced Tea", "icedtea")),
					choice("food_drinks_and_treats_q6", "Which do you prefer?", photo("Hot Chocolate", "hotchocolate"), photo("Cappuccino", "cappuccino")),
				},
			},
			{
				ID: "food_eating_out", Title: "Eating Out", Icon: "map.fill", Format: formatThisOrThat,
				Questions: []catalogQuestion{
					choice("food_eating_out_q1", "Which sounds better?", icon("Fancy Restaurant", "crown.fill"), icon("Street Food", "flame.fill")),
					choice("food_eating_out_q2", "Which sounds better?", icon("Brunch", "sun.max.fill"), icon("Late Dinner", "moon.stars.fill")),
					choice("food_eating_out_q3", "Which sounds better?", icon("Cozy Booth", "house.fill"), icon("Patio Table", "leaf.fill")),
					choice("food_eating_out_q4", "Which sounds better?", icon("Split Everything", "person.2.fill"), icon("Order Your Own", "person.fill")),
					choice("food_eating_out_q5", "Which sounds better?", icon("Try New Spots", "sparkles"), icon("Our Usual Place", "heart.fill")),
					choice("food_eating_out_q6", "Which sounds better?", icon("Tasting Menu", "star.fill"), icon("Just Dessert", "gift.fill")),
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

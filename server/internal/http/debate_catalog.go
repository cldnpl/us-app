package httpapi

// Couples Debate topic packs. These echo the "How Well Do You Know Me" packs in
// theme (food, travel, romance, little habits…) but are their own content: each
// entry is a debatable *motion* one partner argues for and the other against,
// not a preference question.

type debateMotion struct {
	ID     string
	Prompt string // the motion under debate
}

type debatePack struct {
	ID       string
	Title    string
	Icon     string
	ColorKey string
	Tag      string
	Motions  []debateMotion
}

var debatePacks = []debatePack{
	{
		ID: "hot_takes", Title: "Hot Takes", Icon: "flame.fill", ColorKey: "red", Tag: "FUN",
		Motions: []debateMotion{
			{ID: "hot_takes_r1", Prompt: "Pineapple absolutely belongs on pizza."},
			{ID: "hot_takes_r2", Prompt: "A hot dog is a sandwich."},
			{ID: "hot_takes_r3", Prompt: "Cereal should be poured before the milk, always."},
		},
	},
	{
		ID: "food_fight", Title: "Food Fight", Icon: "fork.knife", ColorKey: "amber", Tag: "FUN",
		Motions: []debateMotion{
			{ID: "food_fight_r1", Prompt: "Breakfast is the best meal of the day."},
			{ID: "food_fight_r2", Prompt: "Leftovers taste better than the fresh meal did."},
			{ID: "food_fight_r3", Prompt: "It's fine to have dessert before dinner."},
		},
	},
	{
		ID: "screen_time", Title: "Screen Time", Icon: "play.rectangle.fill", ColorKey: "blue", Tag: "FUN",
		Motions: []debateMotion{
			{ID: "screen_time_r1", Prompt: "Texting is better than calling."},
			{ID: "screen_time_r2", Prompt: "Subtitles should be on for everything."},
			{ID: "screen_time_r3", Prompt: "The book is always better than the movie."},
		},
	},
	{
		ID: "travel_wars", Title: "Travel Wars", Icon: "airplane", ColorKey: "blue", Tag: "FUN",
		Motions: []debateMotion{
			{ID: "travel_wars_r1", Prompt: "A beach holiday beats a mountain getaway."},
			{ID: "travel_wars_r2", Prompt: "The best trips are planned to the minute."},
			{ID: "travel_wars_r3", Prompt: "The window seat is the only correct choice."},
		},
	},
	{
		ID: "pet_debates", Title: "Pet Debates", Icon: "pawprint.fill", ColorKey: "purple", Tag: "CUTE",
		Motions: []debateMotion{
			{ID: "pet_debates_r1", Prompt: "Cats make better companions than dogs."},
			{ID: "pet_debates_r2", Prompt: "Pets should be allowed on the bed."},
			{ID: "pet_debates_r3", Prompt: "Giving pets human names is a great idea."},
		},
	},
	{
		ID: "homebody_vs", Title: "Homebody vs Adventurer", Icon: "house.fill", ColorKey: "green", Tag: "FUN",
		Motions: []debateMotion{
			{ID: "homebody_vs_r1", Prompt: "A night in beats a night out."},
			{ID: "homebody_vs_r2", Prompt: "Morning people have it figured out."},
			{ID: "homebody_vs_r3", Prompt: "Making the bed every day is worth it."},
		},
	},
	{
		ID: "matters_of_the_heart", Title: "Matters of the Heart", Icon: "heart.fill", ColorKey: "pink", Tag: "DEEP",
		Motions: []debateMotion{
			{ID: "matters_r1", Prompt: "Small everyday gestures matter more than grand ones."},
			{ID: "matters_r2", Prompt: "A surprise date beats a carefully planned one."},
			{ID: "matters_r3", Prompt: "Whoever is angrier should apologise first."},
		},
	},
	{
		ID: "spicy_debates", Title: "Spicy Debates", Icon: "sparkles", ColorKey: "red", Tag: "18+",
		Motions: []debateMotion{
			{ID: "spicy_r1", Prompt: "A little PDA in public is totally fine."},
			{ID: "spicy_r2", Prompt: "A bit of jealousy is flattering, not a red flag."},
			{ID: "spicy_r3", Prompt: "Keeping some mystery is sexier than sharing everything."},
		},
	},
}

func findDebatePack(id string) (debatePack, bool) {
	for _, p := range debatePacks {
		if p.ID == id {
			return p, true
		}
	}
	return debatePack{}, false
}

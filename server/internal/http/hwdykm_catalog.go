package httpapi

// "How Well Do You Know Me" content. Each pack has questions; per couple, each
// question has a subject (one partner) who answers honestly while the other
// guesses — matches score compatibility. Subject alternates by question index.
// Answers reuse quiz_answers with quiz_id "hwdykm:<packID>".

type hwdykmQuestion struct {
	ID      string   `json:"id"`
	Prompt  string   `json:"prompt"`
	Options []string `json:"options"`
}

type hwdykmPack struct {
	ID        string           `json:"id"`
	Title     string           `json:"title"`
	Icon      string           `json:"icon"`     // SF Symbol
	ColorKey  string           `json:"colorKey"` // card gradient on iOS
	Tag       string           `json:"tag"`      // CUTE / FUN / DEEP / 18+
	Questions []hwdykmQuestion `json:"questions"`
}

var hwdykmPacks = []hwdykmPack{
	{
		ID: "favorites", Title: "Favorites", Icon: "star.fill", ColorKey: "purple", Tag: "CUTE",
		Questions: []hwdykmQuestion{
			{ID: "favorites_q1", Prompt: "Go-to comfort food?", Options: []string{"Pizza 🍕", "Pasta 🍝", "Sushi 🍣", "Tacos 🌮"}},
			{ID: "favorites_q2", Prompt: "Perfect weekend mood?", Options: []string{"Cozy night in 🛋️", "Out and about 🎉", "Outdoor adventure 🥾", "Total lazy day 😴"}},
			{ID: "favorites_q3", Prompt: "Best season of the year?", Options: []string{"Spring 🌸", "Summer ☀️", "Autumn 🍂", "Winter ❄️"}},
			{ID: "favorites_q4", Prompt: "Ideal movie night pick?", Options: []string{"Rom-com 💕", "Action-packed 💥", "Horror thrills 👻", "Feel-good animation 🐣"}},
			{ID: "favorites_q5", Prompt: "Drink of choice?", Options: []string{"Coffee ☕", "Tea 🍵", "Something bubbly 🥂", "Just water 💧"}},
			{ID: "favorites_q6", Prompt: "Favorite color vibe?", Options: []string{"Warm reds 🔴", "Cool blues 🔵", "Earthy greens 🟢", "Soft pastels 🌷"}},
			{ID: "favorites_q7", Prompt: "Best way to unwind?", Options: []string{"Music and chill 🎧", "A good book 📖", "Long hot bath 🛁", "Gaming session 🎮"}},
			{ID: "favorites_q8", Prompt: "Ultimate sweet treat?", Options: []string{"Chocolate 🍫", "Ice cream 🍦", "Cookies 🍪", "Fresh fruit 🍓"}},
		},
	},
	{
		ID: "first_impressions", Title: "First Impressions", Icon: "eye.fill", ColorKey: "pink", Tag: "CUTE",
		Questions: []hwdykmQuestion{
			{ID: "first_impressions_q1", Prompt: "First thing people notice?", Options: []string{"The smile 😁", "The eyes 👀", "The laugh 😂", "The outfit 👗"}},
			{ID: "first_impressions_q2", Prompt: "Vibe walking into a party?", Options: []string{"Life of it 🎉", "Cozy in the corner 🛋️", "Fashionably late 🚪", "Straight to the snacks 🍕"}},
			{ID: "first_impressions_q3", Prompt: "Texting style on day one?", Options: []string{"Paragraphs 📝", "One-word wonders 💬", "All emojis 😍", "Master of the meme 🤣"}},
			{ID: "first_impressions_q4", Prompt: "Signature flirting move?", Options: []string{"Bad puns 😏", "Bold and direct 🔥", "Shy glances 🙈", "Playful teasing 😜"}},
			{ID: "first_impressions_q5", Prompt: "Fastest way to win someone over?", Options: []string{"Good food 🍜", "A great playlist 🎶", "Making them laugh 😆", "Deep chats 🌙"}},
			{ID: "first_impressions_q6", Prompt: "Energy in a first conversation?", Options: []string{"Chatterbox 🗣️", "Great listener 👂", "Nervous rambler 😅", "Cool and calm 😎"}},
			{ID: "first_impressions_q7", Prompt: "First-date dress code?", Options: []string{"Dressed to impress ✨", "Comfy casual 👟", "Classic and clean 👔", "Whatever's clean 🧺"}},
			{ID: "first_impressions_q8", Prompt: "Lasting impression left behind?", Options: []string{"So funny 😂", "So sweet 🥰", "So mysterious 🕶️", "So genuine 💛"}},
		},
	},
	{
		ID: "little_habits", Title: "Little Habits", Icon: "sparkles", ColorKey: "blue", Tag: "FUN",
		Questions: []hwdykmQuestion{
			{ID: "little_habits_q1", Prompt: "Coffee order, honestly?", Options: []string{"Black as the void ☕️", "Milk and sugar situation 🥛", "It's basically dessert 🍫", "Tea person, actually 🍵"}},
			{ID: "little_habits_q2", Prompt: "Phone battery at any given moment?", Options: []string{"Always near 100% 🔋", "Living on the edge at 4% 🪫", "Chronic mid-40s dweller 📱"}},
			{ID: "little_habits_q3", Prompt: "Living space vibe?", Options: []string{"Spotless showroom ✨", "Organized chaos 🌀", "Floordrobe enthusiast 🧦"}},
			{ID: "little_habits_q4", Prompt: "The morning alarm ritual?", Options: []string{"Up on the first beep ⏰", "Snooze five times minimum 😴", "Six alarms, just in case 🚨"}},
			{ID: "little_habits_q5", Prompt: "Toilet-roll orientation stance?", Options: []string{"Over, obviously 🧻", "Under, fight me 👇", "Whatever lands is fine 🤷"}},
			{ID: "little_habits_q6", Prompt: "Dishwasher-loading philosophy?", Options: []string{"Tetris-grandmaster precision 🧩", "Cram it and pray 🙏", "There's a wrong way? 🍽️"}},
			{ID: "little_habits_q7", Prompt: "Texting typo policy?", Options: []string{"Instant follow-up correction ✍️", "Sends the *fixed word 🔁", "Autocorrect does the talking 🤖", "Typos are a personality 😅"}},
			{ID: "little_habits_q8", Prompt: "Toothpaste-tube technique?", Options: []string{"Neatly rolled from the end 🧴", "Squeezed from the middle 💥", "It's a crumpled mystery 🔍"}},
		},
	},
	{
		ID: "food_cravings", Title: "Food & Cravings", Icon: "fork.knife", ColorKey: "red", Tag: "FUN",
		Questions: []hwdykmQuestion{
			{ID: "food_cravings_q1", Prompt: "Ultimate comfort food?", Options: []string{"Mac & cheese 🧀", "Warm soup 🍲", "Buttery toast 🍞", "Mashed potatoes 🥔"}},
			{ID: "food_cravings_q2", Prompt: "Guiltiest snack?", Options: []string{"Chips 🥔", "Cookies 🍪", "Gummy bears 🐻", "Popcorn 🍿"}},
			{ID: "food_cravings_q3", Prompt: "Go-to coffee order?", Options: []string{"Black drip ☕️", "Sweet latte 🥛", "Iced cold brew 🧊", "None, tea please 🍵"}},
			{ID: "food_cravings_q4", Prompt: "Top pizza topping?", Options: []string{"Pepperoni 🍕", "Mushrooms 🍄", "Extra cheese 🧀", "Pineapple 🍍"}},
			{ID: "food_cravings_q5", Prompt: "Spice tolerance level?", Options: []string{"No heat 🥛", "Mild kick 🌶️", "Bring the fire 🔥", "Ghost pepper 👻"}},
			{ID: "food_cravings_q6", Prompt: "Sweet or savory pick?", Options: []string{"Always sweet 🍰", "Strictly savory 🧀", "Salty-sweet combo 🥨", "Depends on mood 🍫"}},
			{ID: "food_cravings_q7", Prompt: "Late-night craving?", Options: []string{"Leftover pizza 🍕", "Cereal bowl 🥣", "Ice cream 🍦", "Instant noodles 🍜"}},
			{ID: "food_cravings_q8", Prompt: "Dream cuisine night?", Options: []string{"Italian pasta 🍝", "Sushi spread 🍣", "Taco fiesta 🌮", "Thai curry 🍛"}},
		},
	},
	{
		ID: "travel_dreams", Title: "Travel Dreams", Icon: "airplane", ColorKey: "blue", Tag: "FUN",
		Questions: []hwdykmQuestion{
			{ID: "travel_dreams_q1", Prompt: "Dream destination?", Options: []string{"Tropical island 🏝️", "Historic city 🏛️", "Snowy mountains 🏔️", "Wild safari 🦁"}},
			{ID: "travel_dreams_q2", Prompt: "Packing style?", Options: []string{"Light carry-on 🎒", "Overpacked suitcase 🧳", "Last-minute chaos 🌀"}},
			{ID: "travel_dreams_q3", Prompt: "Seat preference?", Options: []string{"Window seat 🪟", "Aisle seat 🚶", "Whatever's open 🎲"}},
			{ID: "travel_dreams_q4", Prompt: "Trip planning vibe?", Options: []string{"Detailed itinerary 📋", "Loose plan 🗺️", "Total spontaneity ✨"}},
			{ID: "travel_dreams_q5", Prompt: "Beaches or mountains?", Options: []string{"Sandy beaches 🏖️", "Lofty mountains ⛰️", "Both please 🌍"}},
			{ID: "travel_dreams_q6", Prompt: "Souvenir habit?", Options: []string{"Fridge magnets 🧲", "Local snacks 🍫", "Too many photos 📸", "Nothing at all 🚫"}},
			{ID: "travel_dreams_q7", Prompt: "Ideal trip length?", Options: []string{"Quick weekend 🌅", "One full week 📅", "Endless months 🌐"}},
			{ID: "travel_dreams_q8", Prompt: "Travel must-have?", Options: []string{"Cozy neck pillow 💤", "Headphones on 🎧", "Fully charged phone 🔋", "Good book 📖"}},
		},
	},
	{
		ID: "pet_peeves", Title: "Pet Peeves", Icon: "exclamationmark.bubble.fill", ColorKey: "amber", Tag: "FUN",
		Questions: []hwdykmQuestion{
			{ID: "pet_peeves_q1", Prompt: "Biggest pet peeve?", Options: []string{"Loud chewing 😤", "Constant lateness ⏰", "Slow walkers 🐌", "Interrupting mid-sentence 🙊"}},
			{ID: "pet_peeves_q2", Prompt: "Ultimate ick?", Options: []string{"Bad table manners 🍽️", "Being rude to staff 😠", "Never saying sorry 🙅", "Talking during movies 🎬"}},
			{ID: "pet_peeves_q3", Prompt: "Instant mood killer?", Options: []string{"Empty phone battery 🔋", "Traffic jams 🚗", "A rude comment 💢", "Being ignored 🙄"}},
			{ID: "pet_peeves_q4", Prompt: "Most dreaded chore?", Options: []string{"Doing dishes 🧽", "Folding laundry 🧺", "Taking out trash 🗑️", "Scrubbing floors 🧹"}},
			{ID: "pet_peeves_q5", Prompt: "Worst texting habit?", Options: []string{"One-word replies 😑", "Leaving on read 👀", "Typing then stopping ⌨️", "Endless voice notes 🎙️"}},
			{ID: "pet_peeves_q6", Prompt: "Kitchen crime?", Options: []string{"Empty milk carton back in fridge 🥛", "Dirty dishes in sink 🍳", "No refill after finishing ☕", "Crumbs everywhere 🍞"}},
			{ID: "pet_peeves_q7", Prompt: "Most annoying sound?", Options: []string{"Nails on chalkboard 😬", "Loud gum chewing 🍬", "Sniffling nonstop 🤧", "Alarm snooze spam ⏰"}},
			{ID: "pet_peeves_q8", Prompt: "Public transport peeve?", Options: []string{"Loud phone speakers 📢", "Seat hoggers 💺", "No personal space 🫸", "Blocking the doors 🚪"}},
		},
	},
	{
		ID: "love_romance", Title: "Love & Romance", Icon: "heart.fill", ColorKey: "pink", Tag: "DEEP",
		Questions: []hwdykmQuestion{
			{ID: "love_romance_q1", Prompt: "Ideal romantic date?", Options: []string{"Candlelit dinner 🕯️", "Sunset picnic 🧺", "Slow dancing at home 💃", "Weekend getaway 🧳"}},
			{ID: "love_romance_q2", Prompt: "Main love language?", Options: []string{"Words of affirmation 💌", "Quality time ⏳", "Physical touch 🤗", "Thoughtful gifts 🎁"}},
			{ID: "love_romance_q3", Prompt: "Favorite way to feel loved?", Options: []string{"Long warm hugs 🤗", "Sweet little notes 💌", "Undivided attention 👀", "Surprise treats 🍫"}},
			{ID: "love_romance_q4", Prompt: "Most romantic gesture?", Options: []string{"Handwritten letter ✍️", "Surprise flowers 💐", "Breakfast in bed 🥐", "A heartfelt playlist 🎶"}},
			{ID: "love_romance_q5", Prompt: "Perfect anniversary?", Options: []string{"Cozy night in 🏡", "Fancy dinner out 🍷", "Adventure trip ✈️", "Recreating the first date 💞"}},
			{ID: "love_romance_q6", Prompt: "Sweetest way to say sorry?", Options: []string{"Heartfelt apology 🫶", "Comfort food gift 🍰", "A tender hug 🤍", "Making it up together 🌷"}},
			{ID: "love_romance_q7", Prompt: "Dreamiest way to fall asleep?", Options: []string{"Wrapped in a cuddle 🌙", "Whispering goodnights 💬", "Under the stars ✨", "Hand in hand 🤝"}},
			{ID: "love_romance_q8", Prompt: "Most swoon-worthy moment?", Options: []string{"A slow first kiss 💋", "Dancing in the rain 🌧️", "A surprise reunion 🥹", "Locking eyes across a room 👀"}},
		},
	},
	{
		ID: "future_us", Title: "Future Us", Icon: "sunrise.fill", ColorKey: "green", Tag: "DEEP",
		Questions: []hwdykmQuestion{
			{ID: "future_us_q1", Prompt: "Dream home together?", Options: []string{"Beach house 🏝️", "Mountain cabin 🏔️", "Cozy cottage 🏡", "City penthouse 🌆"}},
			{ID: "future_us_q2", Prompt: "Kids or pets?", Options: []string{"A house full of kids 👶", "A pack of pets 🐾", "Both, all of it 🏠", "Just the two of us 💑"}},
			{ID: "future_us_q3", Prompt: "Ideal retirement?", Options: []string{"Traveling the world ✈️", "Quiet by the sea 🌊", "Farm life 🌻", "Close to family 👨‍👩‍👧"}},
			{ID: "future_us_q4", Prompt: "Place to grow old?", Options: []string{"Where we started 🏡", "Somewhere sunny ☀️", "Near the mountains 🏔️", "Wherever we're together ❤️"}},
			{ID: "future_us_q5", Prompt: "Biggest shared life goal?", Options: []string{"Building a home 🏠", "Seeing the world 🌍", "Raising a family 👪", "Freedom to roam 🕊️"}},
			{ID: "future_us_q6", Prompt: "A dream we chase together?", Options: []string{"Starting a business 💼", "Writing our story 📖", "Giving back 🤝", "Living slow 🌿"}},
			{ID: "future_us_q7", Prompt: "Perfect future weekend?", Options: []string{"Adventures out 🥾", "Cozy at home 🛋️", "Hosting friends 🎉", "Exploring somewhere new 🗺️"}},
			{ID: "future_us_q8", Prompt: "How we spend forever?", Options: []string{"Always exploring 🧭", "Building roots 🌳", "Chasing sunsets 🌅", "Growing together 🌱"}},
		},
	},
	{
		ID: "money_style", Title: "Money Style", Icon: "dollarsign.circle.fill", ColorKey: "green", Tag: "FUN",
		Questions: []hwdykmQuestion{
			{ID: "money_style_q1", Prompt: "Saver or spender?", Options: []string{"Diligent saver 🏦", "Free spender 💸", "Somewhere in between ⚖️"}},
			{ID: "money_style_q2", Prompt: "Go-to splurge item?", Options: []string{"Good food 🍜", "New gadgets 📱", "Travel adventures ✈️", "Cozy home stuff 🛋️"}},
			{ID: "money_style_q3", Prompt: "Budgeting style?", Options: []string{"Spreadsheet devotee 📊", "Budgeting app fan 📲", "Vibes and guesswork 🤷"}},
			{ID: "money_style_q4", Prompt: "Treat or save a windfall?", Options: []string{"Treat right away 🎉", "Straight to savings 🐷", "Half and half ✂️"}},
			{ID: "money_style_q5", Prompt: "Worst money habit?", Options: []string{"Impulse buys 🛒", "Forgotten subscriptions 🔁", "Too many takeout orders 🥡", "Late-night online carts 🌙"}},
			{ID: "money_style_q6", Prompt: "Dream splurge?", Options: []string{"Fancy car 🚗", "Big trip 🏝️", "Dream home 🏡", "Designer wardrobe 👜"}},
			{ID: "money_style_q7", Prompt: "Gift-giving style?", Options: []string{"Grand and generous 🎁", "Thoughtful and modest 💌", "Handmade with love 🧶"}},
			{ID: "money_style_q8", Prompt: "Payday move?", Options: []string{"Little treat first 🍰", "Pay the bills 🧾", "Stash it away 🏦", "Split it all up 📂"}},
		},
	},
	{
		ID: "guilty_pleasures", Title: "Guilty Pleasures", Icon: "face.smiling", ColorKey: "amber", Tag: "FUN",
		Questions: []hwdykmQuestion{
			{ID: "guilty_pleasures_q1", Prompt: "Ultimate reality show binge?", Options: []string{"Dating drama 🌹", "Housewives chaos 🍸", "Cooking competitions 🍳", "Renovation makeovers 🔨"}},
			{ID: "guilty_pleasures_q2", Prompt: "Secret midnight snack?", Options: []string{"Cold pizza slice 🍕", "Spoonful of Nutella 🍫", "Cereal by the handful 🥣", "Leftover fries 🍟"}},
			{ID: "guilty_pleasures_q3", Prompt: "Most embarrassing playlist anthem?", Options: []string{"Cheesy boy band 🎤", "Guilty breakup ballad 💔", "Overplayed pop hit 🎧", "Throwback one-hit wonder 📻"}},
			{ID: "guilty_pleasures_q4", Prompt: "Splurge with zero regrets?", Options: []string{"Impulse online cart 🛒", "Fancy overpriced coffee ☕", "Another pair of shoes 👟", "Shiny new gadget 📱"}},
			{ID: "guilty_pleasures_q5", Prompt: "Go-to procrastination move?", Options: []string{"Endless scrolling 📲", "Snack raid 🍿", "Sudden deep clean 🧹", "Just one more nap 😴"}},
			{ID: "guilty_pleasures_q6", Prompt: "Comfort rewatch on repeat?", Options: []string{"Same sitcom loop 📺", "Childhood cartoon 🧸", "Cozy holiday movie 🎄", "Trusty action flick 💥"}},
			{ID: "guilty_pleasures_q7", Prompt: "Weirdest food combo obsession?", Options: []string{"Fries in a shake 🍟", "Pickles with peanut butter 🥒", "Chips on a sandwich 🥪", "Chocolate plus chips 🍫"}},
			{ID: "guilty_pleasures_q8", Prompt: "Hidden party-trick talent?", Options: []string{"Freakishly good memory 🧠", "Spot-on impressions 🎭", "Secret dance moves 🕺", "Random trivia dump 🎲"}},
		},
	},
	{
		ID: "deep_feelings", Title: "Deep Feelings", Icon: "brain.head.profile", ColorKey: "purple", Tag: "DEEP",
		Questions: []hwdykmQuestion{
			{ID: "deep_feelings_q1", Prompt: "Best way to recharge emotionally?", Options: []string{"Quiet alone time 🌙", "Talking it out 💬", "A slow morning ☕", "Being held close 🤗"}},
			{ID: "deep_feelings_q2", Prompt: "Biggest comfort when sad?", Options: []string{"A warm hug 🤗", "Favorite music 🎧", "A cozy blanket 🛋️", "Kind words 💌"}},
			{ID: "deep_feelings_q3", Prompt: "Deepest fear?", Options: []string{"Being alone 🌑", "Losing loved ones 💔", "Not being enough 🥺", "The unknown 🌫️"}},
			{ID: "deep_feelings_q4", Prompt: "What creates a real sense of safety?", Options: []string{"Honesty 🤍", "Steady routine 🧭", "Warm presence 🫂", "Being understood 💭"}},
			{ID: "deep_feelings_q5", Prompt: "Way stress tends to show?", Options: []string{"Going quiet 🤐", "Getting busy 🌀", "Needing space 🚪", "Overthinking 🧠"}},
			{ID: "deep_feelings_q6", Prompt: "Biggest need during an argument?", Options: []string{"A calm pause ⏸️", "To feel heard 👂", "Gentle reassurance 🕊️", "Space to think 🌬️"}},
			{ID: "deep_feelings_q7", Prompt: "What sparks the most pride?", Options: []string{"Small wins 🌱", "Helping others 🤝", "Staying kind 💛", "Never giving up 🔥"}},
			{ID: "deep_feelings_q8", Prompt: "Deepest source of motivation?", Options: []string{"Love ❤️", "Growth 🌿", "A dream 🌟", "Family 🏡"}},
		},
	},
	{
		ID: "under_pressure", Title: "Under Pressure", Icon: "bolt.fill", ColorKey: "red", Tag: "FUN",
		Questions: []hwdykmQuestion{
			{ID: "under_pressure_q1", Prompt: "Running late for something?", Options: []string{"Sprint mode 🏃", "Blame traffic 🚗", "Calm, we're fine 😌", "Silent stress spiral 😰"}},
			{ID: "under_pressure_q2", Prompt: "Unexpected guests at the door?", Options: []string{"Hide the mess 🧹", "Warm welcome 🤗", "Pretend nobody's home 🤫", "Instant snack platter 🧀"}},
			{ID: "under_pressure_q3", Prompt: "Mid-argument energy?", Options: []string{"Cool debater 🧊", "Voice goes up 📢", "Need a break 🚪", "Crack a joke 😅"}},
			{ID: "under_pressure_q4", Prompt: "Scary part of a movie?", Options: []string{"Eyes covered 🙈", "Nervous laughter 😆", "Totally unbothered 😐", "Grab the nearest arm 💪"}},
			{ID: "under_pressure_q5", Prompt: "A spider in the room?", Options: []string{"Cup and card rescue 🥤", "Loud panic 😱", "Handle it barehanded ✋", "Leave the room forever 🚪"}},
			{ID: "under_pressure_q6", Prompt: "Losing a friendly game?", Options: []string{"Gracious loser 🤝", "Demand a rematch 🔁", "Dramatic sulk 😤", "Blame the rules 📜"}},
			{ID: "under_pressure_q7", Prompt: "A looming work deadline?", Options: []string{"Early and organized 📅", "Last-minute genius ⏰", "Panic then power through 💥", "Snacks first, work later 🍿"}},
			{ID: "under_pressure_q8", Prompt: "Getting lost on a trip?", Options: []string{"Trust the map 🗺️", "Wing it confidently 😎", "Ask a local 🙋", "Quiet backseat panic 😬"}},
		},
	},
	{
		ID: "spicy_bold", Title: "Spicy & Bold", Icon: "flame.fill", ColorKey: "red", Tag: "18+",
		Questions: []hwdykmQuestion{
			{ID: "spicy_bold_q1", Prompt: "Biggest turn-on?", Options: []string{"Confidence 😏", "A lingering gaze 👀", "Whispered words 🤫", "A wicked grin 😈"}},
			{ID: "spicy_bold_q2", Prompt: "Ideal flirt move?", Options: []string{"A slow wink 😉", "A daring text 📱", "A soft touch 🫦", "Playful teasing 😜"}},
			{ID: "spicy_bold_q3", Prompt: "Favorite compliment to hear?", Options: []string{"\"You're irresistible\" 🔥", "\"Can't stop staring\" 👀", "\"You drive me wild\" 💫", "\"So dangerously cute\" 😈"}},
			{ID: "spicy_bold_q4", Prompt: "Most attractive trait?", Options: []string{"Bold confidence 😏", "A magnetic smile 😁", "Quick wit 🧠", "Smoldering eyes 🔥"}},
			{ID: "spicy_bold_q5", Prompt: "Perfect romantic tension?", Options: []string{"Almost-kiss pauses 😮‍💨", "Locked eye contact 👁️", "Accidental touches ✨", "Teasing banter 😏"}},
			{ID: "spicy_bold_q6", Prompt: "Boldest move?", Options: []string{"Making the first move 💋", "A surprise slow dance 💃", "A midnight confession 🌙", "Stealing a kiss 😘"}},
			{ID: "spicy_bold_q7", Prompt: "Guilty crush type?", Options: []string{"The mysterious one 🖤", "The charming flirt 😏", "The bad influence 😈", "The smooth talker 🎩"}},
			{ID: "spicy_bold_q8", Prompt: "Ideal slow-dance song?", Options: []string{"Something sultry 🎷", "A slow R&B groove 🎶", "A steamy tango 💃", "A candlelit ballad 🕯️"}},
		},
	},
	{
		ID: "bedroom_secrets", Title: "Bedroom Secrets", Icon: "bed.double.fill", ColorKey: "red", Tag: "18+",
		Questions: []hwdykmQuestion{
			{ID: "bedroom_secrets_q1", Prompt: "Perfect mood setting?", Options: []string{"Candlelight 🕯️", "Soft music 🎶", "Silk sheets 🛏️", "Warm bath 🛁"}},
			{ID: "bedroom_secrets_q2", Prompt: "Favorite time for closeness?", Options: []string{"Lazy morning 🌅", "Afternoon escape ☀️", "Midnight hours 🌙", "Golden dusk 🌇"}},
			{ID: "bedroom_secrets_q3", Prompt: "Preferred pace?", Options: []string{"Slow and tender 🐢", "Passionate rush 🔥", "Playful tease 😏", "Whatever the mood 🌊"}},
			{ID: "bedroom_secrets_q4", Prompt: "Best kind of kiss?", Options: []string{"Soft and slow 💋", "Deep and hungry 🔥", "Neck and shoulders 🌹", "Everywhere else ✨"}},
			{ID: "bedroom_secrets_q5", Prompt: "Preferred role?", Options: []string{"Take the lead 👑", "Happily led 🎀", "Trade turns 🔄", "Read the moment 🌗"}},
			{ID: "bedroom_secrets_q6", Prompt: "Biggest turn-on?", Options: []string{"Lingering eye contact 👀", "Whispered words 💬", "A gentle touch 🤍", "Undivided attention 💫"}},
			{ID: "bedroom_secrets_q7", Prompt: "Favorite afterglow?", Options: []string{"Tangled cuddles 🫂", "Whispered talks 🗣️", "Drift to sleep 😴", "Shared shower 🚿"}},
			{ID: "bedroom_secrets_q8", Prompt: "Secret fantasy vibe?", Options: []string{"Weekend getaway ✈️", "Roleplay night 🎭", "Somewhere daring 🌃", "Slow rediscovery 🔓"}},
		},
	},
}

func findHwdykmPack(id string) (hwdykmPack, bool) {
	for _, p := range hwdykmPacks {
		if p.ID == id {
			return p, true
		}
	}
	return hwdykmPack{}, false
}

// Everything the app knows about food, meals, plans and movement. Pictures
// for these live in ui/icons.dart: the app shows icons, never emoji.

/// Lighter options offered when a high-calorie food goes in on the Low plan.
const swaps = <String, String>{
  'masaladosa': 'dosa', 'gheeroast': 'dosa', 'parotta': 'chapati', 'poori': 'chapati', 'pongal': 'upma', 'lemonrice': 'rice',
  'vegbiryani': 'sambarrice', 'friedrice': 'sambarrice', 'chk65': 'chkcurry', 'fishfry': 'fishcurry', 'mutton': 'chkcurry',
  'samosa': 'sundal', 'puffs': 'sundal', 'paneer': 'dal', 'kesari': 'banana', 'mysorepak': 'banana', 'chips': 'nuts', 'meals': 'sambarrice',
};

enum Tint { med, green, high, brand }

class MealInfo {
  final String id;
  final String label;
  final double share;
  final Tint tint;
  const MealInfo(this.id, this.label, this.share, this.tint);
}

const meals = <MealInfo>[
  MealInfo('breakfast', 'Breakfast', .25, Tint.med),
  MealInfo('lunch', 'Lunch', .35, Tint.green),
  MealInfo('snack', 'Snacks', .10, Tint.high),
  MealInfo('dinner', 'Dinner', .30, Tint.brand),
];

MealInfo mealInfo(String id) => meals.firstWhere((m) => m.id == id, orElse: () => meals[2]);

class HungerLevel {
  final int v;
  final String title;
  final String desc;
  final Tint tint;
  const HungerLevel(this.v, this.title, this.desc, this.tint);
}

const hungerLevels = <HungerLevel>[
  HungerLevel(1, 'Not hungry', 'Eating because it’s there, or out of habit', Tint.brand),
  HungerLevel(2, 'A little peckish', 'Could wait an hour easily', Tint.brand),
  HungerLevel(3, 'Hungry', 'Ready for a meal', Tint.green),
  HungerLevel(4, 'Very hungry', 'Stomach growling, hard to focus', Tint.med),
  HungerLevel(5, 'Starving', 'Shaky or irritable. Eat something now', Tint.high),
];

class PlanInfo {
  final String id;
  final String name;
  final String desc;
  final Tint tint;
  const PlanInfo(this.id, this.name, this.desc, this.tint);
}

/// Low is the plan built for not overeating; High is for very active days or
/// building muscle, and says so.
const plans = <PlanInfo>[
  PlanInfo('low', 'Low calorie', 'Lose weight slowly · about 500 kcal under what you burn', Tint.green),
  PlanInfo('medium', 'Medium calorie', 'Stay where you are · matches what you burn', Tint.med),
  PlanInfo('high', 'High calorie', 'Very active or building muscle · about 300 kcal over', Tint.high),
];

PlanInfo planInfo(String id) => plans.firstWhere((p) => p.id == id, orElse: () => plans[0]);

class ActivityInfo {
  final double v;
  final String title;
  final String desc;
  const ActivityInfo(this.v, this.title, this.desc);
}

const activities = <ActivityInfo>[
  ActivityInfo(1.2, 'Mostly sitting', 'Desk job, little walking'),
  ActivityInfo(1.375, 'Light', 'Yoga or walks 1–3 days'),
  ActivityInfo(1.55, 'Moderate', 'Exercise 3–5 days'),
  ActivityInfo(1.725, 'Very active', 'Hard exercise most days'),
];

class DietPref {
  final String id;
  final String short;
  final String title;
  final String desc;
  const DietPref(this.id, this.short, this.title, this.desc);
}

const dietPrefs = <DietPref>[
  DietPref('veg', 'Veg', 'Vegetarian', 'No eggs, meat or fish'),
  DietPref('egg', 'Egg', 'Eggetarian', 'Vegetarian plus eggs'),
  DietPref('nonveg', 'Non-veg', 'Non-vegetarian', 'Eggs, chicken and fish too'),
];

DietPref dietPrefInfo(String id) => dietPrefs.firstWhere((p) => p.id == id, orElse: () => dietPrefs[0]);

/// Workouts, with MET values from the Compendium of Physical Activities.
class WorkoutInfo {
  final String id;
  final String title;
  final double met;
  const WorkoutInfo(this.id, this.title, this.met);
}

const workouts = <WorkoutInfo>[
  WorkoutInfo('walk', 'Brisk walk', 4.3),
  WorkoutInfo('yoga', 'Yoga', 2.5),
  WorkoutInfo('surya', 'Surya namaskar', 3.3),
  WorkoutInfo('jog', 'Jogging', 7.0),
  WorkoutInfo('cycle', 'Cycling', 6.8),
  WorkoutInfo('gym', 'Weights', 3.5),
  WorkoutInfo('dance', 'Dance', 5.0),
  WorkoutInfo('swim', 'Swimming', 6.0),
  WorkoutInfo('badminton', 'Badminton', 5.5),
  WorkoutInfo('cricket', 'Cricket', 4.8),
  WorkoutInfo('skip', 'Skipping', 11.8),
  WorkoutInfo('house', 'Housework', 3.5),
];

WorkoutInfo? workoutInfo(String id) {
  for (final w in workouts) {
    if (w.id == id) return w;
  }
  return null;
}

/// The kitchen: what's usually at home. Plans only use these.
class PantryItem {
  final String id;
  final String label;
  const PantryItem(this.id, this.label);
}

class PantryGroup {
  final String name;
  final List<PantryItem> items;
  const PantryGroup(this.name, this.items);
}

const pantryGroups = <PantryGroup>[
  PantryGroup('Grains & batter', [
    PantryItem('rice', 'Rice'), PantryItem('atta', 'Atta (wheat flour)'), PantryItem('batter', 'Idli / dosa batter'),
    PantryItem('rava', 'Rava'), PantryItem('ragi', 'Ragi flour'), PantryItem('oats', 'Oats'), PantryItem('riceflour', 'Idiyappam / rice flour'),
  ]),
  PantryGroup('Dal & pulses', [
    PantryItem('dal', 'Toor / moong dal'), PantryItem('chana', 'Chana / chickpeas'), PantryItem('greengram', 'Whole green gram'),
  ]),
  PantryGroup('Milk, eggs & meat', [
    PantryItem('milk', 'Milk'), PantryItem('curd', 'Curd'), PantryItem('paneer', 'Paneer'),
    PantryItem('eggs', 'Eggs'), PantryItem('chicken', 'Chicken'), PantryItem('fish', 'Fish'),
  ]),
  PantryGroup('Vegetables', [
    PantryItem('beans', 'Beans'), PantryItem('carrot', 'Carrot'), PantryItem('cabbage', 'Cabbage'), PantryItem('beetroot', 'Beetroot'),
    PantryItem('keerai', 'Keerai / spinach'), PantryItem('okra', 'Vendakkai / okra'), PantryItem('brinjal', 'Brinjal'),
    PantryItem('drumstick', 'Drumstick'), PantryItem('pumpkin', 'Pumpkin'), PantryItem('potato', 'Potato'),
    PantryItem('tomato', 'Tomato'), PantryItem('onion', 'Onion'), PantryItem('cucumber', 'Cucumber'),
  ]),
  PantryGroup('Fruit', [
    PantryItem('banana', 'Banana'), PantryItem('apple', 'Apple'), PantryItem('guava', 'Guava'), PantryItem('papaya', 'Papaya'),
    PantryItem('orange', 'Orange / sathukudi'), PantryItem('mango', 'Mango'), PantryItem('watermelon', 'Watermelon'),
  ]),
  PantryGroup('Nuts & others', [
    PantryItem('peanuts', 'Peanuts'), PantryItem('almonds', 'Almonds'), PantryItem('cashews', 'Cashews'), PantryItem('coconut', 'Coconut'),
  ]),
];

final pantryInfo = <String, PantryItem>{for (final g in pantryGroups) for (final i in g.items) i.id: i};

/// A typical South Indian kitchen, ticked in advance so setup is one tap.
const defaultPantry = <String>[
  'rice', 'atta', 'batter', 'rava', 'dal', 'chana', 'milk', 'curd', 'beans', 'carrot', 'cabbage',
  'tomato', 'onion', 'cucumber', 'drumstick', 'banana', 'guava', 'peanuts', 'coconut',
];

final vegIds = [for (final i in pantryGroups[3].items) i.id];
final fruitIds = [for (final i in pantryGroups[4].items) i.id];
const nutIds = ['peanuts', 'almonds', 'cashews'];
const sambarVeg = ['drumstick', 'brinjal', 'pumpkin', 'okra', 'carrot', 'beans', 'potato'];
const poriyalVeg = ['beans', 'carrot', 'cabbage', 'beetroot', 'keerai', 'okra', 'brinjal', 'potato', 'pumpkin'];

/// What each food needs: every group must have at least one item at home.
final needs = <String, List<List<String>>>{
  'idli': [['batter']], 'dosa': [['batter']], 'ragidosa': [['ragi']], 'pesarattu': [['greengram']], 'upma': [['rava']],
  'oats': [['oats'], ['milk']], 'chapati': [['atta']], 'rice': [['rice']], 'idiyappam': [['riceflour']],
  'sambar': [['dal'], vegIds], 'dal': [['dal']], 'kootu': [['dal'], vegIds], 'poriyal': [vegIds], 'avial': [vegIds, ['coconut']],
  'kurma': [vegIds], 'salad': [['cucumber', 'carrot', 'tomato', 'onion']], 'tchutney': [['tomato', 'onion', 'coconut']],
  'curd': [['curd']], 'buttermilk': [['curd']], 'milk': [['milk']], 'paneer': [['paneer']],
  'egg': [['eggs']], 'omelette': [['eggs']], 'chkcurry': [['chicken']], 'fishcurry': [['fish']], 'sundal': [['chana', 'greengram']],
};

/// One item in a planned meal: [portions], and whether it's the staple that
/// grows or shrinks to fit the budget. FRUIT and NUT come from the kitchen.
class PlanItem {
  final String id;
  final double qty;
  final bool flex;
  const PlanItem(this.id, this.qty, [this.flex = false]);
}

class MealOption {
  final String name;
  final String pref; // veg | egg | nonveg
  final List<PlanItem> items;
  const MealOption(this.name, this.pref, this.items);
}

const diet = <String, List<MealOption>>{
  'breakfast': [
    MealOption('Idli with sambar', 'veg', [PlanItem('idli', 3, true), PlanItem('sambar', 1), PlanItem('tchutney', 1)]),
    MealOption('Pesarattu with chutney', 'veg', [PlanItem('pesarattu', 2, true), PlanItem('tchutney', 1)]),
    MealOption('Ragi dosa with sambar', 'veg', [PlanItem('ragidosa', 2, true), PlanItem('sambar', 1)]),
    MealOption('Vegetable upma with curd', 'veg', [PlanItem('upma', 1, true), PlanItem('curd', 0.5)]),
    MealOption('Oats with milk and fruit', 'veg', [PlanItem('oats', 1, true), PlanItem('FRUIT', 1)]),
    MealOption('Dosa with chutney', 'veg', [PlanItem('dosa', 2, true), PlanItem('tchutney', 1)]),
    MealOption('Chapati with dal', 'veg', [PlanItem('chapati', 2, true), PlanItem('dal', 0.5)]),
    MealOption('Omelette with chapati', 'egg', [PlanItem('omelette', 1), PlanItem('chapati', 1, true), PlanItem('salad', 1)]),
    MealOption('Idli with boiled eggs', 'egg', [PlanItem('idli', 2, true), PlanItem('egg', 2), PlanItem('tchutney', 1)]),
  ],
  'lunch': [
    MealOption('Rice, sambar, poriyal and curd', 'veg', [PlanItem('rice', 1, true), PlanItem('sambar', 1), PlanItem('poriyal', 1), PlanItem('curd', 0.5)]),
    MealOption('Rice, dal, kootu and salad', 'veg', [PlanItem('rice', 1, true), PlanItem('dal', 1), PlanItem('kootu', 1), PlanItem('salad', 1)]),
    MealOption('Chapati, dal and poriyal', 'veg', [PlanItem('chapati', 2, true), PlanItem('dal', 1), PlanItem('poriyal', 1), PlanItem('salad', 1)]),
    MealOption('Rice, sambar and avial', 'veg', [PlanItem('rice', 1, true), PlanItem('sambar', 1), PlanItem('avial', 1)]),
    MealOption('Rice, dal and poriyal', 'veg', [PlanItem('rice', 1, true), PlanItem('dal', 1), PlanItem('poriyal', 1)]),
    MealOption('Chapati with eggs and dal', 'egg', [PlanItem('chapati', 2, true), PlanItem('egg', 2), PlanItem('dal', 0.5), PlanItem('poriyal', 1)]),
    MealOption('Rice with fish curry and poriyal', 'nonveg', [PlanItem('rice', 1, true), PlanItem('fishcurry', 1), PlanItem('poriyal', 1), PlanItem('salad', 1)]),
    MealOption('Rice with chicken curry and poriyal', 'nonveg', [PlanItem('rice', 1, true), PlanItem('chkcurry', 1), PlanItem('poriyal', 1)]),
  ],
  'snack': [
    MealOption('Sundal', 'veg', [PlanItem('sundal', 1, true)]),
    MealOption('Fruit and buttermilk', 'veg', [PlanItem('FRUIT', 1, true), PlanItem('buttermilk', 1)]),
    MealOption('A handful of nuts', 'veg', [PlanItem('NUT', 1, true)]),
    MealOption('Fruit with tea, no sugar', 'veg', [PlanItem('FRUIT', 1, true), PlanItem('blackcoffee', 1)]),
    MealOption('Fruit', 'veg', [PlanItem('FRUIT', 1, true)]),
    MealOption('Buttermilk and nuts', 'veg', [PlanItem('buttermilk', 1), PlanItem('NUT', 0.5, true)]),
    MealOption('Boiled eggs and buttermilk', 'egg', [PlanItem('egg', 2, true), PlanItem('buttermilk', 1)]),
  ],
  'dinner': [
    MealOption('Chapati, dal and salad', 'veg', [PlanItem('chapati', 2, true), PlanItem('dal', 1), PlanItem('salad', 1)]),
    MealOption('Dosa with sambar', 'veg', [PlanItem('dosa', 2, true), PlanItem('sambar', 1)]),
    MealOption('Idiyappam with veg kurma', 'veg', [PlanItem('idiyappam', 3, true), PlanItem('kurma', 1)]),
    MealOption('Ragi dosa, sambar and salad', 'veg', [PlanItem('ragidosa', 2, true), PlanItem('sambar', 1), PlanItem('salad', 1)]),
    MealOption('Chapati with poriyal and curd', 'veg', [PlanItem('chapati', 2, true), PlanItem('poriyal', 1), PlanItem('curd', 0.5)]),
    MealOption('Idli with egg and sambar', 'egg', [PlanItem('idli', 3, true), PlanItem('egg', 1), PlanItem('sambar', 1)]),
    MealOption('Chapati with chicken curry', 'nonveg', [PlanItem('chapati', 2, true), PlanItem('chkcurry', 1), PlanItem('salad', 1)]),
    MealOption('Chapati with fish curry', 'nonveg', [PlanItem('chapati', 2, true), PlanItem('fishcurry', 1), PlanItem('salad', 1)]),
  ],
};

const mealOffset = {'breakfast': 0, 'lunch': 2, 'snack': 1, 'dinner': 3};

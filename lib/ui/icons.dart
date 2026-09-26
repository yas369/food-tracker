// Every picture in the app is a Material icon, so it looks the same on every
// phone. No emoji anywhere: test/no_emoji_test.dart checks.

import 'package:flutter/material.dart';

import '../models.dart';

/// Meals by time of day: sunrise, midday sun, a bite, night.
IconData mealIcon(String id) => switch (id) {
      'breakfast' => Icons.wb_twilight,
      'lunch' => Icons.wb_sunny_outlined,
      'snack' => Icons.cookie_outlined,
      'dinner' => Icons.nights_stay_outlined,
      'checkin' => Icons.lock_clock_outlined,
      _ => Icons.restaurant_outlined,
    };

const _categoryIcons = <String, IconData>{
  'Tiffin': Icons.breakfast_dining_outlined,
  'Rice & meals': Icons.rice_bowl_outlined,
  'Curries & sides': Icons.soup_kitchen_outlined,
  'Egg, meat & fish': Icons.set_meal_outlined,
  'Snacks': Icons.tapas_outlined,
  'Sweets': Icons.cake_outlined,
  'Drinks': Icons.local_cafe_outlined,
  'Fruit': Icons.eco_outlined,
  'My foods': Icons.bookmark_border,
};

/// Foods that have a closer icon than their category's.
const _foodIcons = <String, IconData>{
  'egg': Icons.egg_outlined,
  'omelette': Icons.egg_alt_outlined,
  'chk65': Icons.kebab_dining_outlined,
  'friedrice': Icons.ramen_dining_outlined,
  'idiyappam': Icons.ramen_dining_outlined,
  'parotta': Icons.bakery_dining_outlined,
  'puffs': Icons.bakery_dining_outlined,
  'biscuit': Icons.cookie_outlined,
  'icecream': Icons.icecream_outlined,
  'salad': Icons.eco_outlined,
  'poriyal': Icons.eco_outlined,
  'ghee': Icons.water_drop_outlined,
  'oil': Icons.water_drop_outlined,
  'nuts': Icons.grain,
  'sundal': Icons.grain,
  'milk': Icons.local_drink_outlined,
  'buttermilk': Icons.local_drink_outlined,
  'juice': Icons.local_drink_outlined,
  'soda': Icons.local_drink_outlined,
  'tender': Icons.local_drink_outlined,
};

IconData categoryIcon(String cat) => _categoryIcons[cat] ?? Icons.restaurant_outlined;

IconData foodIcon(Food f) => _foodIcons[f.id] ?? categoryIcon(f.cat);

/// Hunger as a battery: full when you're not hungry, empty when starving.
IconData hungerIcon(int v) => switch (v) {
      1 => Icons.battery_full,
      2 => Icons.battery_5_bar,
      3 => Icons.battery_3_bar,
      4 => Icons.battery_1_bar,
      _ => Icons.battery_alert,
    };

IconData planIcon(String id) => switch (id) {
      'low' => Icons.trending_down,
      'high' => Icons.trending_up,
      _ => Icons.trending_flat,
    };

IconData activityIcon(double v) => v <= 1.2
    ? Icons.chair_outlined
    : v <= 1.375
        ? Icons.directions_walk
        : v <= 1.55
            ? Icons.directions_run
            : Icons.fitness_center;

IconData dietPrefIcon(String id) => switch (id) {
      'egg' => Icons.egg_outlined,
      'nonveg' => Icons.set_meal_outlined,
      _ => Icons.eco_outlined,
    };

IconData workoutIcon(String id) => switch (id) {
      'walk' => Icons.directions_walk,
      'yoga' => Icons.self_improvement,
      'surya' => Icons.wb_sunny_outlined,
      'jog' => Icons.directions_run,
      'cycle' => Icons.directions_bike,
      'gym' => Icons.fitness_center,
      'dance' => Icons.music_note_outlined,
      'swim' => Icons.pool,
      'badminton' => Icons.sports_tennis,
      'cricket' => Icons.sports_cricket,
      'skip' => Icons.sports_gymnastics,
      'house' => Icons.cleaning_services_outlined,
      _ => Icons.fitness_center,
    };

# Cap Breaker System - Complete Implementation Guide

## Overview

The Cap Breaker system allows players to exceed the physical attribute caps by applying up to 5 "cap breakers" per attribute. Each cap breaker adds a certain number of points to an attribute, with diminishing returns for each subsequent application.

## Key Concepts

### 1. Physical Cap vs Final Value
- **Physical Cap**: The maximum value an attribute can reach based on body configuration (height, weight, wingspan, position)
- **Base Value**: The value set by the user (cannot exceed physical cap)
- **Cap Breaker Gain**: Additional points from cap breakers
- **Final Value**: `baseValue + capBreakerGain` (can exceed physical cap, max 99)

### 2. Cap Breaker Gains
- Each attribute has 5 possible cap breaker applications (indexed 0-4)
- Gains are non-increasing: `gain[0] >= gain[1] >= gain[2] >= gain[3] >= gain[4]`
- Gains depend on the current rating and the build's archetype
- Two scenarios: `isolated` (other attrs at 25) and `near_caps` (other attrs at their caps)

### 3. Constraints
- Cap breakers cannot be applied if `baseValue >= physicalCap`
- Total with cap breakers cannot exceed 99
- Gains are looked up from `gains_by_rating.json` based on current rating

## Data Structure

### gains_by_rating.json
```json
{
  "scenario": "near_caps",  // or "isolated"
  "attribute": 0,           // attribute index (0-20)
  "rating": 75,             // current base rating
  "application": 0,         // which cap breaker (0-4)
  "gain": 8                 // points added
}
```

### Lookup Key Format
`$scenario-$attributeIndex-$rating`

Example: `near_caps-0-75` = gains for Close Shot at rating 75 in near_caps scenario

## Files

### Models
- `cap_breaker.dart` - `CapBreakerState` class for tracking applied cap breakers

### State Management
- `builder_state_v2.dart` - `BuilderStateV2` with integrated cap breaker logic

### UI
- `cap_breakers_panel_v2.dart` - Interactive panel for applying/removing cap breakers

### Data Loading
- `dataset_loader_v2.dart` - Updated loader with efficient cap breaker data structure

## Usage

### 1. Initialize State
```dart
final state = BuilderStateV2();
// State automatically loads cap breaker data on initialization
```

### 2. Get Attribute State
```dart
final attrState = state.getAttributeState(0); // Close Shot
print('Base: ${attrState.baseValue}');
print('CB Gain: ${attrState.capBreakerGain}');
print('Final: ${attrState.finalValue}');
print('Cap: ${attrState.baseCap}');
```

### 3. Check if Cap Breaker Can Be Applied
```dart
if (state.canApplyCapBreaker(0)) {
  // Can apply cap breaker to Close Shot
}
```

### 4. Apply Cap Breaker
```dart
final success = state.applyCapBreaker(0); // Apply to Close Shot
if (success) {
  print('Applied! New value: ${state.ratings[0]}');
}
```

### 5. Remove Cap Breaker
```dart
state.removeCapBreaker(0); // Remove last from Close Shot
// or
state.removeAllCapBreakers(0); // Remove all from Close Shot
```

### 6. Get Available Gains
```dart
final gains = state.getAvailableCapBreakerGains(0);
// Returns: [8, 7, 6, 5, 4] (example)
// gains[0] = gain for first cap breaker
// gains[1] = gain for second cap breaker
// etc.
```

## UI Integration

### Using CapBreakersPanelV2
```dart
ChangeNotifierProvider(
  create: (_) => BuilderStateV2(),
  child: Consumer<BuilderStateV2>(
    builder: (context, state, child) {
      return CapBreakersPanelV2();
    },
  ),
)
```

### Custom Implementation
```dart
Consumer<BuilderStateV2>(
  builder: (context, state, child) {
    return Column(
      children: [
        for (int i = 0; i < 21; i++)
          if (state.getAttributeState(i).hasCapBreakers)
            Text('${_attrName(i)}: +${state.capBreakerState.getTotalGain(i)}'),
      ],
    );
  },
)
```

## Overall Rating Calculation

The overall rating is calculated using the **final ratings** (base + cap breakers):

```dart
int get overallRating => _loader.getOvr(_position, _heightInches, _finalRatings).round();
```

This means cap breakers directly affect the overall rating.

## Badge Requirements

Badge requirements are checked against **final ratings** (including cap breakers):

```dart
final highestTier = _loader.getHighestQualifiedTier(badgeId, _finalRatings);
```

This allows cap breakers to unlock higher badge tiers.

## Save/Load

### Save Build
```dart
final json = state.toJson();
// json includes capBreakers map
```

### Load Build
```dart
state.fromJson(json);
// Cap breakers are automatically restored
```

## Example: Applying Cap Breakers

```dart
// User has Close Shot at 75 with cap of 80
// Available gains: [8, 7, 6, 5, 4]

// Apply first cap breaker
state.applyCapBreaker(0); // Close Shot: 75 + 8 = 83

// Apply second cap breaker
state.applyCapBreaker(0); // Close Shot: 75 + 8 + 7 = 90

// Apply third cap breaker
state.applyCapBreaker(0); // Close Shot: 75 + 8 + 7 + 6 = 96

// Can't apply fourth (would exceed 99)
state.canApplyCapBreaker(0); // false (96 + 5 = 101 > 99)
```

## Key Differences from v1

1. **Proper State Management**: Cap breakers are tracked separately from base ratings
2. **Interactive UI**: Users can apply/remove individual cap breakers
3. **Efficient Data Lookup**: Gains are pre-processed into a map structure
4. **Overall Rating Integration**: Cap breakers affect overall rating calculation
5. **Badge Integration**: Cap breakers can unlock higher badge tiers
6. **Save/Load Support**: Cap breaker state is persisted

## Troubleshooting

### Cap Breaker Not Applying
- Check if `baseValue < physicalCap`
- Check if `finalValue + gain <= 99`
- Check if gains data exists for this attribute/rating

### Gains Not Showing
- Verify `gains_by_rating.json` is loaded
- Check if scenario matches (near_caps vs isolated)
- Check if rating is within data range

### Overall Rating Not Updating
- Ensure `_recalculateFinalRatings()` is called after cap breaker changes
- Check that `_finalRatings` is used for overall calculation, not `_baseRatings`

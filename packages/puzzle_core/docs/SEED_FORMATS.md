# Seed Formats

This document describes the seed formats used for puzzle generation in the Brainiax Puzzles system.

## Overview

Seeds are strings that provide deterministic input for puzzle generation. They ensure that:
- The same seed always produces the same puzzle
- Different seeds produce different puzzles
- Seeds can encode metadata about the puzzle context

## Seed Types

### 1. Daily Challenge Seeds

**Format**: `"$puzzleId:${yyyyMMdd}"`

**Purpose**: Ensure all users get the same puzzle on the same day for a given puzzle type.

**Timezone**: UTC (Coordinated Universal Time)

**Examples**:
```
sudoku:20240101
nonogram:20240101
kakuro:20240101
```

**Implementation**:
```dart
String generateDailySeed(String puzzleId, DateTime date) {
  final utcDate = date.toUtc();
  final dateStr = '${utcDate.year.toString().padLeft(4, '0')}'
      '${utcDate.month.toString().padLeft(2, '0')}'
      '${utcDate.day.toString().padLeft(2, '0')}';
  return '$puzzleId:$dateStr';
}
```

**Usage**:
```dart
// Generate today's daily puzzle
final today = DateTime.now().toUtc();
final seed = generateDailySeed('sudoku', today);

// Generate specific date's daily puzzle
final specificDate = DateTime(2024, 1, 1).toUtc();
final seed = generateDailySeed('nonogram', specificDate);
```

### 2. Random Play Seeds

**Format**: `"$puzzleId:$userId:$sessionNonce"`

**Purpose**: Provide unique puzzles for individual users and sessions.

**Components**:
- `puzzleId`: The type of puzzle (e.g., "sudoku", "nonogram")
- `userId`: Unique identifier for the user
- `sessionNonce`: Unique identifier for the session

**Examples**:
```
sudoku:user123:session456
nonogram:user789:session101
kakuro:user456:session202
```

**Implementation**:
```dart
String generateRandomPlaySeed(String puzzleId, String userId, String sessionNonce) {
  return '$puzzleId:$userId:$sessionNonce';
}
```

**Usage**:
```dart
// Generate random play seed
final userId = 'user123';
final sessionNonce = 'session456';
final seed = generateRandomPlaySeed('sudoku', userId, sessionNonce);
```

### 3. Test Seeds

**Format**: `"test:$puzzleId:$testIndex"`

**Purpose**: Provide deterministic seeds for testing and validation.

**Examples**:
```
test:sudoku:0
test:nonogram:1
test:kakuro:2
```

**Implementation**:
```dart
String generateTestSeed(String puzzleId, int testIndex) {
  return 'test:$puzzleId:$testIndex';
}
```

### 4. Random Seeds

**Format**: `"random:$puzzleId:$timestamp:$random"`

**Purpose**: Provide truly random seeds for property testing and stress testing.

**Examples**:
```
random:sudoku:1704067200000:123456
random:nonogram:1704067201000:789012
```

**Implementation**:
```dart
String generateRandomSeed(String puzzleId) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = Random().nextInt(1000000);
  return 'random:$puzzleId:$timestamp:$random';
}
```

## Seed Parsing

### Parse Seed Components

```dart
class SeedComponents {
  final String puzzleId;
  final String? dateStr;
  final String? userId;
  final String? sessionNonce;
  final String? testIndex;
  final String? timestamp;
  final String? random;

  SeedComponents({
    required this.puzzleId,
    this.dateStr,
    this.userId,
    this.sessionNonce,
    this.testIndex,
    this.timestamp,
    this.random,
  });
}

SeedComponents parseSeed(String seed) {
  final parts = seed.split(':');
  
  if (parts.length < 2) {
    throw ArgumentError('Invalid seed format: $seed');
  }
  
  final puzzleId = parts[0];
  
  switch (puzzleId) {
    case 'test':
      if (parts.length != 3) {
        throw ArgumentError('Invalid test seed format: $seed');
      }
      return SeedComponents(
        puzzleId: parts[1],
        testIndex: parts[2],
      );
      
    case 'random':
      if (parts.length != 4) {
        throw ArgumentError('Invalid random seed format: $seed');
      }
      return SeedComponents(
        puzzleId: parts[1],
        timestamp: parts[2],
        random: parts[3],
      );
      
    default:
      if (parts.length == 2) {
        // Daily seed: puzzleId:date
        return SeedComponents(
          puzzleId: puzzleId,
          dateStr: parts[1],
        );
      } else if (parts.length == 3) {
        // Random play seed: puzzleId:userId:sessionNonce
        return SeedComponents(
          puzzleId: puzzleId,
          userId: parts[1],
          sessionNonce: parts[2],
        );
      } else {
        throw ArgumentError('Invalid seed format: $seed');
      }
  }
}
```

## Best Practices

### 1. Timezone Handling

Always use UTC for daily seeds to ensure consistency across timezones:

```dart
// ✅ Correct
final utcDate = DateTime.now().toUtc();
final seed = generateDailySeed('sudoku', utcDate);

// ❌ Incorrect - uses local timezone
final localDate = DateTime.now();
final seed = generateDailySeed('sudoku', localDate);
```

### 2. User ID Format

Use consistent user ID formats:

```dart
// ✅ Good - UUID format
final userId = 'user_123e4567-e89b-12d3-a456-426614174000';

// ✅ Good - Simple format
final userId = 'user123';

// ❌ Avoid - inconsistent formats
final userId = 'User-123';
```

### 3. Session Nonce Generation

Generate unique session nonces:

```dart
// ✅ Good - timestamp-based
final sessionNonce = 'session_${DateTime.now().millisecondsSinceEpoch}';

// ✅ Good - UUID-based
final sessionNonce = 'session_${Uuid().v4()}';

// ❌ Avoid - predictable values
final sessionNonce = 'session1';
```

### 4. Seed Validation

Always validate seeds before use:

```dart
bool isValidSeed(String seed) {
  try {
    parseSeed(seed);
    return true;
  } catch (e) {
    return false;
  }
}
```

## Migration and Compatibility

### Versioning

If seed formats need to change, use version prefixes:

```dart
// Version 1 (current)
sudoku:20240101

// Version 2 (future)
v2:sudoku:20240101
```

### Backward Compatibility

Maintain backward compatibility when possible:

```dart
SeedComponents parseSeed(String seed) {
  // Handle versioned seeds
  if (seed.startsWith('v2:')) {
    return parseSeedV2(seed.substring(3));
  }
  
  // Handle legacy seeds
  return parseSeedV1(seed);
}
```

## Security Considerations

### 1. User ID Privacy

Don't include sensitive information in user IDs:

```dart
// ✅ Good - anonymized
final userId = 'user_${hashUserEmail(email)}';

// ❌ Bad - includes email
final userId = 'user_${email}';
```

### 2. Session Nonce Security

Use cryptographically secure random values for session nonces:

```dart
// ✅ Good - secure random
final sessionNonce = 'session_${Random.secure().nextInt(1000000)}';

// ❌ Bad - predictable
final sessionNonce = 'session_${counter++}';
```

### 3. Seed Collision Prevention

Ensure seeds are unique within their context:

```dart
// ✅ Good - includes timestamp
final seed = 'random:sudoku:${DateTime.now().millisecondsSinceEpoch}:${random}';

// ❌ Bad - might collide
final seed = 'random:sudoku:${random}';
```

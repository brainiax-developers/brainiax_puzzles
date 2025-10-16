/// Result of a backtracking search operation.
/// 
/// Contains the solutions found and information about whether the search
/// was aborted early (e.g., when looking for unique solutions).
class BacktrackingResult<TVar, TValue> {
  /// The solutions found during the search.
  final List<Map<TVar, TValue>> solutions;
  
  /// Whether the search was aborted when a second solution was found.
  final bool abortedOnSecondSolution;

  const BacktrackingResult({
    required this.solutions,
    required this.abortedOnSecondSolution,
  });

  /// Whether at least one solution was found.
  bool get hasSolution => solutions.isNotEmpty;
  
  /// Whether exactly one unique solution was found (no second solution detected).
  bool get hasUniqueSolution => solutions.length == 1 && !abortedOnSecondSolution;
}

/// Function that generates the domain (possible values) for a variable.
/// 
/// Given a variable and the current assignment, returns the set of values
/// that are still possible for that variable.
typedef DomainGenerator<TVar, TValue> = Iterable<TValue> Function(
    TVar variable, Map<TVar, TValue> assignment);

/// Function that validates whether a value assignment is consistent.
/// 
/// Given a variable, a value, and the current assignment, returns true
/// if the assignment is consistent with all constraints.
typedef ConstraintValidator<TVar, TValue> = bool Function(
    TVar variable, TValue value, Map<TVar, TValue> assignment);

/// Function that provides a heuristic score for value ordering.
/// 
/// Lower scores indicate better values (Least Constraining Value heuristic).
/// This helps the solver try more promising values first.
typedef LcvHeuristic<TVar, TValue> = int Function(
    TVar variable, TValue value, Map<TVar, TValue> assignment);

/// A generic backtracking constraint satisfaction problem solver.
/// 
/// This solver implements the classic backtracking algorithm with several
/// optimizations including Most Constrained Variable (MCV) selection and
/// Least Constraining Value (LCV) ordering. It also includes domain caching
/// for improved performance.
/// 
/// Example usage:
/// ```dart
/// final solver = BacktrackingSolver<int, int>(
///   variables: [0, 1, 2],
///   domainGenerator: (variable, assignment) => [1, 2, 3],
///   isConsistent: (variable, value, assignment) {
///     // Check that no two variables have the same value
///     return !assignment.values.contains(value);
///   },
/// );
/// 
/// final result = solver.solve(stopOnSecondSolution: true);
/// if (result.hasUniqueSolution) {
///   print('Found unique solution: ${result.solutions.first}');
/// }
/// ```
class BacktrackingSolver<TVar, TValue> {
  /// The variables to be assigned values.
  final List<TVar> variables;
  
  /// Function that generates the domain for each variable.
  final DomainGenerator<TVar, TValue> domainGenerator;
  
  /// Function that validates constraint consistency.
  final ConstraintValidator<TVar, TValue> isConsistent;
  
  /// Optional heuristic for value ordering (LCV).
  final LcvHeuristic<TVar, TValue>? leastConstrainingValue;
  
  /// Maximum number of domains to cache for performance.
  final int maxCacheSize;

  /// Creates a new backtracking solver.
  /// 
  /// [variables] are the variables to be assigned values.
  /// [domainGenerator] provides possible values for each variable.
  /// [isConsistent] validates constraint satisfaction.
  /// [leastConstrainingValue] is an optional heuristic for value ordering.
  /// [maxCacheSize] limits the domain cache size to prevent memory issues.
  BacktrackingSolver({
    required Iterable<TVar> variables,
    required this.domainGenerator,
    required this.isConsistent,
    this.leastConstrainingValue,
    this.maxCacheSize = 1000,
  }) : variables = List<TVar>.from(variables);

  BacktrackingResult<TVar, TValue> solve({
    bool stopOnSecondSolution = false,
  }) {
    final List<Map<TVar, TValue>> solutions = <Map<TVar, TValue>>[];
    final Map<TVar, TValue> assignment = <TVar, TValue>{};
    final Set<TVar> unassigned = variables.toSet();
    _domainCache.clear();

    bool search() {
      if (unassigned.isEmpty) {
        solutions.add(Map<TVar, TValue>.from(assignment));
        if (stopOnSecondSolution && solutions.length >= 2) {
          return true;
        }
        return false;
      }

      final TVar variable = _selectVariable(unassigned, assignment);
      final List<TValue> domain =
          List<TValue>.from(_domainCache.remove(variable) ??
              domainGenerator(variable, assignment));
      if (domain.isEmpty) {
        return false;
      }
      if (leastConstrainingValue != null) {
        domain.sort((TValue a, TValue b) {
          final int scoreA =
              leastConstrainingValue!(variable, a, assignment);
          final int scoreB =
              leastConstrainingValue!(variable, b, assignment);
          return scoreA.compareTo(scoreB);
        });
      }

      unassigned.remove(variable);
      for (final TValue value in domain) {
        assignment[variable] = value;
        if (isConsistent(variable, value, assignment)) {
          final bool shouldStop = search();
          if (shouldStop) {
            return true;
          }
        }
        assignment.remove(variable);
      }
      unassigned.add(variable);
      return false;
    }

    final bool aborted = search();
    return BacktrackingResult<TVar, TValue>(
      solutions: stopOnSecondSolution && solutions.length > 2
          ? solutions.sublist(0, 2)
          : solutions,
      abortedOnSecondSolution: stopOnSecondSolution && (aborted || solutions.length >= 2),
    );
  }

  TVar _selectVariable(
    Set<TVar> unassigned,
    Map<TVar, TValue> assignment,
  ) {
    TVar? bestVar;
    int? bestDomainSize;
    List<TValue>? bestDomain;

    for (final TVar variable in unassigned) {
      final List<TValue> domain =
          List<TValue>.from(domainGenerator(variable, assignment));
      final int size = domain.length;
      if (bestVar == null || size < bestDomainSize!) {
        bestVar = variable;
        bestDomainSize = size;
        bestDomain = domain;
      }
      if (size == 1) {
        break;
      }
    }

    if (bestVar == null) {
      throw StateError('No variables left to assign');
    }

    // Cache the best domain for immediate reuse, but respect cache size limit.
    if (_domainCache.length < maxCacheSize) {
      _domainCache[bestVar] = bestDomain ??
          List<TValue>.from(domainGenerator(bestVar, assignment));
    }

    return bestVar;
  }

  final Map<TVar, List<TValue>> _domainCache = <TVar, List<TValue>>{};
}

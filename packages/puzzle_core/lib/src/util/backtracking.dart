class BacktrackingResult<TVar, TValue> {
  final List<Map<TVar, TValue>> solutions;
  final bool abortedOnSecondSolution;

  const BacktrackingResult({
    required this.solutions,
    required this.abortedOnSecondSolution,
  });

  bool get hasSolution => solutions.isNotEmpty;
  bool get hasUniqueSolution => solutions.length == 1 && !abortedOnSecondSolution;
}

typedef DomainGenerator<TVar, TValue> = Iterable<TValue> Function(
    TVar variable, Map<TVar, TValue> assignment);

typedef ConstraintValidator<TVar, TValue> = bool Function(
    TVar variable, TValue value, Map<TVar, TValue> assignment);

typedef LcvHeuristic<TVar, TValue> = int Function(
    TVar variable, TValue value, Map<TVar, TValue> assignment);

class BacktrackingSolver<TVar, TValue> {
  final List<TVar> variables;
  final DomainGenerator<TVar, TValue> domainGenerator;
  final ConstraintValidator<TVar, TValue> isConsistent;
  final LcvHeuristic<TVar, TValue>? leastConstrainingValue;

  BacktrackingSolver({
    required Iterable<TVar> variables,
    required this.domainGenerator,
    required this.isConsistent,
    this.leastConstrainingValue,
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

    // Cache the best domain for immediate reuse.
    _domainCache[bestVar] = bestDomain ??
        List<TValue>.from(domainGenerator(bestVar, assignment));

    return bestVar;
  }

  final Map<TVar, List<TValue>> _domainCache = <TVar, List<TValue>>{};
}

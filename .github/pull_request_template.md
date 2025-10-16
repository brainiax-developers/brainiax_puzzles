# Pull Request

## Description
Brief description of the changes made.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Performance improvement
- [ ] Documentation update
- [ ] Refactoring (no functional changes)

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Performance benchmarks run

## Performance Impact
If this PR affects performance, please provide benchmark results:

### Host CLI Benchmark Results
The CI will automatically run host benchmarks and comment with results. Look for the "📊 Performance Benchmark Results" comment.

### Device Benchmark Results
For device-specific performance data, please attach JSON output from the in-app benchmark:

1. **Access the benchmark screen**: Tap "Puzzle Home" 5 times quickly in the app
2. **Run a benchmark**: Use default settings (stub engine, medium difficulty, 9x9, count 100)
3. **Export results**: Use the download button to save the JSON file
4. **Attach to PR**: Drag and drop the JSON file into this PR description

**Expected JSON filename format**: `benchmark_stub_YYYY-MM-DDTHH-mm-ss.json`

### Performance Checklist
- [ ] No significant regression in host benchmarks (>20% threshold)
- [ ] Device benchmark results attached (if applicable)
- [ ] Performance impact documented in description

## Screenshots/Videos
If applicable, add screenshots or videos to help explain your changes.

## Checklist
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published

## Additional Notes
Any additional information that reviewers should know.

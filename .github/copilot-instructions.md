# GitHub Copilot Instructions for Our Laravel Application

This document contains important guidelines, patterns, and fixes that must be followed when making changes to this Laravel application's codebase. These instructions ensure code quality, consistency, and prevent the regression of previously fixed issues.

## Getting Things Done

- Always check for existing issues or feature requests before starting work.
- Always when I ask you to work on an issue number, use the GitHub CLI to fetch the issue information.
- Always use the gh command line tool to interact with GitHub issues and pull requests. You can read issue content using this command:
  ```bash
  timeout 5 gh issue view <issue_number> --json title,body,author,createdAt,updatedAt,state,labels,comments
  ```
- Always use the issue number in commit messages and PR titles.
- Always create a new branch for each issue or feature and name it according to the issue number (e.g., issue-1234-feature-name).
- Always update the issue status to "In Progress" when starting work.
- Always update the issue status to "Done" when the work is complete and the PR is merged.
- Always update the issue with comments about the progress and decisions made during development.
- Always create a pull request (PR) for code review before merging into the main branch.
- Always assign the PR to me for review.
- Always link the PR to the issue it resolves.
- Always include a clear description of changes in the PR.

## 🔧 Code Quality Standards

### Pint & Larastan Compliance

- **ALWAYS** maintain zero Pint styling issues.
- **ALWAYS** maintain zero Larastan static analysis errors.
- Before completing any task, run both tools:

```bash
# Run the linter to fix styling issues
./vendor/bin/pint

# Run static analysis to find potential bugs
./vendor/bin/phpstan analyse
```

### Use Statement Management

- Remove unused use statements immediately. (pint can do this automatically).
- Group use statements according to PSR-12: class, function, then const imports, each block alphabetized. pint handles this automatically.
- Always import the specific class. Do not rely on full namespaces in your code.

### Type Declarations

- **ALL** methods must have return type declarations (e.g., `: void`, `: User`, `: Illuminate\Http\JsonResponse`).
- **ALL** method parameters must have type declarations.
- Use nullable types (`?Type`) for parameters that can be null.
- Use `mixed` sparingly and only when the type cannot be known.

**Common patterns:**
```php
use App\Models\User;
use Illuminate\Http\Request;

public function updateUser(Request $request, int $userId): User
{
    // ...
}

public function scheduleReport(string $reportName, ?string $recipient = null): void
{
    // ...
}

public function processData(array|string $data): mixed
{
    // ...
}
```
## 🔄 Queue & Job Patterns

### Queue and Job Management (Critical Fix)

When working with background tasks, delegate them to Laravel's queue system to avoid blocking web requests.

```php
// In a Controller or Service
use App\Jobs\ProcessPodcast;

public function store(Request $request)
{
    // ... validation ...

    // Dispatch a job to the queue
    ProcessPodcast::dispatch($podcast);

    return response()->json(['message' => 'Podcast processing has been scheduled.']);
}

// The Job itself
class ProcessPodcast implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(public Podcast $podcast) {}

    public function handle(): void
    {
        // Business logic here.
        // This code runs in a separate worker process.
        // Use dependency injection for services.
    }
}
```

### Safe External API Calls

Always use safe wrappers for external API operations, especially in jobs or services.

```php
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Http\Client\RequestException;

class ExternalApiService
{
    /**
     * Safely invoke an external API with proper error handling.
     */
    public function safeApiRequest(string $url, array $payload): ?array
    {
        try {
            $response = Http::timeout(15)->post($url, $payload);

            // Throw an exception on 4xx or 5xx responses
            $response->throw();

            return $response->json();
        } catch (RequestException $e) {
            Log::error('External API request failed', [
                'url' => $url,
                'error' => $e->getMessage(),
                'response_body' => $e->response->body()
            ]);
            
            // Optionally, dispatch a notification or retry job
            // For now, return null to indicate failure
            return null;
        }
    }
}
```
## 📁 File-Specific Guidelines

### Configuration Files

- **pint.json**: Any changes to styling rules must be reviewed and documented.
- **composer.json**: Prefer running `composer require` to add dependencies to ensure composer.lock is updated correctly.
- **phpstan.neon**: Static analysis rules should only be loosened with explicit approval.

### Test Files

- Prefix unused variables with an underscore: `$_unused_var`.
- Change bare `catch (Throwable $e)` to `catch (SpecificException $e)` whenever possible.
- Write tests that cover both the "happy path" and expected failure scenarios (e.g., validation errors, exceptions).

### Laravel Component Guidelines

- **Controllers**: Keep controllers thin. Their only job is to handle HTTP requests, validate input (using Form Requests), and return a response. All business logic should be in Service Classes or Action classes.
- **Models**: Models should represent database tables and their relationships. Use them for Eloquent scopes, accessors, and mutators. Avoid placing complex business logic here.
- **Service Classes**: All core business logic should reside in service classes. They should be stateless (if possible), injectable via the service container, and easily testable.## 🚨 Critical Issues to Avoid

### Never Do These:

- Don't put complex business logic in Controllers or Models.
- Don't run long-running tasks in a web request. Use queues.
- Don't use a generic `catch (Throwable $e)` without logging the specific error or re-throwing a more specific exception.
- Don't leave unused use statements. Run `./vendor/bin/pint`.
- Don't write raw SQL queries. Use the Eloquent ORM or the Query Builder.
- Don't forget type declarations on new methods and parameters.

### Error Patterns Fixed:

- **"Maximum execution time exceeded"** - Move the long-running task to a queued Job.
- **N+1 Query problems** - Use eager loading (`with()`) when fetching models with their relationships.
- **Inconsistent responses** - Use dedicated API Resources to format JSON responses consistently.## 🧪 Testing Requirements

### Before Completing Tasks:

- **MANDATORY**: Run all relevant tests: `php artisan test`
- **MANDATORY**: Run linting and static analysis: `./vendor/bin/pint` and `./vendor/bin/phpstan analyse`
- **RECOMMENDED**: Use `make quality-check` to run all three checks in sequence
- Test specific functionality manually if it involves complex UI or integrations.

### Test Patterns:

- Mock external dependencies (APIs, Mailers) using Laravel's built-in fakes (`Http::fake()`, `Mail::fake()`).
- Use Pest or PHPUnit for feature and unit tests.
- Test both success and error paths (e.g., test for a 200 OK and a 422 Unprocessable Entity response).
- Validate error handling and that appropriate exceptions are thrown.## 📊 Observability & Monitoring

### DataDog Integration:

- Maintain application performance monitoring (APM) traces.
- Use proper span annotations to add context to traces.
- Don't break existing metric collection.
- Test observability endpoints after changes.

### Logging:

- Use Laravel's Log facade with consistent, structured logging.
- Include relevant context (user_id, request_id, etc.).
- Use appropriate log levels (Log::info, Log::warning, Log::error).
- Never log sensitive information (passwords, API keys, PII).

```php
use Illuminate\Support\Facades\Log;

Log::info('User created a new report.', ['user_id' => $user->id, 'report_id' => $report->id]);
```
## 🔄 Development Workflow

### Code Changes:

- Understand the existing patterns before modifying.
- Maintain backward compatibility unless explicitly changing APIs.
- Update type declarations when adding or changing parameters.
- Verify related features (e.g., queued jobs, event listeners) still work.
- Verify observability and logging still work as expected.

### Documentation:

- Update relevant docs in docs/ when making significant changes.
- Keep README.md current with setup instructions.
- Document any new environment variables or configuration in .env.example.## 📝 Task Completion Protocol

### When Completing Any Task:

- **ALWAYS** create an entry in docs/vibe_history/ with the format: `XXXX_YYYY_MM_DD_task_summary.md`
  - XXXX = incremental number (0001, 0002, 0003, etc.)
  - Include date and brief task description in the filename.
  - Document what was requested (feature? bug? improvement?), what was changed, why, and any important notes.

- **ALWAYS** run final verification before considering the task complete:
  ```bash
  # Run individual commands:
  ./vendor/bin/pint
  ./vendor/bin/phpstan analyse
  php artisan test
  
  # OR use the Makefile (recommended):
  make quality-check
  ```
  
- **MANDATORY**: All three quality checks MUST pass before task completion:
  - ✅ **Pint**: Zero styling issues
  - ✅ **PHPStan**: Zero static analysis errors  
  - ✅ **Tests**: All tests must pass
  
- **NEVER** complete a task with failing quality checks. Fix all issues first.

- **ALWAYS** summarize what was accomplished and any remaining items.

### Vibe History Format:

```markdown
# Task: [Brief Description]
**Date**: YYYY-MM-DD
**Completed by**: GitHub Copilot

## What Was Requested
- Description of the task or issue.
- Link to the issue or feature request if applicable.
- Context of the request (bug fix, feature addition, etc.).
- Any specific requirements or constraints.

## What Was Done
- Bullet points of main changes.
- Files modified.
- Issues resolved.

## Technical Details
- Specific implementation notes (e.g., "Used a Form Request for validation," "Delegated logic to a new `ReportingService`").
- Patterns used.
- Dependencies added/removed (and why).

## Verification
- Tests run and results.
- Linting and static analysis status.
- Any manual testing performed.

## Notes for Future
- Anything important to remember.
- Related areas that might need attention.
- Follow-up tasks if any.
```
- Issues resolved.

## Technical Details
- Specific implementation notes (e.g., "Used a Form Request for validation," "Delegated logic to a new `ReportingService`").
- Patterns used.
- Dependencies added/removed (and why).

## Verification
- Tests run and results.
- Linting and static analysis status.
- Any manual testing performed.

## Notes for Future
- Anything important to remember.
- Related areas that might need attention.
- Follow-up tasks if any.
## 🔄 Maintenance Instructions

### For Future Copilot Sessions:

- **ALWAYS** read this file before making significant changes.
- **ALWAYS** update this file when new patterns emerge or issues are fixed.
- **ALWAYS** maintain the historical context of fixes.
- **ALWAYS** preserve the Queue/Job patterns for background tasks.
- **ALWAYS** keep type declarations comprehensive and accurate.
- **ALWAYS** update architecture documentation when system changes are made.
- **ALWAYS** update observability documentation when monitoring changes are made.

### Documentation Maintenance Requirements:

#### Architecture Updates: Update docs/ARCHITECTURE.md when:
- New services or major components are added.
- External dependencies change (e.g., new SaaS provider).
- Database schema modifications are made.
- API endpoints are added/modified/removed.
- Queue or worker configuration changes.

#### Observability Updates: Update docs/OBSERVABILITY.md when:
- New custom metrics are added or removed.
- Alert thresholds are modified.
- Logging patterns are updated.
- Tracing configuration is modified.
- DataDog integration changes.

#### Developer Guide Updates: Update docs/DEVELOPER_GUIDE.md when:
- Development workflow changes (setup, testing, deployment).
- New dependencies are added (composer.json).
- Configuration files are modified (pint.json, phpstan.neon).
- CI/CD pipeline changes.
- New environment variables or setup requirements are added.
- Code quality standards or linting rules change.
- New Artisan commands or scripts are added.

### When to Update This Document:
- If the system architecture changes significantly.
- New linting or static analysis rules are added.
- New coding patterns are established (e.g., using Action classes).
- Critical bugs are fixed that shouldn't be repeated.
- Development workflow changes.
- New testing requirements are added.

## 📋 Update Reminder
This document should be updated whenever new patterns, fixes, or guidelines are established. Keep it current to ensure consistent code quality and prevent the regression of fixed issues. Each update should be documented in the git commit message and include the reason for the change.

## 🎯 Success Criteria
When this document is properly followed, the codebase should maintain zero Pint issues, zero Larastan errors, all tests passing, and proper use of Laravel's queue system for background tasks.
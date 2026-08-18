# qa-toolkit

> Engineering toolkit for QA Automation Engineers.

`qa-toolkit` is a Go-based CLI that automates common QA engineering tasks around automated test execution, test result analysis, flaky test detection, test data generation, and CI/CD quality gates.

The project is built as a practical engineering tool rather than a test framework or a collection of shell scripts.

```text
Test Framework
      │
      ▼
 Test Results
      │
      ▼
    qactl
      │
 ┌────┼──────────────┐
 ▼    ▼              ▼
Analyze Flaky    Quality Gate
 │    │              │
 └────┴──────────────┘
           │
           ▼
          CI
```

## Why?

Automated tests answer an important question:

> Did the tests pass?

But engineering teams often need more information:

* How many tests actually passed?
* What is the failure rate?
* Which tests are the slowest?
* Which tests are potentially flaky?
* Did the test suite meet the required quality threshold?
* Should the CI pipeline continue?
* How did the test suite behave across multiple runs?

These tasks are often solved with a combination of shell scripts, CI configuration, test framework-specific tooling, and manual analysis.

`qactl` provides a single CLI for these operations.

The tool is intentionally positioned **after the test runner**:

```text
Playwright / JUnit / other framework
                │
                ▼
          Test results
                │
                ▼
             qactl
                │
        ┌───────┼────────┐
        ▼       ▼        ▼
     analyze  flaky    quality
                        gate
```

`qa-toolkit` does not replace Playwright, JUnit, or other test frameworks. It consumes their results and provides additional engineering capabilities around them.

---

## Features

### Test Result Analysis

Analyze automated test results and calculate:

* total tests;
* passed tests;
* failed tests;
* skipped tests;
* pass rate;
* failure rate;
* total duration;
* slowest tests;
* potential flaky tests.

Currently supported:

* JUnit XML.

Planned:

* Playwright JSON;
* Allure results.

---

### Flaky Test Detection

Identify tests that demonstrate unstable behaviour based on multiple signals:

* pass/fail ratio;
* number of executions;
* retry behaviour;
* failure consistency;
* duration variance.

The detector is intentionally heuristic.

A test that fails once is not automatically considered flaky.

For example:

```text
Run 1 → PASS
Run 2 → PASS
Run 3 → FAIL
Run 4 → PASS
Run 5 → PASS
```

is a stronger flaky candidate than:

```text
Run 1 → FAIL
Run 2 → FAIL
Run 3 → FAIL
Run 4 → FAIL
Run 5 → FAIL
```

The second case is more likely to represent a consistently broken test rather than flaky behaviour.

See [Flaky Detection](docs/flaky-detection.md) for details.

---

### Quality Gates

Use test results as a CI/CD quality gate.

Example configuration:

```yaml
quality_gates:
  min_pass_rate: 98
  max_flaky_rate: 2
```

Run:

```bash
qactl analyze ./test-results --quality-gate
```

If the requirements are not met:

```text
Quality Gate: FAILED

Pass rate: 96.4%
Required:   98.0%

Process exited with code 4.
```

This makes `qactl` suitable for automated CI pipelines.

---

### Test Data Generation

Generate deterministic test data for common QA scenarios.

Example:

```bash
qactl generate-data --users 1000 --flights 500
```

Output:

```text
Generated test data

Users:      1000
Flights:     500
Passengers: 1000
```

Generated data can be written to:

```text
testdata/
├── users.json
├── flights.json
└── passengers.json
```

Planned output targets include PostgreSQL.

---

## Architecture

The project follows a layered architecture with a normalized domain model between external test-result formats and analysis logic.

```text
                    ┌─────────────┐
                    │    qactl    │
                    │     CLI     │
                    └──────┬──────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │   Application   │
                  │    Services     │
                  └────────┬────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
           Parser       Analyzer    Quality Gate
              │            │            │
              ▼            │            │
        TestResult Model ──┴────────────┘
```

### Parser layer

External formats are converted into a common internal representation.

```text
JUnit XML ────────┐
                  │
Playwright JSON ──┼──► TestResult
                  │
Allure ───────────┘
```

This keeps the analysis layer independent from a specific test framework.

### Domain layer

The domain contains the core concepts used by the application:

* `TestResult`;
* `TestRun`;
* `TestAnalysis`;
* `FlakyCandidate`;
* quality gate results.

Domain objects do not depend on CLI or external file formats.

### Analyzer

The analyzer calculates test-suite statistics and identifies important characteristics of the run.

### Flaky detector

The flaky detector evaluates historical execution data and produces candidates with a confidence/instability score.

### Quality gate

The quality gate converts analysis results into a CI-friendly decision:

```text
PASS → exit code 0
FAIL → exit code 4
```

---

## Repository Structure

```text
qa-toolkit/
│
├── cmd/
│   └── qactl/
│       └── main.go
│
├── internal/
│   ├── cli/
│   ├── config/
│   ├── domain/
│   ├── parser/
│   ├── analyzer/
│   ├── flaky/
│   ├── qualitygate/
│   ├── reporter/
│   └── errors/
│
├── configs/
├── testdata/
├── examples/
├── docs/
├── scripts/
│
├── .github/
│   └── workflows/
│
├── Dockerfile
├── Makefile
├── go.mod
├── go.sum
├── qactl.example.yaml
└── README.md
```

The project intentionally uses `internal/` for application packages.

The code is not designed as a reusable Go framework at this stage, so a large public `pkg/` layer would add unnecessary API surface and complexity.

---

## Installation

### From source

Requirements:

* Go 1.26+
* Git

Clone the repository:

```bash
git clone https://github.com/<your-username>/qa-toolkit.git
cd qa-toolkit
```

Build:

```bash
make build
```

Or directly:

```bash
go build -o bin/qactl ./cmd/qactl
```

Run:

```bash
./bin/qactl --help
```

On Windows:

```powershell
.\bin\qactl.exe --help
```

---

## Quick Start

### 1. Initialize configuration

```bash
qactl init
```

This creates a local configuration file based on the project defaults.

---

### 2. Analyze test results

```bash
qactl analyze ./test-results
```

Example:

```text
QA Test Analysis

Tests
  Total:       428
  Passed:      419
  Failed:        5
  Skipped:       4

Pass rate:      97.9%
Failure rate:    1.2%

Duration:       4m 32s

Slowest tests
  1. booking.spec.ts       12.4s
  2. payment.spec.ts        9.8s
  3. search.spec.ts         8.2s
```

---

### 3. Detect flaky tests

```bash
qactl flaky ./test-results
```

Example:

```text
Flaky Test Analysis

Candidates: 3

Test                    Pass Rate    Executions
booking.spec.ts            80.0%          10
payment.spec.ts            83.3%          12
search.spec.ts             90.0%          10
```

---

### 4. Run quality gates

```bash
qactl analyze ./test-results --quality-gate
```

Example:

```text
Quality Gate

PASS  Pass rate >= 98%
FAIL  Flaky rate <= 2%

Pass rate: 96.4%
Required:   98.0%

Quality Gate: FAILED
```

The command exits with a non-zero status so that CI can fail the pipeline.

---

## Commands

### `qactl init`

Creates a project configuration.

```bash
qactl init
```

---

### `qactl analyze`

Analyzes test results.

```bash
qactl analyze ./test-results
```

Options include:

```text
--format
--config
--quality-gate
--output
--verbose
```

---

### `qactl flaky`

Analyzes test execution history and identifies potential flaky tests.

```bash
qactl flaky ./test-results
```

---

### `qactl generate-data`

Generates QA test data.

```bash
qactl generate-data --users 1000 --flights 500
```

---

### `qactl report`

Generates a report from test results.

Planned output formats:

```text
console
json
markdown
html
```

Example:

```bash
qactl report ./test-results --format json
```

---

### `qactl test`

Provides test execution orchestration.

The command is planned to integrate test execution with result analysis and quality gates.

```bash
qactl test
```

---

## Configuration

Example:

```yaml
project:
  name: flight-booking

tests:
  results: ./test-results

quality_gates:
  min_pass_rate: 98
  max_flaky_rate: 2

data:
  output: ./testdata
```

Configuration precedence:

```text
CLI flags
    ↓
Environment variables
    ↓
qactl.yaml
    ↓
Default values
```

Configuration is validated before command execution.

Invalid configuration results in a dedicated non-zero exit code.

See [Configuration](docs/configuration.md).

---

## Quality Gates

Quality gates allow test results to become an explicit CI/CD decision.

Example:

```yaml
quality_gates:
  min_pass_rate: 98
  max_flaky_rate: 2
```

The following command evaluates the gate:

```bash
qactl analyze ./test-results --quality-gate
```

Example:

```text
Quality Gate: PASSED
```

or:

```text
Quality Gate: FAILED

Pass rate: 96.4%
Required:   98.0%
```

Exit codes:

| Code | Meaning                |
| ---: | ---------------------- |
|  `0` | Success                |
|  `1` | General error          |
|  `2` | Invalid CLI usage      |
|  `3` | Invalid configuration  |
|  `4` | Quality gate failed    |
|  `5` | Input or parsing error |

The exact exit code is intentionally stable and can be consumed by CI systems.

---

## CI/CD

`qactl` is designed to work as a CI pipeline component.

Example workflow:

```text
Checkout
   │
   ▼
Setup Go
   │
   ▼
Build qactl
   │
   ▼
Run automated tests
   │
   ▼
Collect test results
   │
   ▼
qactl analyze
   │
   ▼
Quality Gate
   │
   ├── PASS → pipeline continues
   │
   └── FAIL → pipeline fails
```

Example GitHub Actions step:

```yaml
- name: Analyze test results
  run: |
    ./qactl analyze ./test-results --quality-gate
```

Test artifacts can be uploaded separately by the CI workflow.

See `.github/workflows/ci.yml`.

---

## Docker

Docker is provided as an optional distribution method.

The primary distribution model is a standalone Go binary.

Build the image:

```bash
docker build -t qa-toolkit .
```

Run analysis against a mounted results directory:

```bash
docker run --rm \
  -v "$(pwd)/test-results:/data" \
  qa-toolkit analyze /data
```

Docker is not required for local development.

---

## Testing

`qa-toolkit` tests itself.

The project uses several levels of testing.

### Unit tests

Core business logic is covered by unit tests:

```bash
go test ./...
```

### Race detector

```bash
go test -race ./...
```

### Integration tests

Integration tests verify interactions between parsers, domain models, analyzers, and filesystem fixtures.

### CLI tests

CLI tests verify:

* command behaviour;
* output;
* error handling;
* exit codes.

### Table-driven tests

Go table-driven tests are used where multiple input/output scenarios are required.

Example scenarios include:

```text
all tests passed
some tests failed
skipped tests
empty result set
invalid JUnit XML
quality gate passed
quality gate failed
insufficient data for flaky detection
```

---

## Development

Format code:

```bash
make fmt
```

Run tests:

```bash
make test
```

Run race detector:

```bash
make test-race
```

Run static analysis:

```bash
make lint
```

Build:

```bash
make build
```

Run benchmarks:

```bash
make benchmark
```

Install locally:

```bash
make install
```

---

## Code Quality

The project uses standard Go tooling:

```text
gofmt
go vet
go test
go test -race
golangci-lint
```

Each tool has a specific purpose:

* `gofmt` — consistent source formatting;
* `go vet` — detects suspicious constructs;
* `go test` — functional correctness;
* `go test -race` — detects data races;
* `golangci-lint` — additional static analysis.

The same checks are executed in CI.

---

## Benchmarks

Performance-sensitive components include benchmarks for:

* JUnit XML parsing;
* large test result analysis;
* test data generation.

Run:

```bash
go test -bench=. -benchmem ./...
```

Example benchmark targets:

```text
BenchmarkJUnitParser
BenchmarkAnalyzeResults
BenchmarkGenerate100KUsers
```

The goal is not premature optimization but establishing measurable performance characteristics for large QA datasets.

---

## Design Principles

### Small core

The project intentionally avoids unnecessary dependencies and infrastructure.

### Explicit boundaries

Parsing, analysis, reporting, configuration, and CLI concerns are separated.

### Framework agnostic

The analyzer works with normalized test results rather than directly depending on a particular test framework.

### CI friendly

Commands provide deterministic exit codes and machine-friendly behaviour.

### Testable by design

Core logic does not depend on the CLI and can be tested independently.

### Engineering over abstraction

Interfaces and abstractions are introduced when they solve an actual problem rather than to make the architecture look more complex.

---

## Roadmap

### v0.1 — Core Analyzer

* [x] CLI foundation
* [x] configuration
* [x] JUnit parser
* [x] test result domain model
* [x] test result analyzer
* [x] flaky detection foundation
* [x] quality gates
* [x] console reporting
* [x] unit tests
* [x] integration tests
* [x] CI

### v0.2 — QA Toolkit

* [ ] Playwright JSON support
* [ ] test data generator
* [ ] JSON reporting
* [ ] Markdown/HTML reports
* [ ] improved flaky analysis
* [ ] Docker image
* [ ] release binaries

### v0.3 — Historical Analytics

* [ ] PostgreSQL storage
* [ ] historical test runs
* [ ] flaky test history
* [ ] duration trends
* [ ] failure trends
* [ ] performance regression detection

### v1.0 — CI Engineering Platform

* [ ] stable CLI interface
* [ ] JUnit + Playwright support
* [ ] historical analytics
* [ ] test data generation
* [ ] HTML reports
* [ ] Docker distribution
* [ ] CI documentation
* [ ] release automation

Future ideas:

* Allure integration
* Slack notifications
* GitHub PR comments
* PostgreSQL test data generation
* API testing helpers

---

## Project Status

`qa-toolkit` is an actively developed personal engineering project.

The project is intentionally developed incrementally:

```text
Core
  ↓
Analysis
  ↓
Quality Gates
  ↓
Flaky Detection
  ↓
Test Data
  ↓
Historical Analytics
```

The goal is to keep each stage useful and production-oriented without introducing infrastructure that is not yet justified by the problem.

---

## License

MIT

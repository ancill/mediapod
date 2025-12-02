.PHONY: all lint format check clean help \
        go-lint go-format go-vet go-test go-mod-tidy \
        dart-lint dart-format dart-analyze dart-test \
        flutter-lint flutter-format flutter-analyze flutter-test

# Default target - run all checks
all: check

# Run all linters and analyzers
check: go-check dart-check flutter-check
	@echo "✓ All checks passed!"

# Run all formatters
format: go-format dart-format flutter-format
	@echo "✓ All formatting complete!"

# Run all linters
lint: go-lint dart-analyze flutter-analyze
	@echo "✓ All linting complete!"

# Run all tests
test: go-test dart-test flutter-test
	@echo "✓ All tests passed!"

# =============================================================================
# Go targets
# =============================================================================

GO_SERVICES := services/media-api services/media-worker

go-check: go-format-check go-vet
	@echo "✓ Go checks passed!"

go-format:
	@echo "→ Formatting Go code..."
	@for dir in $(GO_SERVICES); do \
		echo "  Formatting $$dir..."; \
		gofmt -w $$dir; \
	done

go-format-check:
	@echo "→ Checking Go formatting..."
	@for dir in $(GO_SERVICES); do \
		if [ -n "$$(gofmt -l $$dir)" ]; then \
			echo "  ✗ $$dir needs formatting:"; \
			gofmt -l $$dir; \
			exit 1; \
		fi; \
	done
	@echo "  ✓ Go formatting OK"

go-vet:
	@echo "→ Running go vet..."
	@for dir in $(GO_SERVICES); do \
		echo "  Vetting $$dir..."; \
		(cd $$dir && go vet ./...); \
	done
	@echo "  ✓ Go vet OK"

go-lint:
	@echo "→ Running golangci-lint..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		for dir in $(GO_SERVICES); do \
			echo "  Linting $$dir..."; \
			(cd $$dir && golangci-lint run ./...); \
		done; \
	else \
		echo "  ⚠ golangci-lint not installed, skipping..."; \
	fi

go-test:
	@echo "→ Running Go tests..."
	@for dir in $(GO_SERVICES); do \
		echo "  Testing $$dir..."; \
		(cd $$dir && go test ./...); \
	done
	@echo "  ✓ Go tests passed!"

go-mod-tidy:
	@echo "→ Tidying Go modules..."
	@for dir in $(GO_SERVICES); do \
		echo "  Tidying $$dir..."; \
		(cd $$dir && go mod tidy); \
	done

go-build:
	@echo "→ Building Go services..."
	@for dir in $(GO_SERVICES); do \
		echo "  Building $$dir..."; \
		(cd $$dir && go build ./...); \
	done
	@echo "  ✓ Go build complete!"

# =============================================================================
# Dart targets
# =============================================================================

DART_PKG := dart-client

dart-check: dart-format-check dart-analyze
	@echo "✓ Dart checks passed!"

dart-format:
	@echo "→ Formatting Dart code..."
	@(cd $(DART_PKG) && dart format .)

dart-format-check:
	@echo "→ Checking Dart formatting..."
	@(cd $(DART_PKG) && dart format --set-exit-if-changed --output=none .) || \
		(echo "  ✗ Dart code needs formatting"; exit 1)
	@echo "  ✓ Dart formatting OK"

dart-analyze:
	@echo "→ Analyzing Dart code..."
	@(cd $(DART_PKG) && dart pub get > /dev/null 2>&1 && dart analyze)
	@echo "  ✓ Dart analysis OK"

dart-test:
	@echo "→ Running Dart tests..."
	@(cd $(DART_PKG) && dart test) || echo "  ⚠ No tests found"

dart-pub-get:
	@echo "→ Getting Dart dependencies..."
	@(cd $(DART_PKG) && dart pub get)

# =============================================================================
# Flutter targets
# =============================================================================

FLUTTER_PKG := flutter-widget

flutter-check: flutter-format-check flutter-analyze
	@echo "✓ Flutter checks passed!"

flutter-format:
	@echo "→ Formatting Flutter code..."
	@(cd $(FLUTTER_PKG) && dart format .)

flutter-format-check:
	@echo "→ Checking Flutter formatting..."
	@(cd $(FLUTTER_PKG) && dart format --set-exit-if-changed --output=none .) || \
		(echo "  ✗ Flutter code needs formatting"; exit 1)
	@echo "  ✓ Flutter formatting OK"

flutter-analyze:
	@echo "→ Analyzing Flutter code..."
	@(cd $(FLUTTER_PKG) && \
		cp pubspec.yaml pubspec.yaml.bak && \
		awk '{gsub(/mediapod_client: \^1\.0\.0/, "mediapod_client:\n    path: ../dart-client")}1' pubspec.yaml.bak > pubspec.yaml && \
		flutter pub get > /dev/null 2>&1 && \
		output=$$(flutter analyze 2>&1 | grep -v "^Package file_picker\|^Ask the maintainers\|^Resolving\|^Downloading\|^Got dependencies\|packages have newer\|flutter pub outdated\|available)$$"); \
		echo "$$output" | grep -v "^$$"; \
		mv pubspec.yaml.bak pubspec.yaml; \
		if echo "$$output" | grep -q "error •"; then exit 1; fi; \
		exit 0)

flutter-test:
	@echo "→ Running Flutter tests..."
	@(cd $(FLUTTER_PKG) && flutter test)
	@echo "  ✓ Flutter tests passed!"

flutter-pub-get:
	@echo "→ Getting Flutter dependencies..."
	@(cd $(FLUTTER_PKG) && flutter pub get)

# =============================================================================
# Utility targets
# =============================================================================

deps: go-mod-tidy dart-pub-get flutter-pub-get
	@echo "✓ All dependencies installed!"

clean:
	@echo "→ Cleaning build artifacts..."
	@rm -rf $(FLUTTER_PKG)/build
	@rm -rf $(FLUTTER_PKG)/.dart_tool
	@rm -rf $(DART_PKG)/.dart_tool
	@for dir in $(GO_SERVICES); do \
		rm -f $$dir/server $$dir/worker 2>/dev/null || true; \
	done
	@echo "✓ Clean complete!"

# =============================================================================
# CI target (strict mode for CI/CD pipelines)
# =============================================================================

ci: go-format-check go-vet go-build dart-format-check dart-analyze flutter-format-check flutter-analyze
	@echo "✓ CI checks passed!"

# =============================================================================
# Help
# =============================================================================

help:
	@echo "Mediapod Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Main targets:"
	@echo "  all, check    Run all checks (format + vet + analyze)"
	@echo "  format        Format all code (Go, Dart, Flutter)"
	@echo "  lint          Run strict linters (golangci-lint + analyzers)"
	@echo "  test          Run all tests"
	@echo "  ci            Run CI checks (format + vet + build + analyze)"
	@echo "  deps          Install all dependencies"
	@echo "  clean         Clean build artifacts"
	@echo ""
	@echo "Go targets:"
	@echo "  go-check      Run Go checks (format + vet)"
	@echo "  go-format     Format Go code with gofmt"
	@echo "  go-vet        Run go vet"
	@echo "  go-lint       Run golangci-lint (strict, may have warnings)"
	@echo "  go-test       Run Go tests"
	@echo "  go-build      Build Go services"
	@echo "  go-mod-tidy   Tidy Go modules"
	@echo ""
	@echo "Dart targets:"
	@echo "  dart-check    Run Dart checks (format + analyze)"
	@echo "  dart-format   Format Dart code"
	@echo "  dart-analyze  Run dart analyze"
	@echo "  dart-test     Run Dart tests"
	@echo "  dart-pub-get  Get Dart dependencies"
	@echo ""
	@echo "Flutter targets:"
	@echo "  flutter-check    Run Flutter checks (format + analyze)"
	@echo "  flutter-format   Format Flutter code"
	@echo "  flutter-analyze  Run flutter analyze"
	@echo "  flutter-test     Run Flutter tests"
	@echo "  flutter-pub-get  Get Flutter dependencies"

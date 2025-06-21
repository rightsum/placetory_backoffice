# Makefile for Laravel Application
# Based on the coding standards defined in .github/copilot-instructions.md

.PHONY: help lint analyze test quality-check install dev build clean

# Default target
help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Code Quality Commands
lint: ## Run Pint to fix styling issues automatically
	./vendor/bin/pint

analyze: ## Run PHPStan static analysis to find potential bugs
	./vendor/bin/phpstan analyse

test: ## Run all tests using PHPUnit/Pest
	php artisan test

# Combined quality check (as required by copilot instructions)
quality-check: lint analyze test ## Run all code quality checks (lint + analyze + test)
	@echo "✅ All quality checks completed successfully!"

# Development Commands
install: ## Install PHP and Node.js dependencies
	composer install
	npm install

dev: ## Start development server
	php artisan serve

build: ## Build frontend assets for production
	npm run build

# Utility Commands
clean: ## Clear Laravel caches and logs
	php artisan cache:clear
	php artisan config:clear
	php artisan route:clear
	php artisan view:clear
	rm -rf storage/logs/*.log

# Git workflow helpers (based on copilot instructions)
pre-commit: quality-check ## Run quality checks before committing (recommended)
	@echo "✅ Pre-commit checks passed! Ready to commit."

# Database commands
migrate: ## Run database migrations
	php artisan migrate

migrate-fresh: ## Fresh migration with seeding
	php artisan migrate:fresh --seed

# Quick development setup
setup: install migrate ## Complete development setup (install + migrate)
	@echo "✅ Development environment is ready!"

package db

import (
	"context"
	"embed"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog/log"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

type DB struct {
	pool *pgxpool.Pool
}

func New(databaseURL string) (*DB, error) {
	pool, err := pgxpool.New(context.Background(), databaseURL)
	if err != nil {
		return nil, fmt.Errorf("unable to create connection pool: %w", err)
	}

	// Test connection
	if err := pool.Ping(context.Background()); err != nil {
		return nil, fmt.Errorf("unable to ping database: %w", err)
	}

	return &DB{pool: pool}, nil
}

func (db *DB) Close() {
	db.pool.Close()
}

func (db *DB) Pool() *pgxpool.Pool {
	return db.pool
}

func (db *DB) RunMigrations() error {
	ctx := context.Background()

	// Create migrations table if not exists
	_, err := db.pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version INTEGER PRIMARY KEY,
			applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		)
	`)
	if err != nil {
		return fmt.Errorf("failed to create migrations table: %w", err)
	}

	migrations := []struct {
		version int
		file    string
	}{
		{1, "migrations/001_initial_schema.sql"},
	}

	for _, m := range migrations {
		// Check if migration already applied
		var exists bool
		err := db.pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version = $1)", m.version).Scan(&exists)
		if err != nil {
			return fmt.Errorf("failed to check migration %d: %w", m.version, err)
		}

		if exists {
			log.Info().Int("version", m.version).Msg("Migration already applied")
			continue
		}

		// Read migration file
		sql, err := migrationsFS.ReadFile(m.file)
		if err != nil {
			return fmt.Errorf("failed to read migration %d: %w", m.version, err)
		}

		// Execute migration
		tx, err := db.pool.Begin(ctx)
		if err != nil {
			return fmt.Errorf("failed to begin transaction for migration %d: %w", m.version, err)
		}

		_, err = tx.Exec(ctx, string(sql))
		if err != nil {
			tx.Rollback(ctx)
			return fmt.Errorf("failed to execute migration %d: %w", m.version, err)
		}

		_, err = tx.Exec(ctx, "INSERT INTO schema_migrations (version) VALUES ($1)", m.version)
		if err != nil {
			tx.Rollback(ctx)
			return fmt.Errorf("failed to record migration %d: %w", m.version, err)
		}

		if err := tx.Commit(ctx); err != nil {
			return fmt.Errorf("failed to commit migration %d: %w", m.version, err)
		}

		log.Info().Int("version", m.version).Msg("Migration applied successfully")
	}

	return nil
}

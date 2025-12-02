-- Assets table
CREATE TABLE IF NOT EXISTS assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind VARCHAR(20) NOT NULL CHECK (kind IN ('image', 'video', 'audio', 'document')),
    state VARCHAR(20) NOT NULL DEFAULT 'uploading' CHECK (state IN ('uploading', 'processing', 'ready', 'failed')),
    bucket VARCHAR(100) NOT NULL,
    object_key VARCHAR(500) NOT NULL,
    filename VARCHAR(255) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    size_bytes BIGINT NOT NULL DEFAULT 0,
    sha256 VARCHAR(64),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(bucket, object_key)
);

CREATE INDEX idx_assets_kind ON assets(kind);
CREATE INDEX idx_assets_state ON assets(state);
CREATE INDEX idx_assets_created_at ON assets(created_at DESC);

-- Asset metadata table
CREATE TABLE IF NOT EXISTS asset_meta (
    asset_id UUID PRIMARY KEY REFERENCES assets(id) ON DELETE CASCADE,
    width INTEGER,
    height INTEGER,
    duration_seconds DECIMAL(10, 2),
    bitrate INTEGER,
    codec VARCHAR(50),
    exif JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Asset variants table (different renditions/sizes)
CREATE TABLE IF NOT EXISTS asset_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    variant_type VARCHAR(50) NOT NULL, -- 'hls_720p', 'thumbnail', 'webp_800', etc.
    path VARCHAR(500) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    width INTEGER,
    height INTEGER,
    bitrate INTEGER,
    size_bytes BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_asset_variants_asset_id ON asset_variants(asset_id);
CREATE INDEX idx_asset_variants_type ON asset_variants(variant_type);

-- Asset tags table
CREATE TABLE IF NOT EXISTS asset_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    tag VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(asset_id, tag)
);

CREATE INDEX idx_asset_tags_asset_id ON asset_tags(asset_id);
CREATE INDEX idx_asset_tags_tag ON asset_tags(tag);

-- Usage references table (track where assets are used)
CREATE TABLE IF NOT EXISTS asset_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    owner_type VARCHAR(50) NOT NULL, -- 'product', 'user', 'post', etc.
    owner_id UUID NOT NULL,
    purpose VARCHAR(100), -- 'avatar', 'banner', 'gallery', etc.
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(asset_id, owner_type, owner_id, purpose)
);

CREATE INDEX idx_asset_usage_asset_id ON asset_usage(asset_id);
CREATE INDEX idx_asset_usage_owner ON asset_usage(owner_type, owner_id);

-- Processing jobs table
CREATE TABLE IF NOT EXISTS processing_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    job_type VARCHAR(50) NOT NULL, -- 'transcode', 'thumbnail', 'extract_meta', etc.
    state VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'processing', 'completed', 'failed')),
    priority INTEGER NOT NULL DEFAULT 5,
    attempts INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 3,
    error_message TEXT,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_processing_jobs_state ON processing_jobs(state);
CREATE INDEX idx_processing_jobs_asset_id ON processing_jobs(asset_id);
CREATE INDEX idx_processing_jobs_priority ON processing_jobs(priority DESC, created_at ASC);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_assets_updated_at BEFORE UPDATE ON assets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Copy the standard OAI database schema
-- You can get this from:
-- https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-fed/-/raw/master/docker-compose/database/oai_db.sql

-- Or use a minimal version with test subscriber:
CREATE DATABASE IF NOT EXISTS oai_db;
USE oai_db;

-- Add your test subscriber (IMSI: 208950000000001)
-- (Full schema omitted for brevity - use official OAI schema)

-- Runs once, on the first start of the empty `db` volume (MariaDB entrypoint).
-- Users are created here so the server-side accounts exist before db-init runs;
-- db-init.sh (re)applies passwords and grants from .env on every boot.
CREATE USER IF NOT EXISTS 'mangos'@'%' IDENTIFIED BY 'placeholder';
CREATE USER IF NOT EXISTS 'realmweb'@'%' IDENTIFIED BY 'placeholder';

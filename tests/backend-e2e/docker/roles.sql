-- Executed by the Supabase image as its bootstrap superuser.
-- The password is generated for this job; never copied from a real project.
\getenv test_password POSTGRES_PASSWORD
ALTER ROLE authenticator WITH PASSWORD :'test_password';
ALTER ROLE supabase_auth_admin WITH PASSWORD :'test_password';

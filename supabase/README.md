# Supabase Project Setup

This directory holds the infrastructure-as-code assets used to provision the OrderVista backend. We use the Supabase CLI to manage database migrations, storage policies, and Edge Functions, keeping everything versioned alongside the Flutter client.

## Prerequisites
- Supabase CLI (`npm install -g supabase`)
- Access to the target Supabase project (organization + API keys)
- Docker (for local emulation, optional but recommended)

## Quick Start
```bash
# 1. Authenticate the CLI (opens browser)
supabase login

# 2. Link to your Supabase project (once per machine)
supabase link --project-ref <project-ref>

# 3. Start the local emulator stack (database, storage, auth)
supabase start

# 4. Apply migrations to the local stack
supabase db reset  # or `supabase db push`
```

## Deploying to Remote
```bash
# Run migrations against the linked project
supabase db push

# Deploy Edge Functions
supabase functions deploy <function-name>
```

## Structure
```
supabase/
├── README.md            # this file
├── functions/           # Deno edge functions (chat-interaction, optimize-route, etc.)
└── migrations/          # SQL migrations that define schema + policies
```

Migrations are timestamped (UTC) and executed in lexical order, e.g., `20251208_initial_schema.sql`. Use `supabase migration new <name>` to scaffold new files.

See `docs/backend_contract.md` for the detailed data model and API contracts that these migrations implement.

# Firebase SQL Connect (Cloud SQL Postgres) for project sukaseafood-654b7
#
# Instance: sukaseafood-654b7-instance (us-east4)
# Database: sukaseafood-654b7-database
# Trial: ~3 months no-cost (see Firebase Console banner)
#
# Schema contract: **Database Schema V3**
#   - SQL source of truth: backend/db/schema/v3_*.sql
#   - GraphQL mirror:     dataconnect/schema/schema.gql
#   - seafood_item_id is the only canonical seafood identity
#
# App accounts + seafood domain data live in **PostgreSQL only**.
# Firestore is not used for domain data.
#
# Apply GitHub SQL to Cloud SQL or local Docker:
#
#   docker compose up -d db
#   DATABASE_URL=postgresql://sukaseafood:sukaseafood@localhost:5432/sukaseafood \
#     bash backend/db/apply.sh
#
# Then point FastAPI at that DATABASE_URL and run the API.
#
# Keep dataconnect.yaml schemaValidation unset or COMPATIBLE so Firebase does
# not overwrite the reviewed SQL DDL.
#
# Console: https://console.firebase.google.com/project/sukaseafood-654b7/dataconnect

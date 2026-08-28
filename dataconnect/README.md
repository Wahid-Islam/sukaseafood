# Firebase SQL Connect (Cloud SQL Postgres) for project sukaseafood-654b7
#
# Instance: sukaseafood-654b7-instance (us-east4)
# Database: sukaseafood-654b7-database
# Trial: ~3 months no-cost (see Firebase Console banner)
#
# App accounts + seafood domain data live in **PostgreSQL only**
# (table `app_user` + I1 schema under backend/db/). Firestore is not used.
#
# Apply GitHub SQL to Cloud SQL or local Docker:
#
#   docker compose up -d db
#   DATABASE_URL=postgresql://sukaseafood:sukaseafood@localhost:5432/sukaseafood \
#     bash backend/db/apply.sh
#
# Then point FastAPI at that DATABASE_URL and run the API.
#
# Console: https://console.firebase.google.com/project/sukaseafood-654b7/dataconnect

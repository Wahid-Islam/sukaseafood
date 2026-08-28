# Firebase SQL Connect (Cloud SQL Postgres) for project sukaseafood-654b7
#
# Instance: sukaseafood-654b7-instance (us-east4)
# Database: sukaseafood-654b7-database
# Trial: ~3 months no-cost (see Firebase Console banner)
#
# Domain schema: use the GitHub Postgres DDL under backend/db/ — not a
# separate invented GraphQL model. When ready:
#
#   1. Connect with Cloud SQL Auth Proxy or Firebase SQL shell
#   2. Run backend/db/apply.sh (or apply schema + seed SQL in order)
#   3. Point FastAPI DATABASE_URL at this Cloud SQL instance
#
# Console: https://console.firebase.google.com/project/sukaseafood-654b7/dataconnect

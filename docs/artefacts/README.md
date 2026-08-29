# Product artefacts

Large PDFs are kept locally (gitignored):

- `SUKASEAFOOD ARTEFACTS.pdf`
- `SukaSeafood — Iteration 1 Build Plan.pdf`
- `SukaSeafood_Team15_FIT5120_V3.0.pdf`
- `SukaSeafood_V3_Database_Schema_Implementation_Guide.pdf` — schema contract for Firebase SQL Connect / Cloud SQL (hub-and-spoke around `seafood_item`)

Store shared copies in team Drive/SharePoint rather than git. The implemented
DDL lives in `backend/db/schema/v3_*.sql`; the Firebase GraphQL mirror is
`dataconnect/schema/schema.gql`.

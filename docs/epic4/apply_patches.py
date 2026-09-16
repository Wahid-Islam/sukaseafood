"""Apply Epic 4 edits to existing files in-place (idempotent)."""
import pathlib, sys

root = pathlib.Path(sys.argv[1])

def patch(rel, old, new, marker):
    p = root / rel
    s = p.read_text()
    if marker in s:
        print("already:", rel); return
    assert old in s, f"anchor missing in {rel}: {old[:60]!r}"
    p.write_text(s.replace(old, new, 1)); print("patched:", rel)

# --- backend main.py
patch("backend/app/main.py",
 "from app.api.auth_routes import router as auth_router\n",
 "from app.api.auth_routes import router as auth_router\nfrom app.api.cooking_routes import router as cooking_router\n",
 "cooking_routes")
patch("backend/app/main.py",
 "    app.include_router(me_router, prefix=settings.api_prefix)\n",
 "    app.include_router(me_router, prefix=settings.api_prefix)\n    app.include_router(cooking_router, prefix=settings.api_prefix)\n",
 "include_router(cooking_router")

# --- backend .env.example
patch("backend/.env.example",
 "# ---------------------------------------------------------------------------\n# CV\n",
 """# ---------------------------------------------------------------------------
# OpenAI — Epic 4 recipe generation (server-side only; never ship to Flutter)
# ---------------------------------------------------------------------------
# Leave empty to disable recipes (POST /recipes/generate returns 503).
# On Cloud Run store it in Secret Manager:
#   gcloud run services update sukaseafood-api --update-secrets=OPENAI_API_KEY=openai-api-key:latest
OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o-mini

# ---------------------------------------------------------------------------
# CV
""", "OPENAI_API_KEY")

# --- Flutter router
patch("frontend/lib/core/router/app_router.dart",
 "import '../../features/cooking/cooking_screen.dart';\n",
 "import '../../data/models/cooking_intent.dart';\nimport '../../features/cooking/cooking_screen.dart';\nimport '../../features/cooking/recipe_screen.dart';\n",
 "recipe_screen.dart")
patch("frontend/lib/core/router/app_router.dart",
 """      GoRoute(
        path: '/price/:id',""",
 """      GoRoute(
        path: '/smart-swap',
        builder: (context, state) {
          return SmartSwapScreen(
            initialQuery: state.uri.queryParameters['q'],
          );
        },
      ),
      GoRoute(
        path: '/recipe',
        builder: (context, state) {
          // `extra` is lost on a web refresh or deep link; fall back to the
          // Smart Swap flow instead of crashing.
          final Object? extra = state.extra;
          return extra is Recipe
              ? RecipeScreen(recipe: extra)
              : const SmartSwapScreen();
        },
      ),
      GoRoute(
        path: '/price/:id',""",
 "path: '/smart-swap'")

# --- Flutter API client
patch("frontend/lib/data/api/api_client.dart",
 "import '../models/identify_result.dart';\n",
 "import '../models/cooking_intent.dart';\nimport '../models/identify_result.dart';\n",
 "cooking_intent.dart")
patch("frontend/lib/data/api/api_client.dart",
 "  bool get isUnreachable => statusCode == null;\n",
 "  bool get isUnreachable => statusCode == null;\n\n  /// The server has no OpenAI key, so recipe generation is switched off.\n  bool get isRecipeUnavailable => code == 'RECIPE_UNAVAILABLE';\n",
 "isRecipeUnavailable")
patch("frontend/lib/data/api/api_client.dart",
 "  void close() => _client.close();\n",
 """  /// Epic 4 — parse a cooking intent and rank better alternatives.
  ///
  /// Send `query` for free text; send structured keys (`cooking_method`,
  /// `servings`, `fish_id`, …) without a query to re-rank after chip edits.
  /// An empty string clears a field; null leaves it unset.
  Future<SmartSwapResult> smartSwap(Map<String, Object?> body) async {
    return SmartSwapResult.fromJson(await _postJson('/smart-swap', body));
  }

  /// Epic 4 — recipes for the chosen fish, generated server-side (OpenAI).
  /// The OpenAI key never leaves the backend.
  Future<RecipeBatch> generateRecipes({
    required String fishId,
    String? cookingMethod,
    String? dish,
    int servings = 2,
    int count = 1,
    bool kidFriendly = false,
    List<String> excludeTitles = const <String>[],
  }) async {
    final Map<String, dynamic> json = await _postJson(
      '/recipes/generate',
      <String, Object?>{
        'fish_id': fishId,
        'cooking_method': cookingMethod,
        'dish': dish,
        'servings': servings,
        'count': count,
        'kid_friendly': kidFriendly,
        'exclude_titles': excludeTitles,
      },
      timeout: const Duration(seconds: 90),
    );
    return RecipeBatch.fromJson(json);
  }

  void close() => _client.close();
""", "generateRecipes(")
patch("frontend/lib/data/api/api_client.dart",
 "  Map<String, String> _authHeaders(String token) {\n",
 """  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> body, {
    Duration? timeout,
  }) async {
    final Map<String, Object?> clean = <String, Object?>{
      for (final MapEntry<String, Object?> e in body.entries)
        if (e.value != null) e.key: e.value,
    };
    try {
      final http.Response response = await _client
          .post(
            _uri(path),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(clean),
          )
          .timeout(timeout ?? _timeout);
      return _decode(response);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_unreachableMessage(error));
    }
  }

  Map<String, String> _authHeaders(String token) {
""", "Future<Map<String, dynamic>> _postJson(")

# --- Cooking screen: the "coming soon" recipe card now opens Epic 4
patch("frontend/lib/features/cooking/cooking_screen.dart",
 """                  SoftCard(
                    color: const Color(0xFFF3EEFF),
                    child: Row(""",
 """                  SoftCard(
                    color: const Color(0xFFF3EEFF),
                    onTap: () => context.push('/seafood/${item.fishId}/swap'),
                    child: Row(""",
 "/swap'),\n                    child: Row(")
patch("frontend/lib/features/cooking/cooking_screen.dart",
 "Text('Powered by RecipeDB · Coming soon'),",
 "Text('Smart Swap & AI recipes for your dish'),",
 "Smart Swap & AI recipes")

# --- backend/.env: add the OpenAI key if provided via environment
import os
key = os.environ.get("OPENAI_API_KEY", "").strip()
if key:
    env = root / "backend/.env"
    lines = env.read_text().splitlines() if env.exists() else []
    lines = [l for l in lines if not l.startswith(("OPENAI_API_KEY=", "OPENAI_MODEL="))]
    lines += [f"OPENAI_API_KEY={key}", "OPENAI_MODEL=" + os.environ.get("OPENAI_MODEL", "gpt-4o-mini")]
    env.write_text("\n".join(lines) + "\n")
    print("wrote OPENAI_API_KEY to backend/.env (gitignored)")

# --- backend config: OpenAI settings
patch("backend/app/config.py",
 '    model_config = SettingsConfigDict(env_file=".env", extra="ignore")\n',
 '''    # --- OpenAI (Epic 4 recipe generation) ---------------------------------
    # Server-side only (backend/.env locally, Secret Manager on Cloud Run).
    # Empty: Smart Swap still works; POST /recipes/generate answers 503.
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"
    openai_base_url: str = "https://api.openai.com/v1"
    openai_timeout_seconds: float = 45.0

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
''', "openai_api_key")
patch("backend/app/config.py",
 "    @property\n    def is_production(self) -> bool:",
 "    @property\n    def openai_enabled(self) -> bool:\n        return bool(self.openai_api_key.strip())\n\n    @property\n    def is_production(self) -> bool:",
 "def openai_enabled")

# --- backend schemas: Epic 4 models
schemas = root / "backend/app/schemas/__init__.py"
if "class SmartSwapRequest" not in schemas.read_text():
    extra = (pathlib.Path(__file__).parent / "schemas_epic4.py.txt").read_text()
    schemas.write_text(schemas.read_text().rstrip() + "\n\n\n" + extra)
    print("patched: backend/app/schemas/__init__.py")
else:
    print("already: backend/app/schemas/__init__.py")

import Foundation

// MARK: - App configuration
// Every environment-specific value the app needs, in one place. All of
// these are public identifiers, not secrets: the Supabase publishable key
// is designed to ship in clients, and every table it could reach has
// row-level security on with no policies (Server/src/db/migrations/
// 0003_enable_rls.sql), so it grants nothing beyond Supabase Auth itself.
// See docs/adr/0004-leave-aws.md.
enum AppConfig {
    /// Supabase → Project Settings → API → Project URL.
    static let supabaseURL = URL(string: "https://udeaqqtngqjwrosihece.supabase.co")!

    /// Supabase → Project Settings → API Keys → publishable key
    /// (`sb_publishable_…`, or the legacy `anon` key on older projects).
    static let supabasePublishableKey = "sb_publishable_FnauvPy9UMN713yK0Gz6zA_Ou0G9qSK"

    /// The Untilt API (Server/) on Render. Shown on the service's page
    /// once the Blueprint in render.yaml is deployed.
    static let backendURL = URL(string: "https://untilt-api.onrender.com")!

    /// Where Supabase sends the user back after Google sign-in. Must be
    /// listed under Authentication → URL Configuration → Redirect URLs.
    static let authRedirectURI = "untilt://auth-callback"
}

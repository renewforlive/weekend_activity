param(
  [Parameter(Mandatory = $true)] [string]$SupabaseUrl,
  [Parameter(Mandatory = $true)] [string]$SupabasePublishableKey
)

flutter build apk --debug --flavor dev `
  --dart-define=APP_ENV=dev `
  --dart-define=SUPABASE_DEV_URL=$SupabaseUrl `
  --dart-define=SUPABASE_DEV_PUBLISHABLE_KEY=$SupabasePublishableKey

param(
  [int]$Port = 8080,
  [string]$Directory = (Join-Path $PSScriptRoot '..\build\web')
)

$root = [System.IO.Path]::GetFullPath($Directory)
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

$mime = @{
  '.css' = 'text/css'; '.html' = 'text/html'; '.ico' = 'image/x-icon'
  '.js' = 'application/javascript'; '.json' = 'application/json'
  '.map' = 'application/json'; '.png' = 'image/png'; '.svg' = 'image/svg+xml'
  '.wasm' = 'application/wasm'
}

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $relative = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
    if ([string]::IsNullOrWhiteSpace($relative)) { $relative = 'index.html' }
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $root $relative))
    if (!$candidate.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase) -or !(Test-Path -LiteralPath $candidate -PathType Leaf)) {
      $candidate = Join-Path $root 'index.html'
    }
    $extension = [System.IO.Path]::GetExtension($candidate).ToLowerInvariant()
    $context.Response.ContentType = if ($mime.ContainsKey($extension)) { $mime[$extension] } else { 'application/octet-stream' }
    $content = [System.IO.File]::ReadAllBytes($candidate)
    $context.Response.ContentLength64 = $content.Length
    $context.Response.OutputStream.Write($content, 0, $content.Length)
    $context.Response.Close()
  }
} finally {
  $listener.Close()
}

# Simple static file server for previewing index.html
# Usage: powershell -ExecutionPolicy Bypass -File serve.ps1

$port = 5173
$root = $PSScriptRoot

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Serving $root at http://localhost:$port/"

$mime = @{
    ".html"  = "text/html; charset=utf-8"
    ".css"   = "text/css; charset=utf-8"
    ".js"    = "application/javascript; charset=utf-8"
    ".json"  = "application/json; charset=utf-8"
    ".svg"   = "image/svg+xml"
    ".png"   = "image/png"
    ".jpg"   = "image/jpeg"
    ".jpeg"  = "image/jpeg"
    ".webp"  = "image/webp"
    ".gif"   = "image/gif"
    ".ico"   = "image/x-icon"
    ".mp4"   = "video/mp4"
    ".webm"  = "video/webm"
    ".woff"  = "font/woff"
    ".woff2" = "font/woff2"
    ".ttf"   = "font/ttf"
    ".md"    = "text/markdown; charset=utf-8"
    ".txt"   = "text/plain; charset=utf-8"
}

try {
    while ($listener.IsListening) {
        $context = $null
        try {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response

            $path = [System.Uri]::UnescapeDataString($request.Url.LocalPath)
            if ($path -eq "/") { $path = "/index.html" }
            $relative = $path.TrimStart("/").Replace("/", "\")
            $file = Join-Path $root $relative

            if (Test-Path $file -PathType Leaf) {
                $bytes = [System.IO.File]::ReadAllBytes($file)
                $ext = [System.IO.Path]::GetExtension($file).ToLower()
                $response.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
                $response.StatusCode = 200
                # Close(bytes, willBlock) writes the body AND closes the response in one call,
                # avoiding the Content-Length / Write race that throws ProtocolViolationException.
                $response.Close($bytes, $false)
            } else {
                $response.StatusCode = 404
                $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $path")
                $response.ContentType = "text/plain; charset=utf-8"
                $response.Close($msg, $false)
            }
        } catch {
            Write-Host "Request error: $_"
            if ($null -ne $context) {
                try {
                    $context.Response.StatusCode = 500
                    $context.Response.Close()
                } catch {}
            }
        }
    }
} finally {
    $listener.Stop()
}

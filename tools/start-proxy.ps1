# Run the Cloud SQL Auth Proxy against the SukaSeafood instance, restarting it
# with fresh tokens before they expire.
#
# Why the loop: IAM database authentication is what lets this repo hold no
# database password at all, but the tokens it relies on last about an hour. The
# proxy does not renew tokens supplied with --token/--login-token, so a
# long-running dev session otherwise dies mid-demo with a 500 from the API and
# no obvious cause. Restarting slightly early is cheaper than diagnosing that.
#
# The alternative — `gcloud auth application-default login` — lets the proxy
# refresh on its own, but writes a long-lived refresh token to disk. This keeps
# the credential short-lived instead.
#
# Usage:  powershell -ExecutionPolicy Bypass -File tools\start-proxy.ps1

$ErrorActionPreference = 'Stop'

$instance = 'sukaseafood-654b7:us-east4:sukaseafood-654b7-instance'
$proxy = Join-Path $PSScriptRoot 'cloud-sql-proxy.exe'
$port = 5432

# Tokens are valid for ~3600s. Recycle well inside that so an in-flight request
# never lands on an expired one.
$lifetimeSeconds = 2700

if (-not (Test-Path $proxy)) {
    throw "cloud-sql-proxy.exe not found at $proxy. See backend/README.md."
}

while ($true) {
    Write-Host "[start-proxy] minting tokens..." -ForegroundColor Cyan
    $accessToken = (& gcloud auth print-access-token).Trim()
    $loginToken = (& gcloud sql generate-login-token).Trim()

    if (-not $accessToken -or -not $loginToken) {
        throw 'Could not mint tokens. Run `gcloud auth login` and try again.'
    }

    Write-Host "[start-proxy] listening on 127.0.0.1:$port (recycling in $lifetimeSeconds s)" `
        -ForegroundColor Cyan

    $process = Start-Process -FilePath $proxy -PassThru -NoNewWindow -ArgumentList @(
        '--auto-iam-authn'
        '--token', $accessToken
        '--login-token', $loginToken
        '--address', '127.0.0.1'
        '--port', "$port"
        $instance
    )

    $exited = $process.WaitForExit($lifetimeSeconds * 1000)

    if ($exited) {
        Write-Host "[start-proxy] proxy exited with $($process.ExitCode); restarting" `
            -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
    else {
        Write-Host '[start-proxy] token lifetime reached; restarting with new tokens' `
            -ForegroundColor Cyan
        $process.Kill()
        $process.WaitForExit()
    }
}

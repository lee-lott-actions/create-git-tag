param(
    [int]$Port = 3000
)

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()

Write-Host "Mock server listening on http://127.0.0.1:$Port..." -ForegroundColor Green

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $path = $request.Url.LocalPath
        $method = $request.HttpMethod
        
        Write-Host "Mock intercepted: $method $path" -ForegroundColor Cyan
        
        $responseJson = $null
        $statusCode = 200

        # HealthCheck endpoint: GET /HealthCheck
        if ($method -eq "GET" -and $path -eq "/HealthCheck") {
            $statusCode = 200
            $responseJson = @{ status = "ok" } | ConvertTo-Json
        }
        # Mock endpoint for getting branch info: GET /repos/:owner/:repo/branches/:branch
        elseif ($method -eq "GET" -and $path -match '^/repos/([^/]+)/([^/]+)/branches/(.+)$') {
            $owner = $Matches[1]
            $repo = $Matches[2]
            $branch = $Matches[3]
            
            $statusCode = 200
            $responseJson = @{
                name = $branch
                commit = @{
                    sha = "abc123branchsha"
                    url = "https://api.github.com/repos/$owner/$repo/commits/abc123branchsha"
                }
            } | ConvertTo-Json -Compress -Depth 10
        }
        # Mock endpoint for creating a tag object: POST /repos/:owner/:repo/git/tags
        elseif ($method -eq "POST" -and $path -match '^/repos/([^/]+)/([^/]+)/git/tags$') {
            $owner = $Matches[1]
            $repo = $Matches[2]
            
            # Read request body
            $reader = New-Object System.IO.StreamReader($request.InputStream)
            $requestBody = $reader.ReadToEnd()
            $reader.Close()
            $bodyObj = $requestBody | ConvertFrom-Json
            
            $statusCode = 201
            $responseJson = @{
                tag = $bodyObj.tag
                sha = "def456tagsha"
                url = "https://api.github.com/repos/$owner/$repo/git/tags/def456tagsha"
                message = $bodyObj.message
                tagger = $bodyObj.tagger
                object = $bodyObj.object
            } | ConvertTo-Json -Compress -Depth 10
        }
        # Mock endpoint for creating a ref: POST /repos/:owner/:repo/git/refs
        elseif ($method -eq "POST" -and $path -match '^/repos/([^/]+)/([^/]+)/git/refs$') {
            $owner = $Matches[1]
            $repo = $Matches[2]
            
            # Read request body
            $reader = New-Object System.IO.StreamReader($request.InputStream)
            $requestBody = $reader.ReadToEnd()
            $reader.Close()
            $bodyObj = $requestBody | ConvertFrom-Json
            
            $statusCode = 201
            $responseJson = @{
                ref = $bodyObj.ref
                node_id = "mock-node-id"
                url = "https://api.github.com/repos/$owner/$repo/git/refs/$($bodyObj.ref)"
                object = @{
                    sha = $bodyObj.sha
                    type = "tag"
                }
            } | ConvertTo-Json -Compress -Depth 10
        }
        else {
            $statusCode = 404
            $responseJson = @{ message = "Not Found" } | ConvertTo-Json
        }
        
        # Send response
        $response.StatusCode = $statusCode
        $response.ContentType = "application/json"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseJson)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.Close()
    }
}
finally {
    $listener.Stop()
    $listener.Close()
    Write-Host "Mock server stopped." -ForegroundColor Yellow
}
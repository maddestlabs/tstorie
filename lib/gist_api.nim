## GitHub Gist API Module
##
## Provides simple interface for loading and creating GitHub Gists.
## Supports authentication via environment variable or compile-time token.
##
## Usage:
##   # Set token via environment variable
##   export GITHUB_TOKEN="ghp_..."
##   
##   # Or compile with token
##   nim c -d:githubToken="ghp_..." yourfile.nim
##
##   # Load a gist
##   let gist = loadGist("abc123...")
##   echo gist.files[0].content
##   
##   # Create a gist
##   var newGist = Gist(
##     description: "My cool demo",
##     public: true,
##     files: @[GistFile(filename: "demo.md", content: "# Hello")]
##   )
##   let gistId = createGist(newGist)

import std/[httpclient, json, os, strutils, tables]

type
  GistFile* = object
    ## A single file within a gist
    filename*: string
    content*: string
    language*: string  # Detected language (from GitHub)
    size*: int         # File size in bytes
  
  Gist* = object
    ## A GitHub Gist with metadata and files
    id*: string
    description*: string
    public*: bool
    files*: seq[GistFile]
    htmlUrl*: string   # Web URL to view gist
    owner*: string     # Username of gist owner
    createdAt*: string
    updatedAt*: string
  
  GistError* = object of CatchableError
    ## Error raised when gist operations fail

const GITHUB_API_BASE = "https://api.github.com"

# ================================================================
# TOKEN MANAGEMENT
# ================================================================

proc getGithubToken*(): string =
  ## Get GitHub token from environment or compile-time constant
  ## Priority: Environment variable > Compile-time define
  result = getEnv("GITHUB_TOKEN")
  
  # Fall back to compile-time token if available
  when defined(githubToken):
    if result == "":
      const token {.strdefine.} = ""
      result = token
  
  return result

proc hasGithubToken*(): bool =
  ## Check if a GitHub token is available
  return getGithubToken() != ""

# ================================================================
# HTTP HELPERS
# ================================================================

proc createAuthHeaders*(token: string = ""): HttpHeaders =
  ## Create HTTP headers with optional authentication
  result = newHttpHeaders({
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "TStorie-Editor/1.0"
  })
  
  let authToken = if token != "": token else: getGithubToken()
  if authToken != "":
    result["Authorization"] = "Bearer " & authToken

proc handleResponse*(response: Response): JsonNode =
  ## Parse and validate HTTP response
  if response.code.int >= 400:
    let errorMsg = "GitHub API error " & $response.code & ": " & response.body
    raise newException(GistError, errorMsg)
  
  try:
    result = parseJson(response.body)
  except JsonParsingError as e:
    raise newException(GistError, "Failed to parse GitHub response: " & e.msg)

# ================================================================
# GIST PARSING
# ================================================================

proc parseGistFile(fileJson: JsonNode, filename: string): GistFile =
  ## Parse a single gist file from JSON
  result.filename = filename
  result.content = fileJson["content"].getStr("")
  result.language = fileJson{"language"}.getStr("")
  result.size = fileJson{"size"}.getInt(0)

proc parseGist*(json: JsonNode): Gist =
  ## Parse a gist from GitHub API JSON response
  result.id = json["id"].getStr("")
  result.description = json["description"].getStr("")
  result.public = json["public"].getBool(true)
  result.htmlUrl = json{"html_url"}.getStr("")
  result.createdAt = json{"created_at"}.getStr("")
  result.updatedAt = json{"updated_at"}.getStr("")
  
  # Parse owner
  if json.hasKey("owner") and json["owner"].kind != JNull:
    result.owner = json["owner"]["login"].getStr("")
  
  # Parse files
  result.files = @[]
  if json.hasKey("files"):
    for filename, fileJson in json["files"].pairs():
      result.files.add(parseGistFile(fileJson, filename))

# ================================================================
# GIST OPERATIONS
# ================================================================

proc loadGist*(gistId: string, token: string = ""): Gist =
  ## Load a gist by ID from GitHub
  ## Raises GistError if the gist cannot be loaded
  let client = newHttpClient()
  defer: client.close()
  
  client.headers = createAuthHeaders(token)
  
  let url = GITHUB_API_BASE & "/gists/" & gistId
  
  try:
    let response = client.get(url)
    let json = handleResponse(response)
    result = parseGist(json)
  except HttpRequestError as e:
    raise newException(GistError, "Failed to load gist: " & e.msg)
  except GistError:
    raise
  except Exception as e:
    raise newException(GistError, "Unexpected error loading gist: " & e.msg)

proc createGist*(gist: Gist, token: string = ""): string =
  ## Create a new gist on GitHub
  ## Returns the ID of the created gist
  ## Raises GistError if creation fails or no token is available
  let authToken = if token != "": token else: getGithubToken()
  if authToken == "":
    raise newException(GistError, "GitHub token required to create gists. Set GITHUB_TOKEN environment variable.")
  
  let client = newHttpClient()
  defer: client.close()
  
  client.headers = createAuthHeaders(authToken)
  
  # Build request JSON
  var filesJson = newJObject()
  for file in gist.files:
    filesJson[file.filename] = %* {
      "content": file.content
    }
  
  let requestBody = %* {
    "description": gist.description,
    "public": gist.public,
    "files": filesJson
  }
  
  let url = GITHUB_API_BASE & "/gists"
  
  try:
    let response = client.post(url, $requestBody)
    let json = handleResponse(response)
    result = json["id"].getStr("")
  except HttpRequestError as e:
    raise newException(GistError, "Failed to create gist: " & e.msg)
  except GistError:
    raise
  except Exception as e:
    raise newException(GistError, "Unexpected error creating gist: " & e.msg)

proc updateGist*(gist: Gist, token: string = "") =
  ## Update an existing gist on GitHub
  ## Requires the gist.id to be set
  ## Raises GistError if update fails or no token is available
  if gist.id == "":
    raise newException(GistError, "Gist ID required for update")
  
  let authToken = if token != "": token else: getGithubToken()
  if authToken == "":
    raise newException(GistError, "GitHub token required to update gists. Set GITHUB_TOKEN environment variable.")
  
  let client = newHttpClient()
  defer: client.close()
  
  client.headers = createAuthHeaders(authToken)
  
  # Build request JSON
  var filesJson = newJObject()
  for file in gist.files:
    filesJson[file.filename] = %* {
      "content": file.content
    }
  
  let requestBody = %* {
    "description": gist.description,
    "files": filesJson
  }
  
  let url = GITHUB_API_BASE & "/gists/" & gist.id
  
  try:
    let response = client.patch(url, $requestBody)
    discard handleResponse(response)
  except HttpRequestError as e:
    raise newException(GistError, "Failed to update gist: " & e.msg)
  except GistError:
    raise
  except Exception as e:
    raise newException(GistError, "Unexpected error updating gist: " & e.msg)

proc listUserGists*(username: string = "", token: string = ""): seq[Gist] =
  ## List gists for a user (or authenticated user if username is empty)
  ## Returns up to 30 most recent gists
  ## Raises GistError if listing fails
  let client = newHttpClient()
  defer: client.close()
  
  client.headers = createAuthHeaders(token)
  
  let url = if username != "":
    GITHUB_API_BASE & "/users/" & username & "/gists"
  else:
    # List authenticated user's gists
    let authToken = if token != "": token else: getGithubToken()
    if authToken == "":
      raise newException(GistError, "GitHub token required to list your gists. Set GITHUB_TOKEN environment variable.")
    GITHUB_API_BASE & "/gists"
  
  try:
    let response = client.get(url)
    let json = handleResponse(response)
    
    result = @[]
    for gistJson in json:
      result.add(parseGist(gistJson))
  except HttpRequestError as e:
    raise newException(GistError, "Failed to list gists: " & e.msg)
  except GistError:
    raise
  except Exception as e:
    raise newException(GistError, "Unexpected error listing gists: " & e.msg)

# ================================================================
# CONVENIENCE FUNCTIONS
# ================================================================

proc getFirstMarkdownFile*(gist: Gist): GistFile =
  ## Get the first markdown file from a gist
  ## Raises GistError if no markdown file is found
  for file in gist.files:
    if file.filename.endsWith(".md"):
      return file
  
  raise newException(GistError, "No markdown file found in gist")

proc hasMarkdownFile*(gist: Gist): bool =
  ## Check if gist contains at least one markdown file
  for file in gist.files:
    if file.filename.endsWith(".md"):
      return true
  return false

proc getFile*(gist: Gist, filename: string): GistFile =
  ## Get a specific file from a gist by name
  ## Raises GistError if file is not found
  for file in gist.files:
    if file.filename == filename:
      return file
  
  raise newException(GistError, "File '" & filename & "' not found in gist")

proc hasFile*(gist: Gist, filename: string): bool =
  ## Check if gist contains a specific file
  for file in gist.files:
    if file.filename == filename:
      return true
  return false

# ================================================================
# URL PARSING HELPERS
# ================================================================

proc extractGistIdFromUrl*(url: string): string =
  ## Extract gist ID from various GitHub gist URL formats
  ## Supports:
  ##   - https://gist.github.com/username/abc123
  ##   - https://gist.github.com/abc123
  ##   - gist.github.com/abc123
  ##   - abc123 (raw ID)
  let cleaned = url.strip()
  
  # If it doesn't contain a slash, assume it's already a gist ID
  if '/' notin cleaned and cleaned.len > 0:
    return cleaned
  
  # Extract from URL
  let parts = cleaned.split('/')
  if parts.len > 0:
    # Last segment is usually the gist ID
    let lastPart = parts[^1]
    # Remove query parameters if present
    let idPart = lastPart.split('?')[0]
    if idPart.len > 0:
      return idPart
  
  return ""

when isMainModule:
  # Simple test/example
  echo "GitHub Gist API Module"
  echo "====================="
  echo ""
  
  if hasGithubToken():
    echo "✓ GitHub token found"
  else:
    echo "✗ No GitHub token (set GITHUB_TOKEN environment variable)"
  
  echo ""
  echo "Example usage:"
  echo "  let gist = loadGist(\"abc123def456\")"
  echo "  echo gist.files[0].content"

# Usage

## Projects

Use the Project menu in the sidebar to create, import, export, or delete projects.

Project names are editable directly in the sidebar header. Use the chevron next to a project name to collapse or expand its requests.

## Requests

Each request has tabs for:

- Request: name, HTTP method, and URL
- Auth: authentication settings
- Query: query parameters
- Headers: request headers
- Body: JSON request body
- Notes: request notes
- Settings: request-specific behavior

Use `Command + Return` or the Send button to run the selected request.

## Authentication

SwiftCurl supports:

- No authentication
- Basic authentication
- Bearer token
- API key in a header or query parameter

Bearer tokens can be revealed with the Show switch in the Auth tab.

## HTTPS Certificate Bypass

The Settings tab includes an option to allow invalid SSL certificates.

This is intended for local development, self-signed certificates, or trusted internal systems. Keep it disabled for normal internet APIs.

## cURL Import And Export

Use Import cURL from the toolbar to add a request from a cURL command.

Use the cURL button in the request header to view the generated cURL command for the selected request.

## Responses

The response panel shows:

- HTTP status
- request duration
- response body
- response headers

Large responses are shown in an AppKit-backed text viewer for better performance.

MP3 and WAV responses are detected automatically and shown with an audio player instead of raw binary text.

Use Save Response to write the original response bytes to disk.

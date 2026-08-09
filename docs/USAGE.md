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

## Project Variables

Open a request's Variables tab to add values shared by every request in its project. Reference a value in a URL, query parameter, header, authentication field, or body with `{{name}}`, for example `https://{{server}}/api`. In the Bearer token field, enter `{{LoginToken}}`.

The same tab can capture a value after a request completes. Choose JSON body and enter a path such as `LoginToken`, `data.token`, or `items[0].id`; alternatively choose Response header and enter its name. A single JSON key also searches nested objects. The variable name may be left empty, in which case the last path component or header name is used automatically. The captured value creates or updates the project variable.

Captured JSON arrays are expanded into numbered project variables. For example, `"UserIds": [27, 42, 81]` creates `UserIds = 27`, `UserIds1 = 42`, and `UserIds2 = 81`. A one-item array creates only `UserIds`. Use an explicit path such as `UserIds[1]` when only a particular item is required.

Paths can also project a property across an array of objects. For example, `Value.User.AgentInfoList.Extension` collects the `Extension` value from every item and creates `Extension`, `Extension1`, `Extension2`, and so on. Use `Value.User.AgentInfoList[1].Extension` to capture only one array item.

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

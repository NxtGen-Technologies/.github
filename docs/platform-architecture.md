# MSS Platform Architecture — Cross-Repo Reference

> This doc covers how repos connect, shared patterns, and the checklist for adding new modules.
> Per-repo details stay in each repo's CLAUDE.md. Global coding standards: `claude/global-standards.md`.

## Repo Map

### MSS Admin Platform (Google OAuth + DynamoDB RBAC)

| Repo | Path | Role | Tech |
|------|------|------|------|
| `mysafespaces-admin` | `GitHub2/nxtgen-mysafespaces-admin` | Operations dashboard SPA | React 18, CRA, React Query v5, vanilla CSS |
| `mysafespaces-website` | `GitHub2/nxtgen-mysafespaces-website` | Public marketing site + lead intake | React 18, CRA, react-snap SSG, vanilla CSS |
| `mysafespaces-blog-service` | `GitHub2/nxtgen-mysafespaces-blog-service` | Blog API | Lambda + DynamoDB |
| `mysafespaces-assets` | `GitHub2/mysafespaces-assets` | Shared media/asset service | Lambda + DynamoDB + S3 + CloudFront |
| `mysafespaces-webinar` | `GitHub2/mysafespaces-webinar` | Webinar management + public registration | Lambda + DynamoDB + API Gateway |

### JourniPro Platform (Cognito BFF + Aurora PostgreSQL)

| Repo | Path | Role |
|------|------|------|
| `mss-journipro-core` | `GitHub/mss-journipro-core` | Shared library (DB, crypto, session, logging) |
| `mss-journipro-auth` | `GitHub/mss-journipro-auth` | OAuth BFF (Cognito token exchange) |
| `mss-journipro-admin` | `GitHub/mss-journipro-admin` | User/patient/practice provisioning Lambda |
| `mss-journipro-patient-sessions` | `GitHub/mss-journipro-patient-sessions` | SOAP notes + review workflow Lambda |
| `mss-journipro-people` | `GitHub/mss-journipro-people` | People directory service |
| `mss-journipro-web` | `GitHub/mss-journipro-web` | Practitioner/admin app (Next.js) |
| `mss-journipro-scheduling` | `GitHub/mss-journipro-scheduling` | Scheduling + booking API (Lambda) |
| `mss-journipro-booking-portal` | `GitHub/mss-journipro-booking-portal` | Public booking portal (Next.js) |

---

## Integration Map

### Admin Dashboard → Backend Services

Each admin module talks to its own Lambda via a dedicated API base URL from SSM:

```
Admin SPA  →  REACT_APP_{MODULE}_API_URL  →  API Gateway  →  Lambda handler  →  DynamoDB/PostgreSQL
```

Auth flow: Google OAuth token stored in `localStorage('mss_admin_token')` → sent as `Authorization: Bearer` header → Lambda verifies via Google userinfo/tokeninfo endpoints.

### Website → Backend Services

The website calls backend APIs for dynamic content:

| Feature | API | Auth |
|---------|-----|------|
| Blog posts | `REACT_APP_BLOG_API_URL` | None (public read) |
| Lead submission | `REACT_APP_CRM_API_URL` `/leads` | None (public write) |
| Job listings | `REACT_APP_JOBS_API_URL` `/jobs` | None (public read) |
| Job applications | `REACT_APP_JOBS_API_URL` `/applications` | None (public write) |
| Newsletter subscribe | `REACT_APP_BLOG_API_URL` `/subscribe` | None (public write) |
| Upcoming webinars | `REACT_APP_WEBINAR_API_URL` `/public/webinars/upcoming` | None (public read) |
| Webinar registration | `REACT_APP_WEBINAR_API_URL` `/public/webinars/{id}/register` | None (public write) |

**Key pattern**: Website endpoints are public (no auth). Admin endpoints require Google OAuth. When a Lambda serves both, route-level auth decisions are needed.

### Website → Assets CDN

Static assets (images, documents) served via CloudFront:
- Dev: `assets-dev.mysafespaces.org`
- Prod: `assets.mysafespaces.org`
- URL pattern: `https://{cdn}/{folder}/{timestamp}_{filename}`

### Admin → Assets Service

Upload flow (presigned URL pattern):
1. Admin SPA calls `POST /assets/upload-url` with `{ fileName, folder, program, tags }`
2. Lambda creates DynamoDB record + returns presigned S3 PUT URL (5-min expiry)
3. Admin SPA PUTs file directly to S3
4. CDN URL is immediately available

---

## Backend Service Inventory

### Admin Platform Services

| Service | Stack | Lambda | DB | Tables |
|---------|-------|--------|----|--------|
| CRM | `mss-admin-crm-{env}` | `mss-admin-crm-handler-{env}` | PostgreSQL | `mss_crm_*` |
| HR | `mss-hr-api-{env}` | `mss-admin-hr-handler-{env}` | PostgreSQL | `mss_hr_*` |
| RBAC | `mss-rbac-infrastructure-{env}` | `mss-admin-rbac-handler-{env}` | PostgreSQL | `mss_rbac_*` |
| SWISS | `mss-swiss-stack-{env}` | `mss-admin-swiss-{env}` | DynamoDB | `mss-swiss-*-{env}` |
| Blog | (separate repo) | (separate repo) | DynamoDB | `mss-blog-*-{env}` |
| Channel Partners | `mss-admin-channel-partner-{env}` | `mss-admin-channel-partner-handler-{env}` | DynamoDB | `mss-admin-channel-partner-*-{env}` |
| Counseling Network | `mss-admin-counseling-network-{env}` | `mss-admin-counseling-network-api-{env}` | DynamoDB | `mss-admin-counseling-network-*-{env}` |
| Customers | `mss-admin-customers-{env}` | `mss-admin-customers-handler-{env}` | DynamoDB | `mss-admin-customers-*-{env}` |
| Assets | `mss-admin-assets-{env}` | `mss-admin-assets-handler-{env}` | DynamoDB + S3 | `mss-admin-assets-{env}` |
| Jobs | `mss-admin-jobs-{env}` | `mss-admin-jobs-handler-{env}` | DynamoDB | `mss-admin-jobs-*-{env}` |
| Webinar | `mss-admin-webinar-{env}` | `mss-admin-webinar-api-{env}` | DynamoDB | `mss-admin-webinars-{env}`, `mss-admin-webinar-registrations-{env}` |

### SSM → Env Var Mapping (Admin)

| SSM Parameter | Env Var |
|---------------|---------|
| `/mysafespaces/{env}/api/blog` | `REACT_APP_API_URL` |
| `/mysafespaces/{env}/api/hr` | `REACT_APP_HR_API_URL` |
| `/mysafespaces/{env}/api/rbac` | `REACT_APP_RBAC_API_URL` |
| `/mysafespaces/{env}/api/swiss` | `REACT_APP_SWISS_API_URL` |
| `/mysafespaces/{env}/api/crm` | `REACT_APP_CRM_API_URL` |
| `/mysafespaces/{env}/api/channel-partner` | `REACT_APP_PARTNER_API_URL` |
| `/mysafespaces/{env}/api/counseling-network` | `REACT_APP_COUNSELING_NETWORK_API_URL` |
| `/mysafespaces/{env}/api/jobs` | `REACT_APP_JOBS_API_URL` |
| `/mysafespaces/{env}/api/customers` | `REACT_APP_CUSTOMERS_API_URL` |
| `/mysafespaces/{env}/api/assets` | `REACT_APP_ASSETS_API_URL` |
| `/mysafespaces/{env}/assets/cdn-url` | `REACT_APP_ASSETS_CDN_URL` |
| `/mysafespaces/{env}/api/webinar` | `REACT_APP_WEBINAR_API_URL` |
| `/mysafespaces/{env}/google/client-id` | `REACT_APP_GOOGLE_CLIENT_ID` |
| `/mysafespaces/{env}/admin/super-admin-emails` | `REACT_APP_SUPER_ADMIN_EMAILS` |

---

## Shared Patterns

### Lambda Handler Pattern (DynamoDB services)

All DynamoDB-backed admin services use a unified handler:

```
infrastructure/
  templates/mss-admin-{module}.yaml    # CloudFormation (API GW + Lambda + DynamoDB + IAM)
  lambda/
    {module}-handler.js                # Single handler, route matching via path + method
    auth-utils.js                      # Google OAuth verification (copy per service)
    ssm-utils.js                       # CORS headers + SSM config loading (copy per service)
    __tests__/
```

Handler structure:
1. Parse `httpMethod` + `path` from API Gateway event
2. OPTIONS → return CORS headers (204)
3. Verify auth via `auth-utils.js` (returns user email or 401)
4. Route matching: exact paths first, then regex patterns (e.g., `/items/bulk` before `/items/{id}`)
5. Zod validation on request body/query params
6. DynamoDB operation
7. Return `{ statusCode, headers: corsHeaders, body: JSON.stringify({ data }) }`

### Email Sending

**Browser-side (admin dashboard):**
- Gmail API via logged-in user's OAuth token (`mss_gmail_access_token`)
- Scopes: `gmail.send`, `gmail.compose`
- `emailService.js` handles MIME construction, bulk sending with rate limiting
- `EmailComposer` component: rich text editor, template selection, recipient management
- Template variables: `{{firstName}}`, `{{company}}` etc — regex substitution
- Tracking pixel injected via `emailApiService.wrapInHtmlTemplate()`
- Templates stored in CRM backend, fetched via `emailApiService.js`

**Limitation**: No server-side email. Automated/scheduled emails (reminders, confirmations) require SES or a service account — Gmail tokens expire and require browser interaction.

### File Upload (Presigned URL)

Frontend component: `AssetUploader.js`
- Props: `folder`, `program`, `tags`, `onUpload`, `accept`, `maxSizeMB`, `compact`
- States: idle → selected (confirm step) → uploading → success (shows CDN URL)
- Drag-and-drop supported

Frontend service: `assetsApiService.js`
- `uploadFile(file, { folder, program, tags })` — convenience wrapper
- `listAssets(params)` — query with pagination
- `updateAsset(assetId, { program, tags })` — inline edit metadata
- `deleteAsset(assetId)` — remove from S3 + DynamoDB

### CSV Import/Export/Template

Standard toolbar pattern for CSV operations (used in Leads, Webinars, Media, Partners, Counseling Network):

**Toolbar buttons** (order: Template → Import → Export → Refresh → Add):
- `toolbar-icon-btn` with `FileText` icon — download CSV template (sample headers + example row)
- `toolbar-icon-btn` wrapping `<label>` with hidden file input + `Upload` icon — import CSV
- `toolbar-icon-btn` with `Download` icon — export current list as CSV

**Import flow**:
- File input reads CSV via `FileReader`
- Strip UTF-8 BOM (`\uFEFF`), split lines, parse headers
- Validate required columns, parse rows (respecting quoted fields)
- Call API per row, track imported/failed counts
- If failures: show import result modal with downloadable CSV (original columns + `error_reason`)
- If all succeed: show success toast

**Export flow**:
```javascript
const csv = [headers, ...rows].map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(',')).join('\n');
const blob = new Blob([csv], { type: 'text/csv' });
// Create <a> element, set href to blob URL, trigger click, revoke URL
```

**Template flow**: Same as export but with hardcoded headers + one example row.

### RBAC & Permissions

- 4 levels: none (0), read (1), write (2), full (3)
- Module registry in `RBACContext.js` — must add new modules here
- Hook: `usePermissions(module)` → `{ canView, canEdit, canDelete, canManage, isSuperAdmin }`
- Route guard: `<ProtectedModule module="moduleName">` wraps page components
- Super admin bypass via `REACT_APP_SUPER_ADMIN_EMAILS`

### Toast Notifications

- `useToast()` hook — `showToast('success' | 'error', message)`
- Auto-dismiss, stackable
- Used after every mutation (create, update, delete, email send)

### Modal Pattern

- `useModalClose(isOpen, onClose, { isDirty, blockClose })` for unsaved changes detection
- Background click to close (blocked during processing)
- `DiscardConfirm` component for dirty state warnings

### Admin UI Component Library

Shared CSS files in `src/components/` provide consistent styling across all admin pages:

**Page Toolbar** (`Toolbar.css`):
- `page-actions` — right-aligned flex container (from `index.css`)
- `toolbar-icon-btn` — 40px square icon button (template, import, export, refresh)
- `toolbar-add-btn` — primary action button with icon + text ("Add Lead", "New Webinar")
- `toolbar-search` — search input with icon
- Button order: `[Search] ... [Template] [Import] [Export] [Refresh] [Add X]`

**Detail Modal** (`DetailModal.css`):
- `detail-modal` / `detail-modal wide` — slide-in modal container (700px / 920px)
- `modal-header` — gradient background with `detail-header-info` (badge + title + meta) + `close-btn`
- `modal-tabs` / `tab` / `tab.active` — horizontal tab strip
- `modal-content` — scrollable body with `info-grid` → `info-card` → `info-row` layout
- `detail-actions` — footer bar with `btn btn-primary` (save), `btn btn-danger` (delete), `btn btn-secondary` (cancel)

**Standard Buttons** (`index.css`):
- `btn btn-primary` — primary action (save, upload, submit)
- `btn btn-secondary` — secondary action (cancel, close, load more)
- `btn btn-danger` — destructive action (delete, archive)

Used by: LeadsPage, WebinarsPage. Apply to all new admin pages.

---

## Assets Service Details

### Folders (S3 organization)

| Folder | Content | MIME types |
|--------|---------|------------|
| `images` | Logos, photos, banners | PNG, JPG, SVG, WebP, GIF |
| `documents` | PDFs, Word, Excel, PPT | PDF, DOCX, XLSX, PPTX |
| `email-assets` | Email template images | Same as images |

Adding a folder requires updating `VALID_FOLDERS` in `infrastructure/lambda/content-types.js` (Zod enum validates).

### Programs (metadata tag)

Defined in admin `src/config/constants.js` as `ASSET_PROGRAMS`. Adding a program is frontend-only — no backend change needed. Current: swiss, blog, crm, email, hr.

### Video support

Not currently supported. Adding requires:
1. MIME types in `content-types.js` (`.mp4`, `.webm`, `.mov`)
2. Consider upload size — presigned URL expires in 5 min, may be too short for large files
3. May need multipart upload support for files >100MB

---

## Website Patterns

### Page Structure

All program pages follow: Hero → Stats → Problem → Features → Benefits → Tiers → CTA

### Lead Capture

Single modal system used site-wide:
- `ContactModalContext` provides `openContactModal(productId?)`
- `LeadIntakeModal`: 3-step form (product → contact details → org details)
- Submits to CRM API `/leads` endpoint (public, no auth)
- Products defined in `config/products.js`

### Blog / Dynamic Content

- Blog API fetched via `config/blogApi.js`
- Category filtering, pagination, featured "Editor's Picks"
- Post detail pages with related content
- SEO via react-helmet + JSON-LD structured data

### Routing

Two layout modes:
- `MainLayout`: Header + Footer + IntellicareWidget + LeadIntakeModal (most pages)
- `StandaloneLayout`: Clean layout without nav (special pages like TAISI)

### Environment Variables (Website)

```
REACT_APP_BLOG_API_URL, REACT_APP_CRM_API_URL, REACT_APP_JOBS_API_URL,
REACT_APP_PARTNER_API_URL, REACT_APP_WEBINAR_API_URL, REACT_APP_STUDENT_PORTAL_URL,
REACT_APP_ADMIN_PORTAL_URL, REACT_APP_THRIVE_ACADEMY_URL, REACT_APP_SWISS_PORTAL_URL,
REACT_APP_SWISS_WEBSITE_URL, REACT_APP_INTELLICARE_WIDGET_URL, REACT_APP_GOOGLE_CLIENT_ID,
REACT_APP_SUPER_ADMIN_EMAILS
```

---

## Checklist: Adding a New Admin Module (End-to-End)

### Backend (new repo or new stack in existing repo)

1. **CloudFormation template** — API Gateway + Lambda + DynamoDB table(s) + IAM role
   - Naming: `mss-admin-{module}-{env}` (stack), `mss-admin-{module}-handler-{env}` (Lambda)
   - DynamoDB: PAY_PER_REQUEST, point-in-time recovery, appropriate GSIs
2. **Lambda handler** — unified handler with route matching
   - Copy `auth-utils.js` and `ssm-utils.js` from an existing service
   - Zod validation on all inputs
   - CORS from SSM (`/mysafespaces/{env}/cors/allowed-origins`)
3. **SSM parameter** — `/mysafespaces/{env}/api/{module}` storing the API Gateway URL
4. **GitHub Actions workflow** — test → deploy CF → deploy Lambda → update SSM → smoke test
5. **Tests** — Jest unit tests for handler logic

### Admin Frontend (`mysafespaces-admin`)

6. **API service** — `src/services/{module}ApiService.js` with fetch + auth pattern
7. **Env var** — `REACT_APP_{MODULE}_API_URL` added to Amplify build config + SSM mapping
8. **Page component** — `src/pages/{Module}Page.js` + `{Module}Page.css`
9. **Route** — lazy-loaded in `App.js` wrapped in `<ProtectedModule module="{module}">`
10. **RBAC registration** — add module key to `MODULE_REGISTRY` in `RBACContext.js`
11. **Navigation** — add sidebar/nav link (conditional on `canView`)
12. **User guide** — `docs/user-guides/{module}.md` if user-facing

### If module has public-facing pages on website

13. **Public API endpoints** — unauthenticated routes in Lambda (separate from admin routes)
14. **Website API config** — add to `config/constants.js` API_ENDPOINTS
15. **Website env var** — `REACT_APP_{MODULE}_API_URL` in website Amplify config
16. **Website page/component** — route in `App.js`, follow existing page patterns
17. **SEO** — react-helmet meta tags, JSON-LD structured data if applicable

### If module uses assets

18. **Asset folder** — add to `VALID_FOLDERS` in assets service `content-types.js`
19. **Asset program** — add to `ASSET_PROGRAMS` in admin `config/constants.js`
20. **Media page** — add folder tab to `MediaPage.js` FOLDERS array

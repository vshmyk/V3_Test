# Parspec Migrator

Object-by-object migration harness for moving Oasis/MACSII business-layer data into Parspec.

Current working migration plan: [PARSPEC_MIGRATION_CHECKLIST.md](PARSPEC_MIGRATION_CHECKLIST.md)

## Current slice

The first implemented slice is `Users`.

Important constraint from the Parspec API contract:

- `GET /v1/users`
- `GET /v1/users/{userId}`
- `PATCH /v1/users/{userId}`

There is no public `POST /v1/users`, so user migration must be handled as:

1. inventory active Oasis users
2. match them to existing Parspec users
3. patch supported writable fields

## Commands

```powershell
cd tools\parspec-migrator
dotnet run -- users-scan
dotnet run -- companies-scan
dotnet run -- companies-create <erpCompanyId>
dotnet run -- purchase-orders-scan
dotnet run -- purchase-orders-export 100 0
dotnet run -- purchase-orders-export 20 0 ready-only
dotnet run -- locations-scan
dotnet run -- users-probe-api
dotnet run -- users-patch <parspecUserId> <oasisUserId>
```

`purchase-orders-export` prepares canonical PO headers and ordered lines using stable Oasis ERP IDs. Parspec currently publishes read-only Purchase Order endpoints, so the export is intentionally staged and no sandbox writes are attempted.

## Current user mapping assumptions

- Parspec `erpId` <- `OASIS_MACSII.oasis.CHSC_USERS.USERID`
- Parspec `crmId` <- `MACSII_V2.AO.User.Id`
- Parspec `name` <- `FIRSTNAME + LASTNAME` for reporting only
- Parspec `lastActiveDateTime` <- `CHSC_USERS.LASTLOGIN` for reporting only

Still unresolved for the first pass:

- Parspec `defaultLocation`
- Parspec `locationAccess`
- reliable destination-user matching strategy in Parspec
- whether missing user email can be sourced elsewhere for validation/matching

## Location mappings

`users-scan` now consumes `LocationMappings` from [appsettings.json](appsettings.json).

Run this first:

```powershell
dotnet run -- locations-scan
```

That command inventories source-side codes such as:

- `MACS-LTG-`
- `MACS-ELEC-`
- `MACS-POW-`
- `MACS-PQ-`
- `MACS-IND-`

Once the real Parspec location IDs are known, set them in `LocationMappings` and rerun `users-scan`.

For the current MACSII sandbox tenant, all five source workgroup codes are temporarily mapped to Parspec location `2592` (`Mac's II`) so user PATCH payloads can be validated end-to-end.

## Configuration

Edit [appsettings.json](appsettings.json) or set `PARSPEC_API_KEY`.

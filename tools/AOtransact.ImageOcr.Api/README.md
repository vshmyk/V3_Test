# AOtransact.ImageOcr.Api

Local HTTP API for OCR on document images, suitable for IIS hosting.

## Run

```powershell
dotnet run --project tools\AOtransact.ImageOcr.Api
```

By default ASP.NET Core prints the listening URL, usually something like `http://localhost:5000` or `http://localhost:5183`.

## Endpoints

`GET /health`

Returns a simple health payload.

`POST /ocr`

Accepts `multipart/form-data` with:

- `file` required image file
- `lang` optional OCR language, default `eng`
- `psm` optional Tesseract page segmentation mode integer, default `6`

Authorization:

- send the API key in the `X-Api-Key` header
- header name can be changed with `OcrApi:ApiKeyHeaderName`

## PowerShell example

```powershell
$form = @{
  file = Get-Item C:\path\to\scan.png
  lang = "eng"
  psm = "6"
}

Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:5000/ocr `
  -Headers @{ "X-Api-Key" = "change-this-dev-key" } `
  -Form $form
```

## curl example

```powershell
curl.exe -X POST http://localhost:5000/ocr `
  -H "X-Api-Key: change-this-dev-key" `
  -F "file=@C:\path\to\scan.png" `
  -F "lang=eng" `
  -F "psm=6"
```

## IIS publish

Publish the app:

```powershell
.\tools\AOtransact.ImageOcr.Api\Publish-Iis.ps1
```

That creates IIS-ready output in:

```text
tools\AOtransact.ImageOcr.Api\bin\Release\net8.0\publish
```

## IIS setup

1. Install the ASP.NET Core Hosting Bundle for .NET 8 on the IIS server.
2. Create an IIS site pointing to the publish folder.
3. Enable HTTPS on the site and bind a certificate.
4. In IIS Manager, set an environment variable for the app:

```text
OcrApi__ApiKey=your-long-random-secret
```

5. Optionally set:

```text
OcrApi__ApiKeyHeaderName=X-Api-Key
OcrApi__MaxUploadBytes=10485760
OcrApi__RequireHttps=true
ASPNETCORE_ENVIRONMENT=Production
```

6. Restrict inbound access in the firewall to the caller IPs you trust if possible.

## Security notes

- Do not store the production API key in `appsettings.json`.
- Prefer a long random key passed through IIS environment variables.
- Keep HTTPS enabled when exposing this outside your network.
- If this will be internet-facing, IP allowlisting in IIS or the firewall is strongly recommended in addition to the API key.

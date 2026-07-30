# AOtransact.ImageOcr

Lightweight local OCR for document images using Tesseract.

## Build

```powershell
dotnet build tools\AOtransact.ImageOcr
```

## Run

Single image to stdout:

```powershell
dotnet run --project tools\AOtransact.ImageOcr -- --input C:\path\to\scan.png --stdout
```

Folder of images to text files:

```powershell
dotnet run --project tools\AOtransact.ImageOcr -- --input C:\path\to\images --output C:\path\to\ocr-output
```

## Notes

- Supported image types: `.png`, `.jpg`, `.jpeg`, `.tif`, `.tiff`, `.bmp`
- Default language: `eng`
- Default page segmentation mode: `6` (`SingleBlock`)
- English trained data is bundled through NuGet, so no separate Tesseract install is required

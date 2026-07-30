# AOtransact.RfqExtractor

Prototype CLI for extracting RFQ metadata from PDF documents using:

- local PDF text extraction
- OCR fallback for scanned or weak-text pages
- Azure Foundry Anthropic-compatible model calls
- structured JSON output for downstream import flows

## What It Extracts

The prompt is currently tuned for:

- `projectName`
- `clientDistributor`
- `customer`
- `endUser`
- `engineers`
- `architects`
- `contractors`
- `additionalEntities`
- `summary`
- `warnings`

## Run

```powershell
$env:AZURE_API_KEY = "your-key"
dotnet run --project tools\AOtransact.RfqExtractor -- `
  --input "C:\Users\you\Documents\RFQ.pdf" `
  --save-text `
  --stdout
```

Optional flags:

```powershell
--output C:\temp\rfq-output
--endpoint https://centeraai.services.ai.azure.com/anthropic/v1/messages
--model claude-opus-4-8
--max-pages 12
--max-tokens 1600
--ocr always
--ocr-scale 2.5
--min-direct-text-chars 80
```

## Outputs

- `<name>.text.txt`: extracted PDF text when `--save-text` is used
- `<name>.rfq.json`: normalized `rfq-import-v1` payload plus document/method metadata

## Schema Notes

- The result includes `schemaVersion: "rfq-import-v1"`.
- `importRecord` contains normalized scalar fields with `value`, `evidence`, and `confidence`.
- Party lists such as `engineers`, `architects`, and `contractors` are always arrays.
- `document.pageMethods` shows whether each page used direct text, OCR fallback, or OCR only.
- The default path is now OCR-first, which is usually more reliable for title blocks, drawing sheets, and scanned RFQ packages.

## Current Limitation

This pass is tuned for document-level metadata extraction, not line-item/spec parsing. OCR quality also depends on scan quality and drawing density.

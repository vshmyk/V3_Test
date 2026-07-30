using AOtransact.ImageOcr.Core;
using Tesseract;

var parseResult = Options.Parse(args);
if (!parseResult.Success)
{
    if (!string.IsNullOrWhiteSpace(parseResult.ErrorMessage))
    {
        Console.Error.WriteLine(parseResult.ErrorMessage);
        Console.Error.WriteLine();
    }

    Console.Error.WriteLine(Options.Usage);
    return parseResult.ExitCode;
}

var options = parseResult.Value!;
var engine = new ImageOcrEngine();
var inputs = engine.ResolveInputs(options.InputPath);
if (inputs.Count == 0)
{
    Console.Error.WriteLine($"No supported image files were found at '{options.InputPath}'.");
    return 1;
}

Directory.CreateDirectory(options.OutputDirectory);

foreach (var input in inputs)
{
    var result = engine.RecognizeFile(input, options.Language, options.PageSegMode);

    if (options.WriteToStdOut && inputs.Count == 1)
    {
        Console.WriteLine(result.Text);
        continue;
    }

    var outputFile = Path.Combine(
        options.OutputDirectory,
        $"{Path.GetFileNameWithoutExtension(input)}.txt");

    File.WriteAllText(outputFile, result.Text);
    Console.WriteLine($"{Path.GetFileName(input)} -> {outputFile}");
}

return 0;

internal sealed record Options(
    string InputPath,
    string OutputDirectory,
    string Language,
    PageSegMode PageSegMode,
    bool WriteToStdOut)
{
    public const string Usage =
        """
        Usage:
          dotnet run --project tools/AOtransact.ImageOcr -- --input <image-or-folder> [--output <folder>] [--lang eng] [--psm 6] [--stdout]

        Notes:
          --input   Required. A single image file or a folder of images.
          --output  Defaults to an 'ocr-output' folder beside the input.
          --lang    Defaults to 'eng'.
          --psm     Tesseract page segmentation mode. Defaults to 6.
          --stdout  Prints OCR text to stdout for a single input file.
        """;

    public static ParseResult<Options> Parse(string[] args)
    {
        if (args.Length == 0)
        {
            return ParseResult<Options>.Fail("Missing arguments.");
        }

        string? inputPath = null;
        string? outputDirectory = null;
        var language = "eng";
        var pageSegMode = PageSegMode.SingleBlock;
        var writeToStdOut = false;

        for (var i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--input":
                case "-i":
                    if (!TryReadValue(args, ref i, out inputPath))
                    {
                        return ParseResult<Options>.Fail("Missing value for --input.");
                    }
                    break;
                case "--output":
                case "-o":
                    if (!TryReadValue(args, ref i, out outputDirectory))
                    {
                        return ParseResult<Options>.Fail("Missing value for --output.");
                    }
                    break;
                case "--lang":
                    if (!TryReadValue(args, ref i, out language))
                    {
                        return ParseResult<Options>.Fail("Missing value for --lang.");
                    }
                    break;
                case "--psm":
                    if (!TryReadValue(args, ref i, out var psmRaw) || !int.TryParse(psmRaw, out var psmValue))
                    {
                        return ParseResult<Options>.Fail("Missing or invalid value for --psm.");
                    }

                    if (!Enum.IsDefined(typeof(PageSegMode), psmValue))
                    {
                        return ParseResult<Options>.Fail($"Unsupported page segmentation mode '{psmValue}'.");
                    }

                    pageSegMode = (PageSegMode)psmValue;
                    break;
                case "--stdout":
                    writeToStdOut = true;
                    break;
                case "--help":
                case "-h":
                case "/?":
                    return ParseResult<Options>.Fail(string.Empty, 0);
                default:
                    return ParseResult<Options>.Fail($"Unknown argument '{args[i]}'.");
            }
        }

        if (string.IsNullOrWhiteSpace(inputPath))
        {
            return ParseResult<Options>.Fail("Missing required --input argument.");
        }

        var fullInputPath = Path.GetFullPath(inputPath);
        outputDirectory ??= Path.Combine(
            Directory.Exists(fullInputPath) ? fullInputPath : Path.GetDirectoryName(fullInputPath)!,
            "ocr-output");

        var selectedLanguage = string.IsNullOrWhiteSpace(language) ? "eng" : language;

        return ParseResult<Options>.Ok(new Options(
            fullInputPath,
            Path.GetFullPath(outputDirectory),
            selectedLanguage,
            pageSegMode,
            writeToStdOut));
    }

    private static bool TryReadValue(string[] args, ref int index, out string? value)
    {
        if (index + 1 >= args.Length)
        {
            value = null;
            return false;
        }

        index++;
        value = args[index];
        return true;
    }
}

internal sealed record ParseResult<T>(bool Success, T? Value, string ErrorMessage, int ExitCode)
{
    public static ParseResult<T> Ok(T value) => new(true, value, string.Empty, 0);

    public static ParseResult<T> Fail(string message, int exitCode = 1) => new(false, default, message, exitCode);
}

using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;

namespace AOtransact.ImageOcr.Api;

internal static class ApiKeyAuth
{
    public static bool IsAuthorized(HttpRequest request, OcrApiOptions options)
    {
        if (string.IsNullOrWhiteSpace(options.ApiKey))
        {
            throw new InvalidOperationException("OCR API key is not configured.");
        }

        if (!request.Headers.TryGetValue(options.ApiKeyHeaderName, out var providedValues))
        {
            return false;
        }

        var provided = providedValues.ToString();
        if (string.IsNullOrWhiteSpace(provided))
        {
            return false;
        }

        var expectedBytes = Encoding.UTF8.GetBytes(options.ApiKey);
        var providedBytes = Encoding.UTF8.GetBytes(provided);
        return CryptographicOperations.FixedTimeEquals(expectedBytes, providedBytes);
    }

    public static RouteHandlerBuilder RequireApiKey(this RouteHandlerBuilder builder)
    {
        return builder.AddEndpointFilter(async (context, next) =>
        {
            var httpContext = context.HttpContext;
            var options = httpContext.RequestServices.GetRequiredService<IOptions<OcrApiOptions>>().Value;

            if (!IsAuthorized(httpContext.Request, options))
            {
                return Results.Json(new { error = "Unauthorized." }, statusCode: StatusCodes.Status401Unauthorized);
            }

            return await next(context);
        });
    }
}

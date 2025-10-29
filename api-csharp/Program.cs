using System.Threading.RateLimiting;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.ResponseCompression;

ThreadPool.SetMinThreads(100, 100);

var builder = WebApplication.CreateBuilder(args);

// CORS yapılandırması
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll",
        policy =>
        {
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        });
});

builder.Services.AddResponseCompression(options =>
{
    options.Providers.Add<BrotliCompressionProvider>();
    options.EnableForHttps = true;
});

builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.TypeInfoResolverChain.Add(RateLimitJsonContext.Default);
    options.SerializerOptions.TypeInfoResolverChain.Add(WorldClockJsonContext.Default);
});

// HttpClient with Resilience for Go API
var goApiUrl = Environment.GetEnvironmentVariable("GO_API_URL") ?? "http://datetime-api-go-service";
builder.Services.AddHttpClient("GoApiClient", client =>
{
    client.BaseAddress = new Uri(goApiUrl);
    client.Timeout = TimeSpan.FromSeconds(30);
})
.AddStandardResilienceHandler(options =>
{
    // Retry policy: 3 attempts with exponential backoff
    options.Retry.MaxRetryAttempts = 3;
    options.Retry.UseJitter = true;

    // Circuit breaker: Open after 5 failures in 30 seconds
    options.CircuitBreaker.FailureRatio = 0.5;
    options.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(30);
    options.CircuitBreaker.MinimumThroughput = 5;
    options.CircuitBreaker.BreakDuration = TimeSpan.FromSeconds(30);

    // Total timeout
    options.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(10);
});

// Rate Limiting
builder.Services.AddRateLimiter(options =>
{
    // Global rate limit: 100 requests per second
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
    {
        return RateLimitPartition.GetTokenBucketLimiter("global", _ =>
            new TokenBucketRateLimiterOptions
            {
                TokenLimit = 100,
                ReplenishmentPeriod = TimeSpan.FromSeconds(1),
                TokensPerPeriod = 100,
                QueueLimit = 10
            });
    });

    // Per-endpoint rate limits
    options.AddPolicy("go-api-calls", context =>
    {
        // Rate limit for calls to Go API: 20 req/sec
        if (context.Request.Path.StartsWithSegments("/api/go-time"))
        {
            return RateLimitPartition.GetTokenBucketLimiter("go-api-endpoint", _ =>
                new TokenBucketRateLimiterOptions
                {
                    TokenLimit = 20,
                    ReplenishmentPeriod = TimeSpan.FromSeconds(1),
                    TokensPerPeriod = 20,
                    QueueLimit = 5
                });
        }
        return RateLimitPartition.GetNoLimiter("unlimited");
    });

    options.OnRejected = async (context, token) =>
    {
        context.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
        var retryAfterSeconds = context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter)
            ? (double?)retryAfter.TotalSeconds
            : null;

        var error = new RateLimitErrorResponse(
            "Rate limit exceeded",
            "Too many requests. Please try again later.",
            retryAfterSeconds);

        await context.HttpContext.Response.WriteAsJsonAsync(
            error, 
            jsonTypeInfo: RateLimitJsonContext.Default.RateLimitErrorResponse, 
            cancellationToken: token);

    };
});

var turkishDays = new[] {
      "Pazar", "Pazartesi", "Salı", "Çarşamba",
      "Perşembe", "Cuma", "Cumartesi"
  };

var app = builder.Build();

app.UseCors("AllowAll");
app.UseRateLimiter();

app.MapGet("/api/datetime", () =>
{
    var now = DateTime.Now;
    return Results.Ok(new DateTimeResponse(
        now.ToString("dd.MM.yyyy"),
        now.ToString("HH:mm:ss"),
        turkishDays[(int)now.DayOfWeek],
        now.ToString("o")
    ));
});

app.MapGet("/health", () =>
{
    var podName = Environment.GetEnvironmentVariable("HOSTNAME") ?? "unknown";
    var nodeName = Environment.GetEnvironmentVariable("NODE_NAME") ?? "unknown";

    return Results.Ok(new HealthResponse(
        "healthy",
        podName,
        nodeName,
        "datetime-api-csharp"
    ));
});

// New endpoint: Call Go API and get world clock data
app.MapGet("/api/go-time", async (IHttpClientFactory httpClientFactory, CancellationToken cancellationToken) =>
{
    try
    {
        var client = httpClientFactory.CreateClient("GoApiClient");
        var goApiUrl = "/api/worldclock/city?timezone=Europe/Istanbul";
        var response = await client.GetAsync(goApiUrl);

        if (response.IsSuccessStatusCode)
        {
            // Trimming-safe deserialization: source-generated JsonTypeInfo kullanıyoruz
            var goData = await response.Content.ReadFromJsonAsync(
                WorldClockJsonContext.Default.WorldClockResponse,
                cancellationToken
            );

            // Global context ile Results.Json/Ok çağrısı trimming-safe olarak serileştirir
            return Results.Ok(new GoTimeResponse(
                "csharp-api",
                "go-api",
                goApiUrl,
                goData,
                DateTime.UtcNow
            ));
        }

        return Results.Problem(
            detail: $"Go API returned status code: {response.StatusCode}",
            statusCode: (int)response.StatusCode
        );
    }
    catch (Exception ex)
    {
        return Results.Problem(
            detail: $"Failed to call Go API: {ex.Message}",
            statusCode: StatusCodes.Status503ServiceUnavailable
        );
    }
}).RequireRateLimiting("go-api-calls");

app.Run();


public record RateLimitErrorResponse(string Error, string Message, double? RetryAfter);
public record DateTimeResponse(string Date, string Time, string DayOfWeek, string Timestamp);
public record HealthResponse(string Status, string Pod, string Node, string Service);
public record GoTimeResponse(string Source, string CalledService, string Endpoint, WorldClockResponse? Data, DateTime Timestamp);
public sealed class WorldClockResponse
{
    public string City { get; set; } = default!;
    public string Timezone { get; set; } = default!;
    public string Time { get; set; } = default!;
    public string Date { get; set; } = default!;
    public string Offset { get; set; } = default!;
    public bool IsDst { get; set; }
}

[JsonSerializable(typeof(RateLimitErrorResponse))]
[JsonSerializable(typeof(DateTimeResponse))]
[JsonSerializable(typeof(HealthResponse))]
[JsonSerializable(typeof(GoTimeResponse))]
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
public partial class RateLimitJsonContext : JsonSerializerContext
{
}

[JsonSerializable(typeof(WorldClockResponse))]
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
public partial class WorldClockJsonContext : JsonSerializerContext
{
}
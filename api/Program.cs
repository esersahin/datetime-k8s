using System.Threading.RateLimiting;

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

        await context.HttpContext.Response.WriteAsJsonAsync(new
        {
            error = "Rate limit exceeded",
            message = "Too many requests. Please try again later.",
            retryAfter = retryAfterSeconds
        }, cancellationToken: token);
    };
});

var app = builder.Build();

app.UseCors("AllowAll");
app.UseRateLimiter();

app.MapGet("/api/datetime", () =>
{
    var now = DateTime.Now;
    return Results.Ok(new
    {
        date = now.ToString("dd.MM.yyyy"),
        time = now.ToString("HH:mm:ss"),
        dayOfWeek = now.ToString("dddd", new System.Globalization.CultureInfo("tr-TR")),
        timestamp = now.ToString("o")
    });
});

app.MapGet("/health", () =>
{
    var podName = Environment.GetEnvironmentVariable("HOSTNAME") ?? "unknown";
    var nodeName = Environment.GetEnvironmentVariable("NODE_NAME") ?? "unknown";

    return Results.Ok(new
    {
        status = "healthy",
        pod = podName,
        node = nodeName,
        service = "datetime-api"
    });
});

// New endpoint: Call Go API and get world clock data
app.MapGet("/api/go-time", async (IHttpClientFactory httpClientFactory) =>
{
    try
    {
        var client = httpClientFactory.CreateClient("GoApiClient");
        var response = await client.GetAsync("/api/worldclock?city=Istanbul");

        if (response.IsSuccessStatusCode)
        {
            var goData = await response.Content.ReadFromJsonAsync<object>();
            return Results.Ok(new
            {
                source = "csharp-api",
                calledService = "go-api",
                endpoint = "/api/worldclock?city=Istanbul",
                data = goData,
                timestamp = DateTime.UtcNow
            });
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
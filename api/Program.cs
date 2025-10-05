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

var app = builder.Build();

app.UseCors("AllowAll");

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

app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

app.Run();
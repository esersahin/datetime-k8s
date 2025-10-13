# Servisler Arası İletişim ve Resiliency Implementasyonu

## 📋 İçindekiler

1. [Projenin Başlangıç Durumu](#-projenin-başlangıç-durumu)
2. [Problem: Neden Servisler Arası İletişim?](#-problem-neden-servisler-arası-iletişim)
3. [Terimler ve Kavramlar](#-terimler-ve-kavramlar)
4. [Tasarım Kararları](#-tasarım-kararları)
5. [C# API Değişiklikleri (.NET 9)](#-c-api-değişiklikleri-net-9)
6. [Go API Değişiklikleri](#-go-api-değişiklikleri)
7. [Kubernetes Değişiklikleri](#-kubernetes-değişiklikleri)
8. [Test Senaryoları](#-test-senaryoları)
9. [Sorun Giderme](#-sorun-giderme)
10. [Gelecek İyileştirmeler](#-gelecek-iyileştirmeler)

---

## 🎯 Projenin Başlangıç Durumu

### Mevcut Durum (Değişiklikten Önce)

Projede iki farklı dilde yazılmış DateTime API'leri vardı:

```
┌─────────────────────┐
│   C# API (.NET 9)   │
│   - /api/datetime   │
│   - /health         │
└─────────────────────┘
         ↑
         │ (Web'den istek)
         │
    ┌────┴────┐
    │   Web   │
    └─────────┘

┌─────────────────────┐
│   Go API            │
│   - /api/worldclock │
│   - /api/countdown  │
│   - /health         │
└─────────────────────┘
         ↑
         │ (Web-Go'dan istek)
         │
    ┌────┴─────┐
    │  Web-Go  │
    └──────────┘
```

**Sorun**: İki API birbirinden habersiz çalışıyordu. Gerçek bir "polyglot mikroservis mimarisi" için servisler arası iletişim gerekiyordu.

---

## 🔍 Problem: Neden Servisler Arası İletişim?

### 1. Polyglot Mikroservis Mimarisi

**Ne demek?** Farklı programlama dillerinde yazılmış mikroservislerin birlikte çalışması.

**Neden önemli?**
- Her dil kendi güçlü yönlerinde kullanılır (C# → business logic, Go → performance-critical operations)
- Servisler birbirlerinin yeteneklerinden faydalanabilir
- Gerçek dünya senaryolarını simüle eder

### 2. Resiliency (Dayanıklılık) İhtiyacı

**Ne demek?** Sistemin hatalara karşı dirençli olması ve kendi kendini iyileştirmesi.

**Neden gerekli?**
- Bir servis çökerse diğerlerini etkilememeli
- Ağ sorunları olduğunda otomatik retry yapmalı
- Aşırı yük altında sistem korunmalı

---

## 📚 Terimler ve Kavramlar

### 1. Circuit Breaker (Devre Kesici)

**Ne işe yarar?**
Elektrik sigortası gibi çalışır. Bir servis sürekli hata veriyorsa, ona istek göndermeyi keser.

**Analoji:**
```
Evdeki elektrik sigortası:
├─ Normal → Elektrik akar
├─ Kısa devre → Sigorta atar (open)
└─ 5 dakika sonra → Sigorta tekrar denenir (half-open)
```

**Kod Örneği:**
```csharp
// 5 hata olursa → 30 saniye bekle
CircuitBreaker.FailureRatio = 0.5;        // %50 hata oranı
CircuitBreaker.SamplingDuration = 30s;    // 30 saniye içinde ölç
CircuitBreaker.BreakDuration = 30s;       // 30 saniye bekle
```

**Durumlar:**
- **Closed (Kapalı)**: Normal çalışıyor, istekler geçiyor
- **Open (Açık)**: Çok fazla hata var, istekler reddediliyor
- **Half-Open (Yarı-Açık)**: Test ediliyor, birkaç istek deneniyor

### 2. Retry Policy (Tekrar Deneme Politikası)

**Ne işe yarar?**
Başarısız istekleri otomatik olarak tekrar dener.

**Exponential Backoff (Üstel Geri Çekilme):**
```
1. deneme → Hemen
2. deneme → 100ms bekle
3. deneme → 200ms bekle
4. deneme → 400ms bekle
```

**Neden Exponential?**
- Sunucu yükünü azaltır
- Geçici sorunların düzelmesi için zaman tanır
- Ağ tıkanıklığını önler

**Jitter (Rastgelelik):**
```
Jitter olmadan:
Tüm istemciler → 100ms'de aynı anda → Tekrar yük

Jitter ile:
İstemci 1 → 95ms bekle
İstemci 2 → 103ms bekle
İstemci 3 → 98ms bekle
→ Yük dağılır
```

### 3. Rate Limiting (Hız Sınırlama)

**Ne işe yarar?**
Saniye başına maksimum istek sayısını sınırlar.

**Token Bucket Algoritması:**

```
Kova Kapasitesi: 10 token
Yenileme Hızı: 5 token/saniye

[Başlangıç]
Kova: 🪙🪙🪙🪙🪙🪙🪙🪙🪙🪙 (10/10)

[İstek geldi]
Kova: 🪙🪙🪙🪙🪙🪙🪙🪙🪙   (9/10)  ✅ İzin verildi

[10 istek birden]
Kova: (boş)                    (0/10)

[11. istek]
❌ 429 Too Many Requests

[1 saniye sonra]
Kova: 🪙🪙🪙🪙🪙              (5/10)  ✅ 5 token eklendi
```

**Neden Token Bucket?**
- Burst traffic'e izin verir (kova doluysa)
- Sürekli yük altında stabilize olur
- Adil kaynak dağılımı sağlar

**Per-Service Rate Limiting:**
```
C# API Total: 100 req/sec
├─ Go API'ye yapılan çağrılar: 20 req/sec (özel limit)
└─ Diğer endpoint'ler: 80 req/sec

Neden?
→ Bir servis diğerini boğamaz
→ Cascading failure önlenir
```

### 4. Service Discovery (Servis Keşfi)

**Ne işe yarar?**
Bir servisin diğerini nasıl bulacağını belirler.

**Kubernetes DNS:**
```
C# API → Go API'yi çağırmak ister
└─ URL: http://datetime-api-go-service
   └─ Kubernetes DNS → IP'yi bulur (örn: 10.96.87.242)
      └─ Load Balancer → 3 pod'dan birine yönlendirir
```

**Avantajları:**
- IP adresleri değişse de kod değişmez
- Otomatik load balancing
- Service mesh uyumlu

### 5. Timeout (Zaman Aşımı)

**Ne işe yarar?**
Bir isteğin ne kadar bekleyeceğini belirler.

```
Total Request Timeout: 10s
├─ İstek gönder
├─ 10 saniye içinde cevap gelmezse
└─ ❌ Timeout error
```

**Neden önemli?**
- Sonsuza kadar bekleyen thread'ler kaynakları tüketir
- Kullanıcı deneyimini korur
- Cascading timeout'ları önler

### 6. Fallback (Yedek Plan)

**Ne işe yarar?**
Ana servis çalışmazsa ne yapılacağını belirler.

```
C# API → Go API çağırır
├─ ✅ Başarılı → Go'dan gelen data
└─ ❌ Başarısız →
   └─ Cache'den eski data
   └─ Default değer
   └─ Error mesajı
```

---

## 🎨 Tasarım Kararları

### 1. Neden .NET 9 Built-in Resiliency?

**Alternatifler:**
- ❌ Polly (3rd party library)
- ✅ Microsoft.Extensions.Http.Resilience (built-in)

**Tercih Sebebi:**
```
Built-in Avantajları:
├─ Microsoft'un resmi desteği
├─ .NET ile derin entegrasyon
├─ Performans optimizasyonları
├─ Dependency azlığı
└─ Long-term support
```

### 2. Neden gobreaker (Go için)?

**Alternatifler:**
- go-resiliency/circuitbreaker
- sony/gobreaker ✅
- hystrix-go

**Tercih Sebebi:**
```
gobreaker Avantajları:
├─ Basit API
├─ Aktif bakım
├─ Hafif (minimum dependency)
├─ İyi dokümantasyon
└─ Production-proven
```

### 3. Rate Limiting Değerleri

**C# API:**
```
Global: 100 req/sec
Go API Calls: 20 req/sec

Neden 20?
→ Go API'ye aşırı yük binmemesi için
→ Diğer endpoint'lere de quota kalsın
→ 100'ün %20'si → Adil dağılım
```

**Go API:**
```
Global: 150 req/sec
C# API Calls: 30 req/sec

Neden 150?
→ Go daha performanslı
→ Daha fazla yük kaldırabilir
→ C#'dan %50 daha fazla
```

### 4. Circuit Breaker Değerleri

**Neden 5 hata?**
```
Çok düşük (2 hata) → Yanlış alarm çok olur
Çok yüksek (20 hata) → Geç müdahale
5 hata → Dengeli
```

**Neden 30 saniye break?**
```
Çok kısa (5s) → Servis toparlanamaz
Çok uzun (5min) → Kullanıcılar çok bekler
30s → Sunucu toparlanması + Kullanıcı deneyimi
```

---

## 🔧 C# API Değişiklikleri (.NET 9)

### 1. NuGet Paketi Ekleme

**Dosya:** `api/DateTimeApi.csproj`

```xml
<ItemGroup>
    <PackageReference Include="Microsoft.Extensions.Http.Resilience" Version="9.0.0" />
</ItemGroup>
```

**Neden?**
- .NET 9'un resiliency özellikleri bu pakette
- Circuit breaker, retry, timeout built-in

### 2. HttpClient ve Resiliency Konfigürasyonu

**Dosya:** `api/Program.cs`

```csharp
using System.Threading.RateLimiting;

// HttpClient with Resilience for Go API
var goApiUrl = Environment.GetEnvironmentVariable("GO_API_URL")
    ?? "http://datetime-api-go-service";

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
```

**Satır Satır Açıklama:**

1. **`AddHttpClient("GoApiClient")`**
   - Named HTTP client oluşturur
   - Dependency injection ile kullanılabilir
   - Her istek için yeni HttpClient oluşturmaz (performans)

2. **`client.BaseAddress`**
   - Go API'nin base URL'i
   - Environment variable'dan alınır (Kubernetes'te override edilebilir)
   - Default: Service DNS name

3. **`AddStandardResilienceHandler()`**
   - .NET 9'un built-in resiliency pipeline'ı
   - Retry + Circuit Breaker + Timeout otomatik

4. **`Retry.MaxRetryAttempts = 3`**
   - Başarısız istek için 3 kez daha dene
   - Total: 4 deneme (1 original + 3 retry)

5. **`Retry.UseJitter = true`**
   - Her retry'a rastgele gecikme ekle
   - Thundering herd problemini önler

6. **`CircuitBreaker.FailureRatio = 0.5`**
   - %50 hata oranında circuit aç
   - Örnek: 10 istekten 5'i başarısız → Circuit açılır

7. **`CircuitBreaker.SamplingDuration = 30s`**
   - 30 saniye içindeki istekleri değerlendir
   - Pencere kayar (sliding window)

8. **`CircuitBreaker.MinimumThroughput = 5`**
   - En az 5 istek olmalı ki değerlendirme yapılsın
   - 2-3 istek için circuit açmaz

9. **`CircuitBreaker.BreakDuration = 30s`**
   - Circuit açıldığında 30 saniye bekle
   - Sonra half-open'a geç

10. **`TotalRequestTimeout.Timeout = 10s`**
    - Tüm işlem (retry'lar dahil) 10 saniyede bitmeli
    - ⚠️ **ÖNEMLİ:** SamplingDuration'ın en az 2 katı olmalı!
    - Yoksa: `OptionsValidationException` hatası

### 3. Rate Limiting Konfigürasyonu

**Dosya:** `api/Program.cs`

```csharp
builder.Services.AddRateLimiter(options =>
{
    // Global rate limit: 100 requests per second
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
    {
        return RateLimitPartition.GetTokenBucketLimiter("global", _ =>
            new TokenBucketRateLimiterOptions
            {
                TokenLimit = 100,          // Kova kapasitesi
                ReplenishmentPeriod = TimeSpan.FromSeconds(1),  // 1 saniyede
                TokensPerPeriod = 100,     // 100 token ekle
                QueueLimit = 10            // 10 istek kuyruğa alınabilir
            });
    });

    // Per-endpoint rate limits
    options.AddPolicy("go-api-calls", context =>
    {
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
```

**Satır Satır Açıklama:**

1. **`GlobalLimiter`**
   - Tüm endpoint'ler için geçerli
   - 100 req/sec sınırı

2. **`TokenLimit = 100`**
   - Kovada maksimum 100 token
   - Burst için yedek

3. **`ReplenishmentPeriod = 1s`**
   - Her 1 saniyede token ekle

4. **`TokensPerPeriod = 100`**
   - Her saniye 100 token ekle
   - Sürekli yük: 100 req/sec

5. **`QueueLimit = 10`**
   - Token biterse 10 istek bekleyebilir
   - 11. istek hemen reddedilir

6. **`AddPolicy("go-api-calls")`**
   - Endpoint'e özel rate limit
   - `/api/go-time` için 20 req/sec

7. **`OnRejected`**
   - Rate limit aşıldığında ne yapılacak
   - 429 status code
   - Retry-After header

### 4. Middleware Aktivasyonu

**Dosya:** `api/Program.cs`

```csharp
var app = builder.Build();

app.UseCors("AllowAll");
app.UseRateLimiter();  // ⚠️ CORS'tan sonra olmalı!
```

**Neden bu sıra?**
```
1. CORS → Preflight requests
2. Rate Limiter → Gerçek istekleri sınırla
3. Endpoint'ler → İş mantığı
```

### 5. Yeni Endpoint: Service-to-Service Communication

**Dosya:** `api/Program.cs`

```csharp
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
```

**Satır Satır Açıklama:**

1. **`IHttpClientFactory httpClientFactory`**
   - Dependency injection
   - Named client "GoApiClient" alınacak

2. **`CreateClient("GoApiClient")`**
   - Resiliency pipeline ile birlikte geliyor
   - Circuit breaker, retry otomatik

3. **`GetAsync("/api/worldclock?city=Istanbul")`**
   - Go API'nin worldclock endpoint'ini çağır
   - Base URL zaten ayarlı (datetime-api-go-service)

4. **`ReadFromJsonAsync<object>()`**
   - JSON response'u deserialize et
   - Dynamic object olarak al

5. **`Results.Ok(new { ... })`**
   - Wrapper response
   - Hangi servisten geldiğini göster
   - Timestamp ekle

6. **`catch (Exception ex)`**
   - Circuit open olabilir
   - Timeout olabilir
   - Network error olabilir
   - Hepsini yakala → 503 Service Unavailable

7. **`.RequireRateLimiting("go-api-calls")`**
   - Bu endpoint için özel rate limit
   - 20 req/sec

---

## 🐹 Go API Değişiklikleri

### 1. Go Modülleri Ekleme

**Dosya:** `api-go/go.mod`

```go
module github.com/esersahin/datetime-api-go

go 1.25.1

require (
	github.com/sony/gobreaker v1.0.0    // Circuit breaker
	golang.org/x/time v0.8.0             // Rate limiter
)
```

**Neden bu kütüphaneler?**

**gobreaker:**
- Production-proven (Sony tarafından kullanılıyor)
- Basit API
- State change callback'leri
- Customizable settings

**golang.org/x/time/rate:**
- Go'nun resmi extended library'si
- Token bucket implementasyonu
- Thread-safe
- Low overhead

### 2. Rate Limiter Middleware

**Dosya:** `api-go/middleware/ratelimit.go`

```go
package middleware

import (
	"net/http"
	"sync"
	"golang.org/x/time/rate"
)

// RateLimiter holds rate limiters per endpoint
type RateLimiter struct {
	limiters map[string]*rate.Limiter
	mu       sync.RWMutex
}

// NewRateLimiter creates a new rate limiter
func NewRateLimiter() *RateLimiter {
	return &RateLimiter{
		limiters: make(map[string]*rate.Limiter),
	}
}

// GetLimiter returns the rate limiter for a given key
func (rl *RateLimiter) GetLimiter(key string, r rate.Limit, b int) *rate.Limiter {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	limiter, exists := rl.limiters[key]
	if !exists {
		limiter = rate.NewLimiter(r, b)
		rl.limiters[key] = limiter
	}

	return limiter
}

// RateLimitMiddleware creates a rate limiting middleware
func RateLimitMiddleware(rl *RateLimiter, requestsPerSecond float64, burst int) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			limiter := rl.GetLimiter("global", rate.Limit(requestsPerSecond), burst)

			if !limiter.Allow() {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusTooManyRequests)
				w.Write([]byte(`{"error":"Rate limit exceeded","message":"Too many requests."}`))
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// PerEndpointRateLimitMiddleware creates per-endpoint rate limiting
func PerEndpointRateLimitMiddleware(rl *RateLimiter, endpoint string, requestsPerSecond float64, burst int) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			limiter := rl.GetLimiter(endpoint, rate.Limit(requestsPerSecond), burst)

			if !limiter.Allow() {
				reservation := limiter.Reserve()
				retryAfter := reservation.Delay()
				reservation.Cancel()

				w.Header().Set("Content-Type", "application/json")
				w.Header().Set("Retry-After", retryAfter.String())
				w.WriteHeader(http.StatusTooManyRequests)
				w.Write([]byte(`{"error":"Rate limit exceeded"}`))
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
```

**Satır Satır Açıklama:**

1. **`sync.RWMutex`**
   - Thread-safe map için
   - Concurrent access kontrolü
   - Read lock vs Write lock

2. **`map[string]*rate.Limiter`**
   - Her endpoint için ayrı limiter
   - Key: "global", "csharp-api-calls", vb.

3. **`rate.NewLimiter(r, b)`**
   - r: requests per second (float64)
   - b: burst size (int)
   - Token bucket algoritması

4. **`limiter.Allow()`**
   - Token var mı kontrol et
   - true → İzin ver
   - false → Reddet

5. **`limiter.Reserve()`**
   - Gelecek için token rezerve et
   - Delay() → Ne kadar beklemeli?
   - Cancel() → İptal et (sadece bilgi için kullandık)

6. **Middleware Pattern:**
   ```go
   func(http.Handler) http.Handler
   ```
   - Go'nun standard HTTP middleware pattern'i
   - Chain edilebilir
   - Reusable

### 3. Circuit Breaker Client (C# API için)

**Dosya:** `api-go/client/csharp_client.go`

```go
package client

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	"github.com/sony/gobreaker"
)

// CSharpAPIClient handles communication with C# API
type CSharpAPIClient struct {
	baseURL        string
	httpClient     *http.Client
	circuitBreaker *gobreaker.CircuitBreaker
}

// CSharpDateTimeResponse represents the response from C# API
type CSharpDateTimeResponse struct {
	Date      string `json:"date"`
	Time      string `json:"time"`
	DayOfWeek string `json:"dayOfWeek"`
	Timestamp string `json:"timestamp"`
}

// NewCSharpAPIClient creates a new client with circuit breaker
func NewCSharpAPIClient() *CSharpAPIClient {
	baseURL := os.Getenv("CSHARP_API_URL")
	if baseURL == "" {
		baseURL = "http://datetime-api-service"
	}

	// Circuit breaker settings
	settings := gobreaker.Settings{
		Name:        "CSharpAPI",
		MaxRequests: 3,                    // Half-open'da max 3 istek
		Interval:    10 * time.Second,     // 10 saniyede bir sayaçları sıfırla
		Timeout:     30 * time.Second,     // Open'dan half-open'a geçiş süresi
		ReadyToTrip: func(counts gobreaker.Counts) bool {
			failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
			return counts.Requests >= 5 && failureRatio >= 0.5
		},
		OnStateChange: func(name string, from gobreaker.State, to gobreaker.State) {
			fmt.Printf("Circuit Breaker '%s' changed from '%s' to '%s'\n", name, from, to)
		},
	}

	return &CSharpAPIClient{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
		circuitBreaker: gobreaker.NewCircuitBreaker(settings),
	}
}

// GetDateTime calls C# API with retry and circuit breaker
func (c *CSharpAPIClient) GetDateTime() (*CSharpDateTimeResponse, error) {
	var result *CSharpDateTimeResponse
	var err error

	// Execute with circuit breaker
	_, cbErr := c.circuitBreaker.Execute(func() (interface{}, error) {
		// Retry logic with exponential backoff
		maxRetries := 3
		for attempt := 0; attempt < maxRetries; attempt++ {
			result, err = c.makeRequest()
			if err == nil {
				return result, nil
			}

			// Exponential backoff: 100ms, 200ms, 400ms
			if attempt < maxRetries-1 {
				backoff := time.Duration(100*(1<<uint(attempt))) * time.Millisecond
				time.Sleep(backoff)
			}
		}
		return nil, err
	})

	if cbErr != nil {
		return nil, fmt.Errorf("circuit breaker error: %w", cbErr)
	}

	return result, err
}

// makeRequest performs the actual HTTP request
func (c *CSharpAPIClient) makeRequest() (*CSharpDateTimeResponse, error) {
	url := fmt.Sprintf("%s/api/datetime", c.baseURL)
	resp, err := c.httpClient.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to call C# API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("C# API returned status %d: %s", resp.StatusCode, string(body))
	}

	var response CSharpDateTimeResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &response, nil
}

// GetCircuitBreakerState returns the current state
func (c *CSharpAPIClient) GetCircuitBreakerState() gobreaker.State {
	return c.circuitBreaker.State()
}
```

**Satır Satır Açıklama:**

1. **`gobreaker.Settings`**
   ```go
   Name: "CSharpAPI"  // Circuit breaker adı (log için)
   ```

2. **`MaxRequests: 3`**
   - Half-open state'de maksimum 3 istek dene
   - Başarılı → Closed'a geç
   - Başarısız → Open'a geri dön

3. **`Interval: 10s`**
   - Her 10 saniyede başarı/hata sayaçlarını sıfırla
   - Sliding window değil, tumbling window

4. **`Timeout: 30s`**
   - Open state'de 30 saniye bekle
   - Sonra half-open'a geç

5. **`ReadyToTrip`**
   ```go
   failureRatio := TotalFailures / Requests
   return Requests >= 5 && failureRatio >= 0.5
   ```
   - En az 5 istek olmalı
   - %50 başarısızlık oranı → Circuit aç

6. **`OnStateChange`**
   - State değiştiğinde log bas
   - Monitoring için önemli

7. **Exponential Backoff:**
   ```go
   100 * (1 << attempt)
   attempt=0: 100ms
   attempt=1: 200ms
   attempt=2: 400ms
   ```

8. **`circuitBreaker.Execute()`**
   - Tüm circuit breaker logic'i
   - Closure içinde retry logic
   - Error handling otomatik

### 4. Yeni Handler'lar

**Dosya:** `api-go/handlers/interop.go`

```go
package handlers

import (
	"net/http"
	"time"

	"github.com/esersahin/datetime-api-go/client"
	"github.com/esersahin/datetime-api-go/models"
)

// CSharpDateTimeHandler calls C# API
func CSharpDateTimeHandler(csharpClient *client.CSharpAPIClient) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		data, err := csharpClient.GetDateTime()
		if err != nil {
			respondWithError(w, http.StatusServiceUnavailable,
				"service_unavailable",
				"Failed to call C# API: "+err.Error())
			return
		}

		response := struct {
			Source           string                              `json:"source"`
			CalledService    string                              `json:"calledService"`
			Endpoint         string                              `json:"endpoint"`
			Data             *client.CSharpDateTimeResponse      `json:"data"`
			Timestamp        time.Time                           `json:"timestamp"`
			CircuitBreaker   string                              `json:"circuitBreakerState"`
		}{
			Source:         "go-api",
			CalledService:  "csharp-api",
			Endpoint:       "/api/datetime",
			Data:           data,
			Timestamp:      time.Now().UTC(),
			CircuitBreaker: csharpClient.GetCircuitBreakerState().String(),
		}

		respondWithJSON(w, http.StatusOK, response)
	}
}

// ResiliencyStatusHandler returns resiliency status
func ResiliencyStatusHandler(csharpClient *client.CSharpAPIClient) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		response := models.ResiliencyStatus{
			Service:              "datetime-api-go",
			CircuitBreakerState:  csharpClient.GetCircuitBreakerState().String(),
			RateLimitConfigured:  true,
			RetryPolicyActive:    true,
			Timestamp:            time.Now(),
		}

		respondWithJSON(w, http.StatusOK, response)
	}
}
```

**Satır Satır Açıklama:**

1. **Dependency Injection:**
   ```go
   func Handler(client *Client) http.HandlerFunc
   ```
   - Client dependency olarak inject edilir
   - Testable
   - Reusable

2. **Circuit Breaker State Dönme:**
   - `closed` → Normal çalışıyor
   - `open` → Servis down
   - `half-open` → Test ediliyor

3. **Wrapper Response:**
   - Hangi servisten geldiğini göster
   - Circuit breaker state'i ekle
   - Debugging için faydalı

### 5. Main.go Güncellemeleri

**Dosya:** `api-go/main.go`

```go
func main() {
	// Initialize C# API client with circuit breaker
	csharpClient := client.NewCSharpAPIClient()
	log.Printf("🔌 C# API client initialized with circuit breaker")

	// Initialize rate limiter
	rateLimiter := middleware.NewRateLimiter()
	globalRateLimit := middleware.RateLimitMiddleware(rateLimiter, 150.0, 150)
	csharpAPIRateLimit := middleware.PerEndpointRateLimitMiddleware(rateLimiter, "csharp-api-calls", 30.0, 30)

	// ... existing endpoints ...

	// NEW: Service-to-service communication
	http.Handle("/api/csharp-datetime",
		csharpAPIRateLimit(
			globalRateLimit(
				chainMiddleware(
					handlers.CSharpDateTimeHandler(csharpClient),
					corsMiddleware,
					loggingMiddleware
				)
			)
		)
	)

	// NEW: Resiliency status
	http.HandleFunc("/api/resiliency-status",
		chainMiddleware(
			handlers.ResiliencyStatusHandler(csharpClient),
			corsMiddleware,
			loggingMiddleware
		)
	)

	log.Printf("🛡️  Resiliency features enabled:")
	log.Printf("   ✅ Circuit Breaker (5 failures → 30s break)")
	log.Printf("   ✅ Retry Policy (3 attempts with exponential backoff)")
	log.Printf("   ✅ Rate Limiting (Global: 150 req/sec, C# API: 30 req/sec)")

	http.ListenAndServe(":8080", nil)
}
```

**Middleware Chaining:**
```
Request
  ↓
csharpAPIRateLimit (30 req/sec)
  ↓
globalRateLimit (150 req/sec)
  ↓
corsMiddleware
  ↓
loggingMiddleware
  ↓
Handler
```

---

## ☸️ Kubernetes Değişiklikleri

### 1. Environment Variable'lar

**Dosya:** `k8s/api-deployment.yaml`

```yaml
env:
  - name: ASPNETCORE_ENVIRONMENT
    value: "Production"
  - name: TZ
    value: "Europe/Istanbul"
  - name: NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
  - name: GO_API_URL  # YENİ
    value: "http://datetime-api-go-service"
```

**Dosya:** `k8s/api-go-deployment.yaml`

```yaml
env:
  - name: TZ
    value: "Europe/Istanbul"
  - name: NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
  - name: CSHARP_API_URL  # YENİ
    value: "http://datetime-api-service"
```

**Neden Environment Variable?**

1. **12-Factor App:**
   - Config dışarıda
   - Code'da hardcoded değil

2. **Farklı Ortamlar:**
   ```
   Development: http://localhost:5000
   Staging: http://api.staging.local
   Production: http://datetime-api-service
   ```

3. **Service Discovery:**
   - Kubernetes DNS
   - Service name → IP çözümleme

### 2. Service DNS Çözümleme

**Kubernetes'te DNS nasıl çalışır?**

```
Service: datetime-api-go-service
Namespace: default

DNS Name:
├─ Kısa form: datetime-api-go-service
├─ Tam form: datetime-api-go-service.default.svc.cluster.local
└─ Çözümlenen IP: 10.96.87.242 (ClusterIP)

Pod'lar:
├─ 10.244.1.4 (kind-worker)
├─ 10.244.2.4 (kind-worker2)
└─ 10.244.2.5 (kind-worker2)

İstek Akışı:
C# API Pod → DNS Query (datetime-api-go-service)
           → CoreDNS → 10.96.87.242
           → kube-proxy → Load Balance
           → Pod seç (Round Robin)
           → 10.244.1.4
```

---

## 🧪 Test Senaryoları

### 1. Normal İletişim Testi

```bash
# C# API → Go API
curl http://api.local/api/go-time
```

**Beklenen:**
```json
{
  "source": "csharp-api",
  "calledService": "go-api",
  "endpoint": "/api/worldclock?city=Istanbul",
  "data": [ ... 20 şehir ... ],
  "timestamp": "2025-10-06T21:04:10.390258Z"
}
```

**İşlem Adımları:**
```
1. C# API → HttpClient.GetAsync()
2. Resiliency Pipeline → Retry + Circuit Breaker
3. Kubernetes DNS → datetime-api-go-service → 10.96.87.242
4. kube-proxy → Load Balance → Pod seç
5. Go API → /api/worldclock handler
6. Response → C# API
7. Wrapper response → Client
```

### 2. Circuit Breaker Testi

**Senaryo:** Go API'yi kapat, circuit breaker açılsın mı?

```bash
# Go API'yi kapat
kubectl scale deployment datetime-api-go --replicas=0

# C# API'den istek at
for i in {1..10}; do
  curl http://api.local/api/go-time
done
```

**Beklenen Davranış:**

```
İstek 1-3: Retry ile deneniyor → 503 Service Unavailable
İstek 4-5: Failure ratio %50'ye ulaştı → Circuit OPEN
İstek 6-10: Circuit open → Anında 503 (retry yok)

30 saniye sonra:
Circuit → HALF-OPEN
İstek 11: Test ediliyor
  → Başarısız (Go API hala down)
  → Circuit tekrar OPEN
```

**Log Çıktısı:**
```
Circuit Breaker 'CSharpAPI' changed from 'closed' to 'open'
```

### 3. Rate Limiting Testi

```bash
# 25 istek birden (limit: 20 req/sec)
for i in {1..25}; do
  curl -s http://api.local/api/go-time -o /dev/null -w "Request $i: %{http_code}\n"
done
```

**Beklenen:**
```
Request 1-20: 200 OK
Request 21: 429 Too Many Requests (kuyruğa girdi)
Request 22: 429 Too Many Requests (kuyruğa girdi)
Request 23-25: 429 Too Many Requests (kuyruk dolu)
```

**Response (429):**
```json
{
  "error": "Rate limit exceeded",
  "message": "Too many requests. Please try again later.",
  "retryAfter": 0.5
}
```

### 4. Retry Policy Testi

**Senaryo:** Go API yavaş yanıt veriyor (timeout)

```bash
# Go API'de gecikme ekle (test için)
kubectl exec -it deployment/datetime-api-go -- sh
# Handler'a time.Sleep(15*time.Second) ekle

# C# API'den istek at
time curl http://api.local/api/go-time
```

**Beklenen Davranış:**

```
1. deneme → 10s timeout → Retry
2. deneme → 10s timeout → Retry
3. deneme → 10s timeout → Fail
Total: ~30s

Response: 503 Service Unavailable
```

### 5. Resiliency Status Testi

```bash
curl http://api-go.local/api/resiliency-status | jq
```

**Response:**
```json
{
  "service": "datetime-api-go",
  "circuitBreakerState": "closed",
  "rateLimitConfigured": true,
  "retryPolicyActive": true,
  "timestamp": "2025-10-07T00:04:26.813296335+03:00"
}
```

---

## 🔧 Sorun Giderme

### Problem 1: Circuit Breaker Validation Error

**Hata:**
```
OptionsValidationException: The sampling duration of circuit breaker
strategy needs to be at least double of an attempt timeout strategy's
timeout interval. Sampling Duration: 10s, Attempt Timeout: 10s
```

**Sebep:**
.NET 9'un resiliency pipeline'ı, circuit breaker'ın doğru çalışması için sampling duration'ın timeout'tan en az 2 kat fazla olmasını istiyor.

**Çözüm:**
```csharp
// YANLIŞ
CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(10);
TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(10);

// DOĞRU
CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(30);
TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(10);
```

### Problem 2: Go Build Error - Missing go.sum

**Hata:**
```
missing go.sum entry for module providing package github.com/sony/gobreaker
```

**Sebep:**
go.mod'da dependency tanımlı ama go.sum'da hash yok.

**Çözüm:**
```bash
cd api-go
go mod tidy  # go.sum'ı günceller
```

### Problem 3: Rate Limiter Time() Method Not Found

**Hata:**
```
limiter.Reserve().Time undefined
```

**Sebep:**
golang.org/x/time/rate kütüphanesinin API'si değişmiş.

**Çözüm:**
```go
// YANLIŞ
retryAfter := time.Until(limiter.Reserve().Time())

// DOĞRU
reservation := limiter.Reserve()
retryAfter := reservation.Delay()
reservation.Cancel()
```

### Problem 4: Service Discovery Çalışmıyor

**Semptom:**
```
Failed to call Go API: Get "http://datetime-api-go-service":
dial tcp: lookup datetime-api-go-service: no such host
```

**Debug:**
```bash
# 1. Service var mı?
kubectl get svc datetime-api-go-service

# 2. DNS çalışıyor mu?
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
nslookup datetime-api-go-service

# 3. Environment variable doğru mu?
kubectl exec deployment/datetime-api -- env | grep GO_API_URL
```

**Çözüm:**
- Service yoksa: `kubectl apply -f k8s/api-go-deployment.yaml`
- DNS çalışmıyorsa: CoreDNS pod'ları kontrol et
- Env variable yanlışsa: Deployment YAML'ı düzelt

### Problem 5: Circuit Breaker Sürekli Open

**Semptom:**
```
Circuit breaker 'CSharpAPI' is open
```

**Debug:**
```bash
# 1. Hedef servis çalışıyor mu?
kubectl get pods -l app=datetime-api
kubectl logs -l app=datetime-api --tail=20

# 2. Network bağlantısı var mı?
kubectl exec deployment/datetime-api-go -- wget -O- http://datetime-api-service/health

# 3. Circuit breaker state'i
curl http://api-go.local/api/resiliency-status
```

**Çözüm:**
```bash
# Hedef servisi yeniden başlat
kubectl rollout restart deployment/datetime-api

# 30 saniye bekle (BreakDuration)
# Circuit half-open'a geçecek ve tekrar deneyecek
```

---

## 🚀 Gelecek İyileştirmeler

### 1. Distributed Tracing

**Ne?** İsteklerin servisler arası yolculuğunu izleme.

**Neden?**
- Hangi servis yavaş?
- Hata nerede oluştu?
- Dependency chain görselleştirme

**Nasıl?**
```csharp
// OpenTelemetry kullan
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddJaegerExporter());
```

### 2. Health Check Aggregation

**Ne?** Servislerin birbirlerinin health'ini kontrol etmesi.

**Örnek:**
```csharp
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy())
    .AddUrlGroup(new Uri($"{goApiUrl}/health"), "go-api");
```

**Response:**
```json
{
  "status": "Healthy",
  "checks": {
    "self": "Healthy",
    "go-api": "Healthy"
  }
}
```

### 3. Metrics & Monitoring

**Ne?** Rate limit hit count, circuit breaker open count vb.

**Prometheus Metrics:**
```csharp
var rateLimitCounter = Metrics.CreateCounter(
    "rate_limit_exceeded_total",
    "Total number of rate limit rejections"
);

options.OnRejected = async (context, token) =>
{
    rateLimitCounter.Inc();
    // ... error response
};
```

### 4. Adaptive Rate Limiting

**Ne?** Yük durumuna göre dinamik rate limit.

**Örnek:**
```
Normal yük: 100 req/sec
Yüksek CPU: 50 req/sec
Düşük bellek: 30 req/sec
```

### 5. Bulkhead Pattern

**Ne?** Farklı işlemler için ayrı resource pool'ları.

**Neden?**
```
C# API:
├─ Thread Pool 1: Go API çağrıları (max 10 concurrent)
├─ Thread Pool 2: Database queries (max 20 concurrent)
└─ Thread Pool 3: Diğer işlemler (unlimited)

→ Go API yavaşsa database etkilenmez
```

### 6. Service Mesh (Istio/Linkerd)

**Ne?** Resiliency logic'i sidecar proxy'ye taşıma.

**Avantaj:**
- Kod değişikliği yok
- Tüm diller için aynı özellikler
- Centralized configuration

**Nasıl Çalışır:**
```
C# Pod                        Go Pod
├─ App Container              ├─ App Container
└─ Envoy Sidecar              └─ Envoy Sidecar
   ├─ Circuit Breaker            ├─ Circuit Breaker
   ├─ Retry                      ├─ Retry
   ├─ Rate Limit                 ├─ Rate Limit
   └─ Metrics                    └─ Metrics
```

---

## 📊 Özet: Ne Yaptık, Neden Yaptık?

### Öncesi
```
❌ Servisler birbirinden bağımsız
❌ Hata durumunda cascading failure
❌ Rate limiting yok → DDoS riski
❌ Retry yok → Geçici hatalar kalıcı oluyor
❌ Circuit breaker yok → Çöken servise istek yağmuru
```

### Sonrası
```
✅ C# ↔ Go servisler arası iletişim
✅ Circuit Breaker → Çöken servisi korur
✅ Retry Policy → Geçici hataları çözer
✅ Rate Limiting → Aşırı yükü önler
✅ Timeout → Kaynakları boşa harcamaz
✅ Service Discovery → IP bağımsız
✅ Monitoring-ready → State görünürlüğü
```

### Kazanımlar

**1. Production-Ready:**
- Gerçek dünya senaryolarına hazır
- Netflix/Amazon benzeri resiliency patterns

**2. Öğrenme:**
- .NET 9 built-in resiliency
- Go circuit breaker patterns
- Kubernetes service mesh temelleri
- Rate limiting algoritmaları
- Distributed systems best practices

**3. Genişletilebilir:**
- Yeni servisler eklenebilir
- Monitoring kolayca entegre edilir
- Service mesh'e geçiş kolay

---

## 📚 Kaynaklar

### Resmi Dokümantasyon
- [.NET 9 Resilience](https://learn.microsoft.com/en-us/dotnet/core/resilience/)
- [Rate Limiting in .NET](https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit)
- [gobreaker](https://github.com/sony/gobreaker)
- [golang.org/x/time/rate](https://pkg.go.dev/golang.org/x/time/rate)

### Patterns & Best Practices
- [Circuit Breaker Pattern - Martin Fowler](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Resilience Patterns - AWS](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/)
- [Rate Limiting - Stripe Blog](https://stripe.com/blog/rate-limiters)

### Kubernetes
- [Service Discovery](https://kubernetes.io/docs/concepts/services-networking/service/)
- [DNS for Services](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)

---

**Hazırlayan:** Claude (Anthropic)
**Tarih:** 2025-10-07
**Versiyon:** 1.0
**Proje:** DateTime Kubernetes Polyglot Microservices

using UAMIDemo.Web.Services;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = WebApplication.CreateBuilder(args);

// Load configuration based on environment
builder.Configuration
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: true)
    .AddEnvironmentVariables();

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddRazorPages();
builder.Services.AddControllersWithViews();

// Register Key Vault service
builder.Services.AddScoped<IKeyVaultService, KeyVaultService>();

// RuntimeConfigService holds live credential settings and IDs in memory.
// Seeded from appsettings / env vars on startup; updated at runtime via the
// Setup wizard. No secrets need to be committed to the code repository.
builder.Services.AddSingleton<RuntimeConfigService>();

// Add configuration for Azure settings
builder.Services.Configure<AzureSettings>(
    builder.Configuration.GetSection("Azure"));

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}
else
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();

app.MapControllers();
app.MapRazorPages();
app.MapGet("/", () => Results.Redirect("/index.html"));

app.Run();

using System.IdentityModel.Tokens.Jwt;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using OptimaHealthcare.Api.HostedServices;
using OptimaHealthcare.Api.Services;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Infrastructure.Auth;
using OptimaHealthcare.Infrastructure.Consultation;
using OptimaHealthcare.Infrastructure.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddCors(options =>
{
    options.AddPolicy("DevCors", policy =>
    {
        policy
            .SetIsOriginAllowed(origin =>
                origin.StartsWith("http://localhost:", StringComparison.OrdinalIgnoreCase) ||
                origin.StartsWith("https://localhost:", StringComparison.OrdinalIgnoreCase) ||
                origin.StartsWith("http://127.0.0.1:", StringComparison.OrdinalIgnoreCase))
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

builder.Services.AddScoped<IPatientReadService, InMemoryPatientReadService>();
builder.Services.AddScoped<IPatientDataService, SqlPatientDataService>();
builder.Services.AddScoped<IPatientVitalsService, SqlPatientVitalsService>();
builder.Services.AddScoped<IReferenceTypeService, SqlReferenceTypeService>();
builder.Services.AddScoped<IRecordTypeService, SqlRecordTypeService>();
builder.Services.AddScoped<IRecordKeywordService, SqlRecordKeywordService>();
builder.Services.AddScoped<IPatientMedicalRecordService, SqlPatientMedicalRecordService>();
builder.Services.AddScoped<IPatientRecordDetailService, SqlPatientRecordDetailService>();
builder.Services.AddScoped<IImageStorageService, CloudinaryImageStorageService>();
builder.Services.AddScoped<IPatientAppointmentService, SqlPatientAppointmentService>();
builder.Services.AddScoped<IInvoiceService, SqlInvoiceService>();
builder.Services.AddScoped<IDoctorAnalyticsService, SqlDoctorAnalyticsService>();
builder.Services.AddScoped<IMasterDataService, SqlMasterDataService>();
builder.Services.AddScoped<IUserAuthService, SqlAppUserAuthService>();
builder.Services.AddScoped<IPasswordCryptoService, LegacyPasswordCryptoService>();
builder.Services.AddScoped<IUserRegistrationService, SqlUserRegistrationService>();
builder.Services.AddScoped<IUserRoleLookupService, SqlUserRoleLookupService>();
builder.Services.AddScoped<IUserProfileService, SqlUserProfileService>();
builder.Services.AddScoped<IPasswordResetService, SqlPasswordResetService>();
builder.Services.AddScoped<IEmailService, SmtpEmailService>();
builder.Services.AddScoped<ISpeechService, SpeechService>();
builder.Services.AddScoped<ILLMService, LLMService>();
builder.Services.AddScoped<IConsultationProcessingService, ConsultationProcessingService>();
builder.Services.AddScoped<IConsultationNotesService, SqlConsultationNotesService>();
builder.Services.AddScoped<IAppointmentReminderService, AppointmentReminderService>();
builder.Services.AddHostedService<AppointmentReminderBackgroundService>();

var jwtSection = builder.Configuration.GetSection("Jwt");
var issuer = jwtSection["Issuer"] ?? throw new InvalidOperationException("Jwt:Issuer is required.");
var audience = jwtSection["Audience"] ?? throw new InvalidOperationException("Jwt:Audience is required.");
var key = jwtSection["Key"] ?? throw new InvalidOperationException("Jwt:Key is required.");
var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key));

// Keep JWT claim types as in token so "app_user_id" and role are findable
JwtSecurityTokenHandler.DefaultInboundClaimTypeMap.Clear();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateIssuerSigningKey = true,
            ValidateLifetime = true,
            NameClaimType = "unique_name",
            RoleClaimType = "role",
            ValidIssuer = issuer,
            ValidAudience = audience,
            IssuerSigningKey = signingKey,
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddSingleton<TokenFactory>();

var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Keep HTTP enabled in development to simplify emulator/device testing.
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseCors("DevCors");
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();

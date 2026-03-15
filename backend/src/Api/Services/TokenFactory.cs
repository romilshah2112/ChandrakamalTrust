using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace OptimaHealthcare.Api.Services;

public sealed class TokenFactory
{
    private readonly IConfiguration _configuration;

    public TokenFactory(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public (string token, DateTime expiresAtUtc) CreateToken(int appUserId, string username, string role)
    {
        var jwtSection = _configuration.GetSection("Jwt");
        var issuer = jwtSection["Issuer"]!;
        var audience = jwtSection["Audience"]!;
        var key = jwtSection["Key"]!;
        var ttlMinutes = int.TryParse(jwtSection["AccessTokenMinutes"], out var minutes) ? minutes : 60;

        var expiresAtUtc = DateTime.UtcNow.AddMinutes(ttlMinutes);
        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),
            SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new Claim(JwtRegisteredClaimNames.Sub, username),
            new Claim(ClaimTypes.Name, username),
            new Claim(ClaimTypes.NameIdentifier, appUserId.ToString()),
            new Claim("app_user_id", appUserId.ToString()),
            new Claim(ClaimTypes.Role, role),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        foreach (var normalizedRole in ExpandRoleAliases(role))
        {
            if (!string.Equals(normalizedRole, role, StringComparison.OrdinalIgnoreCase))
            {
                claims.Add(new Claim(ClaimTypes.Role, normalizedRole));
            }
        }

        var token = new JwtSecurityToken(
            issuer,
            audience,
            claims,
            expires: expiresAtUtc,
            signingCredentials: credentials);

        return (new JwtSecurityTokenHandler().WriteToken(token), expiresAtUtc);
    }

    private static IEnumerable<string> ExpandRoleAliases(string role)
    {
        if (string.IsNullOrWhiteSpace(role))
        {
            yield break;
        }

        var normalized = role.Trim();
        yield return normalized;

        if (normalized.Contains("admin", StringComparison.OrdinalIgnoreCase))
        {
            yield return "Admin";
            yield return "Administrator";
        }

        if (normalized.Contains("doctor", StringComparison.OrdinalIgnoreCase))
        {
            yield return "Doctor";
        }

        if (normalized.Contains("reception", StringComparison.OrdinalIgnoreCase))
        {
            yield return "Receptionist";
        }

        if (normalized.Contains("patient", StringComparison.OrdinalIgnoreCase))
        {
            yield return "Patient";
        }
    }
}

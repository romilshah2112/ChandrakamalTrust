using System.Security.Claims;

namespace OptimaHealthcare.Api.Security;

internal static class ClaimsPrincipalExtensions
{
    public static int GetAppUserId(this ClaimsPrincipal user)
    {
        var appUserIdClaim = user.FindFirstValue("app_user_id");
        if (int.TryParse(appUserIdClaim, out var appUserId))
        {
            return appUserId;
        }

        var candidateClaims = user.FindAll(ClaimTypes.NameIdentifier)
            .Concat(user.FindAll("nameid"));

        foreach (var claim in candidateClaims)
        {
            if (int.TryParse(claim.Value, out appUserId))
            {
                return appUserId;
            }
        }

        return 0;
    }

    public static string GetRoleName(this ClaimsPrincipal user)
        => user.FindFirstValue(ClaimTypes.Role)
            ?? user.FindFirstValue("role")
            ?? string.Empty;

    public static string? GetLoginName(this ClaimsPrincipal user)
        => user.FindFirstValue(ClaimTypes.Name)
            ?? user.FindFirstValue("unique_name")
            ?? user.FindFirstValue("sub");
}

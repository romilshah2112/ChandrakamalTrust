using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Api.Security;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Auth;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/user-profile")]
public sealed class UserProfileController : ControllerBase
{
    private readonly IUserProfileService _userProfileService;

    public UserProfileController(IUserProfileService userProfileService)
    {
        _userProfileService = userProfileService;
    }

    [HttpGet("me")]
    [ProducesResponseType(typeof(UserProfileResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<UserProfileResponse>> GetMe(CancellationToken cancellationToken)
    {
        var appUserId = User.GetAppUserId();
        var login = User.GetLoginName();

        if (appUserId <= 0 && string.IsNullOrWhiteSpace(login))
        {
            return Forbid();
        }

        UserProfileResponse? profile = null;
        if (appUserId > 0)
        {
            profile = await _userProfileService.GetByAppUserIdAsync(appUserId, cancellationToken);
        }

        if (profile is null && !string.IsNullOrWhiteSpace(login))
        {
            profile = await _userProfileService.GetByLoginAsync(login, cancellationToken);
        }

        if (profile is null)
        {
            return NotFound();
        }

        return Ok(profile);
    }

    [HttpPut("me")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> UpdateMe([FromBody] UpdateUserProfileRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.FirstName)
            || string.IsNullOrWhiteSpace(request.LastName)
            || string.IsNullOrWhiteSpace(request.EmailAddress)
            || string.IsNullOrWhiteSpace(request.MobileNumber))
        {
            return BadRequest("Invalid profile payload.");
        }

        if (!long.TryParse(request.MobileNumber, out _))
        {
            return BadRequest("Mobile number must be numeric.");
        }

        var appUserId = User.GetAppUserId();
        var login = User.GetLoginName();

        if (appUserId <= 0 && string.IsNullOrWhiteSpace(login))
        {
            return Forbid();
        }

        try
        {
            UserProfileResponse? profile = null;
            if (appUserId > 0)
            {
                profile = await _userProfileService.GetByAppUserIdAsync(appUserId, cancellationToken);
            }

            if (profile is null && !string.IsNullOrWhiteSpace(login))
            {
                profile = await _userProfileService.GetByLoginAsync(login, cancellationToken);
            }

            if (profile is null)
            {
                return NotFound("User profile not found.");
            }

            await _userProfileService.UpdateAsync(profile.AppUserId, request, cancellationToken);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }
}

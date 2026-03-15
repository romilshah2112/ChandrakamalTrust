using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Api.Services;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Auth;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Route("api/v1/auth")]
public sealed class AuthController : ControllerBase
{
    private static readonly string[] AllowedRoleNames = ["Patient", "Doctor", "Receptionist"];

    private readonly TokenFactory _tokenFactory;
    private readonly IUserAuthService _userAuthService;
    private readonly IUserRegistrationService _userRegistrationService;
    private readonly IUserRoleLookupService _userRoleLookupService;
    private readonly IPasswordResetService _passwordResetService;

    public AuthController(
        TokenFactory tokenFactory,
        IUserAuthService userAuthService,
        IUserRegistrationService userRegistrationService,
        IUserRoleLookupService userRoleLookupService,
        IPasswordResetService passwordResetService)
    {
        _tokenFactory = tokenFactory;
        _userAuthService = userAuthService;
        _userRegistrationService = userRegistrationService;
        _userRoleLookupService = userRoleLookupService;
        _passwordResetService = passwordResetService;
    }

    [HttpPost("login")]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<LoginResponse>> Login([FromBody] LoginRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Password))
        {
            return Unauthorized();
        }

        var user = await _userAuthService.AuthenticateAsync(request.Username.Trim(), request.Password, cancellationToken);
        if (user is null)
        {
            return Unauthorized();
        }

        var (token, expiresAtUtc) = _tokenFactory.CreateToken(user.AppUserId, user.Username, user.Role);

        return Ok(new LoginResponse
        {
            AppUserId = user.AppUserId,
            Username = user.Username,
            AccessToken = token,
            ExpiresAtUtc = expiresAtUtc,
            Role = user.Role
        });
    }

    [HttpPost("signup")]
    [ProducesResponseType(typeof(SignUpResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<SignUpResponse>> SignUp([FromBody] SignUpRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.FirstName)
            || string.IsNullOrWhiteSpace(request.LastName)
            || string.IsNullOrWhiteSpace(request.MobileNumber)
            || string.IsNullOrWhiteSpace(request.EmailAddress)
            || string.IsNullOrWhiteSpace(request.Password)
            || request.UserRoleId <= 0)
        {
            return BadRequest("Invalid signup payload.");
        }

        if (!long.TryParse(request.MobileNumber, out var mobileNumber))
        {
            return BadRequest("Mobile number must be numeric.");
        }

        var allowedRoles = await _userRoleLookupService.GetAllowedRolesAsync(cancellationToken);
        if (!allowedRoles.Any(r => r.UserRoleId == request.UserRoleId))
        {
            return BadRequest("Only Patient, Doctor, or Receptionist role is allowed.");
        }

        try
        {
            var newUserId = await _userRegistrationService.RegisterAsync(new Application.Models.AppUserRegistrationInput
            {
                FirstName = request.FirstName.Trim(),
                LastName = request.LastName.Trim(),
                MobileNumber = mobileNumber,
                EmailAddress = request.EmailAddress.Trim(),
                Password = request.Password,
                UserRoleId = request.UserRoleId
            }, cancellationToken);

            return StatusCode(StatusCodes.Status201Created, new SignUpResponse
            {
                AppUserId = newUserId,
                Message = "User created successfully."
            });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(ex.Message);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(ex.Message);
        }
    }

    [HttpPost("forgot-password")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.EmailAddress))
        {
            return BadRequest("Email address is required.");
        }

        await _passwordResetService.RequestPasswordResetAsync(request.EmailAddress.Trim(), cancellationToken);
        return Ok();
    }

    [HttpPost("reset-password")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Token) || string.IsNullOrWhiteSpace(request.NewPassword))
        {
            return BadRequest("Token and new password are required.");
        }

        var success = await _passwordResetService.ResetPasswordAsync(request.Token, request.NewPassword, cancellationToken);
        if (!success)
        {
            return NotFound("Invalid or expired reset token.");
        }

        return Ok();
    }

    [HttpGet("roles")]
    [ProducesResponseType(typeof(IReadOnlyList<UserRoleOptionResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<UserRoleOptionResponse>>> GetAllowedRoles(CancellationToken cancellationToken)
    {
        var roles = await _userRoleLookupService.GetAllowedRolesAsync(cancellationToken);
        var filtered = roles
            .Where(r => AllowedRoleNames.Any(a => string.Equals(a, r.RoleName, StringComparison.OrdinalIgnoreCase)))
            .OrderBy(r => r.RoleName)
            .ToList();
        return Ok(filtered);
    }
}

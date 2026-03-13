namespace OptimaHealthcare.Application.Abstractions;

public interface IPasswordResetService
{
    /// <summary>
    /// Initiates a password reset for the given email. Always returns successfully to avoid email enumeration.
    /// </summary>
    Task RequestPasswordResetAsync(string emailAddress, CancellationToken cancellationToken = default);

    /// <summary>
    /// Resets the password using a valid reset token.
    /// </summary>
    /// <returns>True if the reset was successful; false if the token is invalid or expired.</returns>
    Task<bool> ResetPasswordAsync(string token, string newPassword, CancellationToken cancellationToken = default);
}
